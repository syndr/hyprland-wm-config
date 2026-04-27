#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# For Dark and Light switching.
# Theme family overrides are optional; if none are configured, legacy behavior remains.
# Note: Scripts are looking for keywords Light or Dark except for wallpapers as the are in a separate directories

# Paths
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
wallpaper_base_path="$PICTURES_DIR/wallpapers/Dynamic-Wallpapers"
dark_wallpapers="$wallpaper_base_path/Dark"
light_wallpapers="$wallpaper_base_path/Light"
hypr_config_path="$HOME/.config/hypr"
swaync_style="$HOME/.config/swaync/style.css"
ags_style="$HOME/.config/ags/user/style.css"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"
notif="$HOME/.config/swaync/images/bell.png"
wallust_rofi="$HOME/.config/wallust/templates/colors-rofi.rasi"
kitty_conf="$HOME/.config/kitty/kitty.conf"
wallust_config="$HOME/.config/wallust/wallust.toml"
theme_config="$HOME/.config/hypr/UserConfigs/ThemeConfig.conf"
theme_dir="$HOME/.config/hypr/themes"

pallete_dark="dark16"
pallete_light="light16"
qt5ct_dark="$HOME/.config/qt5ct/colors/Catppuccin-Mocha.conf"
qt5ct_light="$HOME/.config/qt5ct/colors/Catppuccin-Latte.conf"
qt6ct_dark="$HOME/.config/qt6ct/colors/Catppuccin-Mocha.conf"
qt6ct_light="$HOME/.config/qt6ct/colors/Catppuccin-Latte.conf"
kvantum_dark="catppuccin-mocha-blue"
kvantum_light="catppuccin-latte-blue"
active_theme_family="Hackerer"

load_theme_family() {
    [ -f "$theme_config" ] && source "$theme_config"
    active_theme_family="${ACTIVE_THEME_FAMILY:-Hackerer}"

    local profile="$theme_dir/${active_theme_family}.conf"
    if [ -f "$profile" ]; then
        source "$profile"
    fi

    MANAGE_GTK_THEME="${MANAGE_GTK_THEME:-0}"
    MANAGE_ICON_THEME="${MANAGE_ICON_THEME:-0}"
    MANAGE_QT_THEME="${MANAGE_QT_THEME:-0}"
    MANAGE_WALLUST_PALETTE="${MANAGE_WALLUST_PALETTE:-1}"
    GTK_THEME_MISSING_POLICY="${GTK_THEME_MISSING_POLICY:-legacy}"
    ICON_THEME_MISSING_POLICY="${ICON_THEME_MISSING_POLICY:-legacy}"
    QT_THEME_MISSING_POLICY="${QT_THEME_MISSING_POLICY:-legacy}"
}

pick_mode_value() {
    local dark_value="$1"
    local light_value="$2"
    if [ "$next_mode" = "Dark" ]; then
        printf '%s
' "$dark_value"
    else
        printf '%s
' "$light_value"
    fi
}

set_gtk_theme_direct() {
    local gtk_theme="$1"
    local cursor_theme="$2"
    [ -n "$gtk_theme" ] && gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"
    [ -n "$cursor_theme" ] && gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme"

    if command -v flatpak >/dev/null 2>&1; then
        flatpak --user override --filesystem=$HOME/.themes >/dev/null 2>&1 || true
        [ -n "$gtk_theme" ] && flatpak --user override --env=GTK_THEME="$gtk_theme" >/dev/null 2>&1 || true
    fi
}

theme_exists() {
    local kind="$1"
    local candidate="$2"
    [ -n "$candidate" ] || return 1

    case "$kind" in
    gtk)
        [ -d "$HOME/.themes/$candidate" ]
        ;;
    icon)
        [ -d "$HOME/.icons/$candidate" ] || [ -d "$HOME/.local/share/icons/$candidate" ] || [ -d "/usr/share/icons/$candidate" ]
        ;;
    cursor)
        [ -d "$HOME/.icons/$candidate" ] || [ -d "$HOME/.local/share/icons/$candidate" ] || [ -d "/usr/share/icons/$candidate" ]
        ;;
    qt_scheme)
        [ -f "$candidate" ]
        ;;
    kvantum)
        [ -f "$HOME/.config/Kvantum/$candidate/$candidate.kvconfig" ]
        ;;
    *)
        return 1
        ;;
    esac
}

