#!/usr/bin/env bash
# ==================================================
#  hyprland-wm-config (fork of LinuxBeginnings/Hyprland-Dots)
#  Project URL: https://github.com/syndr/hyprland-wm-config
#  Upstream:    https://github.com/LinuxBeginnings/Hyprland-Dots
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================

# Modified version of Refresh.sh but waybar wont refresh
# Used by automatic wallpaper change
# Modified inorder to refresh rofi background, Wallust, SwayNC only

SCRIPTSDIR=$HOME/.config/hypr/scripts
UserScripts=$HOME/.config/hypr/UserScripts

# Define file_exists function
file_exists() {
    if [ -e "$1" ]; then
        return 0  # File exists
    else
        return 1  # File does not exist
    fi
}

# Kill already running processes
_ps=(rofi)
for _prs in "${_ps[@]}"; do
    if pidof "${_prs}" >/dev/null; then
        pkill "${_prs}"
    fi
done

# quit ags & relaunch ags
ags -q && ags &

# quit quickshell & relaunch quickshell
#pkill qs && qs &


# reload swaync
swaync-client --reload-config

# Relaunching rainbow borders if the script exists (disabled - high GPU usage)
#sleep 1
#if file_exists "${UserScripts}/RainbowBorders.sh"; then
#    ${UserScripts}/RainbowBorders.sh &
#fi


exit 0