#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Thin wrapper: the rofi hack picker (thumbnails, descriptions, Alt+P live
# preview, Alt+C hacks.conf editing) lives in the packaged
# swaylock-screensaver-select (swaylock-plugin-screensaver RPM/deb; canonical
# source is swaylock-plugin's contrib/screensaver). This wrapper pins this
# config's rofi theme, state file, thumbnail cache, and terminal.
#
# Bound to SUPER SHIFT L. Preview windows float via the "from the XScreenSaver"
# title rule in configs/WindowRules.conf.

if ! command -v swaylock-screensaver-select >/dev/null; then
  notify-send -i "${XDG_CONFIG_HOME:-$HOME/.config}/swaync/images/error.png" \
    "Screensaver picker" \
    "swaylock-plugin-screensaver is not installed -- no hack picker on this host."
  exit 1
fi

export HACK_STATE="${HACK_STATE:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/.swaylock_hack}"
export SCREENHACK_SHOT_DIR="${SCREENHACK_SHOT_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/screenhack-shots}"
export SCREENHACK_ROFI_THEME="${SCREENHACK_ROFI_THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/rofi/config-screenhack.rasi}"
export SCREENHACK_TERMINAL="${SCREENHACK_TERMINAL:-kitty}"

exec swaylock-screensaver-select "$@"
