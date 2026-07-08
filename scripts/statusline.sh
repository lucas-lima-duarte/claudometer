#!/bin/bash
input=$(cat)

# Portable epoch->string formatter.
# macOS/BSD uses `date -r <epoch>`; Linux/WSL (GNU) uses `date -d @<epoch>`.
# Try BSD form first, fall back to GNU — works on both without detecting the OS.
fmt_epoch() {
  date -r "$1" "$2" 2>/dev/null || date -d "@$1" "$2" 2>/dev/null
}

# Colors
CYAN='\033[36m'
GREEN='\033[32m'
GREEN_BRIGHT='\033[38;5;120m'
ORANGE='\033[38;5;214m'
ORANGE_BRIGHT='\033[38;5;215m'
MODEL_COLOR='\033[38;5;208m'
RED='\033[31m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'
ACTIVE_DIM_GRAY='\033[2;37m'

# Current dir — basename only, like robbyrussell theme
CWD_FULL=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // empty')
if [ -n "$CWD_FULL" ]; then
  CWD=$(basename "$CWD_FULL")
else
  CWD=$(basename "$(pwd)")
fi

# Model display name
MODEL=$(echo "$input" | jq -r '.model.display_name // empty')

# Effort level
EFFORT=$(echo "$input" | jq -r '.effort.level // empty')

# Context used percentage
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

pct_color() {
  local pct=$1
  if [ "$pct" -lt 50 ]; then
    echo "$GREEN"
  elif [ "$pct" -lt 75 ]; then
    echo "$MODEL_COLOR"
  else
    echo "$RED"
  fi
}

pct_color_bright() {
  local pct=$1
  if [ "$pct" -lt 50 ]; then
    echo "$GREEN_BRIGHT"
  elif [ "$pct" -lt 75 ]; then
    echo "$ORANGE_BRIGHT"
  else
    # Red state: luminous light-salmon (256-color) — stands out more than plain 91m
    echo '\033[38;5;210m'
  fi
}

# Pacing-based color: compares pct against the "budget up to the active segment".
#   Green  = pct < floor of the active segment (ahead of pace, budget to spare)
#   Orange = pct within the active segment (spending this hour's/day's share)
#   Red    = pct past the ceiling of the active segment (burned quota, behind pace)
# Fallback: if active_seg < 0 (no time data), use the absolute pct_color.
pct_color_paced() {
  local pct=$1
  local n_segs=$2
  local active_seg=$3
  if [ "$active_seg" -lt 0 ]; then
    pct_color "$pct"
    return
  fi
  local floor=$(( active_seg * 100 / n_segs ))
  local ceil=$(( (active_seg + 1) * 100 / n_segs ))
  if [ "$pct" -lt "$floor" ]; then
    echo "$GREEN"
  elif [ "$pct" -le "$ceil" ]; then
    echo "$MODEL_COLOR"
  else
    echo "$RED"
  fi
}

pct_color_bright_paced() {
  local pct=$1
  local n_segs=$2
  local active_seg=$3
  if [ "$active_seg" -lt 0 ]; then
    pct_color_bright "$pct"
    return
  fi
  local floor=$(( active_seg * 100 / n_segs ))
  local ceil=$(( (active_seg + 1) * 100 / n_segs ))
  if [ "$pct" -lt "$floor" ]; then
    echo "$GREEN_BRIGHT"
  elif [ "$pct" -le "$ceil" ]; then
    echo "$ORANGE_BRIGHT"
  else
    echo '\033[38;5;210m'
  fi
}

