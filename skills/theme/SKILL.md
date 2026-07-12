---
description: Switch the claudometer theme, style, or language. Use when the user runs /claudometer:theme or asks to change the claudometer look.
argument-hint: <fuel|nord|dracula> [segmented|blocks|compact] [en|pt]
disable-model-invocation: true
---

# claudometer theme switcher

Run this exact command and show the user its output — nothing else. It deterministically rewrites
the env-var prefix on the `statusLine` command (preserving the script path); no parsing or
interpretation on your part:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/set-theme.sh" $ARGUMENTS
```

If `$ARGUMENTS` is empty, tell the user the options and ask which they want, then run the command:

- **theme** — `fuel` (default) · `nord` · `dracula`
- **style** — `segmented` (default) · `blocks` · `compact`
- **language** — `en` (default) · `pt`
