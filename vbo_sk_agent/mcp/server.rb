# VBO SkAgent — MCP Server (Production)
# Architecture: V3 — accept_nonblock fully inline on main thread (P50=8ms, P95=27ms)
# Configurable port (default 7891), fallback ephemeral if occupied.
#
# Ported from VBO::LoadPlugins::McpServer (production-ready 2026-04-26)
# Public release adaptations:
#   - Namespace VBO::SkAgent
#   - Port từ Config.get('mcp_port') thay vì cứng
#   - PORT_DIR ở %APPDATA%/VBO/SkAgent/mcp/
#   - Register vào instances.json global khi start

require 'socket'
require 'json'
require 'fileutils'

module VBO
  module SkAgent
    module McpServer
      DEFAULT_PORT  = 7891
      PORT_DIR      = File.join(ENV['APPDATA'] || Dir.home, 'VBO', 'SkAgent', 'mcp')
      PORT_FILE     = File.join(PORT_DIR, '.port')
      INFO_FILE     = File.join(PORT_DIR, 'info.json')
      VERSION       = '1.0.0'.freeze
      MAX_BODY      = 1 * 1024 * 1024  # 1MB
      PUMP_INTERVAL = 0.01
      DRAIN_MAX     = 3
      READ_TIMEOUT  = 2.0

      @server         = nil unless defined?(@server)
      @timer_id       = nil unless defined?(@timer_id)
      @port           = nil unless defined?(@port)
      @preferred_port = nil unless defined?(@preferred_port)
      @running        = false unless defined?(@running)
      @mcp            = nil unless defined?(@mcp)
      @mcp_ready      = false unless defined?(@mcp_ready)
      @stats          = { requests: 0, errors: 0, started_at: nil, tick_count: 0 } unless defined?(@stats)

      class << self
        attr_reader :port, :preferred_port, :running, :stats

        def start
          return @port if @running
          FileUtils.mkdir_p(PORT_DIR)

          # Đọc port từ Config (default 7891) — cho phép user đổi qua Dashboard
          @preferred_port = begin
            VBO::SkAgent::Config.get('mcp_port').to_i
          rescue
            DEFAULT_PORT
          end
          @preferred_port = DEFAULT_PORT if @preferred_port <= 0 || @preferred_port > 65535

          # Try preferred port first, fallback to ephemeral
          begin
            @server = TCPServer.new('127.0.0.1', @preferred_port)
            @port   = @preferred_port
          rescue Errno::EADDRINUSE
            puts "[SkAgent MCP] Port #{@preferred_port} in use — falling back to ephemeral"
            puts "[SkAgent MCP] ⚠️  Multi-instance: open Dashboard for the new port number"
            @server = TCPServer.new('127.0.0.1', 0)
            @port   = @server.addr[1]
          end

          # Wrap post-bind init so any failure closes the socket cleanly (no orphan)
          begin
            File.write(PORT_FILE, @port.to_s)
            write_info_file
            register_in_global_instances
            @running  = true
            @stats    = { requests: 0, errors: 0, started_at: Time.now, tick_count: 0 }
            @timer_id = UI.start_timer(PUMP_INTERVAL, true) { tick }
            puts "[SkAgent MCP] Server on 127.0.0.1:#{@port}  (preferred=#{@port == @preferred_port})"
            puts "[SkAgent MCP] Stop: VBO::SkAgent::McpServer.stop"
            @port
          rescue => e
            puts "[SkAgent MCP] start() failed after bind: #{e.class}: #{e.message}"
            begin; @server.close if @server; rescue; end
            @server = nil
            @port   = nil
            @running = false
            raise
          end
        end

        def stop
          return unless @running
          @running = false
          UI.stop_timer(@timer_id) if @timer_id
          begin; @server.close if @server; rescue; end
          @server = @timer_id = nil
          File.delete(PORT_FILE) if File.exist?(PORT_FILE)
          unregister_from_global_instances
          puts "[SkAgent MCP] Stopped — #{@stats.inspect}"
        end

        def status
          {
            running:           @running,
            port:              @port,
            preferred_port:    @preferred_port || DEFAULT_PORT,
            using_preferred:   @port && @preferred_port && @port == @preferred_port,
            version:           VERSION,
            tick_count:        @stats[:tick_count],
            requests:          @stats[:requests],
            errors:            @stats[:errors],
            uptime_sec:        @stats[:started_at] ? (Time.now - @stats[:started_at]).to_i : 0
          }
        end

        private

        def write_info_file
          info = {
            mcp_url:          "http://127.0.0.1:#{@port}/mcp",
            port:             @port,
            preferred_port:   @preferred_port,
            using_preferred:  @port == @preferred_port,
            pid:              Process.pid,
            version:          VERSION,
            started_at:       Time.now.iso8601,
            sketchup_version: (Sketchup.version rescue 'unknown'),
            ruby_version:     RUBY_VERSION
          }
          File.write(INFO_FILE, JSON.pretty_generate(info))
        end

        def register_in_global_instances
          require_relative 'instances'
          VBO::SkAgent::Instances.register(
            pid:             Process.pid,
            mcp_port:        @port,
            mcp_preferred:   @preferred_port,
            mcp_url:         "http://127.0.0.1:#{@port}/mcp",
            using_preferred: @port == @preferred_port
          )
        rescue => e
          puts "[SkAgent MCP] register_in_global_instances failed: #{e.class}: #{e.message}"
        end

        def unregister_from_global_instances
          require_relative 'instances'
          VBO::SkAgent::Instances.unregister(Process.pid)
        rescue => e
          puts "[SkAgent MCP] unregister_from_global_instances failed: #{e.class}: #{e.message}"
        end

        # Main timer callback — runs entirely on SU main thread, zero GVL wait
        def tick
          @stats[:tick_count] += 1
          DRAIN_MAX.times do
            # exception: false → returns :wait_readable instead of raising.
            # Critical: prevents TracePoint flooding when scoped capture is active
            # (e.g. modal UI.messagebox keeps timer firing during user interaction).
            client = begin
              @server.accept_nonblock(exception: false)
            rescue IOError, Errno::EBADF
              break
            rescue => e
              puts "[SkAgent MCP] accept error: #{e.class}: #{e.message}" if @running
              break
            end
            break if client == :wait_readable || client.nil?

            begin
              client.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) rescue nil
              handle_client(client)
            rescue => e
              @stats[:errors] += 1
              begin; write_response(client, 500, { 'error' => e.message }); rescue; end
            ensure
              begin; client.close; rescue; end
            end
          end
        end

        def handle_client(client)
          request_line = read_line_with_timeout(client)
          return unless request_line

          headers = {}
          loop do
            line = read_line_with_timeout(client)
            break if line.nil? || line == "\r\n"
            k, v = line.chomp.split(': ', 2)
            headers[k.downcase] = v if k
          end

          host = headers['host'] || ''
          unless host =~ /\A(127\.0\.0\.1|localhost)(:\d+)?\z/
            return write_response(client, 403, { 'error' => 'Origin denied' })
          end

          body = nil
          if (len_str = headers['content-length'])
            len = len_str.to_i
            return write_response(client, 413, { 'error' => 'Body too large' }) if len > MAX_BODY
            body = client.read(len) if len > 0
          end

          method_verb, path, = request_line.split(' ', 3)
          route(client, method_verb, path, body)
        end

        def read_line_with_timeout(client, timeout_sec = READ_TIMEOUT)
          ready = IO.select([client], nil, nil, timeout_sec)
          return nil unless ready
          client.gets
        end

        def route(client, method, path, body)
          case [method, path]
          when ['GET', '/health']
            write_response(client, 200, status.merge(
              'ok'               => true,
              'sketchup_version' => (Sketchup.version rescue 'unknown'),
              'ruby_version'     => RUBY_VERSION
            ))

          when ['POST', '/mcp']
            @stats[:requests] += 1
            setup_mcp unless @mcp_ready
            response_json = @mcp.handle_json(body || '{}')
            body_str = response_json.is_a?(String) ? response_json : response_json.to_json
            write_raw_response(client, 200, 'application/json', body_str)

          when ['POST', '/shutdown']
            write_response(client, 200, { 'ok' => true, 'message' => 'Shutting down...' })
            Thread.new { sleep 0.2; stop }

          else
            write_response(client, 404, { 'error' => "Not found: #{method} #{path}" })
          end
        end

        def setup_mcp
          return if @mcp_ready

          vendor = File.join(__dir__, 'vendor')
          [
            File.join(vendor, 'mcp-0.13.0/lib'),
            File.join(vendor, 'json-schema-6.2.0/lib'),
            File.join(vendor, 'addressable-2.9.0/lib'),
            File.join(vendor, 'public_suffix-7.0.5/lib')
          ].each { |p| $LOAD_PATH.unshift(File.expand_path(p)) unless $LOAD_PATH.include?(File.expand_path(p)) }

          require 'mcp'

          # Skip schema self-validation — File.realpath fails on paths with spaces (G: drive)
          MCP::Tool::Schema.class_eval { def validate_schema!; end }

          Sketchup.require File.join(__dir__, 'console_capture')
          Sketchup.require File.join(__dir__, 'tools')

          @mcp = MCP::Server.new(
            name: 'vbo-sketchup',
            version: VERSION,
            tools: VBO::SkAgent::McpTools.all
          )
          @mcp_ready = true
          puts "[SkAgent MCP] MCP layer ready — #{VBO::SkAgent::McpTools.all.size} tools"
        end

        STATUS_TEXT = {
          200 => 'OK', 400 => 'Bad Request', 403 => 'Forbidden',
          404 => 'Not Found', 413 => 'Payload Too Large',
          500 => 'Internal Server Error'
        }.freeze

        def write_response(client, status_code, body_obj)
          write_raw_response(client, status_code, 'application/json', body_obj.to_json)
        end

        def write_raw_response(client, status_code, content_type, body_str)
          status_text = STATUS_TEXT[status_code] || 'OK'
          client.write(
            "HTTP/1.1 #{status_code} #{status_text}\r\n" \
            "Content-Type: #{content_type}; charset=utf-8\r\n" \
            "Content-Length: #{body_str.bytesize}\r\n" \
            "Connection: close\r\n" \
            "\r\n" \
            "#{body_str}"
          )
        end
      end
    end
  end
end
