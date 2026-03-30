#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Scripts for refreshing ags, waybar, rofi, swaync, wallust

SCRIPTSDIR=$HOME/.config/hypr/scripts
UserScripts=$HOME/.config/hypr/UserScripts
WAYBAR_CONFIG=$HOME/.config/waybar/config
WAYBAR_GREENSCREEN_AUTO="$HOME/.config/waybar/configs/[TOP] Greenscreen Auto"

# Define file_exists function
file_exists() {
  if [ -e "$1" ]; then
    return 0 # File exists
  else
    return 1 # File does not exist
  fi
}

# Kill already running processes
_ps=(rofi swaync ags)
for _prs in "${_ps[@]}"; do
  if pidof "${_prs}" >/dev/null; then
    pkill "${_prs}"
  fi
done

# quit ags & relaunch ags
ags -q && ags &

# quit quickshell & relaunch quickshell
#pkill qs && qs &

# some process to kill
for pid in $(pidof rofi swaync ags swaybg); do
  kill -SIGUSR1 "$pid"
  sleep 0.1
done

# Regenerate Greenscreen auto layout when it is the active Waybar target
if [ -e "$WAYBAR_CONFIG" ] && [ -x "${SCRIPTSDIR}/GenerateWaybarGreenscreen.sh" ]; then
  current_waybar_target=$(readlink -f "$WAYBAR_CONFIG" 2>/dev/null || printf '%s\n' "$WAYBAR_CONFIG")
  current_waybar_name=$(basename "$current_waybar_target")
  if [ "$current_waybar_name" = "[TOP] Greenscreen" ] || [ "$current_waybar_name" = "[TOP] Greenscreen Auto" ]; then
    "${SCRIPTSDIR}/GenerateWaybarGreenscreen.sh" >/dev/null 2>&1 || true
    [ -f "$WAYBAR_GREENSCREEN_AUTO" ] && ln -sf "$WAYBAR_GREENSCREEN_AUTO" "$WAYBAR_CONFIG"
  fi
fi

# Reload Waybar in-place so the tray host survives
sleep 0.1
if command -v waybar-msg >/dev/null 2>&1; then
  waybar-msg cmd reload >/dev/null 2>&1 || true
elif pidof waybar >/dev/null; then
  killall -SIGUSR2 waybar 2>/dev/null || true
else
  waybar >/dev/null 2>&1 &
fi

# relaunch swaync
sleep 0.3
swaync >/dev/null 2>&1 &
# reload swaync
swaync-client --reload-config

# Relaunching rainbow borders if the script exists (disabled - high GPU usage)
#sleep 1
#if file_exists "${UserScripts}/RainbowBorders.sh"; then
#  ${UserScripts}/RainbowBorders.sh &
#fi

exit 0
