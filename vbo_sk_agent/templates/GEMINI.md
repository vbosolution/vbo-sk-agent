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
