# claudometer

**A time-paced rate-limit statusline for Claude Code.**

Most usage statuslines show you a number: "5-hour limit, 38%." claudometer shows you that number
**against the clock** — the bars are segmented by time, so you can see at a glance whether you're
*ahead of pace*, *on pace*, or *burning your quota too fast* for how far you are into the window.

<!-- TODO: add docs/screenshot.png (real terminal capture, with color) before release -->

```text
claudometer  Opus 4.8  high effort
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

## What each line shows

- **Line 1** — current folder, model, and reasoning effort.
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

## Privacy

claudometer is just a local shell script. It makes **zero network/API calls** and uses **zero
tokens** — Claude Code pipes the session JSON to it on stdin and renders whatever it prints.

## Roadmap

- **Copilot pedal** — an at-a-glance recommendation that reads your pacing and tells you when to
  *push* or *ease off* (e.g. drop to a cheaper model when you're burning too fast). No other
  statusline recommends an action — this is the headline feature coming next.
- **Themes** — color palettes (`fuel` / `mono` / `neon`) × layouts (`segmented` / `compact` /
  `blocks`).
- **i18n** — English and Portuguese (pt-br) strings.
- **Multi-profile indicator** — show which `CLAUDE_CONFIG_DIR` profile is active, generically.

## Contributing

`main` is protected — all changes go through pull requests, including the maintainer's. See
[CONTRIBUTING.md](./CONTRIBUTING.md) for the workflow.

## License

[MIT](./LICENSE)