# Build a bar made of N_SEGS segments, each SEG_W blocks wide, separated by single spaces.
# Total visual width = N_SEGS * SEG_W + (N_SEGS - 1) gaps.
# Bars are sized for horizontal/series layout on a single line (~109 visible chars total):
#   Session: 1 seg  x 24 blocks           = 24
#   5-hour:  5 segs x  4 blocks + 4 gaps  = 24
#   Weekly:  7 segs x  4 blocks + 6 gaps  = 34
#
# Usage: build_bar_segs <pct> <n_segs> <seg_w> [active_seg_idx] [bar_color_bright] [filled_char] [dim_char]
# active_seg_idx:  0-based index of current segment to highlight (-1 = none)
# bar_color_bright: bright/bold variant of BAR_COLOR used when active seg is filled
# filled_char:     character for filled blocks (default ━)
# dim_char:        character for empty/dim blocks (default ─)
#
# 4-state scheme per block:
#   non-active + filled  → BAR_COLOR       filled_char
#   non-active + dim     → DIM             dim_char
#   active     + filled  → BAR_COLOR_BRIGHT filled_char
#   active     + dim     → BAR_COLOR_BRIGHT dim_char     (same bright color, dim char)
build_bar_segs() {
  local pct=$1
  local n_segs=$2
  local seg_w=$3
  local active_seg=${4:--1}
  local BAR_COLOR_BRIGHT=${5:-'\033[1;97m'}
  local filled_char=${6:-━}
  local dim_char=${7:-─}
  local BAR_COLOR_OVERRIDE=${8:-}
  local total_blocks=$(( n_segs * seg_w ))
  local filled=$(( pct * total_blocks / 100 ))
  local BAR_COLOR
  if [ -n "$BAR_COLOR_OVERRIDE" ]; then
    BAR_COLOR=$BAR_COLOR_OVERRIDE
  else
    BAR_COLOR=$(pct_color "$pct")
  fi

  local bar=""
  local blocks_drawn=0
  local seg=0
  while [ $seg -lt $n_segs ]; do
    # Gap between segments — small gray square, 1 column
    if [ $seg -gt 0 ]; then
      bar="${bar}\033[90m▪\033[0m"
    fi
    local b=0
    while [ $b -lt $seg_w ]; do
      if [ "$seg" -eq "$active_seg" ]; then
        if [ $blocks_drawn -lt $filled ]; then
          # Active + filled: bright/bold variant of bar color
          bar="${bar}${BAR_COLOR_BRIGHT}${filled_char}"
        else
          # Active + dim: subtle light gray (visible but not highlighted)
          bar="${bar}${ACTIVE_DIM_GRAY}${dim_char}"
        fi
      elif [ $blocks_drawn -lt $filled ]; then
        bar="${bar}${BAR_COLOR}${filled_char}"
      else
        bar="${bar}${DIM}${dim_char}"
      fi
      blocks_drawn=$(( blocks_drawn + 1 ))
      b=$(( b + 1 ))
    done
    seg=$(( seg + 1 ))
  done
  bar="${bar}${RESET}"
  printf '%b' "$bar"
}

# Rate limits
FIVE_HOUR_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_HOUR_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
SEVEN_DAY_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
SEVEN_DAY_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Line 1: folder + model + effort
printf "${CYAN}${BOLD}%s${RESET}" "$CWD"
[ -n "$MODEL" ] && printf "  ${BOLD}${MODEL_COLOR}%s${RESET}" "$MODEL"
[ -n "$EFFORT" ] && printf "  ${BOLD}${MODEL_COLOR}%s effort${RESET}" "$EFFORT"
printf "\n"

# Build segment: Session (1 seg x 24 blocks = 24 visual)
CTX_COLOR=$(pct_color "$CTX_PCT")
CTX_BAR=$(build_bar_segs "$CTX_PCT" 1 24)
SESSION_SEG=$(printf "\033[38;5;214m%-7s\033[0m %b %b%3s%%\033[0m" \
  "Session" "$CTX_BAR" "$CTX_COLOR" "$CTX_PCT")

