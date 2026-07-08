---
description: Configure claudometer as the active Claude Code statusline by writing the statusLine block into the user's settings.json. Use when the user runs /claudometer:setup or asks to install/enable the claudometer statusline.
disable-model-invocation: true
---

# claudometer setup

Set up claudometer as the active statusline in the user's Claude Code settings. Work carefully and
do not clobber unrelated settings.

## Steps

1. **Locate the statusline script.**
   - If the `CLAUDE_PLUGIN_ROOT` environment variable is set, the script is at
     `$CLAUDE_PLUGIN_ROOT/scripts/statusline.sh`.
   - Otherwise it is at `scripts/statusline.sh` inside this repository — resolve its **absolute**
     path.
   Confirm the file exists and is executable (run `chmod +x` on it if not).

2. **Check dependencies.** Verify `jq` is installed (`command -v jq`). If missing, tell the user to
   install it (`brew install jq` on macOS, `apt install jq` / `dnf install jq` on Linux) and stop.

3. **Read** `~/.claude/settings.json`. If it doesn't exist, treat it as `{}`.

4. **Merge** this block, preserving every other key already in the file:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "<ABSOLUTE_PATH>/scripts/statusline.sh"
     }
   }
   ```
   If a `statusLine` block already exists, show the user the current value and ask for confirmation
   before overwriting it.

5. **Confirm** to the user that claudometer is configured and will appear on the next status
   refresh (a new prompt, or restarting Claude Code). Note it renders only for Pro/Max accounts
   (the 5-hour / 7-day bars need the `rate_limits` payload) and after the first message of a session.
