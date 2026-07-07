#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Rofi picker for the xscreensaver "hack" used as the swaylock-plugin lock
# background (SUPER SHIFT L). Mirrors WallpaperSelect.sh: menu() | rofi -dmenu,
# persists the selection to a state file consumed by SwaylockScreensaver.sh.
#
# Alt+P previews the highlighted hack live: hacks run windowed (no -root) as a
# floating Xwayland window. The picker stays closed while the preview runs (its
# centered rofi layer would mask the preview) and reopens with the highlight
# restored once the preview window is closed (SUPER Q).
#
# Paths are env-overridable so the script stays portable outside this config
# (see docs/swaylock-screensaver-lockscreen-plan.md).

HACK_DIR="${HACK_DIR:-/usr/libexec/xscreensaver}"
HACK_STATE="${HACK_STATE:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/.swaylock_hack}"
DEFAULT_HACK="${DEFAULT_HACK:-xrayswarm}"
rofi_theme="${SCREENHACK_ROFI_THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config-screenhack.rasi}"
PREVIEW_KEY="Alt+p"

# Directory for swaync icons (error notifications)
iDIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images"

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/.screenhack_picker.pid"

preview_pid=""
# Kills the running preview only — also called between previews, so the
# pidfile must NOT be removed here, or the instance guard goes blind after
# the first preview.
cleanup() {
  if [[ -n "$preview_pid" ]]; then
    kill "$preview_pid" 2>/dev/null
    preview_pid=""
  fi
}
on_exit() {
  cleanup
  [[ "$(cat "$PIDFILE" 2>/dev/null)" == "$$" ]] && rm -f "$PIDFILE"
}
trap on_exit EXIT
trap 'exit 0' TERM INT

# Hacks: executables in HACK_DIR, minus the xscreensaver-* helper binaries
# (xscreensaver-auth, xscreensaver-getimage*, xscreensaver-text, ...).
mapfile -t HACKS < <(find "$HACK_DIR" -maxdepth 1 -type f -executable \
  -printf '%f\n' 2>/dev/null | grep -v '^xscreensaver-' | sort)

if [[ "${#HACKS[@]}" -eq 0 ]]; then
  notify-send -i "$iDIR/error.png" "Screensaver hacks" \
    "No hacks found in $HACK_DIR -- is the xscreensaver package layered?"
  exit 1
fi

current="$([[ -r "$HACK_STATE" ]] && head -n1 "$HACK_STATE")"

menu() {
  printf "%s\n" ". random"
  printf "%s\n" "${HACKS[@]}"
}

# Live preview (Option A): run the highlighted hack windowed. Floated, centered
# and sized by the "from the XScreenSaver" title rule in configs/WindowRules.conf
# (the X class is per-hack, e.g. XRaySwarm, so the title is the stable handle).
preview() {
  local hack="$1"
  [[ -x "$HACK_DIR/$hack" ]] || return 0
  if [[ -z "${DISPLAY:-}" ]]; then
    notify-send -i "$iDIR/error.png" "Screensaver preview" \
      "\$DISPLAY not set -- is Xwayland enabled?"
    return 0
  fi
  cleanup
  setsid "$HACK_DIR/$hack" >/dev/null 2>&1 &
  preview_pid=$!
}

main() {
  local choice rc select_arg
  select_arg="${current:-. random}"

  while :; do
    choice=$(menu | rofi -i -dmenu -config "$rofi_theme" \
      -select "$select_arg" \
      -kb-custom-1 "$PREVIEW_KEY" \
      -mesg "Current: ${current:-none (default: $DEFAULT_HACK)}  |  ${PREVIEW_KEY^}: preview (close preview window to return)")
    rc=$?
    case "$rc" in
      0) break ;;                                        # selection accepted
      10)
        # kb-custom-1: preview windowed. Stay closed while it runs (rofi
        # would mask it), reopen with the highlight restored once the
        # preview window is closed.
        preview "$choice"
        select_arg="$choice"
        if [[ -n "$preview_pid" ]]; then
          wait "$preview_pid" 2>/dev/null
          preview_pid=""
        fi
        ;;
      *) exit 0 ;;                                       # Escape / abort
    esac
  done

  choice=$(echo "$choice" | xargs)
  [[ -z "$choice" ]] && exit 0

  if [[ "$choice" == ". random" ]]; then
    choice="${HACKS[RANDOM % ${#HACKS[@]}]}"
  fi

  mkdir -p "$(dirname "$HACK_STATE")"
  printf "%s\n" "$choice" > "$HACK_STATE"
  notify-send "Screensaver lock" "Hack set to: $choice"
}

# Single instance: re-invoking the keybind while a preview is open replaces
# the running picker; TERM fires its cleanup trap so its preview dies too.
# Pidfile rather than pgrep -f: a cmdline sweep also matches whatever shell
# invoked us. The /proc cmdline check guards against a stale/recycled pid.
if oldpid=$(cat "$PIDFILE" 2>/dev/null) && [[ "$oldpid" =~ ^[0-9]+$ ]] \
    && [[ "$oldpid" != "$$" ]] \
    && grep -qa 'ScreenHackSelect' "/proc/$oldpid/cmdline" 2>/dev/null; then
  kill "$oldpid" 2>/dev/null
fi
printf '%s\n' "$$" > "$PIDFILE"

# Check if rofi is already running
if pidof rofi >/dev/null; then
  pkill rofi
fi

main
