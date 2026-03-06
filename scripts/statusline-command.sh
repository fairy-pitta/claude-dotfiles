#!/bin/zsh
# Claude Code Status Line - 3-line display with rate limit info
# stdin: JSON with model, context, cost, workspace info
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

# ── Rate limit: fetch & cache ───────────────────────────────────
CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_TTL=360
CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"

five_pct=0; seven_pct=0
five_reset="?"; seven_reset="?"

need_refresh=true
if [[ -f "$CACHE_FILE" ]]; then
  cache_ts=$(jq -r '.cached_at // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
  now=$(date +%s)
  if (( now - cache_ts < CACHE_TTL )); then
    need_refresh=false
  fi
fi

if $need_refresh; then
  creds_json=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)
  token=$(echo "$creds_json" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null || true)

  if [[ -n "$token" ]]; then
    # API requires anthropic-beta header
    resp=$(curl -s -H "Authorization: Bearer $token" \
      -H "anthropic-beta: oauth-2025-04-20" \
      "https://api.anthropic.com/api/oauth/usage" 2>/dev/null || true)

    # If error (429/401), try token refresh
    if [[ -z "$resp" ]] || echo "$resp" | jq -e '.error' >/dev/null 2>&1; then
      refresh_token=$(echo "$creds_json" | jq -r '.claudeAiOauth.refreshToken // empty' 2>/dev/null || true)
      if [[ -n "$refresh_token" ]]; then
        new_tokens=$(curl -s -X POST "https://console.anthropic.com/v1/oauth/token" \
          -H "Content-Type: application/json" \
          -d "{\"grant_type\":\"refresh_token\",\"refresh_token\":\"$refresh_token\",\"client_id\":\"$CLIENT_ID\"}" \
          2>/dev/null || true)

        if [[ -n "$new_tokens" ]]; then
          new_access=$(echo "$new_tokens" | jq -r '.access_token // empty' 2>/dev/null)
          new_refresh=$(echo "$new_tokens" | jq -r '.refresh_token // empty' 2>/dev/null)

          if [[ -n "$new_access" ]] && [[ -n "$new_refresh" ]]; then
            # Update keychain with new tokens
            updated=$(echo "$creds_json" | jq \
              --arg at "$new_access" --arg rt "$new_refresh" \
              '.claudeAiOauth.accessToken = $at | .claudeAiOauth.refreshToken = $rt')
            security add-generic-password -U -s "Claude Code-credentials" -a "shuna" \
              -w "$updated" 2>/dev/null

            # Retry with new token
            resp=$(curl -s -H "Authorization: Bearer $new_access" \
              -H "anthropic-beta: oauth-2025-04-20" \
              "https://api.anthropic.com/api/oauth/usage" 2>/dev/null || true)
          fi
        fi
      fi
    fi

    # Cache successful response
    if [[ -n "$resp" ]] && echo "$resp" | jq -e '.five_hour' >/dev/null 2>&1; then
      now=$(date +%s)
      echo "$resp" | jq --argjson ts "$now" '. + {cached_at: $ts}' > "$CACHE_FILE" 2>/dev/null
    fi
  fi
fi

# ── Parse cached usage data ──────────────────────────────────────
if [[ -f "$CACHE_FILE" ]]; then
  # Utilization is 0-100 (percentage)
  five_pct=$(jq -r '.five_hour.utilization // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
  seven_pct=$(jq -r '.seven_day.utilization // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
  five_pct=$(printf "%.0f" "$five_pct" 2>/dev/null || echo "0")
  seven_pct=$(printf "%.0f" "$seven_pct" 2>/dev/null || echo "0")

  # Format reset time (macOS BSD date)
  format_reset() {
    local raw=$1 fmt=$2
    if [[ -z "$raw" ]] || [[ "$raw" = "null" ]]; then echo "?"; return; fi
    # Strip fractional seconds and timezone offset, parse as UTC
    local clean=$(echo "$raw" | sed 's/\.[0-9]*//;s/+00:00$//;s/Z$//')
    local epoch=$(TZ=UTC date -jf "%Y-%m-%dT%H:%M:%S" "$clean" "+%s" 2>/dev/null || echo "")
    if [[ -z "$epoch" ]]; then echo "?"; return; fi
    local result=$(TZ=Asia/Tokyo date -r "$epoch" "+$fmt" 2>/dev/null || echo "?")
    echo "$result" | sed 's/AM/am/g;s/PM/pm/g'
  }

  five_reset_raw=$(jq -r '.five_hour.resets_at // .five_hour.reset_at // empty' "$CACHE_FILE" 2>/dev/null || true)
  seven_reset_raw=$(jq -r '.seven_day.resets_at // .seven_day.reset_at // empty' "$CACHE_FILE" 2>/dev/null || true)

  five_reset=$(format_reset "$five_reset_raw" "%-l%p")
  seven_reset=$(format_reset "$seven_reset_raw" "%b %-d at %-l%p")
fi

# ── Output 3 lines ──────────────────────────────────────────────
ctx_c=$(color_for_pct "$ctx_pct")
five_c=$(color_for_pct "$five_pct")
seven_c=$(color_for_pct "$seven_pct")

# Line 1: model │ context │ lines │ branch
echo "${ctx_c}${model_display}${RESET} ${GRAY}│${RESET} ${ctx_c}${ctx_pct}%${RESET} ${GRAY}│${RESET} ${ctx_c}+${lines_added}/-${lines_removed}${RESET} ${GRAY}│${RESET} ${ctx_c}${ICON_BRANCH} ${branch}${RESET}"

# Line 2: 5-hour rate limit
echo "${five_c}${ICON_CLOCK} 5h  $(progress_bar "$five_pct")  ${five_pct}%${RESET}  Resets ${five_reset} (Asia/Tokyo)"

# Line 3: 7-day rate limit
echo "${seven_c}${ICON_CAL} 7d  $(progress_bar "$seven_pct")  ${seven_pct}%${RESET}  Resets ${seven_reset} (Asia/Tokyo)"
