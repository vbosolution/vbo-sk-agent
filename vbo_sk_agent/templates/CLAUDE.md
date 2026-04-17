# VBO SkAgent -- SketchUp AI Bridge

You have real-time access to SketchUp's Ruby environment via VBO SkAgent.

## Execute Code in SketchUp

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
