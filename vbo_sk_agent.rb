module VBO
  module SkAgent
    PLUGIN_NAME    = 'VBO SkAgent'.freeze
    PLUGIN_VERSION = '1.1.0'.freeze

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
# v1.1.0 (2026-04-24)
# - NEW: Skill System v1 -- 4 built-in skills loaded on startup
#   * traverse_model (ruby): Recursive entity traversal, filter by type/depth/hidden
#   * look (ruby): Vision capture (PNG + clipboard) + ray probe from pixel to entity
#   * create_tool (agent): Guide for creating interactive tools (4 patterns + advanced)
#   * create_dialog_form (agent): Guide for creating HtmlDialog forms with VBO UI library
# - NEW: SkillsLoader auto-generates skills/SKILLS_INDEX.md on startup
# - NEW: Research Protocol (REQUIRED) section in agent templates -- maps user intent
#        to the correct skill README so the agent reads before coding
# - NEW: Quick Start + Skills Are Composable sections in agent templates
# - FIX: look skill -- handle entities without .name method (Face, Edge)
# - FIX: agent templates -- corrected TraverseModel.run API signature example
#
# v1.0.1 (2026-04-17)
# - Added OpenAI Codex support (AGENTS.md config)
# - Added agent-driven auto-update check (agent reads GitHub releases, advises user, can hot-reload)
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
