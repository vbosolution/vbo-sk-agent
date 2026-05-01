# VBO SkAgent — Global Instances Registry
#
# Quản lý danh sách các SU instance đang chạy SkAgent (qua MCP server).
# File: %APPDATA%/VBO/SkAgent/instances.json
#
# Mỗi instance đăng ký lúc McpServer.start, xóa lúc McpServer.stop.
# cleanup_stale loại bỏ entries có PID không còn process.

require 'json'
require 'fileutils'

module VBO
  module SkAgent
    module Instances
      BASE_DIR       = File.join(ENV['APPDATA'] || Dir.home, 'VBO', 'SkAgent')
      INSTANCES_FILE = File.join(BASE_DIR, 'instances.json')

      class << self
        # Đăng ký instance hiện tại (pid + thông tin MCP)
        # @param attrs [Hash] :pid, :mcp_port, :mcp_preferred, :mcp_url, :using_preferred
        def register(attrs)
          ensure_dir
          cleanup_stale
          data = read_safe
          data['instances'].reject! {|i| i['pid'] == attrs[:pid] }
          data['instances'] << {
            'pid'              => attrs[:pid],
            'sketchup_version' => (Sketchup.version rescue 'unknown'),
            'version_year'     => version_year,
            'mcp_port'         => attrs[:mcp_port],
            'mcp_preferred'    => attrs[:mcp_preferred],
            'mcp_url'          => attrs[:mcp_url],
            'using_preferred'  => attrs[:using_preferred],
            'started_at'       => Time.now.iso8601,
            'plugin_version'   => (VBO::SkAgent::PLUGIN_VERSION rescue 'unknown')
          }
          write_safe(data)
        end

        # Xóa entry theo pid
        def unregister(pid)
          return unless File.exist?(INSTANCES_FILE)
          data = read_safe
          data['instances'].reject! {|i| i['pid'] == pid }
          write_safe(data)
        end

        # Đọc danh sách hiện tại (đã cleanup_stale)
        def list
          ensure_dir
          cleanup_stale
          read_safe['instances']
        end

        # Số lượng instance khác (không tính mình)
        def others_count
          list.reject {|i| i['pid'] == Process.pid }.size
        end

        # Toàn bộ thông tin để Dashboard hiển thị
        def status_summary
          all = list
          {
            total:    all.size,
            current:  all.find {|i| i['pid'] == Process.pid },
            others:   all.reject {|i| i['pid'] == Process.pid },
            multi:    all.size > 1
          }
        end

        private

        def ensure_dir
          FileUtils.mkdir_p(BASE_DIR)
        end

        def read_safe
          if File.exist?(INSTANCES_FILE)
            JSON.parse(File.read(INSTANCES_FILE))
          else
            { 'instances' => [] }
          end
        rescue
          { 'instances' => [] }
        end

        def write_safe(data)
          File.write(INSTANCES_FILE, JSON.pretty_generate(data))
        rescue => e
          puts "[SkAgent Instances] write failed: #{e.message}"
        end

        # Loại bỏ entries có PID không còn process
        def cleanup_stale
          data = read_safe
          before = data['instances'].size
          data['instances'].reject! {|i| !process_alive?(i['pid']) }
          after = data['instances'].size
          write_safe(data) if before != after
        end

        def process_alive?(pid)
          return false unless pid.is_a?(Integer) && pid > 0
          # Windows: tasklist filter
          result = `tasklist /FI "PID eq #{pid}" /NH 2>NUL`
          result.include?(pid.to_s)
        rescue
          true  # an toàn: nếu không check được, coi như còn sống (tránh xóa nhầm)
        end

        def version_year
          major = Sketchup.version.split('.').first.to_i
          major >= 100 ? major : (major + 2000)
        rescue
          0
        end
      end
    end
  end
end
