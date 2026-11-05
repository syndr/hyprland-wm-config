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
  # Word boundaries matter here: lspci calls VGA devices "VGA compatible
  # controller", and a bare `ati` alternative matches the "ati" inside
  # "compatible", which made has_amd=1 on every machine with a VGA device. It no
  # longer changes the value written below - every NVIDIA path writes 1 - but it
  # still picks the wrong log line, so the bounds stay.
  if echo "$pci_info" | grep -Eiq '\bintel\b'; then
    has_intel=1
  fi
  if echo "$pci_info" | grep -Eiq '\b(amd|ati)\b|advanced micro devices'; then
    has_amd=1
  fi
  if [ "$has_nvidia" -eq 1 ]; then
    echo "${INFO:-[INFO]} Nvidia GPU detected. Setting up proper env's and configs" 2>&1 | tee -a "$log" || true
    if [ -f "$config_root/hypr/lua/env.lua" ]; then
      sed -i 's/^--[[:space:]]*hl\.env("LIBVA_DRIVER_NAME"/hl.env("LIBVA_DRIVER_NAME"/' "$config_root/hypr/lua/env.lua"
      sed -i 's/^--[[:space:]]*hl\.env("__GLX_VENDOR_LIBRARY_NAME"/hl.env("__GLX_VENDOR_LIBRARY_NAME"/' "$config_root/hypr/lua/env.lua"
      sed -i 's/^--[[:space:]]*hl\.env("NVD_BACKEND"/hl.env("NVD_BACKEND"/' "$config_root/hypr/lua/env.lua"
      sed -i 's/^--[[:space:]]*hl\.env("GSK_RENDERER"/hl.env("GSK_RENDERER"/' "$config_root/hypr/lua/env.lua"
    fi
    if [ "$has_intel" -eq 1 ] || [ "$has_amd" -eq 1 ]; then
      echo "${INFO:-[INFO]} Hybrid GPU detected (Intel/NVIDIA or AMD/NVIDIA). Applying cursor handoff fixes." 2>&1 | tee -a "$log" || true
    fi
    # 1 = don't use hardware cursors. NVIDIA needs software cursors, hybrids
    # included: the cursor plane has to be handed between the iGPU and the dGPU,
    # and that handoff is what users see as a stuck or corrupt cursor.
    [ -f "$config_root/hypr/lua/settings.lua" ] && sed -i -E 's/^([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*)[0-9]+/\1 1/' "$config_root/hypr/lua/settings.lua"
  fi
}

# VM tweaks: enable software renderer envs and virtual monitor defaults.
detect_vm_adjust() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  if hostnamectl | grep -q 'Chassis: vm'; then
    echo "${INFO:-[INFO]} System is running in a virtual machine. Setting up proper env's and configs" 2>&1 | tee -a "$log" || true
    [ -f "$config_root/hypr/lua/env.lua" ] && sed -i 's/^--[[:space:]]*hl\.env("WLR_RENDERER_ALLOW_SOFTWARE"/hl.env("WLR_RENDERER_ALLOW_SOFTWARE"/' "$config_root/hypr/lua/env.lua"
    # Software cursors, like the NVIDIA path: virtual GPUs (virtio, VMware,
    # VirtualBox) mis-render hardware cursors, so enable no_hardware_cursors.
    # Runs after detect_nvidia_adjust, so a passed-through NVIDIA GPU in a VM
    # ends up enabled here too.
    [ -f "$config_root/hypr/lua/settings.lua" ] && sed -i -E 's/^([[:space:]]*no_hardware_cursors[[:space:]]*=[[:space:]]*)[0-9]+/\1 1/' "$config_root/hypr/lua/settings.lua"
  fi
}

