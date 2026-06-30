#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Park KDE's xwaylandvideobridge on a hidden special workspace, robustly.
#
# Two best-effort mechanisms exist and BOTH can miss at login:
#   - the static rule in configs/WindowRules.conf (Xwayland-Video-Bridge-Hide)
#     loses the Xwayland WM_CLASS-set-after-map race, so it does not match at
#     map time and the bridge lands on a visible workspace;
#   - a one-shot poll times out if the bridge XDG-autostarts late under uwsm.
#
# This script does an initial bounded sweep (already-/quickly-mapped case) AND
# then subscribes to Hyprland's IPC, re-parking the bridge whenever a window
# opens -- with short delayed re-sweeps so a class that settles just after map
# is still caught, and any future re-map is handled too. Idempotent and
# single-instance.
set -u

command -v hyprctl >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

target="special:xwvb"

# Single-instance guard: bail if another listener is already running.
self_pid=$$
if pgrep -f "[H]ideXwaylandBridge\\.sh" | grep -vx "$self_pid" >/dev/null; then
  exit 0
fi

# Move any xwaylandvideobridge window that is not already on the hidden ws.
sweep() {
  hyprctl clients -j 2>/dev/null \
    | jq -r --arg ws "$target" \
        '.[] | select(.class=="xwaylandvideobridge") | select(.workspace.name != $ws) | .address' 2>/dev/null \
    | while read -r a; do
        [ -n "$a" ] && hyprctl dispatch movetoworkspacesilent "$target,address:$a" >/dev/null 2>&1 || true
      done
}

# Initial bounded sweep: catch a bridge that is already (or quickly) mapped,
# so it is hidden ASAP without waiting on the first IPC event.
( for _ in $(seq 1 20); do sweep; sleep 0.5; done ) &

# Resolve socket2 (HYPRLAND_INSTANCE_SIGNATURE may be unset in this subshell).
SOCKET2="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
if [ ! -S "$SOCKET2" ]; then
  sig=$(hyprctl instances -j 2>/dev/null | jq -r '.[0].instance' 2>/dev/null)
  SOCKET2="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$sig/.socket2.sock"
fi

# Event-driven: on every window open, sweep immediately and again after short
# delays (the bridge's WM_CLASS often settles a beat after the openwindow
# event). React only to opens to stay cheap. If socat or the socket is
# unavailable, fall back to a slow poll so the bridge is still eventually hid.
if command -v socat >/dev/null 2>&1 && [ -S "$SOCKET2" ]; then
  socat -u UNIX-CONNECT:"$SOCKET2" - 2>/dev/null | while read -r line; do
    case "$line" in
      openwindow*)
        sweep
        ( sleep 0.4; sweep; sleep 1.0; sweep ) &
        ;;
    esac
  done
else
  while :; do sweep; sleep 2; done
fi
