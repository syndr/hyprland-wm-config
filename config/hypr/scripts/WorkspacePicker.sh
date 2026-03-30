#!/usr/bin/env bash

# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #

set -euo pipefail

mode="${1:-pick}"
target_monitor="${2:-}" # Can be monitor name
workspaces_conf="$HOME/.config/hypr/workspaces.conf"
rofi_config="$HOME/.config/rofi/config.rasi"
chooser_theme='window { location: northwest; anchor: northwest; x-offset: 8px; y-offset: 8px; width: 10em; } listview { lines: 4; }'

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || exit 1
}

require_cmd hyprctl
require_cmd jq

# Get focused monitor name and description
focused_monitor_info=$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | "\(.name)|\(.description)"')
focused_name="${focused_monitor_info%|*}"
focused_desc="${focused_monitor_info#*|}"

[ -n "$target_monitor" ] || target_monitor="$focused_name"

# To find workspaces, we need both name and description if we are targeting focused
if [ "$target_monitor" = "$focused_name" ]; then
    mon_name="$focused_name"
    mon_desc="$focused_desc"
else
    # If target_monitor was passed, try to find its description
    mon_name="$target_monitor"
    mon_desc=$(hyprctl -j monitors | jq -r --arg name "$mon_name" '.[] | select(.name == $name) | .description')
fi

current_workspace="$(hyprctl -j monitors | jq -r --arg mon "$mon_name" '.[] | select(.name == $mon) | .activeWorkspace.id' | head -n1)"

[ -n "$mon_name" ] || exit 1
[ -n "$current_workspace" ] || exit 1

mapfile -t monitor_workspaces < <(
  if [ -f "$workspaces_conf" ]; then
    awk -F',' -v mon_name="$mon_name" -v mon_desc="$mon_desc" '
      /^[[:space:]]*workspace[[:space:]]*=/ {
        ws = $1
        gsub(/^[[:space:]]*workspace[[:space:]]*=[[:space:]]*/, "", ws)
        for (i = 2; i <= NF; i++) {
          field = $i
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
          if (field == "monitor:" mon_name || field == "monitor:desc:" mon_desc) {
            print ws
            break
          }
        }
      }
    ' "$workspaces_conf" | sort -n
  fi
)

if [ "${#monitor_workspaces[@]}" -eq 0 ]; then
  mapfile -t monitor_workspaces < <(
    hyprctl -j workspaces | jq -r --arg mon "$mon_name" '.[] | select(.monitor == $mon) | .id' | sort -n
  )
fi

if [ "$mode" = "--current" ]; then
  printf '{"text":"%s","tooltip":"Workspace %s on %s","class":"current-workspace"}\n' \
    "$current_workspace" "$current_workspace" "$mon_name"
  exit 0
fi

require_cmd rofi

choices=()
selected_row=0
for i in "${!monitor_workspaces[@]}"; do
  ws="${monitor_workspaces[$i]}"
  if [ "$ws" = "$current_workspace" ]; then
    choices+=("● $ws")
    selected_row="$i"
  else
    choices+=("  $ws")
  fi
done

[ "${#choices[@]}" -gt 0 ] || exit 0

choice=$(
  printf '%s\n' "${choices[@]}" | rofi -dmenu -i \
    -config "$rofi_config" \
    -theme-str "$chooser_theme" \
    -p "Workspace" \
    -selected-row "$selected_row"
)

[ -n "$choice" ] || exit 0

target_workspace="$(printf '%s' "$choice" | sed 's/^[^0-9]*//')"
[ -n "$target_workspace" ] || exit 0

hyprctl dispatch workspace "$target_workspace" >/dev/null 2>&1