# NixOS tweaks: log detection; polkit handling is delegated inside Polkit.sh
detect_nixos_adjust() {
  local log="$1"
  if hostnamectl | grep -q 'Operating System: NixOS'; then
    echo "${INFO:-[INFO]} NixOS Distro Detected." 2>&1 | tee -a "$log" || true
  fi
}
# Qt Quick Controls style safety: enable Hyprland style only when module exists.
adjust_qt_quick_controls_style() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  local source_hypr_dir="$config_root/hypr"
  local target_hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local style="Basic"
  local qt_style_override="Fusion"
  local has_kvantum_qml=0
  local set_env_lua_vars
  local _restore_nullglob=0

  # The Qt QML probe patterns below are all optional paths, so an unmatched
  # glob must expand to nothing instead of aborting the script. zsh aborts by
  # default (`nomatch`); bash can be configured to as well (`failglob`).
  if [ -n "${ZSH_VERSION:-}" ]; then
    setopt local_options null_glob 2>/dev/null || true
  elif [ -n "${BASH_VERSION:-}" ] && ! shopt -q nullglob 2>/dev/null; then
    shopt -s nullglob 2>/dev/null || true
    _restore_nullglob=1
  fi

  set_env_lua_vars() {
    local file="$1"
    [ -f "$file" ] || return 0

    if grep -q '^hl\.env("QT_QUICK_CONTROLS_STYLE",' "$file"; then
      sed -i -E "s|^hl\\.env\\(\"QT_QUICK_CONTROLS_STYLE\", \".*\"\\)$|hl.env(\"QT_QUICK_CONTROLS_STYLE\", \"${style}\")|" "$file"
    else
      printf '\nhl.env("QT_QUICK_CONTROLS_STYLE", "%s")\n' "$style" >>"$file"
    fi

    if grep -q '^hl\.env("QT_STYLE_OVERRIDE",' "$file"; then
      sed -i -E "s|^hl\\.env\\(\"QT_STYLE_OVERRIDE\", \".*\"\\)$|hl.env(\"QT_STYLE_OVERRIDE\", \"${qt_style_override}\")|" "$file"
    else
      printf 'hl.env("QT_STYLE_OVERRIDE", "%s")\n' "$qt_style_override" >>"$file"
    fi
  }

  local has_hyprland_style=0
  for d in \
    /usr/lib*/qt*/qml \
    /usr/lib*/*-linux-gnu/qt*/qml \
    /usr/lib*/qml \
    /usr/share/qt*/qml \
    /usr/share/qml; do
    [ -d "$d" ] || continue
    if [ -d "$d/org/hyprland/style" ]; then
      has_hyprland_style=1
      break
    fi
  done
  if [ "$has_hyprland_style" -eq 1 ]; then
    style="org.hyprland.style"
  elif command -v dpkg >/dev/null 2>&1 && dpkg -s qml6-module-org-hyprland-style >/dev/null 2>&1; then
    style="org.hyprland.style"
  fi

  for d in \
    /usr/lib*/qt*/qml \
    /usr/lib*/*-linux-gnu/qt*/qml \
    /usr/lib*/qml \
    /usr/share/qt*/qml \
    /usr/share/qml; do
    [ -d "$d" ] || continue
    if [ -d "$d/kvantum" ] || [ -d "$d/org/kde/kvantum" ]; then
      has_kvantum_qml=1
      qt_style_override="kvantum"
      break
    fi
  done
  # Fork: Kvantum is a Qt *widget* style plugin (libkvantum.so under
  # qt5/qt6 plugins/styles), not only a QML module; detect the plugin too.
  if [ "$has_kvantum_qml" -eq 0 ] && find /usr/lib /usr/lib64 -type f -path '*/plugins/styles/libkvantum.so' -print -quit 2>/dev/null | grep -q .; then
    has_kvantum_qml=1
    qt_style_override="kvantum"
  fi

  set_env_lua_vars "$source_hypr_dir/lua/env.lua"
  set_env_lua_vars "$source_hypr_dir/configs/system_env.lua"

  set_env_lua_vars "$target_hypr_dir/lua/env.lua"
  set_env_lua_vars "$target_hypr_dir/configs/system_env.lua"

  if [ "$style" = "org.hyprland.style" ]; then
    echo "${INFO:-[INFO]} hyprland Qt style module detected. Using QT_QUICK_CONTROLS_STYLE=$style" 2>&1 | tee -a "$log" || true
  else
    echo "${WARN:-[WARN]} hyprland Qt style module not found. Using QT_QUICK_CONTROLS_STYLE=Basic to avoid Qt app crashes." 2>&1 | tee -a "$log" || true
  fi
  if [ "$has_kvantum_qml" -eq 1 ]; then
    echo "${INFO:-[INFO]} Kvantum QML module detected. Using QT_STYLE_OVERRIDE=kvantum" 2>&1 | tee -a "$log" || true
  else
    echo "${WARN:-[WARN]} Kvantum QML module not found. Using QT_STYLE_OVERRIDE=Fusion as fallback." 2>&1 | tee -a "$log" || true
  fi

  if [ "$_restore_nullglob" -eq 1 ]; then
    shopt -u nullglob 2>/dev/null || true
  fi
}

