#!/bin/bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
effort=$(echo "$input" | jq -r '.effort.level // "unknown"')
ctx_pct=$(echo "$input" | jq -r 'if .context_window.used_percentage != null then .context_window.used_percentage else "" end')
five_h_pct=$(echo "$input" | jq -r 'if .rate_limits.five_hour.used_percentage != null then .rate_limits.five_hour.used_percentage else "" end')
seven_d_pct=$(echo "$input" | jq -r 'if .rate_limits.seven_day.used_percentage != null then .rate_limits.seven_day.used_percentage else "" end')
five_h_reset=$(echo "$input" | jq -r 'if .rate_limits.five_hour.resets_at != null then .rate_limits.five_hour.resets_at else "" end')
seven_d_reset=$(echo "$input" | jq -r 'if .rate_limits.seven_day.resets_at != null then .rate_limits.seven_day.resets_at else "" end')

out="$model | $effort"

[ -n "$ctx_pct" ] && out="$out | context:$(printf '%.0f' "$ctx_pct")% used"
[ -n "$five_h_pct" ] && out="$out | 5h:$(printf '%.0f' "$five_h_pct")% used"
[ -n "$seven_d_pct" ] && out="$out | 7d:$(printf '%.0f' "$seven_d_pct")% used"
[ -n "$five_h_reset" ] && out="$out | 5h reset:$(date -d @"$five_h_reset" +%H:%M 2>/dev/null)"
[ -n "$seven_d_reset" ] && out="$out | 7d reset:$(date -d @"$seven_d_reset" +"%a %H:%M" 2>/dev/null)"

echo "$out"