resolve_component_mode() {
    local manage_flag="$1"
    local kind="$2"
    local candidate="$3"
    local missing_policy="$4"

    if [ "$manage_flag" = "1" ] && theme_exists "$kind" "$candidate"; then
        printf 'direct\n'
        return 0
    fi

    case "$missing_policy" in
    legacy)
        printf 'legacy\n'
        ;;
    keep | skip)
        printf 'skip\n'
        ;;
    *)
        printf 'legacy\n'
        ;;
    esac
}

set_icon_theme_direct() {
    local icon_theme="$1"
    [ -n "$icon_theme" ] || return 0
    gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
    sed -i "s|^icon_theme=.*$|icon_theme=$icon_theme|" "$HOME/.config/qt5ct/qt5ct.conf"
    sed -i "s|^icon_theme=.*$|icon_theme=$icon_theme|" "$HOME/.config/qt6ct/qt6ct.conf"

    if command -v flatpak >/dev/null 2>&1; then
        flatpak --user override --filesystem=$HOME/.icons >/dev/null 2>&1 || true
        flatpak --user override --env=ICON_THEME="$icon_theme" >/dev/null 2>&1 || true
    fi
}

set_waybar_style() {
    local explicit_style="$1"
    local theme="$2"
    local waybar_styles="$HOME/.config/waybar/style"
    local waybar_style_link="$HOME/.config/waybar/style.css"
    local style_prefix="\[${theme}\].*\.css$"
    local style_file=""

    if [ -n "$explicit_style" ] && [ -f "$explicit_style" ]; then
        style_file="$explicit_style"
    else
        style_file=$(find -L "$waybar_styles" -maxdepth 1 -type f -regex ".*$style_prefix" | shuf -n 1)
    fi

    if [ -n "$style_file" ]; then
        ln -sf "$style_file" "$waybar_style_link"
    else
        echo "Style file not found for $theme theme."
    fi
}

notify_user() {
    notify-send -u low -i "$notif" " Switching to" " $1 mode (${active_theme_family})"
}

# initial kill process
for pid in waybar rofi swaync ags swaybg; do
    killall -SIGUSR1 "$pid" 2>/dev/null || true
done

# Initialize wallpaper daemon if needed
"$WWW_CMD" query || "$WWW_DAEMON" "${WWW_DAEMON_ARGS[@]}"

# Set swww options
swww="$WWW_CMD img"
effect="--transition-bezier .43,1.19,1,.4 --transition-fps 60 --transition-type grow --transition-pos 0.925,0.977 --transition-duration 2"

# Determine current theme mode
if [ "$(cat "$HOME/.cache/.theme_mode" 2>/dev/null)" = "Light" ]; then
    next_mode="Dark"
else
    next_mode="Light"
fi

load_theme_family

# Select Qt color scheme templates for the upcoming mode
qt5ct_color_scheme="$(pick_mode_value "${DARK_QT5_COLOR_SCHEME:-$qt5ct_dark}" "${LIGHT_QT5_COLOR_SCHEME:-$qt5ct_light}")"
qt6ct_color_scheme="$(pick_mode_value "${DARK_QT6_COLOR_SCHEME:-$qt6ct_dark}" "${LIGHT_QT6_COLOR_SCHEME:-$qt6ct_light}")"
wallust_palette="$(pick_mode_value "${DARK_WALLUST_PALETTE:-$pallete_dark}" "${LIGHT_WALLUST_PALETTE:-$pallete_light}")"
selected_gtk_theme="$(pick_mode_value "${DARK_GTK_THEME:-}" "${LIGHT_GTK_THEME:-}")"
selected_icon_theme="$(pick_mode_value "${DARK_ICON_THEME:-}" "${LIGHT_ICON_THEME:-}")"
selected_cursor_theme="$(pick_mode_value "${DARK_CURSOR_THEME:-}" "${LIGHT_CURSOR_THEME:-}")"
selected_kvantum_theme="$(pick_mode_value "${DARK_KVANTUM_THEME:-}" "${LIGHT_KVANTUM_THEME:-}")"
selected_waybar_style="$(pick_mode_value "${DARK_WAYBAR_STYLE:-}" "${LIGHT_WAYBAR_STYLE:-}")"

