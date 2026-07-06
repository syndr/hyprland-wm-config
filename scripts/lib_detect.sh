#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Detection and environment adjustment helpers shared by copy.sh.

# Nvidia tweaks: uncomments envs and adjusts hardware cursor setting.
detect_nvidia_adjust() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  local pci_info
  local has_nvidia=0
  local has_intel=0
  local has_amd=0
  pci_info="$(lspci -k | grep -A 2 -E "(VGA|3D)" || true)"
  if echo "$pci_info" | grep -iq nvidia; then
    has_nvidia=1
  fi
  if echo "$pci_info" | grep -iq intel; then
    has_intel=1
  fi
  if echo "$pci_info" | grep -Eiq 'amd|advanced micro devices|ati'; then
    has_amd=1
  fi
  if [ "$has_nvidia" -eq 1 ]; then
    echo "${INFO:-[INFO]} Nvidia GPU detected. Setting up proper env's and configs" 2>&1 | tee -a "$log" || true
    sed -i '/env = LIBVA_DRIVER_NAME,nvidia/s/^#//' "$config_root/hypr/configs/ENVariables.conf"
    sed -i '/env = __GLX_VENDOR_LIBRARY_NAME,nvidia/s/^#//' "$config_root/hypr/configs/ENVariables.conf"
    sed -i '/env = NVD_BACKEND,direct/s/^#//' "$config_root/hypr/configs/ENVariables.conf"
    sed -i '/env = GSK_RENDERER,ngl/s/^#//' "$config_root/hypr/configs/ENVariables.conf"
    if [ "$has_intel" -eq 1 ] || [ "$has_amd" -eq 1 ]; then
      echo "${INFO:-[INFO]} Hybrid GPU detected (Intel/NVIDIA or AMD/NVIDIA). Applying cursor handoff fixes." 2>&1 | tee -a "$log" || true
      sed -i -E 's/^([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*)[0-9]+/\1 0/' "$config_root/hypr/configs/SystemSettings.conf"
      sed -i -E 's/^([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*)[0-9]+/\1 0/' "$config_root/hypr/lua/settings.lua"
      sed -i '/hyprctl setcursor/s/^#//' "$config_root/hypr/configs/Startup_Apps.conf"
    else
      sed -i -E 's/^([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*)[0-9]+/\1 1/' "$config_root/hypr/configs/SystemSettings.conf"
      sed -i -E 's/^([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*)[0-9]+/\1 1/' "$config_root/hypr/lua/settings.lua"
    fi
  fi
}

# VM tweaks: enable software renderer envs and virtual monitor defaults.
detect_vm_adjust() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  if hostnamectl | grep -q 'Chassis: vm'; then
    echo "${INFO:-[INFO]} System is running in a virtual machine. Setting up proper env's and configs" 2>&1 | tee -a "$log" || true
    sed -i 's/^\([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*\)2/\1 1/' "$config_root/hypr/configs/SystemSettings.conf"
    sed -i '/env = WLR_RENDERER_ALLOW_SOFTWARE,1/s/^#//' "$config_root/hypr/configs/ENVariables.conf"
    sed -i '/monitor = Virtual-1, 1920x1080@60,auto,1/s/^#//' "$config_root/hypr/monitors.conf"
  fi
}

