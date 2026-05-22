#!/usr/bin/env bash
# Launcher chooser for the Waybar phalanx button.
#
# Toggle behavior: a second click while rofi is open dismisses it without
# opening a new one. The challenge is that rofi auto-closes on click-outside
# (default click-to-exit: true), so by the time waybar fires this script
# again, rofi has often already gone. We use a marker file with a short
# deferred removal so the re-click can still detect "rofi was just here."

IFS=$'\n\t'

rofi_config="$HOME/.config/rofi/config.rasi"
chooser_theme='window { location: northwest; anchor: northwest; x-offset: 8px; y-offset: 8px; width: 16em; } listview { lines: 18; }'

marker="/tmp/RofiLauncher.open.$(id -u)"

if [ -e "$marker" ]; then
    # Either rofi is still up, or it just closed within the debounce window.
    # Either way, kill any straggler and suppress this invocation.
    pkill -x rofi 2>/dev/null
    rm -f "$marker"
    exit 0
fi

touch "$marker"
# Defer marker removal ~150ms past our own exit so the close-click can still
# see it. Backgrounded so the script itself doesn't block on the sleep.
trap '(sleep 0.15 && rm -f "$marker" 2>/dev/null) & disown' EXIT INT TERM

chooser_input() {
    printf '%s\n' \
        " Applications" \
        "󰜎 Run Command" \
        "󰉋 Files" \
        "󰖯 Windows"
    printf '%s\000nonselectable\037true\n' "── Apps & Tools ──"
    printf '%s\n' \
        "󰒓 Settings" \
        "󰆍 Terminal" \
        "󰉓 File Manager" \
        "󰖟 Browser"
    printf '%s\000nonselectable\037true\n' "── Wallpaper / Theme ──"
    printf '%s\n' \
        "󰋩 Wallpaper" \
        "󰑐 Wallpaper: Random" \
        "󰏘 Waybar Styles"
    printf '%s\000nonselectable\037true\n' "── Session ──"
    printf '%s\n' \
        "󰤄 Toggle Idle" \
        "󱅄 Toggle Blur" \
        "󰌾 Lock" \
        "󰐥 Power"
}

choice=$(
    chooser_input \
    | rofi -i -dmenu \
        -config "$rofi_config" \
        -theme-str "$chooser_theme" \
        -p "Launcher"
)

# Strip leading Nerd Font glyph + space from the returned label.
case "${choice#* }" in
    "Applications")       rofi -show drun        -config "$rofi_config" ;;
    "Run Command")        rofi -show run         -config "$rofi_config" ;;
    "Files")              rofi -show filebrowser -config "$rofi_config" ;;
    "Windows")            rofi -show window      -config "$rofi_config" ;;
    "Settings")           "$HOME/.config/hypr/scripts/Kool_Quick_Settings.sh" ;;
    "Terminal")           "$HOME/.config/hypr/scripts/WaybarScripts.sh" --term ;;
    "File Manager")       "$HOME/.config/hypr/scripts/WaybarScripts.sh" --files ;;
    "Browser")            xdg-open "https://" ;;
    "Wallpaper")          "$HOME/.config/hypr/UserScripts/WallpaperSelect.sh" ;;
    "Wallpaper: Random")  "$HOME/.config/hypr/UserScripts/WallpaperRandom.sh" ;;
    "Waybar Styles")      "$HOME/.config/hypr/scripts/WaybarStyles.sh" ;;
    "Toggle Idle")        "$HOME/.config/hypr/scripts/Hypridle.sh" toggle ;;
    "Toggle Blur")        "$HOME/.config/hypr/scripts/ChangeBlur.sh" ;;
    "Lock")               "$HOME/.config/hypr/scripts/LockScreen.sh" ;;
    "Power")              "$HOME/.config/hypr/scripts/Wlogout.sh" ;;
esac