# Build segment: 5-hour (5 segs x 4 blocks + 4 gaps = 24 visual)
FIVE_SEG=""
if [ -n "$FIVE_HOUR_PCT" ]; then
  FIVE_H=$(echo "$FIVE_HOUR_PCT" | cut -d. -f1)
  FIVE_RESET_STR=""
  FIVE_ACTIVE_SEG=-1
  if [ -n "$FIVE_HOUR_RESET" ]; then
    _fdate=$(fmt_epoch "$FIVE_HOUR_RESET" "+%H:%M")
    [ -n "$_fdate" ] && FIVE_RESET_STR=$(printf " \033[2m%s\033[0m" "$_fdate")
    # Window started 5h before reset; active seg = floor((now - start) / 3600), clamped 0-4
    NOW_TS=$(date +%s)
    FIVE_WIN_START=$(( FIVE_HOUR_RESET - 5 * 3600 ))
    FIVE_ELAPSED=$(( NOW_TS - FIVE_WIN_START ))
    if [ "$FIVE_ELAPSED" -ge 0 ]; then
      FIVE_ACTIVE_SEG=$(( FIVE_ELAPSED / 3600 ))
      [ "$FIVE_ACTIVE_SEG" -gt 4 ] && FIVE_ACTIVE_SEG=4
    fi
  fi
  FIVE_COLOR=$(pct_color_paced "$FIVE_H" 5 "$FIVE_ACTIVE_SEG")
  FIVE_COLOR_BRIGHT=$(pct_color_bright_paced "$FIVE_H" 5 "$FIVE_ACTIVE_SEG")
  FIVE_BAR=$(build_bar_segs "$FIVE_H" 5 4 "$FIVE_ACTIVE_SEG" "$FIVE_COLOR_BRIGHT" ━ ─ "$FIVE_COLOR")
  FIVE_SEG=$(printf "\033[38;5;214m%-7s\033[0m %b %b%3s%%\033[0m%s" \
    "5-hour" "$FIVE_BAR" "$FIVE_COLOR" "$FIVE_H" "$FIVE_RESET_STR")
fi

# Build segment: Weekly (7 segs x 4 blocks + 6 gaps = 34 visual)
SEVEN_SEG=""
if [ -n "$SEVEN_DAY_PCT" ]; then
  SEVEN_D=$(echo "$SEVEN_DAY_PCT" | cut -d. -f1)
  SEVEN_RESET_STR=""
  SEVEN_ACTIVE_SEG=-1
  if [ -n "$SEVEN_DAY_RESET" ]; then
    _sdate=$(fmt_epoch "$SEVEN_DAY_RESET" "+%a %d %b")
    [ -n "$_sdate" ] && SEVEN_RESET_STR=$(printf " \033[2m%s\033[0m" "$_sdate")
    # Window started 7 days before reset; active seg = floor((now - start) / 86400), clamped 0-6
    NOW_TS=$(date +%s)
    SEVEN_WIN_START=$(( SEVEN_DAY_RESET - 7 * 86400 ))
    SEVEN_ELAPSED=$(( NOW_TS - SEVEN_WIN_START ))
    if [ "$SEVEN_ELAPSED" -ge 0 ]; then
      SEVEN_ACTIVE_SEG=$(( SEVEN_ELAPSED / 86400 ))
      [ "$SEVEN_ACTIVE_SEG" -gt 6 ] && SEVEN_ACTIVE_SEG=6
    fi
  fi
  SEVEN_COLOR=$(pct_color_paced "$SEVEN_D" 7 "$SEVEN_ACTIVE_SEG")
  SEVEN_COLOR_BRIGHT=$(pct_color_bright_paced "$SEVEN_D" 7 "$SEVEN_ACTIVE_SEG")
  SEVEN_BAR=$(build_bar_segs "$SEVEN_D" 7 4 "$SEVEN_ACTIVE_SEG" "$SEVEN_COLOR_BRIGHT" ━ ─ "$SEVEN_COLOR")
  SEVEN_SEG=$(printf "\033[38;5;214m%-7s\033[0m %b %b%3s%%\033[0m%s" \
    "Weekly" "$SEVEN_BAR" "$SEVEN_COLOR" "$SEVEN_D" "$SEVEN_RESET_STR")
fi

# Lines 2+: each bar on its own line (stacked vertically)
printf '%s\n' "$SESSION_SEG"
[ -n "$FIVE_SEG" ]  && printf '%s\n' "$FIVE_SEG"
[ -n "$SEVEN_SEG" ] && printf '%s\n' "$SEVEN_SEG"

# Force exit 0 — in a fresh session without rate_limits, the last `[ -n ... ] &&`
# short-circuits and makes the whole script exit 1, which makes Claude Code
# suppress the statusline until the first turn populates rate_limits.
exit 0
