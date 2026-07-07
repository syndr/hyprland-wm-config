#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Thin wrapper: the screensaver lockscreen logic lives in the packaged
# swaylock-screensaver (swaylock-plugin-screensaver RPM/deb; canonical source
# is swaylock-plugin's contrib/screensaver). This wrapper pins this config's
# paths and keeps hyprlock as the fallback locker, so hypridle's lock_cmd and
# the keybinds keep calling the same script they always did.
#
# Invoked by hypridle's lock_cmd (fires for CTRL+ALT+L, SUPER+grave, idle
# timeout, and before sleep -- all via loginctl lock-session). Hosts without
# the package fall through to hyprlock, silently.

command -v swaylock-screensaver >/dev/null || exec hyprlock

# Same state file the picker has always written; thumbnails from the
# pre-package cache location; recovery lands in hyprlock (fail-secure).
export HACK_STATE="${HACK_STATE:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/.swaylock_hack}"
export SCREENHACK_SHOT_DIR="${SCREENHACK_SHOT_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/screenhack-shots}"
export SWAYLOCK_SCREENSAVER_FALLBACK="${SWAYLOCK_SCREENSAVER_FALLBACK:-hyprlock}"

exec swaylock-screensaver "$@"
