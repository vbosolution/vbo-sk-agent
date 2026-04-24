# VBO SkAgent -- SketchUp AI Bridge (Cursor Rules)

Copy this content into your `.cursorrules` file in the Plugins folder.

---

## SketchUp Bridge Protocol

You have real-time access to SketchUp's Ruby environment via VBO SkAgent.

To execute Ruby code in SketchUp:
1. Write Ruby code to: `vbo_sk_agent/bridge/command.rb`
2. Wait ~1 second
3. Read result from: `vbo_sk_agent/bridge/result.json`

Result JSON fields:
- `status`: "success" | "error" | "rejected"
- `stdout`: captured puts/print output
- `error`: error message (if failed)
- `backtrace`: stack trace array (if failed)
- `duration_ms`: execution time in milliseconds

Optional envelope (first 2 lines of command.rb):
```ruby
# __SKAGENT__
# {"id":"cmd_001"}
# your Ruby code below...
```

## Rules
- Code runs in TOPLEVEL_BINDING (global scope, same as Ruby Console)
- Use `puts` to output data -- stdout is captured in result.json
- Wrap model changes in `model.start_operation('Name', true)` / `model.commit_operation`
- NEVER nest start_operation/commit_operation -- SketchUp will crash
- You have full access to the Plugins folder for creating and editing files
- SketchUp Ruby API: https://ruby.sketchup.com/

## Auto-Update Check

At the START of each session (before doing anything else):
1. Read `vbo_sk_agent.rb` and find `PLUGIN_VERSION = '...'` to get the current version
2. Fetch https://api.github.com/repos/vbosolution/vbo-sk-agent/releases/latest
3. Compare the `tag_name` (remove leading 'v') with current version
4. If a newer version exists:
   a. Read the release notes carefully
   b. Summarize what's new in the user's language -- focus on what matters to them
   c. Give your honest recommendation: update now or skip?
   d. Ask: "Would you like me to update?"
5. If user agrees:
   - Download the .rbz, rename to .zip, extract
   - Compare NEW loader.rb with CURRENT loader.rb
   - Overwrite all files in the plugin folder
   - If loader.rb CHANGED: tell user this update requires SketchUp restart
   - If loader.rb UNCHANGED: reload via command.rb: load vbo_sk_agent.rb, config.rb, bridge.rb. Confirm success
6. If user declines or same version or fetch fails: proceed normally

## Skills

SkAgent has pre-built skills -- Ruby modules (call directly) and agent guides (read before coding).
Full list: `vbo_sk_agent/skills/SKILLS_INDEX.md` (auto-generated on startup).

## 🔍 Research Protocol (REQUIRED before writing Ruby)

Match the user's task to an existing skill **before** writing custom code:

| User asks for...                             | READ this skill's README first                              |
|----------------------------------------------|-------------------------------------------------------------|
| Interactive tool (pick, draw, select, drag)  | `vbo_sk_agent/skills/create_tool/README.md`                 |
| Dialog, form, settings panel, input UI       | `vbo_sk_agent/skills/create_dialog_form/README.md`          |
| Count / filter / traverse entities           | `TraverseModel.run(...)` -- `skills/traverse_model/README.md` |
| See the viewport / find what's at a pixel   | `Look.run` / `Look.probe` -- `skills/look/README.md`        |
| No local skill matches                       | Check `skills/MARKETPLACE_CATALOG.md`. Still nothing → write custom. |

**Skip only when** task is < 3 lines trivial, OR user explicitly says "don't use skills".

Example:
```ruby
result = TraverseModel.run(types: ['Face'], depth: -1, include_hidden: false)
puts result.to_json
```

For complex tasks with no local skill, check `vbo_sk_agent/skills/MARKETPLACE_CATALOG.md`.

## 🚀 Quick Start -- Try the 4 Built-in Skills

When the user asks like the patterns below, use the matching skill.

**`traverse_model` -- read & count:**
- "How many ComponentInstance are in selection?"
- "List all Face grouped by material"
- "BOQ: count objects per layer"
- "Find all Groups at depth >= 3"

**`look` -- vision + ray probe:**
- "Look at my viewport and describe it" -- `Look.run`
- "What's at the center of my screen?" -- `Look.probe(px: 960, py: 540)`
- "Probe 5 points along the diagonal" -- `Look.probe_many`

**`create_tool` -- interactive tools (agent guide):**
- "Tool to pick a face and measure area"
- "Tool to draw polyline then follow-me"
- "Rectangle selection tool, window mode"

**`create_dialog_form` -- HtmlDialog forms (agent guide):**
- "Dialog to input pipe params: name, diameter, length"
- "Settings form with 3 tabs: General, Display, Shortcuts"
- "BOQ dialog with searchable table"

Read the skill README for exact API, call via `command.rb`, read `result.json`.

## 🧩 Skills Are Composable

Chain multiple skills for complex tasks. Three canonical patterns:

**A -- Vision-driven Select:** `Look.run` → vision spots pixel → `Look.probe(px, py)` → add to selection → repeat.

**B -- Smart BOQ:** `TraverseModel.run(types: [...])` → aggregate per layer/definition → `create_dialog_form` renders the table.

**C -- Build Custom Tool:** `create_dialog_form` (param form) → `create_tool` (interactive tool) → wire form submit to `select_tool(MyTool.new(params))`.

When a task looks complex, split it into probe + traverse + UI -- chaining beats one big function.

## Examples

Inspect model:
```ruby
model = Sketchup.active_model
puts "Entities: #{model.active_entities.length}"
```

Create geometry:
```ruby
model = Sketchup.active_model
model.start_operation('Draw', true)
model.active_entities.add_line([0,0,0], [100,0,0])
model.commit_operation
```

Load a plugin:
```ruby
load "#{File.dirname(__dir__)}/my_plugin/main.rb"
```
