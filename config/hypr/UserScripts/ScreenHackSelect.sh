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
# floating Xwayland window. The preview is killed on the next preview or when
# the picker closes.
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

preview_pid=""
cleanup() {
  if [[ -n "$preview_pid" ]]; then
    kill "$preview_pid" 2>/dev/null
    preview_pid=""
  fi
}
trap cleanup EXIT

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

# Live preview (Option A): run the highlighted hack windowed. Under Hyprland it
# opens as a floating Xwayland window; add a windowrulev2 to size/center it once
# the X class the hacks set is confirmed (hyprctl clients).
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
      -mesg "Current: ${current:-none (default: $DEFAULT_HACK)}  |  ${PREVIEW_KEY^}: preview highlighted hack")
    rc=$?
    case "$rc" in
      0) break ;;                                        # selection accepted
      10) preview "$choice"; select_arg="$choice" ;;     # kb-custom-1: preview, re-open
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

# Check if rofi is already running
if pidof rofi >/dev/null; then
  pkill rofi
fi

main
