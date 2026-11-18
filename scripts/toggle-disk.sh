#!/bin/bash
# toggle-disk.sh — hides/shows the disk column. The statusline reads this flag file
# on every refresh; the /claudometer:disk skill just runs this and reports its output.
f="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/state/claudometer-disk-hidden"
if [ -e "$f" ]; then
  rm "$f" && echo "disk: shown"
else
  mkdir -p "$(dirname "$f")" && touch "$f" && echo "disk: hidden"
fi
