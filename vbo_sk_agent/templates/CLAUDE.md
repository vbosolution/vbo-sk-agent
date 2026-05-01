# VBO SkAgent -- SketchUp AI Bridge

You have real-time access to SketchUp's Ruby environment via VBO SkAgent.
Two transports are available: **MCP** (fast, P50 ~13ms) and **file-based** (universal, ~500ms).

## Transport Layer -- Choose Once Per Session (v1.2.0+)

At the START of each session, decide which transport to use:

### Step 1: Check MCP availability
```
GET http://127.0.0.1:7891/health
```
- Returns JSON with `"ok": true` and `"running": true` --> use **MCP transport** (primary, fast)
- Connection refused / error --> use **File-based transport** (fallback)

If user has MCP registered in Claude Code (`claude mcp add ... vbo-sketchup`), the 4 tools below appear automatically as `mcp__vbo-sketchup__execute_ruby`, etc. Use them directly when available.

Remember the chosen transport in this session -- do not re-check every call.

### Step 2 (MCP only): Multi-instance check
After MCP is detected, call `list_instances` ONCE at session start:
- If `total == 1` --> proceed normally
- If `total > 1` (multi-instance) --> **WARN THE USER**: there are N SketchUp instances running. The MCP connection may target the wrong instance. Show the `warning` field from the response. Ask the user to confirm which instance they want before proceeding.

---

## A. MCP Transport (Primary)

When MCP is available, use these 4 tools directly:

| Tool | When to use |
|------|-------------|
| `execute_ruby`     | Run any Ruby code in SU. Returns `result`, `output` (stdout), `error`, `backtrace`, `duration_ms` automatically |
| `reload_file`      | Reload one .rb file (auto-bypasses `file_loaded?` guard) |
| `list_instances`   | List all SU instances running SkAgent. Required at session start for multi-instance check |
| `get_console_output` | Read background errors captured by TracePoint during prior `execute_ruby` calls |

**Output capture is automatic** -- do not wrap with StringIO redirect.

### Example (MCP)
```
execute_ruby:
  code: |
    model = Sketchup.active_model
    puts "Title: #{model.title}"
    puts "Entities: #{model.active_entities.length}"
```
Returns `output:` field with both lines.

---

## B. File-based Transport (Fallback)

Used when MCP is unavailable (older SkAgent, port blocked, IDE without MCP support).

### Execute Code in SketchUp (file-based)

**Write** Ruby code to:
`vbo_sk_agent/bridge/command.rb`

**Wait** ~1 second, then **read** the result:
`vbo_sk_agent/bridge/result.json`

## Result Format

```json
{
  "status": "success|error|rejected",
  "stdout": "captured puts output",
  "error": "error message if failed",
  "backtrace": ["file:line", "..."],
  "duration_ms": 42,
  "sketchup_version": "2026.0",
  "ruby_version": "3.2.2",
  "bridge_version": "1.0.0"
}
```

## Envelope (optional)

Add these 2 lines at the top of command.rb for structured commands:

```ruby
# __SKAGENT__
# {"id":"cmd_001"}
puts Sketchup.version
```

The `id` field helps match commands to results when running multiple commands.

## Important Rules

- Code runs in `TOPLEVEL_BINDING` -- same scope as SketchUp's Ruby Console
- Use `puts` for output -- stdout is captured in result.json
- If you modify the model, wrap in `model.start_operation` / `commit_operation`:
  ```ruby
  model = Sketchup.active_model
  model.start_operation('My Change', true)
  # ... modify model ...
  model.commit_operation
  ```
- **NEVER nest operations** -- SketchUp will crash. Check if your code already wraps operations before adding another.
- SketchUp Ruby API docs: https://ruby.sketchup.com/
- You have full access to the Plugins folder -- you can create, edit, and load plugin files

## Auto-Update Check

At the START of each session (before doing anything else):
1. Read `vbo_sk_agent.rb` and find `PLUGIN_VERSION = '...'` to get the current version
2. Fetch https://api.github.com/repos/vbosolution/vbo-sk-agent/releases/latest
3. Compare the `tag_name` (remove leading 'v') with current version
4. If a newer version exists:
   a. Read the release notes carefully
   b. Summarize what's new in the user's language -- focus on what matters to them:
      new features, bug fixes, breaking changes
   c. Give your honest recommendation: is this update worth doing now or can they skip it?
   d. Ask: "Would you like me to update?"
5. If user agrees:
   - Download the .rbz from the release assets URL
   - Rename to .zip and extract to a temp folder
   - Compare the NEW loader.rb with the CURRENT loader.rb
   - Overwrite all files in the plugin folder (vbo_sk_agent.rb + vbo_sk_agent/)
   - If loader.rb HAS CHANGED: tell the user this update requires a SketchUp restart
     (because loader.rb registers menus/toolbars that can only be created once at startup)
   - If loader.rb is UNCHANGED: reload via command.rb:
     load 'vbo_sk_agent.rb'
     load 'vbo_sk_agent/config.rb'
     load 'vbo_sk_agent/bridge.rb'
     Then read result.json to confirm success and tell user: update complete

6. If user declines: proceed with current version
7. If same version or fetch fails: say nothing, proceed normally

## Skills

SkAgent has a skill system -- pre-built, tested Ruby modules and agent guides you can use instead of writing code from scratch. Two flavours:

- **Ruby skills** -- call a module directly (e.g. `TraverseModel.run(...)`, `Look.run`)
- **Agent skills** -- a README that teaches *you* the correct pattern before you write code (e.g. `create_tool`, `create_dialog_form`)

