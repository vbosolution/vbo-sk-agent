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
