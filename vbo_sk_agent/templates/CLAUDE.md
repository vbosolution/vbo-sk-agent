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
