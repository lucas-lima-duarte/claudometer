#!/usr/bin/env bash
# demo.sh — render claudometer across pace states, languages, themes and styles,
# using live (relative) reset times so the bars actually reach every paced color.
# Handy for eyeballing changes and for capturing the README screenshot.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SL="$HERE/statusline.sh"
NOW=$(date +%s)

# mock <5h_pct> <5h_offset_s> <7d_pct> <7d_offset_s> [model]
mock() {
  printf '{"cwd":"/x/claudometer","model":{"display_name":"%s"},"effort":{"level":"high"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s},"seven_day":{"used_percentage":%s,"resets_at":%s}}}' \
    "${5:-Opus 4.8}" "$1" "$((NOW+$2))" "$3" "$((NOW+$4))"
}
AHEAD=$(mock 5 3600 8 518400)      # both windows ahead of pace
ONPACE=$(mock 42 9000 45 302400)   # both on pace
BEHIND=$(mock 80 9000 85 302400)   # both burning too fast
SPLIT=$(mock 80 9000 8 518400)     # 5h behind, 7d ahead → the two bars disagree
NOLIMITS='{"cwd":"/x/foo","model":{"display_name":"Sonnet 4.6"},"context_window":{"used_percentage":15}}'

hdr() { printf '\n\033[1;36m══ %s ══\033[0m\n' "$1"; }
run() { local m=$1; shift; printf '%s' "$m" | env "$@" bash "$SL"; echo; }

hdr "Pace states — fuel · segmented · en"
run "$AHEAD"; run "$ONPACE"; run "$BEHIND"
hdr "Split windows — 5h behind pace, 7d ahead"
run "$SPLIT"
hdr "Language — pt-br"
run "$BEHIND" CLAUDOMETER_LANG=pt
hdr "Themes — behind pace"
run "$BEHIND" CLAUDOMETER_THEME=nord
run "$BEHIND" CLAUDOMETER_THEME=dracula
hdr "Styles"
run "$BEHIND" CLAUDOMETER_STYLE=blocks
run "$BEHIND" CLAUDOMETER_STYLE=compact
hdr "No rate limits — fresh / free session (5h/7d hidden)"
run "$NOLIMITS"
