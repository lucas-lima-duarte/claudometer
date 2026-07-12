#!/bin/bash
input=$(cat)

# ─────────────────────────────────────────────────────────────────────────────
# Layer A — Config (all optional env vars; sane defaults == MVP behavior)
#   CLAUDOMETER_LANG   en | pt              (fallback: $LANG prefix; default en)
#   CLAUDOMETER_THEME  fuel | mono | neon                       (default fuel)
#   CLAUDOMETER_STYLE  segmented | blocks | compact             (default segmented)
# Invalid values fall back to the default.
# ─────────────────────────────────────────────────────────────────────────────
_lang_raw="${CLAUDOMETER_LANG:-}"
if [ -z "$_lang_raw" ]; then
  case "$LANG" in pt*|PT*) _lang_raw=pt ;; *) _lang_raw=en ;; esac
fi
case "$_lang_raw" in pt) LANG_SEL=pt ;; *) LANG_SEL=en ;; esac
case "${CLAUDOMETER_THEME:-fuel}"      in nord) THEME=nord ;; dracula) THEME=dracula ;; *) THEME=fuel ;; esac
case "${CLAUDOMETER_STYLE:-segmented}" in blocks) STYLE=blocks ;; compact) STYLE=compact ;; *) STYLE=segmented ;; esac
# Bar glyphs per style (segmented default == MVP). blocks = solid gauge, no dividers.
case "$STYLE" in
  blocks) BAR_FILL='█'; BAR_DIM='░'; BAR_DIV='' ;;
  *)      BAR_FILL='━'; BAR_DIM='─'; BAR_DIV='▪' ;;
esac

# Portable epoch->string formatter.
# macOS/BSD uses `date -r <epoch>`; Linux/WSL (GNU) uses `date -d @<epoch>`.
# Try BSD form first, fall back to GNU — works on both without detecting the OS.
fmt_epoch() {
  date -r "$1" "$2" 2>/dev/null || date -d "@$1" "$2" 2>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# Layer B — Colors. Structural styles are theme-independent; the state palette
# (ahead / on-pace / behind, base + bright) is set per theme. Variable NAMES are
# kept so pct_color*/build_bar_segs read them unchanged. fuel == the MVP literals.
#   GREEN/GREEN_BRIGHT = ahead   MODEL_COLOR/ORANGE_BRIGHT = on-pace
#   RED/SALMON = behind          ORANGE = bar labels
# ─────────────────────────────────────────────────────────────────────────────
CYAN='\033[36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'
ACTIVE_DIM_GRAY='\033[2;37m'
case "$THEME" in
  nord)                                   # nordtheme.com — official palette (truecolor)
    GREEN='\033[38;2;163;190;140m';       GREEN_BRIGHT='\033[38;2;192;214;168m'   # aurora green (ahead)
    MODEL_COLOR='\033[38;2;235;203;139m'; ORANGE_BRIGHT='\033[38;2;245;223;176m'  # aurora yellow (on-pace)
    RED='\033[38;2;191;97;106m';          SALMON='\033[38;2;208;135;112m'         # aurora red / orange (behind)
    ORANGE='\033[38;2;129;161;193m'                                               # frost blue (labels)
    ;;
  dracula)                                # draculatheme.com — official palette (truecolor)
    GREEN='\033[38;2;80;250;123m';        GREEN_BRIGHT='\033[38;2;125;251;155m'   # green (ahead)
    MODEL_COLOR='\033[38;2;255;184;108m'; ORANGE_BRIGHT='\033[38;2;255;203;143m'  # orange (on-pace)
    RED='\033[38;2;255;85;85m';           SALMON='\033[38;2;255;121;198m'         # red / pink (behind)
    ORANGE='\033[38;2;189;147;249m'                                               # purple (labels)
    ;;
  *)  # fuel (default) — MUST equal the MVP literals (G0 non-regression)
    GREEN='\033[32m';        GREEN_BRIGHT='\033[38;5;120m'
    MODEL_COLOR='\033[38;5;208m'; ORANGE_BRIGHT='\033[38;5;215m'
    RED='\033[31m';          SALMON='\033[38;5;210m'
    ORANGE='\033[38;5;214m'
    ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