# Ensure ~/.zprofile (zsh) and ~/.profile (bash) source /etc/profile.
# On Debian with zsh, /etc/profile sets up flatpak XDG data dirs so flatpak
# apps appear in the rofi menu. Without this entry the rofi app menu is often
# missing all flatpak-installed applications.
ensure_shell_profile_sources_etc_profile() {
  local log="${1:-/dev/null}"
  local user_shell
  local entry_marker='source /etc/profile'
  local entry
  entry="$(printf 'if [ -f /etc/profile ]; then\n    source /etc/profile\nfi')"

  user_shell="$(basename "${SHELL:-bash}")"

  _add_etc_profile_entry() {
    local profile_file="$1"
    local plog="$2"
    local profile_dir
    profile_dir="$(dirname "$profile_file")"

    # NixOS/Home Manager can manage shell profiles as read-only symlinks.
    # Skip safely so copy.sh continues instead of exiting on redirection errors.
    if [ -e "$profile_file" ] && [ ! -w "$profile_file" ]; then
      if [ -L "$profile_file" ]; then
        echo "${WARN:-[WARN]} $profile_file is a read-only symlink (likely Home Manager managed). Skipping /etc/profile entry update." 2>&1 | tee -a "$plog"
      else
        echo "${WARN:-[WARN]} $profile_file is not writable. Skipping /etc/profile entry update." 2>&1 | tee -a "$plog"
      fi
      return 0
    fi

    if [ ! -e "$profile_file" ] && [ ! -w "$profile_dir" ]; then
      echo "${WARN:-[WARN]} Cannot create $profile_file (directory not writable). Skipping /etc/profile entry update." 2>&1 | tee -a "$plog"
      return 0
    fi
    if [ ! -f "$profile_file" ]; then
      echo "${NOTE:-[NOTE]} Creating $profile_file and adding /etc/profile source entry (fixes flatpak in rofi on Debian)" 2>&1 | tee -a "$plog"
      printf '\n# Source /etc/profile to ensure system paths (e.g. flatpak) are available\n%s\n' "$entry" > "$profile_file" || {
        echo "${WARN:-[WARN]} Failed to write $profile_file. Skipping and continuing." 2>&1 | tee -a "$plog"
        return 0
      }
    elif ! grep -qF "$entry_marker" "$profile_file"; then
      echo "${NOTE:-[NOTE]} Adding /etc/profile source entry to $profile_file (fixes flatpak in rofi on Debian)" 2>&1 | tee -a "$plog"
      printf '\n# Source /etc/profile to ensure system paths (e.g. flatpak) are available\n%s\n' "$entry" >> "$profile_file" || {
        echo "${WARN:-[WARN]} Failed to append to $profile_file. Skipping and continuing." 2>&1 | tee -a "$plog"
        return 0
      }
    else
      echo "${INFO:-[INFO]} $profile_file already sources /etc/profile; no changes needed." 2>&1 | tee -a "$plog"
    fi
  }

  # zsh: check ~/.zprofile when the user's shell is zsh
  if [ "$user_shell" = "zsh" ]; then
    echo "${INFO:-[INFO]} zsh detected - checking ~/.zprofile for /etc/profile source entry..." 2>&1 | tee -a "$log"
    _add_etc_profile_entry "$HOME/.zprofile" "$log"
  fi

  # bash: check ~/.profile when bash is the default shell and the file already exists
  if [ "$user_shell" = "bash" ] && [ -f "$HOME/.profile" ]; then
    echo "${INFO:-[INFO]} bash detected - checking ~/.profile for /etc/profile source entry..." 2>&1 | tee -a "$log"
    _add_etc_profile_entry "$HOME/.profile" "$log"
  fi
}