The full list is at `vbo_sk_agent/skills/SKILLS_INDEX.md` (auto-generated on startup).

## 🔍 Research Protocol (REQUIRED before writing Ruby)

Match the user's task to an existing skill **before** writing any custom code:

| If the user asks for...                      | READ this skill's README first                              |
|----------------------------------------------|-------------------------------------------------------------|
| Interactive tool (pick, draw, select, drag)  | `vbo_sk_agent/skills/create_tool/README.md`                 |
| Dialog, form, settings panel, input UI       | `vbo_sk_agent/skills/create_dialog_form/README.md`          |
| Count / filter / traverse entities           | Call `TraverseModel.run(...)` -- `skills/traverse_model/README.md` |
| See the viewport / find what's at a pixel    | Call `Look.run` / `Look.probe` -- `skills/look/README.md`   |
| No local skill matches                       | Check `skills/MARKETPLACE_CATALOG.md`. Still nothing → write custom. |

**Skip the protocol only when** (1) the task is < 3 lines of trivial code, OR (2) the user explicitly says "write it from scratch, don't use skills".

Example -- one call instead of 30 lines of recursive traversal:
```ruby
# Duyệt selection hiện tại, filter Face, không giới hạn depth
result = TraverseModel.run(types: ['Face'], depth: -1, include_hidden: false)
puts result.to_json
```

Skills are also usable as Ruby libraries by plugin developers (`require` the main.rb).

**Marketplace**: when a missing skill would save significant effort, suggest it to the user -- explain what it does, show the code that would run with it installed, and always offer the option to write custom code instead.

## 🚀 Quick Start -- Try the 4 Built-in Skills

When the user asks something matching the patterns below, use the corresponding skill instead of writing code from scratch.

**`traverse_model` -- read & count model contents:**
- "How many ComponentInstance are in my selection?"
- "List all Face in selection, group by material"
- "Build a BOQ: count objects per layer"
- "Find all Groups at depth >= 3"

**`look` -- see the viewport (vision + ray probe):**
- "Look at my viewport and tell me what's there" -- `Look.run(deep: false)` then attach capture.png
- "What is at the center of my screen?" -- `Look.probe(px: 960, py: 540)`
- "Probe 5 points along the diagonal to check continuity" -- `Look.probe_many(points: [...])`
- "Capture the viewport and analyse it with vision"

**`create_tool` -- build interactive tools (agent guide):**
- "Make a tool that picks a face and measures its area"
- "Make a tool that draws a polyline then follow-me extrudes a selected face"
- "Make a rectangle selection tool in window mode"
- "Make a hover-click tool that selects edges longer than 100cm"

**`create_dialog_form` -- build HtmlDialog forms (agent guide):**
- "Create a dialog to input pipe parameters: name, diameter, length"
- "Create a settings form with 3 tabs: General, Display, Shortcuts"
- "Create a toolbar panel with options for tool X"
- "Create a BOQ dialog with a searchable table"

For each prompt: (1) read the skill's README for the exact API, (2) call it from `command.rb`, (3) read `result.json` for the output.

## 🧩 Skills Are Composable

The real power is chaining multiple skills in one task. Three canonical patterns:

**Pattern A -- Vision-driven Select** (pick entities by looking at them)
1. `Look.run` -- capture viewport (PNG + context)
2. Vision analysis -- "the red chair is near pixel (400, 300)"
3. `Look.probe(px: 400, py: 300)` -- get the entity at that pixel
4. Add returned entity to `model.selection`
5. Repeat until all desired entities are selected

**Pattern B -- Smart BOQ** (build a bill of quantities from natural language)
1. `TraverseModel.run(types: ['Group', 'ComponentInstance'])` -- list all containers
2. Aggregate: count per layer, per definition, sum bounds
3. Follow the `create_dialog_form` guide to render a searchable BOQ table
4. User can refine the query in chat -- re-run traverse, update dialog

**Pattern C -- Build Custom Tool** (form-driven interactive tool)
1. Follow `create_dialog_form` guide -- make a parameter form (e.g. diameter, spacing)
2. Follow `create_tool` guide -- make a tool that reads those params
3. Wire the dialog `submit` callback to `Sketchup.active_model.select_tool(MyTool.new(params))`
4. User gets a complete workflow: fill form → pick points → geometry drawn

When a task looks complex, ask: "can I split this into a probe + a traverse + a UI?" -- chaining often beats writing one big function.

## Quick Examples

### Inspect the model
```ruby
model = Sketchup.active_model
puts "Name: #{model.title}"
puts "Entities: #{model.active_entities.length}"
puts "Materials: #{model.materials.length}"
puts "Components: #{model.definitions.length}"
puts "Layers/Tags: #{model.layers.length}"
```

### Create geometry (with undo support)
```ruby
model = Sketchup.active_model
model.start_operation('Create box', true)
group = model.active_entities.add_group
face = group.entities.add_face(
  [0, 0, 0], [100, 0, 0], [100, 100, 0], [0, 100, 0]
)
face.pushpull(-50)
model.commit_operation
puts "Box created!"
```

### Load a plugin file
```ruby
load "#{File.dirname(__dir__)}/my_plugin/main.rb"
puts "Plugin loaded!"
```

### List installed extensions
```ruby
Sketchup.extensions.each {|ext|
  puts "#{ext.name} v#{ext.version} (#{ext.loaded? ? 'loaded' : 'disabled'})"
}
```

### Get selection info
```ruby
sel = Sketchup.active_model.selection
puts "Selected: #{sel.length} entities"
sel.each {|e| puts "  #{e.class}: #{e.respond_to?(:name) ? e.name : e.to_s}" }
```
