---
description: Switch the claudometer theme, style, or language by rewriting the statusLine command in settings.json. Use when the user runs /claudometer:theme or asks to change the claudometer theme/style/language.
disable-model-invocation: true
---

# claudometer theme switcher

Change claudometer's look by rewriting the env-var prefix on the `statusLine.command` in the user's
`~/.claude/settings.json`. Keep the script path untouched; only the env prefix changes.

Arguments: `$ARGUMENTS` — may name a theme, a style, and/or a language, in any order
(e.g. `dracula compact pt`). Any dimension not named keeps its current value.

## Options

- **theme** — `fuel` (default) · `nord` · `dracula`
- **style** — `segmented` (default) · `blocks` · `compact`
- **language** — `en` (default) · `pt`

## Steps

1. **Parse `$ARGUMENTS`** into theme / style / language. If it's empty, show the options above and
   ask the user which they want (then continue).
2. **Read** `~/.claude/settings.json`; take `statusLine.command`. Extract the **script path** — the
   trailing token ending in `statusline.sh` (keep the `~` or absolute path exactly as it is).
   Read any existing `CLAUDOMETER_*` values so unnamed dimensions are preserved.
3. **Rebuild the command**: prepend `CLAUDOMETER_THEME=… `, `CLAUDOMETER_STYLE=… `,
   `CLAUDOMETER_LANG=… ` for each dimension whose value is **not the default** (drop defaults so the
   command stays clean), then the script path. If everything is default, the command is just the path.
4. **Write it back**, preserving every other key in `settings.json` (edit only `statusLine.command`).
5. **Confirm** the new command and tell the user the bar updates on the next prompt/refresh.

Example results:
- `/claudometer:theme dracula` → `command: "CLAUDOMETER_THEME=dracula ~/.claude/statusline.sh"`
- `/claudometer:theme fuel` → `command: "~/.claude/statusline.sh"` (clean, all defaults)
- `/claudometer:theme nord compact pt` → `command: "CLAUDOMETER_THEME=nord CLAUDOMETER_STYLE=compact CLAUDOMETER_LANG=pt ~/.claude/statusline.sh"`
