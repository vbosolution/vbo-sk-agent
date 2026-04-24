# VBO SkAgent -- SketchUp AI Bridge

Generic instructions for any AI tool.

## How It Works

VBO SkAgent is a plugin running inside SketchUp that watches a file for changes.
When you write Ruby code to that file, SketchUp executes it and writes the result.

## Protocol

1. **Write** Ruby code to: `vbo_sk_agent/bridge/command.rb`
2. **Wait** ~1 second
3. **Read** result from: `vbo_sk_agent/bridge/result.json`

## Result Format

```json
{
  "status": "success|error|rejected",
  "stdout": "any puts/print output",
  "error": "error message if status is error",
  "backtrace": ["stack trace lines"],
  "duration_ms": 42
}
```

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

## Research Protocol (REQUIRED before writing Ruby)

Match the user's task to an existing skill **before** writing custom code:

| User asks for...                             | READ this skill's README first                              |
|----------------------------------------------|-------------------------------------------------------------|
| Interactive tool (pick, draw, select, drag)  | `vbo_sk_agent/skills/create_tool/README.md`                 |
| Dialog, form, settings panel, input UI       | `vbo_sk_agent/skills/create_dialog_form/README.md`          |
| Count / filter / traverse entities           | `TraverseModel.run(...)` -- `skills/traverse_model/README.md` |
| See the viewport / find what's at a pixel   | `Look.run` / `Look.probe` -- `skills/look/README.md`        |
| No local skill matches                       | Check `skills/MARKETPLACE_CATALOG.md`. Still nothing → write custom. |

Skip only when task is < 3 lines trivial, OR user explicitly says "don't use skills".

Example:
```ruby
# Traverse current selection, filter Face
result = TraverseModel.run(types: ['Face'], depth: -1, include_hidden: false)
puts result.to_json
```

## Quick Start -- Try the 4 Built-in Skills

When the user asks something like these patterns, use the matching skill.

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

For each: read the skill README for the exact API, call via `command.rb`, read `result.json`.

## Skills Are Composable

Chain multiple skills for complex tasks:

- **Vision-driven Select:** `Look.run` → vision spots pixel → `Look.probe(px, py)` → add to selection → repeat.
- **Smart BOQ:** `TraverseModel.run(types: [...])` → aggregate per layer/definition → `create_dialog_form` renders the table.
- **Build Custom Tool:** `create_dialog_form` (param form) → `create_tool` (interactive tool) → wire form submit to `select_tool(MyTool.new(params))`.

When a task looks complex, split it into probe + traverse + UI.

## Rules

- Code runs in global scope (same as SketchUp Ruby Console)
- Use `puts` to produce output -- it gets captured in the stdout field
- For model modifications, wrap in undo operation:
  ```ruby
  model = Sketchup.active_model
  model.start_operation('Change Name', true)
  # ... your changes ...
  model.commit_operation
  ```
- Never nest operations (no start_operation inside another start_operation)
- SketchUp Ruby API reference: https://ruby.sketchup.com/
