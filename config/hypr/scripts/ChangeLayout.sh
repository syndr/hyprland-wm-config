#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# for changing Hyprland Layouts (Master, Dwindle, or hy3) on the fly

notif="$HOME/.config/swaync/images/ja.png"

LAYOUT=$(hyprctl -j getoption general:layout | jq '.str' | sed 's/"//g')

set_standard_binds() {
  hyprctl keyword unbind SUPER,O
  hyprctl keyword unbind SUPER_SHIFT,O
  hyprctl keyword unbind SUPER,J
  hyprctl keyword unbind SUPER,K
  hyprctl keyword bind SUPER,J,cyclenext
  hyprctl keyword bind SUPER,K,cyclenext,prev
  hyprctl keyword bindd "SUPER,left,focus left,movefocus,l"
  hyprctl keyword bindd "SUPER,right,focus right,movefocus,r"
  hyprctl keyword bindd "SUPER,up,focus up,movefocus,u"
  hyprctl keyword bindd "SUPER,down,focus down,movefocus,d"
  hyprctl keyword bindd "SUPER_CTRL,left,move window left,movewindow,l"
  hyprctl keyword bindd "SUPER_CTRL,right,move window right,movewindow,r"
  hyprctl keyword bindd "SUPER_CTRL,up,move window up,movewindow,u"
  hyprctl keyword bindd "SUPER_CTRL,down,move window down,movewindow,d"
}

set_master_binds() {
  hyprctl keyword unbind SUPER,O
  hyprctl keyword unbind SUPER_SHIFT,O
  hyprctl keyword unbind SUPER,J
  hyprctl keyword unbind SUPER,K
  hyprctl keyword bind SUPER,J,layoutmsg,cyclenext
  hyprctl keyword bind SUPER,K,layoutmsg,cycleprev
  hyprctl keyword bindd "SUPER,left,focus left,movefocus,l"
  hyprctl keyword bindd "SUPER,right,focus right,movefocus,r"
  hyprctl keyword bindd "SUPER,up,focus up,movefocus,u"
  hyprctl keyword bindd "SUPER,down,focus down,movefocus,d"
  hyprctl keyword bindd "SUPER_CTRL,left,move window left,movewindow,l"
  hyprctl keyword bindd "SUPER_CTRL,right,move window right,movewindow,r"
  hyprctl keyword bindd "SUPER_CTRL,up,move window up,movewindow,u"
  hyprctl keyword bindd "SUPER_CTRL,down,move window down,movewindow,d"
}

set_hy3_binds() {
  hyprctl keyword unbind SUPER,O
  hyprctl keyword unbind SUPER_SHIFT,O
  hyprctl keyword unbind SUPER,J
  hyprctl keyword unbind SUPER,K
  hyprctl keyword bind SUPER,J,cyclenext
  hyprctl keyword bind SUPER,K,cyclenext,prev
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

apply_current_layout_binds() {
  case "$LAYOUT" in
    master)
      set_master_binds
      ;;
    hy3)
      set_hy3_binds
      ;;
    *)
      set_standard_binds
      hyprctl keyword bind SUPER,O,togglesplit
      ;;
  esac
}

if [ "${1:-}" = "init" ]; then
  apply_current_layout_binds
  exit 0
fi

case "$LAYOUT" in
  dwindle)
    hyprctl keyword general:layout master
    set_master_binds
    notify-send -e -u low -i "$notif" " Master Layout"
    ;;
  master)
    hyprctl keyword general:layout hy3
    set_hy3_binds
    notify-send -e -u low -i "$notif" "󰕰 hy3 Layout"
    ;;
  hy3)
    hyprctl keyword general:layout dwindle
    set_standard_binds
    hyprctl keyword bind SUPER,O,togglesplit
    notify-send -e -u low -i "$notif" " Dwindle Layout"
    ;;
  *)
    hyprctl keyword general:layout dwindle
    set_standard_binds
    hyprctl keyword bind SUPER,O,togglesplit
    notify-send -e -u low -i "$notif" " Dwindle Layout"
    ;;
esac
