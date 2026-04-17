# VBO SkAgent

**AI Agent Bridge for SketchUp** — Let AI code your plugins in real-time.

VBO SkAgent connects AI coding assistants (Claude Code, Cursor, Antigravity, Windsurf, etc.) directly to SketchUp's Ruby environment. Write code with AI, execute it in SketchUp instantly, and see results — all without copy-pasting.

## How It Works

```
AI Agent ──write──► command.rb ──(0.5s poll)──► SketchUp eval ──► result.json ──read──► AI Agent
```

1. Your AI assistant writes Ruby code to `command.rb`
2. SkAgent detects the change and executes the code
3. Results (stdout, errors, backtrace) are written to `result.json`
4. Your AI reads the result and continues iterating

## Installation

### From GitHub Releases
1. Download the latest `.rbz` file from [Releases](https://github.com/vbosolution/vbo-sk-agent/releases)
2. In SketchUp: `Window` → `Extension Manager` → `Install Extension` → select the `.rbz`

### Manual (Developer)
Copy `vbo_sk_agent.rb` and `vbo_sk_agent/` folder into your SketchUp Plugins directory:
```
%APPDATA%/SketchUp/SketchUp 20XX/SketchUp/Plugins/
```

## Quick Start

1. **Toggle Bridge** — Click the SkAgent button in the toolbar (or `Extensions` → `VBO SkAgent` → `Toggle Bridge`)
2. **Open Dashboard** — `Extensions` → `VBO SkAgent` → `Dashboard`
3. **Select your AI tool** from the dropdown (Claude Code, Cursor, Antigravity, Windsurf, Copilot, Aider, etc.)
4. **Follow the steps** shown for your tool — the dashboard generates a **setup prompt** tailored to your agent
5. **Copy & paste the setup prompt** into your AI — it will automatically:
   - Ask your preferred language
   - Create the config file for your AI tool
   - Translate the beginner guide
   - Send a test command to verify the connection
6. **Start coding!** — Your AI writes to `command.rb`, SkAgent runs it automatically

### Supported AI Tools

| Tool | Config File | Type |
|------|------------|------|
| **Claude Code** (VS Code / CLI) | `CLAUDE.md` | Automated |
| **Cursor** | `.cursorrules` | Automated |
| **Antigravity** (Gemini) | `GEMINI.md` | Automated |
| **Windsurf** | `.windsurfrules` | Automated |
| **GitHub Copilot** | `.github/copilot-instructions.md` | Automated |
| **Augment** | `AGENTS.md` | Automated |
| **OpenAI Codex** | `AGENTS.md` | Automated |
| **OpenClaw** | `OPENCLAW_INSTRUCTIONS.md` | Automated |
| **Aider** | `.aider/instructions.md` | Automated |
| **ChatGPT / Gemini Web** | Manual copy-paste | Manual |

> **Automated** = AI reads/writes files directly. **Manual** = You copy code between the AI and `command.rb` yourself.

## Beyond Coding — Your AI Assistant

SkAgent isn't just for plugin development. Your AI becomes a powerful assistant that can *act* on your model directly:

- **Generate reports** — *"Create an HTML report of all selected groups with name, dimensions, tag, and material."*
- **Draw from reference images** — *"Read this land survey image and draw the plot shape in SketchUp."*
- **Batch-edit scenes** — *"Copy the camera angle from the current scene and apply it to all scenes named 'Plan'."*
- **Translate entire model** — *"Translate all text entities (3D text, dimensions, labels) into Japanese."*
- **Model cleanup** — *"Find all ungrouped edges and faces, group them by proximity, and name each group."*

Anything you can do in SketchUp's Ruby Console, your AI can do for you — just describe what you want in plain language.

## Features

- **File-based bridge** — Simple, reliable, no network required
- **Stdout capture** — `puts` output captured in result.json
- **Safety mode** — Confirm before running AI-generated code (on by default)
- **Session trust** — Trust once, run freely until bridge is toggled off
- **Dashboard** — View status, paths, command history, and setup guides
- **Multi-language** — Setup prompt auto-translates to your preferred language
- **10+ AI tools supported** — Claude Code, Cursor, Antigravity, Windsurf, Copilot, and more
- **Envelope protocol** — Optional structured commands with ID tracking
- **SketchUp 2017+** compatible

## Protocol

### Simple (raw Ruby)
Just write Ruby code to `command.rb`:
```ruby
puts Sketchup.version
```

### With Envelope (optional)
```ruby
# __SKAGENT__
# {"id":"cmd_001"}
puts Sketchup.version
```

### Result
```json
{
  "status": "success",
  "stdout": "2026.0\n",
  "duration_ms": 2,
  "sketchup_version": "2026.0",
  "bridge_version": "1.0.0"
}
```

## Safety

- **Safety Mode** (default: ON) — Shows a confirmation dialog before executing AI code
- **Session Trust** — After confirming once, you can trust the session to skip future prompts
- Code runs in `TOPLEVEL_BINDING` (same as Ruby Console) — full access to SketchUp API
- Tip: Wrap model changes in `start_operation`/`commit_operation` for undo support

## Disclaimer

VBO SkAgent executes code in SketchUp's Ruby environment. While we include safety features (Safety Mode, confirmation prompts, security rules for AI agents), **you are ultimately responsible for the code that runs on your machine**.

- Always review code before executing, especially from untrusted AI sources
- The built-in security rules instruct AI agents to refuse harmful requests, but modified versions of this plugin may not include these protections
- VBO SkAgent is provided "as is" — the author is not liable for any damage caused by code executed through the bridge, whether by user action or AI-generated code
- Do not use this tool to reverse-engineer, crack, or exploit other software

See the [MIT License](LICENSE) for full legal terms.

## License

MIT — Free and open source.

## Author

**Lê Việt Trường (Tiger Le)** — VBO Solution

- Store: [kcdallc.com/shop](https://kcdallc.com/shop)
- Extension Warehouse: [VBO on Extension Warehouse](https://extensions.sketchup.com/developer/ub5467bd8-c92b-415a-be5a-d92ca62c5b6b)
- Email: support@vbosolution.com
- Facebook: [VBO Solutions Group](https://www.facebook.com/groups/VBOsolutions)
- WhatsApp: [+84 916 792 711](https://wa.me/84916792711)
- Messenger: [m.me/le.v.truong](http://m.me/le.v.truong)
