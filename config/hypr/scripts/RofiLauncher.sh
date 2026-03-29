#!/usr/bin/env bash
# Simple first-step launcher chooser for the Waybar launcher button.

IFS=$'\n\t'

rofi_config="$HOME/.config/rofi/config.rasi"
chooser_theme='window { location: northwest; anchor: northwest; x-offset: 8px; y-offset: 8px; width: 14em; } listview { lines: 4; }'

if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

choice=$(
    printf '%s\n' \
        "Applications" \
        "Run Command" \
        "Files" \
        "Windows" \
    | rofi -i -dmenu \
        -config "$rofi_config" \
        -theme-str "$chooser_theme" \
        -p "Launcher"
)

case "$choice" in
    "Applications")
        rofi -show drun -config "$rofi_config"
        ;;
    "Run Command")
        rofi -show run -config "$rofi_config"
        ;;
    "Files")
        rofi -show filebrowser -config "$rofi_config"
        ;;
    "Windows")
        rofi -show window -config "$rofi_config"
        ;;
esac
