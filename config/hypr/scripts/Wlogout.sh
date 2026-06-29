#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# wlogout (Power, Screen Lock, Suspend, etc)

# Set variables for parameters. First numbers corresponts to Monitor Resolution
# i.e 2160 means 2160p
A_2160=600
B_2160=600
A_1600=400
B_1600=400
A_1440=400
B_1440=400
A_1080=200
B_1080=200
A_720=15
B_720=15

# Check if wlogout is already running
if pgrep -x "wlogout" > /dev/null; then
    pkill -x "wlogout"
    exit 0
fi

# Detect monitor resolution and scaling factor
resolution=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .height / .scale' | awk -F'.' '{print $1}')
mon_width=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .width / .scale' | awk -F'.' '{print $1}')
hypr_scale=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true) | .scale')

# Portrait orientation: 2x3 grid (2 cols, 3 rows) with square cells.
# cell_w = width/2. For square cells, 3*cell_w = usable height, so margin = (height - 3*width/2)/2
if ((mon_width < resolution)); then
    T_val=$(awk "BEGIN {printf \"%.0f\", ($resolution - 3 * $mon_width / 2) / 4}")
    B_val=$T_val
    echo "Setting parameters for portrait orientation"
    wlogout --protocol layer-shell -b 2 -T $T_val -B $B_val &
# Set parameters based on screen resolution and scaling factor
elif ((resolution >= 2160)); then
    T_val=$(awk "BEGIN {printf \"%.0f\", $A_2160 * 2160 * $hypr_scale / $resolution}")
    B_val=$(awk "BEGIN {printf \"%.0f\", $B_2160 * 2160 * $hypr_scale / $resolution}")
    echo "Setting parameters for resolution >= 4k"
    wlogout --protocol layer-shell -b 6 -T $T_val -B $B_val &
elif ((resolution >= 1600 && resolution < 2160)); then
    T_val=$(awk "BEGIN {printf \"%.0f\", $A_1600 * 1600 * $hypr_scale / $resolution}")
    B_val=$(awk "BEGIN {printf \"%.0f\", $B_1600 * 1600 * $hypr_scale / $resolution}")
    echo "Setting parameters for resolution >= 2.5k and < 4k"
    wlogout --protocol layer-shell -b 6 -T $T_val -B $B_val &
elif ((resolution >= 1440 && resolution < 1600)); then
    T_val=$(awk "BEGIN {printf \"%.0f\", $A_1440 * 1440 * $hypr_scale / $resolution}")
    B_val=$(awk "BEGIN {printf \"%.0f\", $B_1440 * 1440 * $hypr_scale / $resolution}")
    echo "Setting parameters for resolution >= 2k and < 2.5k"
    wlogout --protocol layer-shell -b 6 -T $T_val -B $B_val &
elif ((resolution >= 1080 && resolution < 1440)); then
    T_val=$(awk "BEGIN {printf \"%.0f\", $A_1080 * 1080 * $hypr_scale / $resolution}")
    B_val=$(awk "BEGIN {printf \"%.0f\", $B_1080 * 1080 * $hypr_scale / $resolution}")
    echo "Setting parameters for resolution >= 1080p and < 2k"
    wlogout --protocol layer-shell -b 6 -T $T_val -B $B_val &
elif ((resolution >= 720 && resolution < 1080)); then
    T_val=$(awk "BEGIN {printf \"%.0f\", $A_720 * 720 * $hypr_scale / $resolution}")
    B_val=$(awk "BEGIN {printf \"%.0f\", $B_720 * 720 * $hypr_scale / $resolution}")
    echo "Setting parameters for resolution >= 720p and < 1080p"
    wlogout --protocol layer-shell -b 3 -T $T_val -B $B_val &
else
    echo "Setting default parameters"
    wlogout &
fi