# Decide waybar config/style based on chassis type. Echoes chosen config path.
detect_waybar_config() {
  if hostnamectl | grep -q 'Chassis: desktop'; then
    echo "desktop"
  else
    echo "laptop"
  fi
}

# Resolve chassis type, preferring a saved explicit choice over hostnamectl.
resolve_chassis_type() {
  local log="$1"
  local chassis_type_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/.chassis_type"
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

# Idle policy, dispatched on KOOL_IDLE_MANAGED in the preserved, user-owned
# UserConfigs/IdleSettings.conf (default 1):
#
#   1 -> hypridle.conf is a generated artifact. Hand off to the shipped
#        GenerateHypridle.sh, which renders every listener from the named
#        relative knobs in that file (see adjust_idle_policy below).
#   0 -> the user owns hypridle.conf. Fall back to the legacy in-place
#        rewrite, which strips listener blocks by content.
#
# The legacy path below documents the three knobs it understands.
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
adjust_idle_dpms_policy_legacy() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  local hypridle="$config_root/hypr/hypridle.conf"
  [ -f "$hypridle" ] || return 0

  # Caller passes the resolved prefs file (preserved user copy, else the
  # staged one). Falling back to the $HOME path keeps direct callers working.
  local pref_file="${2:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/IdleSettings.conf}"
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
      if ($0 ~ /dpms[[:space:]]+off/ || $0 ~ /ScreenPower\.sh[[:space:]]+off/) hasoff = 1
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

# Entry point called by copy.sh. Renders the staged hypridle.conf from the
# user's IdleSettings.conf, or falls back to the legacy rewrite when the user
# has taken the file back into their own hands.
#
# The generator is invoked out of the staging tree (WORK_CONFIG_DIR) so the
# repo checkout is never dirtied, and is pointed at the *preserved* user
# settings file rather than the one we just staged -- the user's knobs win
# over the release's defaults. On a fresh install there is no preserved file
# yet, so the staged copy is used and the shipped defaults apply.
adjust_idle_dpms_policy() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  local hypridle="$config_root/hypr/hypridle.conf"
  [ -f "$hypridle" ] || return 0

  local user_prefs="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/IdleSettings.conf"
  local staged_prefs="$config_root/hypr/UserConfigs/IdleSettings.conf"
  local prefs="$user_prefs"
  [ -f "$prefs" ] || prefs="$staged_prefs"

  local managed
  managed=$(read_idle_knob "$prefs" KOOL_IDLE_MANAGED 1)
  case "$managed" in
    0|false|no|off|FALSE|No|Off|NO|OFF)
      echo "${INFO:-[INFO]} KOOL_IDLE_MANAGED=0: leaving hypridle.conf under your control." 2>&1 | tee -a "$log" || true
      adjust_idle_dpms_policy_legacy "$log" "$prefs"
      return 0
      ;;
  esac

  local generator="$config_root/hypr/scripts/GenerateHypridle.sh"
  if [ ! -f "$generator" ]; then
    echo "${WARN:-[WARN]} GenerateHypridle.sh missing from the release; falling back to the legacy idle rewrite." 2>&1 | tee -a "$log" || true
    adjust_idle_dpms_policy_legacy "$log" "$prefs"
    return 0
  fi

  if IDLE_SCRIPTS_DIR="$config_root/hypr/scripts" IDLE_SETTINGS_FILE="$prefs" \
      bash "$generator" --output "$hypridle"; then
    local profile
    profile=$(grep -m1 '^# Active profile:' "$hypridle" 2>/dev/null | sed 's/^# Active profile: //' || true)
    echo "${OK:-[OK]} - hypridle.conf generated from IdleSettings.conf (${profile:-unknown} profile)." 2>&1 | tee -a "$log" || true
  else
    echo "${ERROR:-[ERROR]} GenerateHypridle.sh failed; falling back to the legacy idle rewrite." 2>&1 | tee -a "$log" || true
    adjust_idle_dpms_policy_legacy "$log" "$prefs"
  fi
}
