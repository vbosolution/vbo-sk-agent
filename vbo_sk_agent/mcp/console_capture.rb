# VBO SkAgent — Console Capture (3 layers)
#
# Layer 1: StringIO redirect ($stdout/$stderr) — always ON
# Layer 2A: Scoped TracePoint (:raise) — ON within execute scope only
# Layer 2B: Self-healing monitor thread — detects if guard disabled TracePoint
# Layer 2C: Exception.prepend fallback — opt-in via deep: true
#
# Ported from VBO::LoadPlugins::ConsoleCapture (production-ready 2026-04-26)

require 'stringio'

module VBO
  module SkAgent
    module ConsoleCapture
      IGNORE_CLASSES     = [StopIteration, SystemExit, Interrupt, LocalJumpError,
                            ThreadError, IOError, Errno::EPIPE,
                            IO::WaitReadable, IO::WaitWritable,
                            Errno::EAGAIN, Errno::EWOULDBLOCK].freeze
      BACKGROUND_CAP     = 100

      @background_buffer = [] unless defined?(@background_buffer)

      class << self
        attr_reader :background_buffer

        def execute(code, deep: false)
          t0 = Time.now

          # Layer 1: StringIO redirect
          captured = StringIO.new
          old_out  = $stdout
          old_err  = $stderr
          $stdout  = captured
          $stderr  = captured

          # Layer 2A: Scoped TracePoint (enable only for duration of eval)
          tp_buffer = []
          tp = TracePoint.new(:raise) {|evt|
            ex = evt.raised_exception
            next if IGNORE_CLASSES.any? {|c| ex.is_a?(c) }
            tp_buffer << {
              time:    Time.now.iso8601(3),
              class:   ex.class.name,
              message: ex.message,
              file:    evt.path,
              line:    evt.lineno,
              source:  'tracepoint'
            }
          }
          tp.enable

          # Layer 2B: Self-healing monitor (detect TracePoint guard)
          guard_detections = []
          monitor = Thread.new {
            until Thread.current[:stop]
              unless tp.enabled?
                guard_detections << { time: Time.now.iso8601(3) }
                break
              end
              sleep 0.01
            end
          }

          # Layer 2C: Exception.prepend (opt-in deep mode)
          Thread.current[:vbo_capture] = tp_buffer if deep

          status     = nil
          result_val = nil
          error_msg  = nil
          error_cls  = nil
          backtrace  = nil

          begin
            value      = eval(code, TOPLEVEL_BINDING)
            status     = 'ok'
            result_val = value.inspect
          rescue Exception => e
            status    = 'error'
            error_msg = e.message
            error_cls = e.class.name
            backtrace = (e.backtrace || []).first(20)
          ensure
            $stdout = old_out
            $stderr = old_err
            tp.disable
            monitor[:stop] = true
            Thread.current[:vbo_capture] = nil if deep
          end

          @background_buffer = (@background_buffer + tp_buffer).last(BACKGROUND_CAP)

          {
            status:            status,
            result:            result_val,
            output:            captured.string,
            error:             error_msg,
            error_class:       error_cls,
            backtrace:         backtrace,
            duration_ms:       ((Time.now - t0) * 1000).to_i,
            background_errors: tp_buffer,
            capture_health:    {
              tracepoint_healthy: guard_detections.empty?,
              guard_detections:   guard_detections.size,
              deep_mode:          deep
            }
          }
        end
      end

      # Boot-time: prepend once. Thread-local [:vbo_capture] is nil unless deep mode active.
      module ExceptionLogger
        def initialize(*args)
          super
          if (buf = Thread.current[:vbo_capture])
            buf << {
              time:    Time.now.iso8601(3),
              class:   self.class.name,
              message: args.first&.to_s || '',
              source:  'prepend'
            }
          end
        end
      end
      Exception.prepend(ExceptionLogger)
    end
  end
end
