module VBO
  module SkAgent
    PLUGIN_NAME    = 'VBO SkAgent'.freeze
    PLUGIN_VERSION = '1.0.1'.freeze

    unless file_loaded?(__FILE__)
      ex = SketchupExtension.new(PLUGIN_NAME, File.join(__dir__, 'vbo_sk_agent/loader'))
      ex.description = 'AI Agent Bridge for SketchUp — Let AI code your plugins in real-time.'
      ex.version     = PLUGIN_VERSION
      ex.copyright   = '2026 VBO — MIT License'
      ex.creator     = 'Lê Việt Trường (Tiger Le)'
      Sketchup.register_extension(ex, true)
    end
  end
end
file_loaded(__FILE__)

# Release Notes
#
# v1.0.1 (2026-04-17)
# - Added OpenAI Codex support (AGENTS.md config)
# - Fixed encoding in templates (em dash -> ASCII, prevents display issues)
# - Updated README: Quick Start matches dashboard, added Beyond Coding section
# - Updated GitHub links in dashboard
#
# v1.0.0 (2026-04-17)
# - Initial release
# - File-based bridge: command.rb -> eval -> result.json
# - Dashboard with guided setup for 10+ AI tools
# - Setup prompt: auto-translate, auto-config, connection test
# - Safety mode (on by default), session trust
# - Templates: CLAUDE.md, GEMINI.md, cursorrules.md, generic.md
# - Beginner guide: 10 step-by-step prompts
# - SketchUp 2017+ compatible
