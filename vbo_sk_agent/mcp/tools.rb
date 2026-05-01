# VBO SkAgent — MCP Tool Definitions
#
# 4 tools: execute_ruby, reload_file, list_instances, get_console_output
#
# Workarounds applied (from LoadPlugins POC 1b):
#   - Raw hash content items  → MCP::Tool::Response.new([{type:, text:}])
#   - Keyword block args      → |**args|

require 'json'

module VBO
  module SkAgent
    module McpTools
      class << self
        def all
          [execute_ruby_tool, reload_file_tool, list_instances_tool, get_console_output_tool]
        end

        private

        def execute_ruby_tool
          # Capture method ref before block — MCP gem uses instance_exec so implicit
          # self changes; local var `fmt` survives because it's a closure capture.
          fmt = method(:format_execute)
          MCP::Tool.define(
            name: 'execute_ruby',
            description: 'Execute Ruby code in SketchUp (main thread). Returns result, stdout, errors.',
            input_schema: {
              type: 'object',
              properties: {
                code:         { type: 'string',  description: 'Ruby code to execute' },
                timeout_ms:   { type: 'integer', description: 'Timeout ms (default 30000, not enforced server-side for main-thread evals)' },
                deep_capture: { type: 'boolean', description: 'Enable Exception.prepend capture (default false)' }
              },
              required: ['code']
            }
          ) {|**args|
            result = VBO::SkAgent::ConsoleCapture.execute(
              args[:code].to_s,
              deep: args[:deep_capture] == true
            )
            MCP::Tool::Response.new(
              [{ type: 'text', text: fmt.call(result) }],
              error: result[:status] != 'ok'
            )
          }
        end

        def reload_file_tool
          MCP::Tool.define(
            name: 'reload_file',
            description: 'Reload a Ruby file in SketchUp. Bypasses file_loaded? guard.',
            input_schema: {
              type: 'object',
              properties: {
                file_path: { type: 'string', description: 'Absolute path to .rb file' }
              },
              required: ['file_path']
            }
          ) {|**args|
            path = args[:file_path].to_s
            begin
              load path
              MCP::Tool::Response.new([{ type: 'text', text: "ok: reloaded #{File.basename(path)}" }])
            rescue => e
              MCP::Tool::Response.new(
                [{ type: 'text', text: "error: #{e.class}: #{e.message}" }],
                error: true
              )
            end
          }
        end

        def list_instances_tool
          MCP::Tool.define(
            name: 'list_instances',
            description: 'List all SketchUp instances running with VBO SkAgent. Includes a warning when multiple instances are detected (port conflicts may require manual MCP config update).',
            input_schema: { type: 'object', properties: {} }
          ) {|**args|
            require_relative 'instances'
            summary = VBO::SkAgent::Instances.status_summary

            payload = {
              total:           summary[:total],
              multi_instance:  summary[:multi],
              current:         summary[:current],
              others:          summary[:others]
            }

            if summary[:multi]
              payload[:warning] = (
                "⚠️  Multi-instance detected: #{summary[:total]} SketchUp instances running with SkAgent. " \
                "MCP port 7891 (preferred) is bound to ONE instance only — others fall back to ephemeral ports. " \
                "If the agent is connected to the wrong instance, update the MCP config with the correct port from this list."
              )
            end

            MCP::Tool::Response.new([{ type: 'text', text: payload.to_json }])
          }
        end

        def get_console_output_tool
          MCP::Tool.define(
            name: 'get_console_output',
            description: 'Get recent background errors captured by TracePoint during execute_ruby calls.',
            input_schema: {
              type: 'object',
              properties: {
                limit: { type: 'integer', description: 'Max entries to return (default 20)' }
              }
            }
          ) {|**args|
            limit  = [(args[:limit] || 20).to_i, 100].min
            buffer = VBO::SkAgent::ConsoleCapture.background_buffer.last(limit)
            MCP::Tool::Response.new([{ type: 'text', text: buffer.to_json }])
          }
        end

        def format_execute(r)
          lines = ["status: #{r[:status]}"]

          if r[:status] == 'ok'
            lines << "result: #{r[:result]}"
          else
            lines << "error_class: #{r[:error_class]}"
            lines << "error: #{r[:error]}"
            bt = r[:backtrace] || []
            lines << "backtrace:\n#{bt.join("\n")}" unless bt.empty?
          end

          lines << "output:\n#{r[:output]}" unless r[:output].to_s.empty?
          lines << "duration: #{r[:duration_ms]}ms"

          h = r[:capture_health] || {}
          lines << "⚠️  guard_detections: #{h[:guard_detections]}" unless h[:tracepoint_healthy]
          bg = r[:background_errors] || []
          lines << "background_errors (#{bg.size}):\n#{bg.to_json}" if bg.any?

          lines.join("\n")
        end
      end
    end
  end
end
