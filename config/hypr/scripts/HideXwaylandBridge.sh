#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Park KDE's xwaylandvideobridge on a hidden special workspace at login.
#
# The static rule in configs/WindowRules.conf (Xwayland-Video-Bridge-Hide)
# handles the normal case, but can lose a session-start race: the bridge is
# XDG-autostarted and its X11 window sometimes maps before Hyprland applies
# the workspace-assignment rule, leaving a big blank window on a user-facing
# workspace. Poll briefly, sweep any stray instance onto special:xwvb, then
# exit once it is hidden. Idempotent and safe to re-run.
set -euo pipefail

command -v hyprctl >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

target="special:xwvb"

for _ in $(seq 1 40); do  # up to ~20s for slow autostart
  mapfile -t stray < <(hyprctl clients -j | jq -r --arg ws "$target" \
    '.[] | select(.class=="xwaylandvideobridge")
         | select(.workspace.name != $ws) | .address')

  for a in "${stray[@]}"; do
    hyprctl dispatch movetoworkspacesilent "$target,address:$a" >/dev/null 2>&1 || true
  done

  # Done once a bridge exists and none remain on a visible workspace.
  present=$(hyprctl clients -j | jq '[.[] | select(.class=="xwaylandvideobridge")] | length')
  if [ "$present" -gt 0 ] && [ "${#stray[@]}" -eq 0 ]; then
    exit 0
  fi

  sleep 0.5
done