use_direct_gtk_theme=0
use_direct_icon_theme=0
use_direct_qt_theme=0
gtk_theme_mode="$(resolve_component_mode "$MANAGE_GTK_THEME" gtk "$selected_gtk_theme" "$GTK_THEME_MISSING_POLICY")"
icon_theme_mode="$(resolve_component_mode "$MANAGE_ICON_THEME" icon "$selected_icon_theme" "$ICON_THEME_MISSING_POLICY")"

if [ "$gtk_theme_mode" = "direct" ]; then
    use_direct_gtk_theme=1
fi

if [ "$icon_theme_mode" = "direct" ]; then
    use_direct_icon_theme=1
fi

if [ "$MANAGE_QT_THEME" = "1" ] && theme_exists qt_scheme "$qt5ct_color_scheme" && theme_exists qt_scheme "$qt6ct_color_scheme" && theme_exists kvantum "$selected_kvantum_theme"; then
    use_direct_qt_theme=1
elif [ "$QT_THEME_MISSING_POLICY" = "legacy" ]; then
    qt5ct_color_scheme="$(pick_mode_value "$qt5ct_dark" "$qt5ct_light")"
    qt6ct_color_scheme="$(pick_mode_value "$qt6ct_dark" "$qt6ct_light")"
    selected_kvantum_theme="$(pick_mode_value "$kvantum_dark" "$kvantum_light")"
    if theme_exists qt_scheme "$qt5ct_color_scheme" && theme_exists qt_scheme "$qt6ct_color_scheme" && theme_exists kvantum "$selected_kvantum_theme"; then
        use_direct_qt_theme=1
    fi
fi

update_theme_mode() {
    echo "$next_mode" > "$HOME/.cache/.theme_mode"
}

if [ "$MANAGE_WALLUST_PALETTE" = "1" ]; then
    sed -i 's/^palette = .*/palette = "'"$wallust_palette"'"/' "$wallust_config"
fi

set_waybar_style "$selected_waybar_style" "$next_mode"
notify_user "$next_mode"

# swaync color change
if [ "$next_mode" = "Dark" ]; then
    sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.8);/' "${swaync_style}"
else
    sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.9);/' "${swaync_style}"
fi

# ags color change
if command -v ags >/dev/null 2>&1; then
    if [ "$next_mode" = "Dark" ]; then
        sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.4);/' "${ags_style}"
        sed -i '/@define-color text-color/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.7);/' "${ags_style}"
        sed -i '/@define-color noti-bg-alt/s/#.*;/#111111;/' "${ags_style}"
    else
        sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.4);/' "${ags_style}"
        sed -i '/@define-color text-color/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.7);/' "${ags_style}"
        sed -i '/@define-color noti-bg-alt/s/#.*;/#F0F0F0;/' "${ags_style}"
    fi
fi

# kitty background color change
if [ "$next_mode" = "Dark" ]; then
    sed -i '/^foreground /s/^foreground .*/foreground #dddddd/' "${kitty_conf}"
    sed -i '/^background /s/^background .*/background #000000/' "${kitty_conf}"
    sed -i '/^cursor /s/^cursor .*/cursor #dddddd/' "${kitty_conf}"
else
    sed -i '/^foreground /s/^foreground .*/foreground #000000/' "${kitty_conf}"
    sed -i '/^background /s/^background .*/background #dddddd/' "${kitty_conf}"
    sed -i '/^cursor /s/^cursor .*/cursor #000000/' "${kitty_conf}"
fi

for pid_kitty in $(pidof kitty 2>/dev/null); do
    kill -SIGUSR1 "$pid_kitty"
done

# Set Dynamic Wallpaper for Dark or Light Mode
if [ "$next_mode" = "Dark" ]; then
    next_wallpaper="$(find -L "${dark_wallpapers}" -type f \( -iname "*.jpg" -o -iname "*.png" \) -print0 | shuf -n1 -z | xargs -0)"
else
    next_wallpaper="$(find -L "${light_wallpapers}" -type f \( -iname "*.jpg" -o -iname "*.png" \) -print0 | shuf -n1 -z | xargs -0)"
fi

$swww "${next_wallpaper}" $effect

