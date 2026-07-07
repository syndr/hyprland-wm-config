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
# Rows show a screenshot thumbnail (generated locally by ScreenHackShots.sh,
# auto-kicked on first use) and the hack's one-line description from the
# xscreensaver config XMLs; both are searchable text.
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

# Rows show a screenshot thumbnail + one-line description when available.
# Shots come from ScreenHackShots.sh (auto-kicked below on first use);
# descriptions from the hack config XMLs xscreensaver installs.
SHOT_DIR="${SCREENHACK_SHOT_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/screenhack-shots}"
XML_DIR="${SCREENHACK_XML_DIR:-/usr/share/xscreensaver/config}"
DESC_IDX="${XDG_CACHE_HOME:-$HOME/.cache}/screenhack-desc.tsv"

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

# name<TAB>first-description-line index from the xscreensaver config XMLs
# (ISO-8859-1 upstream, hence iconv). Rebuilt when the XML dir changes.
declare -A DESC
if [[ -d "$XML_DIR" ]]; then
  if [[ ! -s "$DESC_IDX" || "$XML_DIR" -nt "$DESC_IDX" ]]; then
    mkdir -p "$(dirname "$DESC_IDX")"
    awk '
      FNR == 1 { name = FILENAME; sub(/.*\//, "", name); sub(/\.xml$/, "", name)
                 indesc = 0; printed = 0 }
      /<_description>/  { indesc = 1; next }
      /<\/_description>/ { indesc = 0 }
      indesc && !printed {
        line = $0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        if (line != "") { printf "%s\t%s\n", name, line; printed = 1 }
      }' "$XML_DIR"/*.xml 2>/dev/null | iconv -f ISO-8859-1 -t UTF-8 > "$DESC_IDX"
  fi
  while IFS=$'\t' read -r n d; do DESC[$n]=$d; done < "$DESC_IDX"
fi

# Rows: padded name + truncated description (searchable), thumbnail as the row
# icon when a shot exists. The name is recovered after selection by cutting at
# the first double space, so it must never contain one (". random" has a
# single space and is safe).
menu() {
  local hack d row shot
  printf "%s\n" ". random  (a different hack every lock)"
  for hack in "${HACKS[@]}"; do
    d="${DESC[$hack]:-}"
    printf -v row '%-22s  %s' "$hack" "${d:0:80}"
    shot="$SHOT_DIR/$hack.jpg"
    if [[ -s "$shot" ]]; then
      printf '%s\0icon\x1f%s\n' "$row" "$shot"
    else
      printf '%s\n' "$row"
    fi
  done
}

# Strip a menu row back to the bare hack name (cut at the double-space
# delimiter, then trim padding).
row_to_hack() {
  local row="${1%%  *}"
  printf '%s' "${row%"${row##*[![:space:]]}"}"
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
        preview "$(row_to_hack "$choice")"
        select_arg="$choice"
        if [[ -n "$preview_pid" ]]; then
          wait "$preview_pid" 2>/dev/null
          preview_pid=""
        fi
        ;;
      *) exit 0 ;;                                       # Escape / abort
    esac
  done

  choice="$(row_to_hack "$choice")"
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

# First use: generate the row thumbnails in the background (its own pidfile
# prevents stacking). They appear the next time the picker opens.
if [[ -z "$(ls -A "$SHOT_DIR" 2>/dev/null)" ]] \
    && command -v Xvfb >/dev/null && command -v import >/dev/null; then
  notify-send "Screensaver previews" \
    "Generating hack screenshots in the background -- thumbnails appear on the next picker open."
  setsid "$(dirname "$(readlink -f "$0")")/ScreenHackShots.sh" >/dev/null 2>&1 &
fi

main
