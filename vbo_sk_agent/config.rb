module VBO
  module SkAgent
    module Config
      SECTION = 'VBO_SkAgent'.freeze

      DEFAULTS = {
        'safety_mode'   => true,
        'poll_interval' => 0.5,
      }.freeze

      def self.get(key)
        default = DEFAULTS[key]
        value = Sketchup.read_default(SECTION, key)
        return default if value.nil?
        case default
        when true, false then value.to_s == 'true'
        when Float       then value.to_f
        when Integer     then value.to_i
        else value
        end
      end

      def self.set(key, value)
        Sketchup.write_default(SECTION, key, value.to_s)
      end

      # Session trust — volatile, reset khi tắt bridge hoặc restart SU
      @session_trust = false unless defined?(@session_trust)

      def self.session_trusted?
        @session_trust == true
      end

      def self.trust_session!
        @session_trust = true
      end

      def self.reset_session
        @session_trust = false
      end
    end
  end
end