# Layer C — i18n. bash 3.2 has no associative arrays → case only.
# Model names (Sonnet/Haiku) are never translated. Labels should fit 7 display
# columns; pad_label (below) keeps them aligned even with accents.
# ─────────────────────────────────────────────────────────────────────────────
t() {
  case "$LANG_SEL" in
    pt)
      case "$1" in
        boost) echo "acelera" ;; hold) echo "segura" ;; save) echo "economiza" ;;
        lbl_session) echo "Sessão" ;; lbl_5h) echo "5 horas" ;; lbl_weekly) echo "Semana" ;;
        tag_week) echo "semana" ;; tag_5h) echo "5h" ;;
        effort) echo "effort" ;;
      esac ;;
    *)
      case "$1" in
        boost) echo "boost it" ;; hold) echo "hold it" ;; save) echo "save it" ;;
        lbl_session) echo "Session" ;; lbl_5h) echo "5-hour" ;; lbl_weekly) echo "Weekly" ;;
        tag_week) echo "week" ;; tag_5h) echo "5h" ;;
        effort) echo "effort" ;;
      esac ;;
  esac
}

# pad_label <str> <width> — left-justify to <width> DISPLAY columns. Unlike printf %-Ns
# (which counts bytes), this counts characters, so accented pt labels like "Sessão"
# stay aligned. ${#s} is character-aware under a UTF-8 locale; under C/byte locales it
# degrades to the old (byte-based) behavior — never worse.
pad_label() {
  local s=$1 w=$2
  local i=${#s}   # separate line: ${#s} must see s already assigned (bash `local` gotcha)
  printf '%s' "$s"
  while [ "$i" -lt "$w" ]; do printf ' '; i=$(( i + 1 )); done
}

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
    # Behind-pace bright (salmon in fuel / amber in mono / hot-pink in neon)
    echo "$SALMON"
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
    echo "$SALMON"
  fi
}

# Draw a FIXED-WIDTH bar of TOTAL_COLS columns, split into N_SEGS time segments so every
# bar lines up regardless of how many segments it has. A segment boundary shows the divider
# glyph in `segmented`; `blocks` passes divider='' so those columns render as normal cells —
# either way the bar is exactly TOTAL_COLS columns wide.
#
# Usage: build_bar_segs <pct> <n_segs> <total_cols> [active_seg] [bright] [filled] [dim] [color_override] [divider]
# active_seg:      0-based index of current segment to highlight (-1 = none)
# bright:          bright/bold color used on the active filled cell
# filled / dim:    glyphs for filled / empty cells (default ━ / ─)
# color_override:  force the bar's base color (else derived from pct)
# divider:         glyph at segment boundaries (default ▪; '' = none, for the blocks style)
build_bar_segs() {
  local pct=$1
  local n_segs=$2
  local total=$3
  local active_seg=${4:--1}
  local BAR_COLOR_BRIGHT=${5:-'\033[1;97m'}
  local filled_char=${6:-━}
  local dim_char=${7:-─}
  local BAR_COLOR_OVERRIDE=${8:-}
  local divider_char=${9-▪}   # unset → default ▪; explicit '' (blocks) → no divider
  local filled=$(( pct * total / 100 ))
  local BAR_COLOR
  if [ -n "$BAR_COLOR_OVERRIDE" ]; then
    BAR_COLOR=$BAR_COLOR_OVERRIDE
  else
    BAR_COLOR=$(pct_color "$pct")
  fi

  local bar="" c=0 prev_seg=0 seg
  while [ $c -lt $total ]; do
    seg=$(( c * n_segs / total ))
    if [ $c -gt 0 ] && [ "$seg" != "$prev_seg" ] && [ -n "$divider_char" ]; then
      # Segment boundary — divider glyph (gray, not part of the fill)
      bar="${bar}\033[90m${divider_char}\033[0m"
    elif [ "$seg" -eq "$active_seg" ]; then
      if [ $c -lt $filled ]; then
        bar="${bar}${BAR_COLOR_BRIGHT}${filled_char}"   # active + filled
      else
        bar="${bar}${ACTIVE_DIM_GRAY}${dim_char}"        # active + dim
      fi
    elif [ $c -lt $filled ]; then
      bar="${bar}${BAR_COLOR}${filled_char}"
    else
      bar="${bar}${DIM}${dim_char}"
    fi
    prev_seg=$seg
    c=$(( c + 1 ))
  done
  bar="${bar}${RESET}"
  printf '%b' "$bar"
}