# NixOS tweaks: ensure polkit overlay is enabled and default disabled.
detect_nixos_adjust() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  if hostnamectl | grep -q 'Operating System: NixOS'; then
    echo "${INFO:-[INFO]} NixOS Distro Detected. Setting up proper env's and configs." 2>&1 | tee -a "$log" || true
    local OVERLAY_SA="$config_root/hypr/configs/Startup_Apps.conf"
    local DISABLE_SA="$config_root/hypr/configs/Startup_Apps.disable"
    mkdir -p "$(dirname "$OVERLAY_SA")"
    touch "$OVERLAY_SA" "$DISABLE_SA"
    grep -qx 'exec-once = $scriptsDir/Polkit-NixOS.sh' "$OVERLAY_SA" || echo 'exec-once = $scriptsDir/Polkit-NixOS.sh' >>"$OVERLAY_SA"
    grep -qx '\$scriptsDir/Polkit.sh' "$DISABLE_SA" || echo '$scriptsDir/Polkit.sh' >>"$DISABLE_SA"
  fi
}
# Qt Quick Controls style safety: enable Hyprland style only when module exists.
adjust_qt_quick_controls_style() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  local env_conf="$config_root/hypr/configs/ENVariables.conf"
  local env_lua="$config_root/hypr/lua/env.lua"
  local style="Basic"
  local qt_style_override="Fusion"
  local has_kvantum=0

  if find /usr/lib /usr/lib64 /usr/share -type d -path '*/qml/*/org/hyprland/style' -print -quit 2>/dev/null | grep -q .; then
    style="org.hyprland.style"
  elif command -v dpkg >/dev/null 2>&1 && dpkg -s qml6-module-org-hyprland-style >/dev/null 2>&1; then
    style="org.hyprland.style"
  fi

  # Kvantum is a Qt *widget* style plugin (libkvantum.so under qt5/qt6
  # plugins/styles), not a QML module. Detect the plugin so QT_STYLE_OVERRIDE
  # stays kvantum when the engine is present (also accept a QML kvantum dir).
  if find /usr/lib /usr/lib64 -type f -path '*/plugins/styles/libkvantum.so' -print -quit 2>/dev/null | grep -q . \
     || find /usr/lib /usr/lib64 /usr/share -type d -path '*/qml/*/kvantum' -print -quit 2>/dev/null | grep -q .; then
    has_kvantum=1
    qt_style_override="kvantum"
  fi

  if [ -f "$env_conf" ]; then
    sed -i -E "s|^env = QT_QUICK_CONTROLS_STYLE,.*$|env = QT_QUICK_CONTROLS_STYLE,${style}|" "$env_conf"
    sed -i -E "s|^env = QT_STYLE_OVERRIDE,.*$|env = QT_STYLE_OVERRIDE,${qt_style_override}|" "$env_conf"
  fi
  if [ -f "$env_lua" ]; then
    sed -i -E "s|^hl\\.env\\(\"QT_QUICK_CONTROLS_STYLE\", \".*\"\\)$|hl.env(\"QT_QUICK_CONTROLS_STYLE\", \"${style}\")|" "$env_lua"
    sed -i -E "s|^hl\\.env\\(\"QT_STYLE_OVERRIDE\", \".*\"\\)$|hl.env(\"QT_STYLE_OVERRIDE\", \"${qt_style_override}\")|" "$env_lua"
  fi

  if [ "$style" = "org.hyprland.style" ]; then
    echo "${INFO:-[INFO]} hyprland Qt style module detected. Using QT_QUICK_CONTROLS_STYLE=$style" 2>&1 | tee -a "$log" || true
  else
    echo "${WARN:-[WARN]} hyprland Qt style module not found. Using QT_QUICK_CONTROLS_STYLE=Basic to avoid Qt app crashes." 2>&1 | tee -a "$log" || true
  fi
  if [ "$has_kvantum" -eq 1 ]; then
    echo "${INFO:-[INFO]} Kvantum style plugin detected. Using QT_STYLE_OVERRIDE=kvantum" 2>&1 | tee -a "$log" || true
  else
    echo "${WARN:-[WARN]} Kvantum style plugin not found. Using QT_STYLE_OVERRIDE=Fusion as fallback." 2>&1 | tee -a "$log" || true
  fi
}

# Resolve chassis type, preferring a saved explicit choice over hostnamectl.
resolve_chassis_type() {
  local log="$1"
  local chassis_type_file="$HOME/.config/hypr/.chassis_type"
  local detected="desktop"

  if hostnamectl | grep -q 'Chassis: laptop'; then
    detected="laptop"
  fi

  if [ -f "$chassis_type_file" ]; then
    local saved
    saved=$(tr '[:upper:]' '[:lower:]' <"$chassis_type_file" | tr -d '[:space:]')
    if [ "$saved" = "desktop" ] || [ "$saved" = "laptop" ]; then
      echo "$saved"
      return 0
    fi
  fi

  mkdir -p "$(dirname "$chassis_type_file")"
  printf '%s\n' "$detected" >"$chassis_type_file"
  echo "${INFO:-[INFO]} Saved chassis type as $detected in $chassis_type_file" 2>&1 | tee -a "$log" >/dev/null
  echo "$detected"
}

# Read a single KEY=value knob from a preserved user prefs file, without
# sourcing it (avoid leaking arbitrary user shell). Echoes the value, or the
# supplied default when the file/key is absent or empty.
read_idle_knob() {
  local file="$1" key="$2" def="$3" val=""
  if [ -f "$file" ]; then
    val=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null | tail -1 \
      | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*#.*$//; s/["'\'']//g; s/[[:space:]]+$//')
  fi
  if [ -n "$val" ]; then printf '%s' "$val"; else printf '%s' "$def"; fi
}

