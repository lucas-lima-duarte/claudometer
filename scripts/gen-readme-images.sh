#!/bin/bash
# Regenerate the README SVGs in docs/ from the statusline itself.
HERE=$(cd "$(dirname "$0")" && pwd); R=$(dirname "$HERE")
SL="$HERE/statusline.sh"; A2S="$HERE/ansi2svg.py"; DOCS="$R/docs"; mkdir -p "$DOCS"
NOW=$(date +%s)
mock()      { printf '{"cwd":"claudometer","model":{"display_name":"Opus 4.8"},"effort":{"level":"high"},"context_window":{"used_percentage":55},"rate_limits":{"five_hour":{"used_percentage":80,"resets_at":%d},"seven_day":{"used_percentage":44,"resets_at":%d}}}' $((NOW+9000)) $((NOW+302400)); }
hero_mock() { printf '{"cwd":"claudometer","model":{"display_name":"Opus 4.8"},"effort":{"level":"high"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":8,"resets_at":%d},"seven_day":{"used_percentage":10,"resets_at":%d}}}' $((NOW+5400)) $((NOW+120000)); }
gen() { eval "$1" | env $2 bash "$SL" | python3 "$A2S" "$3" > "$DOCS/$4"; }
gen hero_mock "CLAUDOMETER_THEME=fuel" ""               hero.svg
gen mock "CLAUDOMETER_THEME=fuel"      "theme: fuel"    theme-fuel.svg
gen mock "CLAUDOMETER_THEME=nord"      "theme: nord"    theme-nord.svg
gen mock "CLAUDOMETER_THEME=dracula"   "theme: dracula" theme-dracula.svg
gen mock "CLAUDOMETER_STYLE=blocks"    "style: blocks"  style-blocks.svg
gen mock "CLAUDOMETER_STYLE=compact"   "style: compact" style-compact.svg
gen mock "CLAUDOMETER_LANG=pt"         "language: pt"   lang-pt.svg
echo "done: $DOCS"