# ─────────────────────────────────────────────────────────────────────────────
# Layer D — Pace / pedal (pure functions).
# ─────────────────────────────────────────────────────────────────────────────

# active_segment <reset_epoch> <window_seconds> <n_segs>
#   → 0-based index of the current time segment, clamped [0, n-1]; -1 if no usable
#     time data (empty reset, or now < window_start). Replaces the old inline calc.
active_segment() {
  local reset=$1 window=$2 n=$3 now win_start elapsed seg
  [ -z "$reset" ] && { echo -1; return; }
  now=$(date +%s)
  win_start=$(( reset - window ))
  elapsed=$(( now - win_start ))
  [ "$elapsed" -lt 0 ] && { echo -1; return; }
  seg=$(( elapsed / (window / n) ))
  [ "$seg" -gt $(( n - 1 )) ] && seg=$(( n - 1 ))
  echo "$seg"
}

# pace_state <pct> <n_segs> <active_seg> → boost | hold | save
#   KEEP THE THRESHOLDS IN SYNC WITH pct_color_paced (same floor/ceil math) so the
#   pedal never contradicts the bar color of the same window.
pace_state() {
  local pct=$1 n=$2 seg=$3 floor ceil
  if [ "$seg" -lt 0 ]; then
    if   [ "$pct" -lt 50 ]; then echo boost
    elif [ "$pct" -lt 75 ]; then echo hold
    else echo save; fi
    return
  fi
  floor=$(( seg * 100 / n ))
  ceil=$(( (seg + 1) * 100 / n ))
  if   [ "$pct" -lt "$floor" ]; then echo boost
  elif [ "$pct" -le "$ceil" ]; then echo hold
  else echo save; fi
}

# pace_severity <state> → 0 boost / 1 hold / 2 save   (for picking the winner)
pace_severity() {
  case "$1" in boost) echo 0 ;; hold) echo 1 ;; save) echo 2 ;; *) echo -1 ;; esac
}

# downgrade_target <model_display_name> → Sonnet | Haiku | /compact
#   Biggest quota saving first; contextual to the current model.
downgrade_target() {
  case "$1" in
    *Opus*)   echo "Sonnet" ;;
    *Sonnet*) echo "Haiku" ;;
    *Haiku*)  echo "/compact" ;;
    *)        echo "/compact" ;;
  esac
}

# pedal_render <state> <conflict_tag> <model>
#   Emits (via %b): "● ● ●  <word>[ · <tag>][ → <target>]"
#   The dot at the state's position lights in the state's bright color; the other
#   two are DIM. Word in the state color. Tag (dim) only on conflict; action (dim,
#   " → model") only on save.
pedal_render() {
  local state=$1 tag=$2 model=$3 d1="$DIM" d2="$DIM" d3="$DIM" wc="$DIM" out
  case "$state" in
    boost) d1="$GREEN_BRIGHT";  wc="$GREEN_BRIGHT" ;;
    hold)  d2="$ORANGE_BRIGHT"; wc="$ORANGE_BRIGHT" ;;
    save)  d3="$SALMON";        wc="$SALMON" ;;
  esac
  out="${d1}●${RESET} ${d2}●${RESET} ${d3}●${RESET}  ${BOLD}${wc}$(t "$state")${RESET}"
  [ -n "$tag" ] && out="${out} ${DIM}· ${tag}${RESET}"
  [ "$state" = "save" ] && out="${out} ${DIM}→ $(downgrade_target "$model")${RESET}"
  printf '%b' "$out"
}

