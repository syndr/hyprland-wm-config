#!/usr/bin/env bash
# ==================================================
#  hyprland-wm-config (fork of LinuxBeginnings/Hyprland-Dots)
#  Project URL: https://github.com/syndr/hyprland-wm-config
#  Upstream:    https://github.com/LinuxBeginnings/Hyprland-Dots
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Script for waybar layout or configs

IFS=$'\n\t'

# Define directories
waybar_layouts="$HOME/.config/waybar/configs"
waybar_config="$HOME/.config/waybar/config"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
greenscreen_auto="[TOP] Greenscreen Auto"
rofi_config="$HOME/.config/rofi/config-waybar-layout.rasi"
msg=' 🎌 NOTE: Some waybar LAYOUT NOT fully compatible with some STYLES'

# Apply selected configuration
apply_config() {
    if [[ "$1" == "[TOP] Greenscreen" && -x "${SCRIPTSDIR}/GenerateWaybarGreenscreen.sh" ]]; then
        "${SCRIPTSDIR}/GenerateWaybarGreenscreen.sh" >/dev/null 2>&1 || true
        if [[ -f "${waybar_layouts}/${greenscreen_auto}" ]]; then
            ln -sf "${waybar_layouts}/${greenscreen_auto}" "$waybar_config"
        else
            ln -sf "$waybar_layouts/$1" "$waybar_config"
        fi
    else
        ln -sf "$waybar_layouts/$1" "$waybar_config"
    fi
    "${SCRIPTSDIR}/Refresh.sh" &
}

main() {
    # Resolve current symlink target and basename
    current_target=$(readlink -f "$waybar_config")
    current_name=$(basename "$current_target")
    if [[ "$current_name" == "$greenscreen_auto" ]]; then
        current_name="[TOP] Greenscreen"
    fi

    # Build sorted list of available layouts
    mapfile -t options < <(
        find -L "$waybar_layouts" -maxdepth 1 -type f ! -name "$greenscreen_auto" -printf '%f\n' | sort
    )

    # Mark and locate the active layout
    default_row=0
    MARKER="👉"
    for i in "${!options[@]}"; do
        if [[ "${options[i]}" == "$current_name" ]]; then
            options[i]="$MARKER ${options[i]}"
            default_row=$i
            break
        fi
    done

    # Launch rofi with the annotated list, pre‑selecting the active row
    choice=$(printf '%s\n' "${options[@]}" \
        | rofi -i -dmenu \
               -config "$rofi_config" \
               -mesg "$msg" \
               -selected-row "$default_row"
    )

    # Exit if nothing chosen
    [[ -z "$choice" ]] && { echo "No option selected. Exiting."; exit 0; }

    # Strip marker before applying
    choice=${choice#"$MARKER "}

    case "$choice" in
        "no panel")
            pgrep -x "waybar" && pkill waybar || true
            ;;
        *)
            apply_config "$choice"
            ;;
    esac
}

# Kill Rofi if already running before execution
if pgrep -x "rofi" >/dev/null; then
    pkill rofi
    #exit 0
fi

main
