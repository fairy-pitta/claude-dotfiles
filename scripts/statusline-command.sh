#!/bin/zsh
# Claude Code Status Line - 3-line display with rate limit info
# stdin: JSON with model, context, cost, workspace, rate_limits info
# Rate limits are now provided natively by Claude Code via stdin JSON
# Uses zsh for native Unicode escape support (\uXXXX)

input=$(cat)

# ── Parse stdin JSON ─────────────────────────────────────────────
model_id=$(echo "$input" | jq -r '.model.id // ""')
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
context_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')

# Model display name
case "$model_id" in
  *opus-4-6*|*opus-4*)     model_display="Opus 4.6" ;;
  *sonnet-4-6*|*sonnet-4*) model_display="Sonnet 4.6" ;;
  *haiku-4-5*|*haiku-4*)   model_display="Haiku 4.5" ;;
  *)                        model_display="$model_name" ;;
esac

# Git branch
branch="N/A"
if [[ -n "$cwd" ]] && [[ -d "$cwd" ]]; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")
fi

ctx_pct=$(printf "%.0f" "${context_pct:-0}" 2>/dev/null || echo "0")

# ── ANSI 24-bit colors ──────────────────────────────────────────
GREEN=$'\033[38;2;151;201;195m'    # #97C9C3
YELLOW=$'\033[38;2;229;192;123m'   # #E5C07B
RED=$'\033[38;2;224;108;117m'      # #E06C75
GRAY=$'\033[38;2;74;88;92m'        # #4A585C
RESET=$'\033[0m'

color_for_pct() {
  local pct=${1:-0}
  if (( pct >= 80 )); then
    echo "$RED"
  elif (( pct >= 50 )); then
    echo "$YELLOW"
  else
    echo "$GREEN"
  fi
}

# ── Nerd Font icons ─────────────────────────────────────────────
ICON_BRANCH=$'\uE725'
ICON_CLOCK=$'\uF017'
ICON_CAL=$'\uF073'

# ── Progress bar (10 segments: ▰▱) ──────────────────────────────
progress_bar() {
  local pct=${1:-0}
  local filled=$(( (pct + 5) / 10 ))
  (( filled > 10 )) && filled=10
  (( filled < 0 )) && filled=0
  local empty=$((10 - filled))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="▰"; done
  for ((i=0; i<empty; i++)); do bar+="▱"; done
  echo "$bar"
}

# ── Rate limits from stdin JSON ──────────────────────────────────
five_pct_raw=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_pct_raw=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_reset_epoch=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_reset_epoch=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

has_rate_limits=false
if [[ -n "$five_pct_raw" ]] || [[ -n "$seven_pct_raw" ]]; then
  has_rate_limits=true
fi

five_pct=$(printf "%.0f" "${five_pct_raw:-0}" 2>/dev/null || echo "0")
seven_pct=$(printf "%.0f" "${seven_pct_raw:-0}" 2>/dev/null || echo "0")

# Format reset time from Unix epoch (macOS BSD date)
format_reset() {
  local epoch=$1 fmt=$2
  if [[ -z "$epoch" ]] || [[ "$epoch" = "null" ]]; then echo "?"; return; fi
  local result=$(TZ=Asia/Singapore date -r "$epoch" "+$fmt" 2>/dev/null || echo "?")
  echo "$result" | sed 's/AM/am/g;s/PM/pm/g'
}

five_reset=$(format_reset "$five_reset_epoch" "%-l%p")
seven_reset=$(format_reset "$seven_reset_epoch" "%b %-d at %-l%p")

# ── Output 3 lines ──────────────────────────────────────────────
ctx_c=$(color_for_pct "$ctx_pct")

# Line 1: model │ context │ lines │ branch
echo "${ctx_c}${model_display}${RESET} ${GRAY}│${RESET} ${ctx_c}${ctx_pct}%${RESET} ${GRAY}│${RESET} ${ctx_c}+${lines_added}/-${lines_removed}${RESET} ${GRAY}│${RESET} ${ctx_c}${ICON_BRANCH} ${branch}${RESET}"

if ! $has_rate_limits; then
  # Rate limits not yet available (before first API response)
  echo "${GRAY}${ICON_CLOCK} 5h  ▱▱▱▱▱▱▱▱▱▱  --  waiting for data${RESET}"
  echo "${GRAY}${ICON_CAL} 7d  ▱▱▱▱▱▱▱▱▱▱  --  waiting for data${RESET}"
else
  five_c=$(color_for_pct "$five_pct")
  seven_c=$(color_for_pct "$seven_pct")
  # Line 2: 5-hour rate limit
  echo "${five_c}${ICON_CLOCK} 5h  $(progress_bar "$five_pct")  ${five_pct}%${RESET}  Resets ${five_reset} (SGT)"
  # Line 3: 7-day rate limit
  echo "${seven_c}${ICON_CAL} 7d  $(progress_bar "$seven_pct")  ${seven_pct}%${RESET}  Resets ${seven_reset} (SGT)"
fi
