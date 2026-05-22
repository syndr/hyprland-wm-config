#!/usr/bin/env bash
# AddWorkspace.sh MONITOR
# Create a new workspace pinned to MONITOR and switch to it. The new
# workspace's ID is one past the highest ID currently on MONITOR.
# Pinning is transient — it lasts until the next Hyprland reload. To make
# a workspace permanent, add a corresponding `workspace =` line to
# ~/.config/hypr/workspaces.conf.

set -u

monitor="${1:-}"
if [ -z "$monitor" ]; then
    echo "usage: $0 MONITOR" >&2
    exit 1
fi

max_id=$(hyprctl -j workspaces 2>/dev/null \
  | jq --arg m "$monitor" '[.[] | select(.monitor == $m) | .id] | max // 0')

if ! [[ "$max_id" =~ ^[0-9]+$ ]]; then
    echo "could not determine max workspace id for $monitor (got: $max_id)" >&2
    exit 1
fi

next_id=$((max_id + 1))

hyprctl keyword workspace "${next_id},monitor:${monitor}" >/dev/null
hyprctl dispatch workspace "$next_id" >/dev/null