# Set Kvantum Manager theme & QT5/QT6 settings only when a complete profile is available.
if [ "$use_direct_qt_theme" = "1" ]; then
    sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt5ct_color_scheme|" "$HOME/.config/qt5ct/qt5ct.conf"
    sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt6ct_color_scheme|" "$HOME/.config/qt6ct/qt6ct.conf"
    [ -n "$selected_kvantum_theme" ] && kvantummanager --set "$selected_kvantum_theme"
fi

# set the rofi color for background
if [ "$next_mode" = "Dark" ]; then
    sed -i '/^background:/s/.*/background: rgba(0,0,0,0.7);/' "$wallust_rofi"
else
    sed -i '/^background:/s/.*/background: rgba(255,255,255,0.9);/' "$wallust_rofi"
fi

# GTK and icon theme management via explicit family config; otherwise keep legacy fallback.
set_custom_icon_theme() {
    mode=$1
    icon_directory="$HOME/.icons"
    icon_setting="org.gnome.desktop.interface icon-theme"

    if [ "$mode" == "Light" ]; then
        search_keywords="*Light*"
    elif [ "$mode" == "Dark" ]; then
        search_keywords="*Dark*"
    else
        echo "Invalid mode provided."
        return 1
    fi

    icons=()

    while IFS= read -r -d '' icon_search; do
        icons+=("$(basename "$icon_search")")
    done < <(find "$icon_directory" -maxdepth 1 -type d -iname "$search_keywords" -print0)

    if [ ${#icons[@]} -gt 0 ]; then
        selected_icon=${icons[RANDOM % ${#icons[@]}]}
        gsettings set $icon_setting "$selected_icon"
        sed -i "s|^icon_theme=.*$|icon_theme=$selected_icon|" "$HOME/.config/qt5ct/qt5ct.conf"
        sed -i "s|^icon_theme=.*$|icon_theme=$selected_icon|" "$HOME/.config/qt6ct/qt6ct.conf"
        if command -v flatpak &> /dev/null; then
            flatpak --user override --filesystem=$HOME/.icons >/dev/null 2>&1 || true
            flatpak --user override --env=ICON_THEME="$selected_icon" >/dev/null 2>&1 || true
        fi
    fi
}

set_custom_gtk_theme() {
    mode=$1
    gtk_themes_directory="$HOME/.themes"
    color_setting="org.gnome.desktop.interface color-scheme"
    theme_setting="org.gnome.desktop.interface gtk-theme"

    if [ "$mode" == "Light" ]; then
        search_keywords="*Light*"
        gsettings set $color_setting 'prefer-light'
    elif [ "$mode" == "Dark" ]; then
        search_keywords="*Dark*"
        gsettings set $color_setting 'prefer-dark'
    else
        echo "Invalid mode provided."
        return 1
    fi

    themes=()

    while IFS= read -r -d '' theme_search; do
        themes+=("$(basename "$theme_search")")
    done < <(find "$gtk_themes_directory" -maxdepth 1 -type d -iname "$search_keywords" -print0)

    if [ ${#themes[@]} -gt 0 ]; then
        selected_theme=${themes[RANDOM % ${#themes[@]}]}
        gsettings set $theme_setting "$selected_theme"
        if command -v flatpak &> /dev/null; then
            flatpak --user override --filesystem=$HOME/.themes >/dev/null 2>&1 || true
            flatpak --user override --env=GTK_THEME="$selected_theme" >/dev/null 2>&1 || true
        fi
    fi
}

if [ "$use_direct_gtk_theme" -eq 1 ]; then
    if [ "$next_mode" = "Light" ]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    else
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    fi
    set_gtk_theme_direct "$selected_gtk_theme" "$selected_cursor_theme"
elif [ "$gtk_theme_mode" = "legacy" ]; then
    set_custom_gtk_theme "$next_mode"
fi

if [ "$use_direct_icon_theme" -eq 1 ]; then
    set_icon_theme_direct "$selected_icon_theme"
elif [ "$icon_theme_mode" = "legacy" ]; then
    set_custom_icon_theme "$next_mode"
fi

update_theme_mode

${SCRIPTSDIR}/WallustSwww.sh &&

sleep 2
for pid1 in waybar rofi swaync ags swaybg; do
    killall "$pid1" 2>/dev/null || true
done

sleep 1
${SCRIPTSDIR}/Refresh.sh
