# claudometer

**A time-paced rate-limit statusline for Claude Code.**

Most usage statuslines show you a number: "5-hour limit, 38%." claudometer shows you that number
**against the clock** — the bars are segmented by time, so you can see at a glance whether you're
*ahead of pace*, *on pace*, or *burning your quota too fast* for how far you are into the window.

<!-- TODO: add docs/screenshot.png (real terminal capture, with color) before release -->

```text
claudometer  Opus 4.8  high effort   ● ● ●  boost it
Session  ━━━━━━━━━━────────────  42%
5-hour   ━━━━▪━━──▪────▪────▪──  38%  14:30
Weekly   ━━━▪━━━▪────▪────▪──    61%  Sat 11 Jul
```

## The idea: bars that are also a clock

Claude Code's rate limits roll over on fixed windows — every **5 hours** and every **7 days**.
claudometer splits each bar into segments that map 1:1 onto that window:

- **5-hour** bar → **5 segments**, one per hour (the `▪` marks divide them).
- **Weekly** bar → **7 segments**, one per day.

The segment for **right now** is highlighted, and the fill color is **paced** — it compares your
usage against how much of the window has already elapsed:

| Color | Meaning |
| :---- | :------ |
| 🟢 green | **Ahead** — you're using less than your time-share of the window. Room to spare. |
| 🟠 orange | **On pace** — you're spending roughly the quota budgeted for where you are. |
| 🔴 red/salmon | **Behind** — you've burned past your time-share. You may hit the wall before it resets. |

(In the terminal these are real ANSI colors, not emoji — the table just labels them here.)

So a bar that's 60% full isn't automatically "bad": if you're 4 days into the weekly window, 60%
is *ahead of pace* and shows green. The same 60% one hour into the 5-hour window shows red.

## The copilot pedal

Every other statusline just *shows* you a number. claudometer also tells you **what to do about
it**. The `● ● ●` on line 1 is a three-position pedal — the lit dot is where you are:

| Pedal | Meaning | Suggests |
| :---- | :------ | :------- |
| **boost it** (dot 1, green) | ahead of pace — quota to spare | push harder |
| **hold it** (dot 2, orange) | on pace | keep going |
| **save it** (dot 3, salmon) | burning too fast — you may hit the wall | ease off → a cheaper model |

It synthesizes **both** windows into one recommendation: the more-severe window wins, and a dim tag
(` · 5h` / ` · week`) names which one pulled the pedal when they disagree. On `save it` the arrow
suggests the biggest quota saving for your current model (`→ Sonnet`, `→ Haiku`, or `→ /compact`).

## What each line shows

- **Line 1** — current folder, model, reasoning effort, and the copilot pedal.
- **Session** — context-window usage for the current session.
- **5-hour** — your rolling 5-hour rate-limit usage, segmented by hour, with the reset time.
- **Weekly** — your rolling 7-day rate-limit usage, segmented by day, with the reset date.

## Install

### Requirements

- [`jq`](https://jqlang.github.io/jq/) (`brew install jq` / `apt install jq`)
- Claude Code **2.1+**
- A **Pro or Max** plan — the 5-hour / 7-day bars need the `rate_limits` data Claude Code sends for
  subscribers. (The context bar works on any plan.)

### Option 1 — Manual (recommended)

```bash
git clone https://github.com/lucas-lima-duarte/claudometer.git
chmod +x claudometer/scripts/statusline.sh
```

Then add this to your `~/.claude/settings.json` (merge it with whatever is already there):

```json
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/to/claudometer/scripts/statusline.sh"
  }
}
```

The statusline appears on your next prompt.

### Option 2 — As a plugin

Load it directly for a session:

```bash
claude --plugin-dir /path/to/claudometer
```

Then run `/claudometer:setup` and Claude will detect the script path and write the `statusLine`
block into your `settings.json` for you.

## Configuration

All optional, via environment variables. With none set you get `fuel` + `segmented` + `en` — the
output shown at the top. Set them inline in your `statusLine` command (or export them in your shell).

| Variable | Values | Default | What it does |
| :------- | :----- | :------ | :----------- |
| `CLAUDOMETER_THEME` | `fuel` · `mono` · `neon` | `fuel` | color palette |
| `CLAUDOMETER_STYLE` | `segmented` · `blocks` · `compact` | `segmented` | bar layout |
| `CLAUDOMETER_LANG`  | `en` · `pt` | `$LANG` prefix, else `en` | language |

Example — neon palette, compact layout, in Portuguese:

```json
{
  "statusLine": {
    "type": "command",
    "command": "CLAUDOMETER_THEME=neon CLAUDOMETER_STYLE=compact CLAUDOMETER_LANG=pt /path/to/claudometer/scripts/statusline.sh"
  }
}
```

- **`mono`** stays grayscale and only colors the `save it` alert — for sober terminals.
- **`blocks`** uses solid `█░` bars (keeps the active-segment highlight, drops the dividers).
- **`compact`** collapses everything onto one line and omits the Session bar.
- Run `scripts/demo.sh` to preview every state, theme, style and language at once.
- Portuguese accented labels (e.g. `Sessão`) can sit one column off in `segmented` — cosmetic, and
  depends on your terminal's locale.

## Privacy

claudometer is just a local shell script. It makes **zero network/API calls** and uses **zero
tokens** — Claude Code pipes the session JSON to it on stdin and renders whatever it prints.

## Roadmap

- **More palettes** — Nord / Dracula / Gruvbox.
- **Multi-profile indicator** — show which `CLAUDE_CONFIG_DIR` profile is active, generically.
- **Perfect multibyte alignment** — column-count padding so accented labels align in every locale.

## Contributing

`main` is protected — all changes go through pull requests, including the maintainer's. See
[CONTRIBUTING.md](./CONTRIBUTING.md) for the workflow.

## License

[MIT](./LICENSE)
