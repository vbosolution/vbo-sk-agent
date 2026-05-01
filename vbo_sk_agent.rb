module VBO
  module SkAgent
    PLUGIN_NAME    = 'VBO SkAgent'.freeze
    PLUGIN_VERSION = '1.2.0'.freeze

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
# v1.2.0 (2026-04-28)
# - NEW: MCP HTTP transport — Claude Code / Cursor connect via http://127.0.0.1:7891/mcp
#        4 tools auto-discovered: execute_ruby, reload_file, list_instances, get_console_output
#        P50 ~13ms (30x faster than file-based bridge)
# - NEW: Toolbar split into 3 buttons (Bridge / MCP Server / Dashboard) — independent toggles
# - NEW: Dashboard "MCP Fast Transport" panel — IDE setup tabs (Claude Code / Cursor /
#        Gemini-Antigravity / Other), 1-click copy command for each IDE
# - NEW: Transport mode setting (auto / mcp_only / file_only) — persistent in Config
# - NEW: Configurable MCP port (default 7891) — change via Dashboard, restarts MCP automatically
# - NEW: Multi-instance detection + warning banner — when 2+ SU instances run SkAgent,
#        Dashboard shows which port to use (preferred 7891 vs ephemeral fallback)
# - NEW: instances.json global registry at %APPDATA%/VBO/SkAgent/ — all SU instances
#        register on startup, unregister on shutdown
# - NEW: Auto-start MCP server on plugin load (controllable via Config.mcp_auto_start)
# - NEW: Bundled MCP gems (mcp-0.13.0, json-schema-6.2.0, addressable-2.9.0, public_suffix-7.0.5)
#        — zero-config, no gem install needed
# - NEW: 3-layer console capture (StringIO + scoped TracePoint + Exception.prepend opt-in)
#        — automatic stdout/stderr/error capture on every execute_ruby
# - COMPAT: Zero breaking change for v1.1.0 users — file-based bridge paths unchanged,
#           file-based template flows still work without modification
# - DOCS: 4 prompt templates updated with Transport Layer section + multi-instance handling
#         (CLAUDE.md, GEMINI.md, cursorrules.md, generic.md)
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