# render_compact — one-line layout (STYLE=compact). Keeps claudometer's core idea —
# a paced bar — in miniature: folder, model, the pedal, then a short 10-column gauge
# (paced color) + % for 5h and 7d. Omits the Session bar for a minimal footprint.
render_compact() {
  local mb
  printf "${CYAN}${BOLD}%s${RESET}" "$CWD"
  [ -n "$MODEL" ]     && printf "  ${BOLD}${MODEL_COLOR}%s${RESET}" "$MODEL"
  [ -n "$PEDAL_STR" ] && printf "  %b" "$PEDAL_STR"
  if [ -n "$FIVE_H" ]; then
    mb=$(build_bar_segs "$FIVE_H" 1 10 -1 '\033[1;97m' "$BAR_FILL" "$BAR_DIM" "$FIVE_COLOR")
    printf "   ${DIM}5h${RESET} %b %b%s%%${RESET}" "$mb" "$FIVE_COLOR" "$FIVE_H"
  fi
  if [ -n "$SEVEN_D" ]; then
    mb=$(build_bar_segs "$SEVEN_D" 1 10 -1 '\033[1;97m' "$BAR_FILL" "$BAR_DIM" "$SEVEN_COLOR")
    printf "  ${DIM}7d${RESET} %b %b%s%%${RESET}" "$mb" "$SEVEN_COLOR" "$SEVEN_D"
  fi
  printf "\n"
}

# Rate limits
FIVE_HOUR_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_HOUR_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
SEVEN_DAY_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
SEVEN_DAY_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# ─────────────────────────────────────────────────────────────────────────────
# Layer E — Early pace compute (the pedal must be ready before line 1 prints).
# Also produces FIVE_H/SEVEN_D/FIVE_ACTIVE_SEG/SEVEN_ACTIVE_SEG reused by the bars.
# ─────────────────────────────────────────────────────────────────────────────
FIVE_H=""; SEVEN_D=""
FIVE_ACTIVE_SEG=-1; SEVEN_ACTIVE_SEG=-1
FIVE_STATE=""; SEVEN_STATE=""
if [ -n "$FIVE_HOUR_PCT" ]; then
  FIVE_H=$(echo "$FIVE_HOUR_PCT" | cut -d. -f1)
  FIVE_ACTIVE_SEG=$(active_segment "$FIVE_HOUR_RESET" 18000 5)
  FIVE_STATE=$(pace_state "$FIVE_H" 5 "$FIVE_ACTIVE_SEG")
fi
if [ -n "$SEVEN_DAY_PCT" ]; then
  SEVEN_D=$(echo "$SEVEN_DAY_PCT" | cut -d. -f1)
  SEVEN_ACTIVE_SEG=$(active_segment "$SEVEN_DAY_RESET" 604800 7)
  SEVEN_STATE=$(pace_state "$SEVEN_D" 7 "$SEVEN_ACTIVE_SEG")
fi

# Synthesize one pedal from both windows: the more severe window wins; a dim tag
# names the winning window only when the two disagree.
PEDAL_STR=""
_ped_state=""; _ped_tag=""
if [ -n "$FIVE_STATE" ] && [ -n "$SEVEN_STATE" ]; then
  if [ "$(pace_severity "$SEVEN_STATE")" -ge "$(pace_severity "$FIVE_STATE")" ]; then
    _ped_state="$SEVEN_STATE"; _ped_win=week
  else
    _ped_state="$FIVE_STATE";  _ped_win=5h
  fi
  if [ "$FIVE_STATE" != "$SEVEN_STATE" ]; then
    [ "$_ped_win" = week ] && _ped_tag=$(t tag_week) || _ped_tag=$(t tag_5h)
  fi
elif [ -n "$FIVE_STATE" ]; then
  _ped_state="$FIVE_STATE"
elif [ -n "$SEVEN_STATE" ]; then
  _ped_state="$SEVEN_STATE"
fi
[ -n "$_ped_state" ] && PEDAL_STR=$(pedal_render "$_ped_state" "$_ped_tag" "$MODEL")

# Line 1: folder + model + effort + pedal (stacked styles; compact renders separately)
if [ "$STYLE" != "compact" ]; then
  printf "${CYAN}${BOLD}%s${RESET}" "$CWD"
  [ -n "$MODEL" ] && printf "  ${BOLD}${MODEL_COLOR}%s${RESET}" "$MODEL"
  [ -n "$EFFORT" ] && printf "  ${BOLD}${MODEL_COLOR}%s $(t effort)${RESET}" "$EFFORT"
  [ -n "$PEDAL_STR" ] && printf "   %b" "$PEDAL_STR"
  printf "\n"
fi

