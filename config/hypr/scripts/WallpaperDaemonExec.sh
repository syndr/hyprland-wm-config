#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# ExecStart for swww-daemon.service: run the wallpaper daemon WallpaperCmd.sh
# picks (awww preferred, swww fallback) in the foreground so systemd owns it.
#
# A script rather than `bash -c` in the unit on purpose: systemd substitutes
# ${VAR} inside ExecStart= before the shell sees it, which turned
# "${WWW_DAEMON_ARGS[@]}" into an empty argument and made swww-daemon exit 255.
# WallpaperDaemon.sh (ExecStartPost) then re-applies the cached wallpaper.

SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"

if ! command -v "$WWW_DAEMON" >/dev/null 2>&1; then
  echo "WallpaperDaemonExec: $WWW_DAEMON not installed" >&2
  exit 1
fi
exec "$WWW_DAEMON" "${WWW_DAEMON_ARGS[@]}"
