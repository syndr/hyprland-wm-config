#!/usr/bin/env bash

# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #

# Script to switch to the Nth workspace of the currently focused monitor
# Usage: ./WorkspaceSwitch.sh <1-10> [move|silent]

set -euo pipefail

workspace_index="${1:-}"
action="${2:-switch}" # switch, move, silent

if [[ ! "$workspace_index" =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 <1-10> [move|silent]"
    exit 1
fi

# Map 0 to 10 if needed (for the '0' key)
if [ "$workspace_index" -eq 0 ]; then
    workspace_index=10
fi

# Get focused monitor name and description
focused_monitor_info=$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | "\(.name)|\(.description)"')
focused_name="${focused_monitor_info%|*}"
focused_desc="${focused_monitor_info#*|}"

workspaces_conf="$HOME/.config/hypr/workspaces.conf"

# Find all workspaces assigned to this monitor (matching name or description)
# We handle both monitor:NAME and monitor:desc:DESCRIPTION
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
    # Fallback to absolute workspace if no rules found for this monitor
    # In a multi-monitor setup without rules, we might want a different default,
    # but for now we follow the requested 1-10, 11-20 etc. pattern.
    target_workspace="$workspace_index"
else
    # Get the Nth workspace for this monitor
    idx=$((workspace_index - 1))
    if [ $idx -lt "${#monitor_workspaces[@]}" ]; then
        target_workspace="${monitor_workspaces[$idx]}"
    else
        # If user asks for workspace 5 but only 3 are defined, maybe just do nothing or go to last?
        # Let's just go to the Nth absolute if it's out of bounds of defined ones.
        target_workspace="$workspace_index"
    fi
fi

case "$action" in
    move)
        hyprctl dispatch movetoworkspace "$target_workspace"
        ;;
    silent)
        hyprctl dispatch movetoworkspacesilent "$target_workspace"
        ;;
    *)
        hyprctl dispatch workspace "$target_workspace"
        ;;
esac