# User-configurable idle policy: DPMS-off and the nag/notifier are two
# independent knobs in the preserved, user-owned UserConfigs/IdleSettings.conf.
#
#   KOOL_IDLE_DPMS_OFF  default 1  -> 0 strips every dpms-off listener so the
#                                     displays stay lit (showing hyprlock) after
#                                     lock. Use on multi-monitor rigs where some
#                                     outputs don't reliably wake from DPMS-off.
#   KOOL_IDLE_NAG       default 0  -> 1 keeps the pre-lock IdleAlert warning and
#                                     the post-lock IdleWatchdog squawk/flash
#                                     (built for the sleepless uConsole
#                                     handheld). Default off: most users don't
#                                     want it, so it is stripped on deploy.
#
# Locking on idle and the after_sleep dpms-ON are always preserved. Operates on
# the staged config and is idempotent (re-running on a stripped file is a
# no-op). Always runs, since KOOL_IDLE_NAG defaults to stripping the nag.
adjust_idle_dpms_policy() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  local hypridle="$config_root/hypr/hypridle.conf"
  [ -f "$hypridle" ] || return 0

  local pref_file="$HOME/.config/hypr/UserConfigs/IdleSettings.conf"
  local dpms_off nag lock_timeout
  dpms_off=$(read_idle_knob "$pref_file" KOOL_IDLE_DPMS_OFF 1)
  nag=$(read_idle_knob "$pref_file" KOOL_IDLE_NAG 0)
  lock_timeout=$(read_idle_knob "$pref_file" KOOL_IDLE_LOCK_TIMEOUT "")

  local strip_dpms=0 strip_nag=0
  case "$dpms_off" in 0|false|no|off|FALSE|No|Off|NO|OFF) strip_dpms=1 ;; esac
  case "$nag" in 1|true|yes|on|TRUE|Yes|On|YES|ON) strip_nag=0 ;; *) strip_nag=1 ;; esac

  # Only honor a positive-integer lock timeout; anything else means "leave stock".
  case "$lock_timeout" in ''|*[!0-9]*) lock_timeout="" ;; esac
  if [ -n "$lock_timeout" ] && [ "$lock_timeout" -le 0 ]; then lock_timeout=""; fi

  if [ "$strip_dpms" -eq 0 ] && [ "$strip_nag" -eq 0 ] && [ -z "$lock_timeout" ]; then
    return 0
  fi

  local tmp_file
  tmp_file=$(mktemp)
  # Drop a listener{} block (plus the comment + blank lines preceding it) when
  # it issues "dpms off" and dpms-off is disabled, or when it fires the
  # IdleAlert nag and the nag is disabled. Keyed on block content, not comment
  # text, so it survives upstream comment rewording.
  awk -v strip_dpms="$strip_dpms" -v strip_nag="$strip_nag" '
    function flush_pending() { printf "%s", pending; pending = "" }
    BEGIN { pending = ""; inblock = 0 }
    !inblock && /^[[:space:]]*#/ { pending = pending $0 "\n"; next }
    !inblock && /^[[:space:]]*$/ { pending = pending $0 "\n"; next }
    !inblock && /^[[:space:]]*listener[[:space:]]*{/ {
      inblock = 1; buf = $0 "\n"; hasoff = 0; hasnag = 0; next
    }
    inblock {
      buf = buf $0 "\n"
      if ($0 ~ /dpms[[:space:]]+off/) hasoff = 1
      if ($0 ~ /IdleAlert\.sh/)       hasnag = 1
      if ($0 ~ /^[[:space:]]*}/) {
        inblock = 0
        drop = (strip_dpms && hasoff) || (strip_nag && hasnag)
        if (drop) { pending = "" }
        else { flush_pending(); printf "%s", buf }
        buf = ""
      }
      next
    }
    { flush_pending(); print }
    END { flush_pending() }
  ' "$hypridle" > "$tmp_file" && mv "$tmp_file" "$hypridle"

  # Watchdog is part of the nag: when disabled, drop only the IdleWatchdog spawn
  # from lock_cmd, preserving whatever locker is configured (swaylock-plugin
  # screensaver or plain hyprlock). '#' delimiter so literal '|' stays safe.
  if [ "$strip_nag" -eq 1 ]; then
    sed -i -E 's#^([[:space:]]*lock_cmd[[:space:]]*=[[:space:]]*.*)[[:space:]]*&[[:space:]]*setsid[[:space:]]+-f[[:space:]]+[^[:space:]]*IdleWatchdog\.sh.*$#\1#' "$hypridle"
  fi

  # Adjust the lock-on-idle timeout: rewrite the timeout line of the listener
  # whose on-timeout locks the session. Replaces the whole line so any stale
  # "# 10 min" inline comment goes with it.
  if [ -n "$lock_timeout" ]; then
    tmp_file=$(mktemp)
    awk -v lt="$lock_timeout" '
      /^[[:space:]]*listener[[:space:]]*{/ && !inblock { inblock=1; n=0; islock=0; lines[n++]=$0; next }
      inblock {
        lines[n++] = $0
        if ($0 ~ /loginctl[[:space:]]+lock-session/) islock = 1
        if ($0 ~ /^[[:space:]]*}/) {
          for (i = 0; i < n; i++) {
            line = lines[i]
            if (islock && line ~ /^[[:space:]]*timeout[[:space:]]*=/) {
              match(line, /^[[:space:]]*/); line = substr(line, 1, RLENGTH) "timeout = " lt
            }
            print line
          }
          inblock = 0
        }
        next
      }
      { print }
    ' "$hypridle" > "$tmp_file" && mv "$tmp_file" "$hypridle"
  fi

  local msg="${INFO:-[INFO]} Idle policy applied to hypridle.conf:"
  [ "$strip_dpms" -eq 1 ] && msg="$msg DPMS-off stripped (KOOL_IDLE_DPMS_OFF=0);"
  [ "$strip_nag" -eq 1 ]  && msg="$msg nag/watchdog stripped (KOOL_IDLE_NAG=0);"
  [ -n "$lock_timeout" ]  && msg="$msg lock timeout=${lock_timeout}s;"
  echo "$msg" 2>&1 | tee -a "$log" || true
}
