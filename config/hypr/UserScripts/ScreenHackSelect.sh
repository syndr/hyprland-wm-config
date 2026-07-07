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
PREVIEW_KEY="${SCREENHACK_PREVIEW_KEY:-Alt+p}"
EDIT_KEY="${SCREENHACK_EDIT_KEY:-Alt+c}"
# Per-hack flags (same file/format as the swaylock-plugin contrib scripts).
HACKS_CONF="${SWAYLOCK_SCREENSAVER_HACKS_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/swaylock-screensaver/hacks.conf}"

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

# Per-hack tuning flags from hacks.conf (same lookup as SwaylockScreensaver.sh:
# `*` line first, then the hack's own line(s); ` # comment` suffix stripped).
hack_args() {
  [[ -r "$HACKS_CONF" ]] || return 0
  awk -v h="$1" '
    /^[[:space:]]*(#|$)/ { next }
    {
      line = $0
      sub(/[[:space:]]+#.*$/, "", line)
      n = split(line, f, /[[:space:]]+/)
      name = f[1]; args = ""
      for (i = 2; i <= n; i++) args = args (args == "" ? "" : " ") f[i]
      if (args == "") next
      if (name == "*") star = star (star == "" ? "" : " ") args
      if (name == h)   own  = own  (own  == "" ? "" : " ") args
    }
    END {
      out = star (star != "" && own != "" ? " " : "") own
      if (out != "") print out
    }' "$HACKS_CONF"
}

# Open hacks.conf in $VISUAL/$EDITOR (terminal-spawned, since the picker runs
# from a keybind). Seeds a commented template on first use. Blocks until the
# editor closes, then the caller reopens the picker -- edit flags, preview,
# repeat.
edit_hacks_conf() {
  mkdir -p "$(dirname "$HACKS_CONF")"
  [[ -s "$HACKS_CONF" ]] || cat > "$HACKS_CONF" <<'EOF'
# swaylock screensaver per-hack flags: <hack> <flags...>
# A '*' line applies to every hack; a hack's own flags are appended after it.
# Flags each hack accepts: man <hack>, or /usr/share/xscreensaver/config/<hack>.xml
# Test with the picker preview (Alt+P) -- a hack that rejects its flags shows no window.
# Examples:
#   glmatrix   --mode dna --speed 0.5
#   xrayswarm  --delay 10000
#   *          --fps
EOF
  local editor="${VISUAL:-${EDITOR:-nano}}" first
  # GUI editors open their own window -- wrapping them in a terminal leaves
  # an empty terminal window behind. Run them directly.
  first="${editor%% *}"
  case "${first##*/}" in
    neovide|gvim|code|codium|subl|zed|zeditor|gedit|kate|gnome-text-editor)
      # shellcheck disable=SC2086  # $editor may carry its own flags
      $editor "$HACKS_CONF"
      return 0
      ;;
  esac
  # shellcheck disable=SC2086  # $editor may carry its own flags
  "${SCREENHACK_TERMINAL:-kitty}" -e $editor "$HACKS_CONF"
}

# Live preview (Option A): run the highlighted hack windowed with its
# hacks.conf flags (matches what the lockscreen will show). Floated, centered
# and sized by the "from the XScreenSaver" title rule in configs/WindowRules.conf
# (the X class is per-hack, e.g. XRaySwarm, so the title is the stable handle).
preview() {
  local hack="$1" args
  [[ -x "$HACK_DIR/$hack" ]] || return 0
  if [[ -z "${DISPLAY:-}" ]]; then
    notify-send -i "$iDIR/error.png" "Screensaver preview" \
      "\$DISPLAY not set -- is Xwayland enabled?"
    return 0
  fi
  cleanup
  args="$(hack_args "$hack")"
  # shellcheck disable=SC2086  # word splitting of $args is intended
  setsid "$HACK_DIR/$hack" $args >/dev/null 2>&1 &
  preview_pid=$!
}

main() {
  local choice rc select_arg
  select_arg="${current:-. random}"

  while :; do
    choice=$(menu | rofi -i -dmenu -config "$rofi_theme" \
      -select "$select_arg" \
      -kb-custom-1 "$PREVIEW_KEY" \
      -kb-custom-2 "$EDIT_KEY" \
      -mesg "Current: ${current:-none (default: $DEFAULT_HACK)}  |  ${PREVIEW_KEY^}: preview (close its window to return)  |  ${EDIT_KEY^}: edit hack flags")
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
      11)
        # kb-custom-2: edit hacks.conf, reopen when the editor closes.
        edit_hacks_conf
        select_arg="$choice"
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
