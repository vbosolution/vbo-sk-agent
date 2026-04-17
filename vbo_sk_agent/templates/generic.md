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
