#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# swaylock-plugin lock screen with an xscreensaver "hack" background.
#
# Invoked by hypridle's lock_cmd (fires for CTRL+ALT+L, SUPER+grave, idle
# timeout, and before sleep -- all via loginctl lock-session). Hosts without
# swaylock-plugin fall through to hyprlock, silently.
#
# The hack is chosen with the rofi picker (ScreenHackSelect.sh, SUPER SHIFT L)
# which writes the name to $HACK_STATE. Available hacks: $HACK_DIR.
#
# All paths are env-overridable so the script stays portable outside this
# config (see docs/swaylock-screensaver-lockscreen-plan.md).
HACK_STATE="${HACK_STATE:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/.swaylock_hack}"
HACK_DIR="${HACK_DIR:-/usr/libexec/xscreensaver}"
# Shipped by the swaylock-plugin RPM (runs Xwayland rooted, execs the hack inside).
WRAPPER="${WRAPPER:-/usr/libexec/swaylock-plugin/example_xwayland_wrapper.py}"
DEFAULT_HACK="${DEFAULT_HACK:-xrayswarm}"
# Background if the hack dies or never starts (otherwise a blank light-gray
# screen, or whatever ~/.config/swaylock/config themes it to). "auto" uses the
# chosen hack's ScreenHackShots.sh screenshot when one exists; "none"
# disables; any other value is an image path.
FALLBACK_BG="${SWAYLOCK_SCREENSAVER_FALLBACK_BG:-auto}"
SHOT_DIR="${SCREENHACK_SHOT_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/screenhack-shots}"
# Per-hack flags (same file/format as the swaylock-plugin contrib scripts, so
# switching to the packaged tools later keeps user config intact).
HACKS_CONF="${SWAYLOCK_SCREENSAVER_HACKS_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/swaylock-screensaver/hacks.conf}"

# Hosts without the RPM (non-phalanx installs) keep hyprlock, quietly.
command -v swaylock-plugin >/dev/null || exec hyprlock

# Runs for every lock trigger; never start a second instance.
pidof -q swaylock-plugin && exit 0

HACK="$([ -r "$HACK_STATE" ] && head -n1 "$HACK_STATE")"
HACK="${HACK:-$DEFAULT_HACK}"

# Stale state file (hack renamed/removed): fall back to the default hack first.
if [ ! -x "$HACK_DIR/$HACK" ] && [ -x "$HACK_DIR/$DEFAULT_HACK" ]; then
    notify-send -u low "swaylock-plugin" \
        "hack '$HACK' not found -- using $DEFAULT_HACK" 2>/dev/null || true
    HACK="$DEFAULT_HACK"
fi

# Per-hack tuning flags from hacks.conf: a `*` line applies to every hack,
# then the hack's own line(s) -- later flags win in the hacks' arg parsers.
# Trailing ` # comment` is stripped.
hack_args() {
    [ -r "$HACKS_CONF" ] || return 0
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

# The plugin surface covers the swaylock background while the hack runs;
# --image only becomes visible if the hack dies or never starts.
bg_args=()
case "$FALLBACK_BG" in
    none) ;;
    auto) [ -s "$SHOT_DIR/$HACK.jpg" ] && bg_args=(--image "$SHOT_DIR/$HACK.jpg" --scaling fill) ;;
    *)    [ -s "$FALLBACK_BG" ] && bg_args=(--image "$FALLBACK_BG" --scaling fill) ;;
esac

if [ -x "$HACK_DIR/$HACK" ] && [ -x "$WRAPPER" ]; then
    ARGS="$(hack_args "$HACK")"
    # --command-each runs one wallpaper instance per output. windowtolayer
    # adapts the Xwayland-hosted hack (via the wrapper) into a layer-shell
    # surface that swaylock-plugin composites as the lock background.
    exec swaylock-plugin "${bg_args[@]}" --command-each \
        "windowtolayer '$WRAPPER' '$HACK_DIR/$HACK' -root${ARGS:+ $ARGS}"
fi

# No usable hack/wrapper: still lock (fail safe -- a lock trigger must never
# leave the session unlocked), just without the animation.
notify-send -u critical "swaylock-plugin" \
    "no usable xscreensaver hack in $HACK_DIR -- locking without animation" 2>/dev/null || true
exec swaylock-plugin "${bg_args[@]}"
