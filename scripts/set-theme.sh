#!/bin/bash
# set-theme.sh <fuel|nord|dracula> [segmented|blocks|compact] [en|pt]  (args in any order)
# Deterministically rewrites ONLY the env-var prefix on the statusLine command in
# ~/.claude/settings.json, preserving the script path. No LLM interpretation needed —
# the /claudometer:theme skill just runs this and reports its output.
set -e
S="$HOME/.claude/settings.json"
[ -f "$S" ] || { echo "settings.json not found at $S"; exit 1; }
CUR=$(jq -r '.statusLine.command // empty' "$S")
[ -n "$CUR" ] || { echo "no statusLine configured — run /claudometer:setup first"; exit 1; }

PATH_ONLY=$(printf '%s' "$CUR" | awk '{print $NF}')                       # the script path (last token)
THEME=$(printf '%s' "$CUR" | grep -oE 'CLAUDOMETER_THEME=[a-z]+' | cut -d= -f2)   # keep current values
STYLE=$(printf '%s' "$CUR" | grep -oE 'CLAUDOMETER_STYLE=[a-z]+' | cut -d= -f2)    # for dimensions the
LANG_=$(printf '%s' "$CUR" | grep -oE 'CLAUDOMETER_LANG=[a-z]+'  | cut -d= -f2)    # user doesn't name

for a in "$@"; do
  case "$a" in
    fuel|nord|dracula)          THEME="$a" ;;
    segmented|blocks|compact)   STYLE="$a" ;;
    en|pt)                      LANG_="$a" ;;
    *) echo "unknown option: '$a' (themes: fuel/nord/dracula · styles: segmented/blocks/compact · langs: en/pt)"; exit 1 ;;
  esac
done

prefix=""
[ -n "$THEME" ] && [ "$THEME" != fuel ]      && prefix="${prefix}CLAUDOMETER_THEME=$THEME "
[ -n "$STYLE" ] && [ "$STYLE" != segmented ] && prefix="${prefix}CLAUDOMETER_STYLE=$STYLE "
[ -n "$LANG_" ] && [ "$LANG_" != en ]        && prefix="${prefix}CLAUDOMETER_LANG=$LANG_ "

TMP=$(mktemp)
jq --arg c "${prefix}${PATH_ONLY}" '.statusLine.command=$c' "$S" > "$TMP" && mv "$TMP" "$S"
echo "claudometer → ${prefix}${PATH_ONLY}"
echo "(the bar updates on the next prompt)"
