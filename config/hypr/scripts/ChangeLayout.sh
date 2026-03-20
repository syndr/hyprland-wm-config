#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# for changing Hyprland Layouts (Master, Dwindle, NStack, or hy3) on the fly

notif="$HOME/.config/swaync/images/ja.png"

LAYOUT=$(hyprctl -j getoption general:layout | jq '.str' | sed 's/"//g')

# Helper to set standard layout keybinds
set_standard_binds() {
	hyprctl keyword unbind SUPER,O
	hyprctl keyword unbind SUPER_SHIFT,O
	hyprctl keyword bindd "SUPER,left,focus left,movefocus,l"
	hyprctl keyword bindd "SUPER,right,focus right,movefocus,r"
	hyprctl keyword bindd "SUPER,up,focus up,movefocus,u"
	hyprctl keyword bindd "SUPER,down,focus down,movefocus,d"
	hyprctl keyword bindd "SUPER_CTRL,left,move window left,movewindow,l"
	hyprctl keyword bindd "SUPER_CTRL,right,move window right,movewindow,r"
	hyprctl keyword bindd "SUPER_CTRL,up,move window up,movewindow,u"
	hyprctl keyword bindd "SUPER_CTRL,down,move window down,movewindow,d"
}

# Helper to set hy3 layout keybinds
set_hy3_binds() {
	hyprctl keyword bindd "SUPER,O,expand focus (raise),hy3:changefocus,raise"
	hyprctl keyword bindd "SUPER_SHIFT,O,shrink focus (lower),hy3:changefocus,lower"
	hyprctl keyword bindd "SUPER,left,focus left,hy3:movefocus,l"
	hyprctl keyword bindd "SUPER,right,focus right,hy3:movefocus,r"
	hyprctl keyword bindd "SUPER,up,focus up,hy3:movefocus,u"
	hyprctl keyword bindd "SUPER,down,focus down,hy3:movefocus,d"
	hyprctl keyword bindd "SUPER_CTRL,left,move window left,hy3:movewindow,l"
	hyprctl keyword bindd "SUPER_CTRL,right,move window right,hy3:movewindow,r"
	hyprctl keyword bindd "SUPER_CTRL,up,move window up,hy3:movewindow,u"
	hyprctl keyword bindd "SUPER_CTRL,down,move window down,hy3:movewindow,d"
}

case $LAYOUT in
"dwindle")
	hyprctl keyword general:layout master
	set_standard_binds
	notify-send -e -u low -i "$notif" " Master Layout"
	;;
"master")
	hyprctl keyword general:layout hy3
	set_hy3_binds
	notify-send -e -u low -i "$notif" "󰕰 hy3 Layout"
	;;
"hy3")
	hyprctl keyword general:layout dwindle
	set_standard_binds
	hyprctl keyword bind SUPER,O,togglesplit
	notify-send -e -u low -i "$notif" " Dwindle Layout"
	;;
*)
	# Default to dwindle if unknown layout
	hyprctl keyword general:layout dwindle
	set_standard_binds
	hyprctl keyword bind SUPER,O,togglesplit
	notify-send -e -u low -i "$notif" " Dwindle Layout"
	;;
esac
