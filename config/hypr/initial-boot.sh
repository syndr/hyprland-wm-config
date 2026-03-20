#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
# A bash script designed to run only once dotfiles installed

# THIS SCRIPT CAN BE DELETED ONCE SUCCESSFULLY BOOTED!! And also, edit ~/.config/hypr/configs/Settings.conf
# NOT necessary to do since this script is only designed to run only once as long as the marker exists
# marker file is located at ~/.config/hypr/.initial_startup_done
# However, I do highly suggest not to touch it since again, as long as the marker exist, script wont run

# Variables
scriptsDir=$HOME/.config/hypr/scripts
wallpaper=$HOME/.config/hypr/wallpaper_effects/.wallpaper_current
waybar_style="$HOME/.config/waybar/style/[Extra] Neon Circuit.css"
kvantum_theme="catppuccin-mocha-blue"
color_scheme="prefer-dark"
gtk_theme="Flat-Remix-GTK-Blue-Dark"
icon_theme="Flat-Remix-Blue-Dark"
cursor_theme="Bibata-Modern-Ice"
force_theme_bootstrap="${FORCE_THEME_BOOTSTRAP:-0}"
theme_config="$HOME/.config/hypr/UserConfigs/ThemeConfig.conf"
theme_dir="$HOME/.config/hypr/themes"
preserve_theme_state_marker="$HOME/.config/hypr/.preserve_theme_state"
apply_gtk_theme=1
apply_icon_theme=1
apply_kvantum_theme=1

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

load_theme_bootstrap_defaults() {
    local active_theme_family="Hackerer"
    local gtk_mode="legacy"
    local icon_mode="legacy"
    local qt_mode="legacy"

    [ -f "$theme_config" ] && source "$theme_config"
    active_theme_family="${ACTIVE_THEME_FAMILY:-Hackerer}"

    local profile="$theme_dir/${active_theme_family}.conf"
    [ -f "$profile" ] && source "$profile"

    MANAGE_GTK_THEME="${MANAGE_GTK_THEME:-0}"
    MANAGE_ICON_THEME="${MANAGE_ICON_THEME:-0}"
    MANAGE_QT_THEME="${MANAGE_QT_THEME:-0}"
    GTK_THEME_MISSING_POLICY="${GTK_THEME_MISSING_POLICY:-legacy}"
    ICON_THEME_MISSING_POLICY="${ICON_THEME_MISSING_POLICY:-legacy}"
    QT_THEME_MISSING_POLICY="${QT_THEME_MISSING_POLICY:-legacy}"

    gtk_mode="$(resolve_component_mode "$MANAGE_GTK_THEME" gtk "${DARK_GTK_THEME:-}" "$GTK_THEME_MISSING_POLICY")"
    icon_mode="$(resolve_component_mode "$MANAGE_ICON_THEME" icon "${DARK_ICON_THEME:-}" "$ICON_THEME_MISSING_POLICY")"
    qt_mode="$(resolve_component_mode "$MANAGE_QT_THEME" kvantum "${DARK_KVANTUM_THEME:-}" "$QT_THEME_MISSING_POLICY")"

    if [ "$gtk_mode" = "direct" ]; then
        gtk_theme="$DARK_GTK_THEME"
    elif [ "$gtk_mode" = "skip" ]; then
        apply_gtk_theme=0
    fi

    if [ "$icon_mode" = "direct" ]; then
        icon_theme="$DARK_ICON_THEME"
    elif [ "$icon_mode" = "skip" ]; then
        apply_icon_theme=0
    fi

    if [ -n "${DARK_CURSOR_THEME:-}" ] && theme_exists cursor "${DARK_CURSOR_THEME:-}"; then
        cursor_theme="$DARK_CURSOR_THEME"
    fi

    if [ "$qt_mode" = "direct" ]; then
        kvantum_theme="$DARK_KVANTUM_THEME"
    elif [ "$qt_mode" = "skip" ]; then
        apply_kvantum_theme=0
    fi
}

swww="swww img"
effect="--transition-bezier .43,1.19,1,.4 --transition-fps 30 --transition-type grow --transition-pos 0.925,0.977 --transition-duration 2"

# Check if a marker file exists.
if [ ! -f "$HOME/.config/hypr/.initial_startup_done" ]; then
    sleep 1
    load_theme_bootstrap_defaults
    # Initialize wallust and wallpaper
	if [ -f "$wallpaper" ]; then
		wallust run -s $wallpaper > /dev/null 
		swww query || swww-daemon && $swww $wallpaper $effect
	    "$scriptsDir/WallustSwww.sh" > /dev/null 2>&1 & 
	fi
	     
	    if [ "$force_theme_bootstrap" = "1" ] || [ ! -f "$preserve_theme_state_marker" ]; then
	      # initiate GTK dark mode and apply icon and cursor theme
	      gsettings set org.gnome.desktop.interface color-scheme $color_scheme > /dev/null 2>&1 &
	      if [ "$apply_gtk_theme" -eq 1 ]; then
	        gsettings set org.gnome.desktop.interface gtk-theme $gtk_theme > /dev/null 2>&1 &
	      fi
	      if [ "$apply_icon_theme" -eq 1 ]; then
	        gsettings set org.gnome.desktop.interface icon-theme $icon_theme > /dev/null 2>&1 &
	      fi
	      gsettings set org.gnome.desktop.interface cursor-theme $cursor_theme > /dev/null 2>&1 &
	      gsettings set org.gnome.desktop.interface cursor-size 24 > /dev/null 2>&1 &

	      # NIXOS initiate GTK dark mode and apply icon and cursor theme
		  if [ -n "$(grep -i nixos < /etc/os-release)" ]; then
	        gsettings set org.gnome.desktop.interface color-scheme "'$color_scheme'" > /dev/null 2>&1 &
	        if [ "$apply_gtk_theme" -eq 1 ]; then
	          dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk_theme'" > /dev/null 2>&1 &
	        fi
	        if [ "$apply_icon_theme" -eq 1 ]; then
	          dconf write /org/gnome/desktop/interface/icon-theme "'$icon_theme'" > /dev/null 2>&1 &
	        fi
	        dconf write /org/gnome/desktop/interface/cursor-theme "'$cursor_theme'" > /dev/null 2>&1 &
	        dconf write /org/gnome/desktop/interface/cursor-size "24" > /dev/null 2>&1 &
		  fi

	      # initiate kvantum theme
	      if [ "$apply_kvantum_theme" -eq 1 ]; then
	        kvantummanager --set "$kvantum_theme" > /dev/null 2>&1 &
	      fi
		    else
		      echo "Preserving existing local GTK/Qt/Kvantum theme state."
		    fi

	    rm -f "$preserve_theme_state_marker"

		# waybar style
	#if [ -L "$HOME/.config/waybar/config" ]; then
    ##    	ln -sf "$waybar_style" "$HOME/.config/waybar/style.css"
    #   	"$scriptsDir/Refresh.sh" > /dev/null 2>&1 & 
	#fi


    # Create a marker file to indicate that the script has been executed.
    touch "$HOME/.config/hypr/.initial_startup_done"

    exit
fi
