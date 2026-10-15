#!/usr/bin/env bash
# Session daemon units: ship, enable and bring up hyprland-session.target.
#
# Long-lived desktop daemons are systemd user units rather than exec-once
# children (an exec-once inherits Hyprland's pre-raise soft RLIMIT_NOFILE of
# 1024 and is the first thing to die when fds run short). The units live in
# config/systemd/user/ and hang off hyprland-session.target; this file is the
# installer side. See docs/adr/run-session-daemons-as-systemd-user-units.md.

# Shipped units that only make sense when their program exists, as
# "unit:gate". The gate is a command name for `command -v`, or one of the
# markers __always__, __wallpaper__ (awww or swww via WallpaperCmd.sh) or
# __ags__ (an ags binary that can actually find its entry script; a half-
# installed ags exits 1 on every start and would sit in a restart loop).
SESSION_UNIT_GATES=(
  "swww-daemon.service:__wallpaper__"
  "nm-applet.service:nm-applet"
  "cliphist-text.service:cliphist"
  "cliphist-image.service:cliphist"
  "quickshell-overview.service:qs"
  "copyq.service:copyq"
  "ags.service:__ags__"
  "idle-power-watch.service:__always__"
)

# Space-separated list of every unit install_session_units enabled or wanted
# on this host. migrate_startup_overlay reads it so an exec-once is only
# stripped from the user's overlay when a unit really took the job over.
SESSION_UNITS_ENABLED=""

# 0 when the user manager knows a unit file for $1 and it is not masked.
session_unit_loaded() {
  local state
  state=$(systemctl --user show "$1" --property=LoadState --value 2>/dev/null || true)
  [ -n "$state" ] && [ "$state" != "not-found" ] && [ "$state" != "masked" ]
}

# 0 when the wallpaper daemon WallpaperCmd.sh would pick is installed.
session_wallpaper_daemon_available() {
  local scripts_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
  local daemon=""
  if [ -r "$scripts_dir/WallpaperCmd.sh" ]; then
    daemon=$(bash -c '. "$1" >/dev/null 2>&1; printf %s "$WWW_DAEMON"' _ "$scripts_dir/WallpaperCmd.sh" 2>/dev/null || true)
  fi
  if [ -n "$daemon" ]; then
    command -v "$daemon" >/dev/null 2>&1
    return
  fi
  command -v awww-daemon >/dev/null 2>&1 || command -v swww-daemon >/dev/null 2>&1
}

