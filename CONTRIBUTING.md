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

The script reads Claude Code's status JSON on stdin. Test with a mock payload:

```bash
bash scripts/statusline.sh <<< '{"model":{"display_name":"Opus 4.8"},"effort":{"level":"high"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":38,"resets_at":9999999999},"seven_day":{"used_percentage":61,"resets_at":9999999999}}}'
```

Or load it live in a throwaway session:

```bash
claude --plugin-dir .
```

## Style & scope

- Keep it a single, dependency-light Bash script — only `jq` and `date` may be assumed.
- **No network calls, ever.** claudometer must stay zero-API / zero-token.
- Match the existing ANSI-color and glyph style; comments in English.
- For large features (the copilot pedal, themes, i18n — see the README roadmap), **open an issue
  first** to align on the approach before sending a big PR.
