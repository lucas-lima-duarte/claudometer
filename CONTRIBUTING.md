# Contributing to claudometer

Thanks for wanting to help! claudometer uses a **pull-request workflow** — nobody pushes straight
to `main`, including the maintainer. The `main` branch is protected on GitHub, so every change
lands through a reviewed PR.

## Workflow

1. **Fork** the repo (external contributors) or create a **branch** (collaborators).
2. Work on a feature branch:
   ```bash
   git checkout -b feat/my-change
   ```
3. Make your change and test it locally (see below).
4. Push and open a **Pull Request** targeting `main`. Fill in the PR template — say what changed,
   why, and how you tested it.
5. A maintainer reviews and merges. Direct pushes to `main` are rejected by branch protection.

## Testing your change

The fastest check is the demo harness — it renders every pace state, theme, style and language
with live reset times:

```bash
bash scripts/demo.sh
```

To test a single case, pipe a mock on stdin. `resets_at` must be **relative to now** — a fixed
far-future value always lands at the start of the window, so the pedal never reaches `save it`:

```bash
FIVE=$(( $(date +%s) + 9000 )); SEVEN=$(( $(date +%s) + 302400 ))
bash scripts/statusline.sh <<< '{"model":{"display_name":"Opus 4.8"},"effort":{"level":"high"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":80,"resets_at":'"$FIVE"'},"seven_day":{"used_percentage":85,"resets_at":'"$SEVEN"'}}}'
```

Or load it live in a throwaway session (try the themes/styles too):

```bash
claude --plugin-dir .
CLAUDOMETER_THEME=neon CLAUDOMETER_STYLE=compact claude --plugin-dir .
```

## Style & scope

- Keep it a single, dependency-light Bash script — only `jq` and `date` may be assumed.
- **No network calls, ever.** claudometer must stay zero-API / zero-token.
- Match the existing ANSI-color and glyph style; comments in English.
- For large features (the copilot pedal, themes, i18n — see the README roadmap), **open an issue
  first** to align on the approach before sending a big PR.
