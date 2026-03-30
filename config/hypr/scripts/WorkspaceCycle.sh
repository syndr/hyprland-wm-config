#!/usr/bin/env bash

# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #

set -euo pipefail

direction="${1:-}"
workspaces_conf="$HOME/.config/hypr/workspaces.conf"

if [ "$direction" != "next" ] && [ "$direction" != "prev" ]; then
  echo "Usage: $0 <next|prev>" >&2
  exit 1
fi

if ! command -v hyprctl >/dev/null 2>&1; then
  echo "hyprctl is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

# Get focused monitor name and description
focused_monitor_info=$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | "\(.name)|\(.description)"')
focused_name="${focused_monitor_info%|*}"
focused_desc="${focused_monitor_info#*|}"

current_workspace="$(hyprctl activeworkspace -j | jq -r '.id')"

[ -n "$focused_name" ] || exit 0
[ -f "$workspaces_conf" ] || {
  if [ "$direction" = "next" ]; then
    hyprctl dispatch workspace e+1 >/dev/null 2>&1
  else
    hyprctl dispatch workspace e-1 >/dev/null 2>&1
  fi
  exit 0
}

mapfile -t monitor_workspaces < <(
  awk -F',' -v mon_name="$focused_name" -v mon_desc="$focused_desc" '
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
)

if [ "${#monitor_workspaces[@]}" -eq 0 ]; then
  if [ "$direction" = "next" ]; then
    hyprctl dispatch workspace e+1 >/dev/null 2>&1
  else
    hyprctl dispatch workspace e-1 >/dev/null 2>&1
  fi
  exit 0
fi

target_workspace=""
for i in "${!monitor_workspaces[@]}"; do
  if [ "${monitor_workspaces[$i]}" = "$current_workspace" ]; then
    if [ "$direction" = "next" ]; then
      target_workspace="${monitor_workspaces[$(((i + 1) % ${#monitor_workspaces[@]}))]}"
    else
      target_workspace="${monitor_workspaces[$(((i - 1 + ${#monitor_workspaces[@]}) % ${#monitor_workspaces[@]}))]}"
    fi
    break
  fi
done

if [ -z "$target_workspace" ]; then
  if [ "$direction" = "next" ]; then
    target_workspace="${monitor_workspaces[0]}"
  else
    target_workspace="${monitor_workspaces[$((${#monitor_workspaces[@]} - 1))]}"
  fi
fi

hyprctl dispatch workspace "$target_workspace" >/dev/null 2>&1
