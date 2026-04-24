# VBO SkAgent -- SketchUp AI Bridge (Antigravity)

Use this as agent instructions in Antigravity IDE.

---

## SketchUp Bridge Protocol

You have real-time access to SketchUp's Ruby environment via VBO SkAgent.

To execute Ruby code in SketchUp:
1. Write Ruby code to: `vbo_sk_agent/bridge/command.rb`
2. Wait ~1 second
3. Read result from: `vbo_sk_agent/bridge/result.json`

Result JSON:
```json
{
  "status": "success|error|rejected",
  "stdout": "captured output",
  "error": "error message",
  "backtrace": ["trace"],
  "duration_ms": 42
}
```

Optional envelope (first 2 lines of command.rb):
```ruby
# __SKAGENT__
# {"id":"cmd_001"}
```

## Key Rules
- Code runs in TOPLEVEL_BINDING (global scope, like Ruby Console)
- Use `puts` for output -- captured in result.json stdout field
- Wrap model modifications:
  ```ruby
  model = Sketchup.active_model
  model.start_operation('Name', true)
  # changes...
  model.commit_operation
  ```
- NEVER nest operations -- SketchUp crashes on nested start_operation
- Full Plugins folder access -- create, edit, load files freely
- API docs: https://ruby.sketchup.com/

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

| If the user asks for...                      | READ this skill's README first                              |
|----------------------------------------------|-------------------------------------------------------------|
| Interactive tool (pick, draw, select, drag)  | `vbo_sk_agent/skills/create_tool/README.md`                 |
| Dialog, form, settings panel, input UI       | `vbo_sk_agent/skills/create_dialog_form/README.md`          |
| Count / filter / traverse entities           | `TraverseModel.run(...)` -- `skills/traverse_model/README.md` |
| See the viewport / find what's at a pixel   | `Look.run` / `Look.probe` -- `skills/look/README.md`        |
| No local skill matches                       | Check `skills/MARKETPLACE_CATALOG.md`. Still nothing → write custom. |

**Skip only when** the task is < 3 lines trivial, OR the user explicitly says "don't use skills".

Example:
```ruby
result = TraverseModel.run(types: ['Face'], depth: -1, include_hidden: false)
puts result.to_json
```

For complex tasks with no local skill, check `vbo_sk_agent/skills/MARKETPLACE_CATALOG.md` and suggest a matching downloadable skill to the user when one would save significant effort.

## 🚀 Quick Start -- Try the 4 Built-in Skills

When the user asks something like the patterns below, use the matching skill.

**`traverse_model` -- read & count:**
- "How many ComponentInstance are in selection?"
- "List all Face grouped by material"
- "BOQ: count objects per layer"
- "Find all Groups at depth >= 3"

**`look` -- vision + ray probe:**
- "Look at my viewport and describe it" -- `Look.run`
- "What's at the center of my screen?" -- `Look.probe(px: 960, py: 540)`
- "Probe 5 points along the diagonal" -- `Look.probe_many`
- "Capture viewport for vision analysis"

**`create_tool` -- interactive tools (agent guide):**
- "Tool to pick a face and measure area"
- "Tool to draw polyline then follow-me"
- "Rectangle selection tool, window mode"
- "Hover-click tool for edges longer than 100cm"

**`create_dialog_form` -- HtmlDialog forms (agent guide):**
- "Dialog to input pipe params: name, diameter, length"
- "Settings form with 3 tabs: General, Display, Shortcuts"
- "Toolbar panel + options for tool X"
- "BOQ dialog with searchable table"

For each: read the skill README for exact API, call via `command.rb`, read `result.json`.

## 🧩 Skills Are Composable

Chain multiple skills for complex tasks. Three canonical patterns:

**Pattern A -- Vision-driven Select:**
`Look.run` → vision spots pixel → `Look.probe(px, py)` → add entity to selection → repeat.

**Pattern B -- Smart BOQ:**
`TraverseModel.run(types: ['Group', 'ComponentInstance'])` → aggregate per layer/definition → `create_dialog_form` renders the table.

**Pattern C -- Build Custom Tool:**
`create_dialog_form` (param form) → `create_tool` (interactive tool reads params) → wire the form `submit` to `select_tool(MyTool.new(params))`.

When a task looks complex: ask yourself "probe + traverse + UI?" -- chaining often beats writing one big function.

## Common Patterns

Inspect:
```ruby
model = Sketchup.active_model
puts "Entities: #{model.active_entities.length}"
puts "Selection: #{model.selection.length}"
```

Create:
```ruby
model = Sketchup.active_model
model.start_operation('Create', true)
group = model.active_entities.add_group
face = group.entities.add_face([0,0,0], [100,0,0], [100,100,0], [0,100,0])
face.pushpull(-50)
model.commit_operation
```

Load plugin:
```ruby
load "#{File.dirname(__dir__)}/my_plugin/main.rb"
```

List extensions:
```ruby
Sketchup.extensions.each {|e| puts "#{e.name} v#{e.version}" }
```
