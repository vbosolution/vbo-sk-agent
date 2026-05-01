require 'json'
require 'stringio'

module VBO
  module SkAgent
    module Bridge
      BRIDGE_DIR   = File.join(__dir__, 'bridge')
      COMMAND_FILE = File.join(BRIDGE_DIR, 'command.rb')
      RESULT_FILE  = File.join(BRIDGE_DIR, 'result.json')

      ENVELOPE_MARKER = '# __SKAGENT__'.freeze
      TEMPLATE_PREFIX = '# VBO SkAgent'.freeze

      # State — survive reloads
      @timer_id   = nil unless defined?(@timer_id)
      @watching   = false unless defined?(@watching)
      @last_mtime = nil unless defined?(@last_mtime)
      @history    = [] unless defined?(@history)

      # --- Start / Stop / Toggle ---

      def self.watching?
        @watching
      end

      def self.toggle
        if @watching
          stop
        else
          start
        end
      end

      def self.start
        return if @watching
        ensure_bridge_dir
        @last_mtime = File.exist?(COMMAND_FILE) ? File.mtime(COMMAND_FILE) : Time.now
        interval = Config.get('poll_interval')
        @timer_id = UI.start_timer(interval, true) { check_command }
        @watching = true
        puts "[SkAgent] Bridge connected. Watching: #{COMMAND_FILE}"
      end

      def self.stop
        if @timer_id
          UI.stop_timer(@timer_id)
          @timer_id = nil
        end
        @watching = false
        Config.reset_session
        puts '[SkAgent] Bridge disconnected.'
      end

      def self.ensure_bridge_dir
        Dir.mkdir(BRIDGE_DIR) unless File.directory?(BRIDGE_DIR)
        unless File.exist?(COMMAND_FILE)
          File.write(COMMAND_FILE, "# VBO SkAgent — Command File\n# AI agent: write Ruby code here\n")
        end
      end

      # --- Command Detection ---

      def self.check_command
        return unless File.exist?(COMMAND_FILE)
        @last_mtime ||= Time.now

        current_mtime = File.mtime(COMMAND_FILE)
        if current_mtime > @last_mtime
          @last_mtime = current_mtime
          UI.start_timer(0.15, false) { process_command }
        end
      rescue => e
        puts "[SkAgent] Watch error: #{e.message}"
      end

      def self.process_command
        raw = File.read(COMMAND_FILE)
        return if raw.strip.empty?
        return if raw.start_with?(TEMPLATE_PREFIX)

        envelope, code = parse_envelope(raw)

        # Safety check
        if Config.get('safety_mode') && !Config.session_trusted?
          return unless safety_prompt(code)
        end

        execute(envelope, code)
      end

      # --- Envelope Parsing ---

      def self.parse_envelope(raw)
        lines = raw.lines
        if lines.first&.strip == ENVELOPE_MARKER
          json_line = lines[1]&.sub(/^#\s*/, '')
          begin
            envelope = JSON.parse(json_line)
            code = lines[2..].join
            [envelope, code]
          rescue JSON::ParserError
            [{}, raw]
          end
        else
          [{}, raw]
        end
      end

      # --- Execution ---

      def self.execute(envelope, code)
        start_time = Time.now
        captured = StringIO.new
        old_stdout = $stdout

        begin
          $stdout = captured
          eval(code, TOPLEVEL_BINDING, COMMAND_FILE, 1)
          $stdout = old_stdout

          duration = ((Time.now - start_time) * 1000).round
          write_result(envelope, 'success', captured.string, duration, nil)
        rescue => e
          $stdout = old_stdout
          duration = ((Time.now - start_time) * 1000).round

          puts "[SkAgent] Error: #{e.message}"
          puts e.backtrace.first(5).join("\n")

          write_result(envelope, 'error', captured.string, duration, e)
        end
      end

      # --- Safety Prompt ---

      def self.safety_prompt(code)
        snippet = code.lines.first(8).join
        snippet += "\n..." if code.lines.length > 8

        result = UI.messagebox(
          "AI Agent wants to run code:\n\n#{snippet}\n\nAllow?",
          MB_YESNO
        )

        if result == IDYES
          trust = UI.messagebox(
            "Trust this session?\n(Won't ask again until bridge is toggled off)",
            MB_YESNO
          )
          Config.trust_session! if trust == IDYES
          true
        else
          write_result({}, 'rejected', nil, 0, 'User rejected execution')
          false
        end
      end

      # --- Result Writer ---

      def self.write_result(envelope, status, stdout_text, duration_ms, error)
        data = {
          'id'        => envelope['id'],
          'status'    => status,
          'timestamp' => Time.now.to_i,
          'duration_ms' => duration_ms,
          'stdout'    => stdout_text.to_s,
        }

        if error.is_a?(Exception)
          data['error']     = error.message
          data['backtrace'] = error.backtrace&.first(10)
        end

        data['sketchup_version'] = Sketchup.version
        data['ruby_version']     = RUBY_VERSION
        data['bridge_version']   = PLUGIN_VERSION

        data.delete_if {|_k, v| v.nil? || (v.is_a?(String) && v.empty?) }

        File.write(RESULT_FILE, JSON.pretty_generate(data))

        # History cho dashboard
        snippet = code_snippet(3) rescue '?'
        @history.unshift({
          timestamp: Time.now.to_i,
          status: status,
          snippet: snippet,
          duration_ms: duration_ms,
        })
        @history = @history.first(20)
      rescue => e
        puts "[SkAgent] Failed to write result: #{e.message}"
      end

      # --- Public API ---

      def self.code_snippet(lines = 3)
        File.read(COMMAND_FILE).lines.reject {|l| l.start_with?('#') }.first(lines).join.strip[0..80]
      end

      def self.history
        @history || []
      end

      def self.command_file_path
        COMMAND_FILE.tr('\\', '/')
      end

      def self.result_file_path
        RESULT_FILE.tr('\\', '/')
      end

      def self.bridge_dir_path
        BRIDGE_DIR.tr('\\', '/')
      end

      def self.plugins_dir_path
        dir = File.expand_path(File.join(__dir__, '..'))
        dir.tr('\\', '/')
      end

      def self.status_info
        info = {
          watching: @watching,
          command_path: command_file_path,
          result_path: result_file_path,
          plugins_dir: plugins_dir_path,
          safety_mode: Config.get('safety_mode'),
          session_trusted: Config.session_trusted?,
          history: history,
          version: PLUGIN_VERSION,
          sketchup_version: Sketchup.version,
        }

        # MCP transport (v1.2.0+) — gắn vào status_info để Dashboard đọc
        mcp_status = mcp_status_safe
        info[:transport_mode] = Config.get('transport_mode')
        info[:mcp]            = mcp_status
        info[:instances]      = instances_summary_safe

        info
      end

      # Helper: trạng thái MCP (an toàn nếu McpServer chưa load)
      def self.mcp_status_safe
        return { available: false } unless defined?(VBO::SkAgent::McpServer)
        s = VBO::SkAgent::McpServer.status
        s[:available] = true
        s[:fallback_warning] = (s[:running] && !s[:using_preferred]) ?
          "Port #{s[:preferred_port]} đang bị instance khác chiếm — đang chạy ephemeral #{s[:port]}." : nil
        s
      rescue => e
        { available: false, error: e.message }
      end

      # Helper: tóm tắt multi-instance
      def self.instances_summary_safe
        return { total: 1, multi: false } unless defined?(VBO::SkAgent::Instances)
        VBO::SkAgent::Instances.status_summary
      rescue => e
        { total: 1, multi: false, error: e.message }
      end

      # Bật/tắt MCP server (Dashboard callback)
      def self.toggle_mcp
        return false unless defined?(VBO::SkAgent::McpServer)
        if VBO::SkAgent::McpServer.running
          VBO::SkAgent::McpServer.stop
        else
          VBO::SkAgent::McpServer.start
        end
        true
      end
    end
  end
end
