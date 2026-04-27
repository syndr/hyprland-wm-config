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
  if lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq nvidia; then
    echo "${INFO:-[INFO]} Nvidia GPU detected. Setting up proper env's and configs" 2>&1 | tee -a "$log" || true
    sed -i '/env = LIBVA_DRIVER_NAME,nvidia/s/^#//' "$config_root/hypr/configs/ENVariables.conf"
    sed -i '/env = __GLX_VENDOR_LIBRARY_NAME,nvidia/s/^#//' "$config_root/hypr/configs/ENVariables.conf"
    sed -i '/env = NVD_BACKEND,direct/s/^#//' "$config_root/hypr/configs/ENVariables.conf"
    sed -i '/env = GSK_RENDERER,ngl/s/^#//' "$config_root/hypr/configs/ENVariables.conf"
    sed -i 's/^\([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*\)2/\1 1/' "$config_root/hypr/configs/SystemSettings.conf"
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
