#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Generate preview screenshots for the xscreensaver hacks shown by
# ScreenHackSelect.sh. Each hack runs briefly on a headless Xvfb display and a
# frame is captured with ImageMagick's import. Local generation (rather than
# fetching jwz.org's screenshot gallery, which 403s non-browser clients) keeps
# this offline-friendly and always matches the installed hack versions.
#
# Incremental: existing shots are kept unless --force. Safe to re-run anytime;
# a second concurrent run exits early. Paths/knobs are env-overridable so the
# script stays portable outside this config.
#
# Usage: ScreenHackShots.sh [--force]

HACK_DIR="${HACK_DIR:-/usr/libexec/xscreensaver}"
SHOT_DIR="${SCREENHACK_SHOT_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/screenhack-shots}"
WARMUP="${SCREENHACK_SHOT_WARMUP:-8}"       # seconds a hack animates before capture
JOBS="${SCREENHACK_SHOT_JOBS:-4}"           # parallel Xvfb workers
GEOMETRY="${SCREENHACK_SHOT_SIZE:-640x480}"
DISPLAY_BASE="${SCREENHACK_SHOT_DISPLAY_BASE:-90}"
iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

notify() { command -v notify-send >/dev/null && notify-send "$@"; }

for tool in Xvfb import; do
  if ! command -v "$tool" >/dev/null; then
    notify -i "$iDIR/error.png" "Screensaver previews" \
      "$tool not found -- install it (Xvfb + ImageMagick) to generate hack screenshots."
    echo "ERROR: $tool not found" >&2
    exit 1
  fi
done

# Single instance: a pidfile-guarded second run exits quietly (the picker
# auto-kicks this script and must not stack generators).
PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/.screenhack_shots.pid"
if oldpid=$(cat "$PIDFILE" 2>/dev/null) && [[ "$oldpid" =~ ^[0-9]+$ ]] \
    && grep -qa 'ScreenHackShots' "/proc/$oldpid/cmdline" 2>/dev/null; then
  exit 0
fi
printf '%s\n' "$$" > "$PIDFILE"
trap '[[ "$(cat "$PIDFILE" 2>/dev/null)" == "$$" ]] && rm -f "$PIDFILE"' EXIT

mkdir -p "$SHOT_DIR"

mapfile -t HACKS < <(find "$HACK_DIR" -maxdepth 1 -type f -executable \
  -printf '%f\n' 2>/dev/null | grep -v '^xscreensaver-' | sort)
[[ "${#HACKS[@]}" -eq 0 ]] && exit 0

# Worker w handles every JOBS-th hack on its own display :(DISPLAY_BASE+w).
capture_worker() {
  local w="$1" dpy=":$((DISPLAY_BASE + $1))" i hack out xvfb_pid hack_pid
  Xvfb "$dpy" -screen 0 "${GEOMETRY}x24" -nolisten tcp >/dev/null 2>&1 &
  xvfb_pid=$!
  sleep 1
  for ((i = w; i < ${#HACKS[@]}; i += JOBS)); do
    hack="${HACKS[i]}"
    out="$SHOT_DIR/$hack.jpg"
    [[ "$FORCE" -eq 0 && -s "$out" ]] && continue
    DISPLAY="$dpy" "$HACK_DIR/$hack" -root >/dev/null 2>&1 &
    hack_pid=$!
    sleep "$WARMUP"
    import -display "$dpy" -window root jpg:"$out.tmp" 2>/dev/null &&
      mv "$out.tmp" "$out" || rm -f "$out.tmp"
    kill "$hack_pid" 2>/dev/null
    wait "$hack_pid" 2>/dev/null
  done
  kill "$xvfb_pid" 2>/dev/null
}

before=$(find "$SHOT_DIR" -name '*.jpg' | wc -l)
pids=()
for ((w = 0; w < JOBS; w++)); do
  capture_worker "$w" &
  pids+=($!)
done
wait "${pids[@]}"
after=$(find "$SHOT_DIR" -name '*.jpg' | wc -l)

notify "Screensaver previews" \
  "Generated $((after - before)) new hack screenshots ($after/${#HACKS[@]} total)."
