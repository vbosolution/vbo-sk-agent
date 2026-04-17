# VBO SkAgent — SketchUp AI Bridge

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

## Rules

- Code runs in global scope (same as SketchUp Ruby Console)
- Use `puts` to produce output — it gets captured in the stdout field
- For model modifications, wrap in undo operation:
  ```ruby
  model = Sketchup.active_model
  model.start_operation('Change Name', true)
  # ... your changes ...
  model.commit_operation
  ```
- Never nest operations (no start_operation inside another start_operation)
- SketchUp Ruby API reference: https://ruby.sketchup.com/