# Build segment: Session — 1 segment, 28 columns
CTX_COLOR=$(pct_color "$CTX_PCT")
CTX_BAR=$(build_bar_segs "$CTX_PCT" 1 28 -1 '\033[1;97m' "$BAR_FILL" "$BAR_DIM")
SESSION_SEG=$(printf "${ORANGE}%s\033[0m %b %b%3s%%\033[0m" \
  "$(pad_label "$(t lbl_session)" 7)" "$CTX_BAR" "$CTX_COLOR" "$CTX_PCT")

# Build segment: 5-hour — 5 segments (one per hour), 28 columns
FIVE_SEG=""
if [ -n "$FIVE_HOUR_PCT" ]; then
  # FIVE_H / FIVE_ACTIVE_SEG already computed in Layer E.
  FIVE_RESET_STR=""
  if [ -n "$FIVE_HOUR_RESET" ]; then
    _fdate=$(fmt_epoch "$FIVE_HOUR_RESET" "+%H:%M")
    [ -n "$_fdate" ] && FIVE_RESET_STR=$(printf " \033[2m%s\033[0m" "$_fdate")
  fi
  FIVE_COLOR=$(pct_color_paced "$FIVE_H" 5 "$FIVE_ACTIVE_SEG")
  FIVE_COLOR_BRIGHT=$(pct_color_bright_paced "$FIVE_H" 5 "$FIVE_ACTIVE_SEG")
  FIVE_BAR=$(build_bar_segs "$FIVE_H" 5 28 "$FIVE_ACTIVE_SEG" "$FIVE_COLOR_BRIGHT" "$BAR_FILL" "$BAR_DIM" "$FIVE_COLOR" "$BAR_DIV")
  FIVE_SEG=$(printf "${ORANGE}%s\033[0m %b %b%3s%%\033[0m%s" \
    "$(pad_label "$(t lbl_5h)" 7)" "$FIVE_BAR" "$FIVE_COLOR" "$FIVE_H" "$FIVE_RESET_STR")
fi

# Build segment: Weekly — 7 segments (one per day), 28 columns
SEVEN_SEG=""
if [ -n "$SEVEN_DAY_PCT" ]; then
  # SEVEN_D / SEVEN_ACTIVE_SEG already computed in Layer E.
  SEVEN_RESET_STR=""
  if [ -n "$SEVEN_DAY_RESET" ]; then
    _sdate=$(fmt_epoch "$SEVEN_DAY_RESET" "+%a %d %b")
    [ -n "$_sdate" ] && SEVEN_RESET_STR=$(printf " \033[2m%s\033[0m" "$_sdate")
  fi
  SEVEN_COLOR=$(pct_color_paced "$SEVEN_D" 7 "$SEVEN_ACTIVE_SEG")
  SEVEN_COLOR_BRIGHT=$(pct_color_bright_paced "$SEVEN_D" 7 "$SEVEN_ACTIVE_SEG")
  SEVEN_BAR=$(build_bar_segs "$SEVEN_D" 7 28 "$SEVEN_ACTIVE_SEG" "$SEVEN_COLOR_BRIGHT" "$BAR_FILL" "$BAR_DIM" "$SEVEN_COLOR" "$BAR_DIV")
  SEVEN_SEG=$(printf "${ORANGE}%s\033[0m %b %b%3s%%\033[0m%s" \
    "$(pad_label "$(t lbl_weekly)" 7)" "$SEVEN_BAR" "$SEVEN_COLOR" "$SEVEN_D" "$SEVEN_RESET_STR")
fi

# Layer F — output per style. segmented/blocks share the stacked layout (bar glyphs
# already differ via BAR_FILL/BAR_DIM/BAR_DIV); compact is a single line.
if [ "$STYLE" = "compact" ]; then
  render_compact
else
  printf '%s\n' "$SESSION_SEG"
  [ -n "$FIVE_SEG" ]  && printf '%s\n' "$FIVE_SEG"
  [ -n "$SEVEN_SEG" ] && printf '%s\n' "$SEVEN_SEG"
fi

# Force exit 0 — in a fresh session without rate_limits, the last `[ -n ... ] &&`
# short-circuits and makes the whole script exit 1, which makes Claude Code
# suppress the statusline until the first turn populates rate_limits.
exit 0
