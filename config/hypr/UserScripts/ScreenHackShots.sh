#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Thin wrapper: the hack thumbnail generator (headless Xvfb + ImageMagick)
# lives in the packaged swaylock-screensaver-shots
# (swaylock-plugin-screensaver RPM/deb; canonical source is swaylock-plugin's
# contrib/screensaver). This wrapper pins this config's cache location.
#
# Usage: ScreenHackShots.sh [--force]

if ! command -v swaylock-screensaver-shots >/dev/null; then
  echo "ERROR: swaylock-plugin-screensaver is not installed" >&2
  exit 1
fi

export SCREENHACK_SHOT_DIR="${SCREENHACK_SHOT_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/screenhack-shots}"

exec swaylock-screensaver-shots "$@"