install_session_units() {
  local log="$1"
  local src="${DOTFILES_DIR:-.}/config/systemd"
  local dest="${XDG_CONFIG_HOME:-$HOME/.config}/systemd"
  local user_dir="$dest/user"
  SESSION_UNITS_ENABLED=""

  if [ -d "$src" ]; then
    mkdir -p "$dest"
    if cp -r "$src/." "$dest/" 2>&1 | tee -a "$log"; then
      echo "${OK:-[OK]} - systemd user units copied to $user_dir" 2>&1 | tee -a "$log"
    fi
  fi

  if ! command -v systemctl >/dev/null 2>&1; then
    echo "${NOTE:-[NOTE]} systemctl not found; session units copied but not enabled." 2>&1 | tee -a "$log"
    return 0
  fi
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    echo "${WARN:-[WARN]} user systemd manager not reachable; session units copied but not enabled." 2>&1 | tee -a "$log"
    echo "        After login run: systemctl --user daemon-reload && systemctl --user enable hyprland-session.target" 2>&1 | tee -a "$log"
    return 0
  fi

  # Hosts that masked waybar/hypridle to stop the old exec-once double start.
  # Only the exact mask shape (a symlink to /dev/null in the user dir) is
  # touched; a real override file is left alone.
  local unit link
  for unit in waybar.service hypridle.service; do
    link="$user_dir/$unit"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "/dev/null" ]; then
      rm -f "$link"
      echo "${NOTE:-[NOTE]} - unmasked $unit (daemons are started by hyprland-session.target now)" 2>&1 | tee -a "$log"
    fi
  done

  systemctl --user daemon-reload 2>&1 | tee -a "$log" || true

  # Units need the compositor's environment. uwsm exports it already; a plain
  # hyprland.desktop session relies on Startup_Session.conf doing so at login,
  # and on this when the installer runs inside a live session.
  if [ -n "${WAYLAND_DISPLAY:-}" ]; then
    systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE >/dev/null 2>&1 || true
  fi

  if systemctl --user enable hyprland-session.target >>"$log" 2>&1; then
    echo "${OK:-[OK]} - hyprland-session.target enabled (WantedBy graphical-session.target)" 2>&1 | tee -a "$log"
  else
    echo "${WARN:-[WARN]} - could not enable hyprland-session.target; see $log" 2>&1 | tee -a "$log"
  fi

  local entry gate
  for entry in "${SESSION_UNIT_GATES[@]}"; do
    unit="${entry%%:*}"
    gate="${entry##*:}"
    [ -f "$user_dir/$unit" ] || continue
    case "$gate" in
      __always__) ;;
      __ags__)
        if ! command -v ags >/dev/null 2>&1 || ! ags --version >/dev/null 2>&1; then
          echo "${NOTE:-[NOTE]} - $unit: ags not installed or not runnable; not enabled" 2>&1 | tee -a "$log"
          continue
        fi
        ;;
      __wallpaper__)
        if ! session_wallpaper_daemon_available; then
          echo "${NOTE:-[NOTE]} - $unit: no awww-daemon or swww-daemon installed; not enabled" 2>&1 | tee -a "$log"
          continue
        fi
        ;;
      *)
        if ! command -v "$gate" >/dev/null 2>&1; then
          echo "${NOTE:-[NOTE]} - $unit: $gate not installed; not enabled" 2>&1 | tee -a "$log"
          continue
        fi
        ;;
    esac
    if systemctl --user enable "$unit" >>"$log" 2>&1; then
      SESSION_UNITS_ENABLED="$SESSION_UNITS_ENABLED $unit"
    else
      echo "${WARN:-[WARN]} - could not enable $unit; see $log" 2>&1 | tee -a "$log"
    fi
  done

  # Distro-provided units we only want, never ship. add-wants is idempotent.
  for unit in waybar.service hypridle.service blueman-applet.service; do
    session_unit_loaded "$unit" || continue
    if systemctl --user add-wants hyprland-session.target "$unit" >>"$log" 2>&1; then
      SESSION_UNITS_ENABLED="$SESSION_UNITS_ENABLED $unit"
    else
      echo "${WARN:-[WARN]} - could not add $unit to hyprland-session.target; see $log" 2>&1 | tee -a "$log"
    fi
  done

  # Exactly one polkit agent. hyprpolkitagent when its unit exists (the repo
  # ships an override making it part of graphical-session.target), else the
  # KDE agent (the shipped drop-ins make it Wayland-clean), else the vendor
  # Polkit.sh exec-once path is left to do its thing.
  local agent=""
  if session_unit_loaded hyprpolkitagent.service; then
    agent=hyprpolkitagent.service
  elif session_unit_loaded plasma-polkit-agent.service; then
    agent=plasma-polkit-agent.service
  fi
  if [ -n "$agent" ]; then
    if pgrep -u "$UID" -f 'xfce-polkit|polkit-gnome-authentication-agent-1|polkit-kde-authentication-agent-1|polkit-mate-authentication-agent-1|lxpolkit' >/dev/null 2>&1 \
        && ! systemctl --user is-active --quiet "$agent" 2>/dev/null; then
      echo "${NOTE:-[NOTE]} - another polkit agent is running right now; $agent is wired for the next login." 2>&1 | tee -a "$log"
    fi
    systemctl --user add-wants hyprland-session.target "$agent" >>"$log" 2>&1 || true
    # Static units have no [Install]; that is fine, the wants link above is enough.
    systemctl --user enable "$agent" >>"$log" 2>&1 || true
    SESSION_UNITS_ENABLED="$SESSION_UNITS_ENABLED $agent"
  else
    echo "${NOTE:-[NOTE]} - no hyprpolkitagent or plasma-polkit-agent unit; leaving the Polkit.sh exec-once path alone." 2>&1 | tee -a "$log"
  fi

  echo "${INFO:-[INFO]} hyprland-session.target wants:${SESSION_UNITS_ENABLED}" 2>&1 | tee -a "$log"

  # Make it live now when a session is running, so the deploy does not look
  # like a grey screen until the next login.
  if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
    if systemctl --user start hyprland-session.target >>"$log" 2>&1; then
      echo "${OK:-[OK]} - hyprland-session.target started in the running session" 2>&1 | tee -a "$log"
    else
      echo "${WARN:-[WARN]} - hyprland-session.target failed to start; see $log and 'systemctl --user --failed'" 2>&1 | tee -a "$log"
    fi
    sleep 1
    local failed
    failed=$(systemctl --user list-units --state=failed --plain --no-legend 2>/dev/null | awk '{print $1}')
    for unit in $SESSION_UNITS_ENABLED; do
      case " $failed " in
        *" $unit "*) echo "${WARN:-[WARN]} - $unit is in failed state: journalctl --user -u $unit" 2>&1 | tee -a "$log" ;;
      esac
    done
  fi
  return 0
}
