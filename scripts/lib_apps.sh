#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# App enablement and editor selection helpers.

enable_asusctl() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  if command -v asusctl >/dev/null 2>&1; then
    local OVERLAY_SA="$config_root/hypr/configs/Startup_Apps.conf"
    mkdir -p "$(dirname "$OVERLAY_SA")"
    touch "$OVERLAY_SA"
    grep -qx 'exec-once = rog-control-center' "$OVERLAY_SA" || echo 'exec-once = rog-control-center' >>"$OVERLAY_SA"
  fi
}

enable_blueman() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  if command -v blueman-applet >/dev/null 2>&1; then
    local OVERLAY_SA="$config_root/hypr/configs/Startup_Apps.conf"
    mkdir -p "$(dirname "$OVERLAY_SA")"
    touch "$OVERLAY_SA"
    grep -qx 'exec-once = blueman-applet' "$OVERLAY_SA" || echo 'exec-once = blueman-applet' >>"$OVERLAY_SA"
  fi
}

enable_ags() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  if command -v ags >/dev/null 2>&1; then
    echo "${INFO:-[INFO]} AGS detected - enabling in startup and refresh scripts" 2>&1 | tee -a "$log"
    local OVERLAY_SA="$config_root/hypr/configs/Startup_Apps.conf"
    mkdir -p "$(dirname "$OVERLAY_SA")"
    touch "$OVERLAY_SA"
    grep -qx 'exec-once = ags' "$OVERLAY_SA" || echo 'exec-once = ags' >>"$OVERLAY_SA"
    sed -i '/#ags -q && ags &/s/^#//' "$config_root/hypr/scripts/RefreshNoWaybar.sh"
    sed -i '/#ags -q && ags &/s/^#//' "$config_root/hypr/scripts/Refresh.sh"
  fi
}

enable_quickshell() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  if command -v qs >/dev/null 2>&1; then
    echo "${INFO:-[INFO]} Quickshell detected - enabling in startup and refresh scripts" 2>&1 | tee -a "$log"
    local OVERLAY_SA="$config_root/hypr/configs/Startup_Apps.conf"
    mkdir -p "$(dirname "$OVERLAY_SA")"
    touch "$OVERLAY_SA"
    grep -qx 'exec-once = qs' "$OVERLAY_SA" || echo 'exec-once = qs' >>"$OVERLAY_SA"
    sed -i '/#pkill qs && qs &/s/^#//' "$config_root/hypr/scripts/RefreshNoWaybar.sh"
    sed -i '/#pkill qs && qs &/s/^#//' "$config_root/hypr/scripts/Refresh.sh"
  fi
}

ensure_keybinds_init() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  local OVERLAY_SA="$config_root/hypr/configs/Startup_Apps.conf"
  mkdir -p "$(dirname "$OVERLAY_SA")"
  if ! grep -qx 'exec-once = \$scriptsDir/KeybindsLayoutInit.sh' "$OVERLAY_SA"; then
    echo 'exec-once = $scriptsDir/KeybindsLayoutInit.sh' >>"$OVERLAY_SA"
    echo "${INFO:-[INFO]} Added KeybindsLayoutInit.sh to user Startup_Apps overlay" 2>&1 | tee -a "$log"
  fi
}

install_terminal_configs() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"

  # Ghostty
  local GHOSTTY_SRC="$config_root/ghostty/config"
  local GHOSTTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
  local GHOSTTY_DEST="$GHOSTTY_DIR/config"
  if [ -f "$GHOSTTY_SRC" ]; then
    if [ -d "$GHOSTTY_DIR" ]; then
      BACKUP_DIR=$(get_backup_dirname)
      local GHOSTTY_BACKUP="$GHOSTTY_DIR-backup-$BACKUP_DIR"
      if [ ! -d "$GHOSTTY_BACKUP" ]; then
        cp -a "$GHOSTTY_DIR" "$GHOSTTY_BACKUP" 2>&1 | tee -a "$log"
        echo "${NOTE:-[NOTE]} - Backed up Ghostty config to $GHOSTTY_BACKUP." 2>&1 | tee -a "$log"
      fi
    fi
    mkdir -p "$GHOSTTY_DIR"
    install -m 0644 "$GHOSTTY_SRC" "$GHOSTTY_DEST" 2>&1 | tee -a "$log"
    if [ -f "$GHOSTTY_DIR/wallust.conf" ]; then
      sed -i -E 's/^(\\s*palette\\s*=\\s*)([0-9]{1,2}):/\\1\\2=/' "$GHOSTTY_DIR/wallust.conf" 2>&1 | tee -a "$log" || true
    fi
  else
    echo "${ERROR:-[ERROR]} - $GHOSTTY_SRC not found; skipping Ghostty config install." 2>&1 | tee -a "$log"
  fi

  # WezTerm
  local WEZTERM_SRC="$config_root/wezterm/wezterm.lua"
  local WEZTERM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wezterm"
  local WEZTERM_DEST="$WEZTERM_DIR/wezterm.lua"
  if [ -f "$WEZTERM_SRC" ]; then
    mkdir -p "$WEZTERM_DIR"
    install -m 0644 "$WEZTERM_SRC" "$WEZTERM_DEST" 2>&1 | tee -a "$log"
  else
    echo "${ERROR:-[ERROR]} - $WEZTERM_SRC not found; skipping WezTerm config install." 2>&1 | tee -a "$log"
  fi
}

choose_default_editor() {
  local log="$1"
  if [ "${EXPRESS_MODE:-0}" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} Express mode: preserving existing default editor." 2>&1 | tee -a "$log"
    return
  fi
  local editor_set=0
  local config_root="${WORK_CONFIG_DIR:-config}"
  local defaults_file="$config_root/hypr/UserConfigs/01-UserDefaults.conf"
  update_editor() {
    local editor=$1
    sed -i "s/#env = EDITOR,.*/env = EDITOR,$editor #default editor/" "$defaults_file"
    echo "${OK:-[OK]} Default editor set to ${MAGENTA:-}$editor${RESET:-}." 2>&1 | tee -a "$log"
  }
  # Set (or, with empty value, comment out) an `env = VAR,value note` line in the
  # defaults file; appends the line if absent. Used for the optional VISUAL editor.
  set_env_default() {
    local var_name="$1" value="$2" note="$3" tmp_file
    tmp_file=$(mktemp)
    awk -v var_name="$var_name" -v value="$value" -v note="$note" '
      BEGIN { updated = 0 }
      {
        if ($0 ~ "^[[:space:]#]*env[[:space:]]*=[[:space:]]*" var_name ",") {
          if (value != "") { print "env = " var_name "," value note } else { print "#env = " var_name "," note }
          updated = 1
        } else { print $0 }
      }
      END {
        if (!updated) {
          if (value != "") { print "env = " var_name "," value note } else { print "#env = " var_name "," note }
        }
      }
    ' "$defaults_file" > "$tmp_file" && mv "$tmp_file" "$defaults_file"
  }
  if command -v nvim &>/dev/null; then
    printf "${INFO:-[INFO]} ${MAGENTA:-}neovim${RESET:-} is detected as installed\n"
    if ! read -r -p "${CAT:-[ACTION]} Do you want to make ${MAGENTA:-}neovim${RESET:-} the default editor? (y/N): " EDITOR_CHOICE </dev/tty; then
      :
    elif [[ "$EDITOR_CHOICE" == "y" || "$EDITOR_CHOICE" == "Y" ]]; then
      update_editor "nvim"
      editor_set=1
    fi
  fi
  printf "\n"
  if [[ "$editor_set" -eq 0 ]] && command -v vim &>/dev/null; then
    printf "${INFO:-[INFO]} ${MAGENTA:-}vim${RESET:-} is detected as installed\n"
    if read -r -p "${CAT:-[ACTION]} Do you want to make ${MAGENTA:-}vim${RESET:-} the default editor? (y/N): " EDITOR_CHOICE </dev/tty; then
      if [[ "$EDITOR_CHOICE" == "y" || "$EDITOR_CHOICE" == "Y" ]]; then
        update_editor "vim"
        editor_set=1
      fi
    fi
  fi

  local visual_choice=""
  local visual_value=""
  local prompt_visual_input=0
  if [[ -n "${VISUAL:-}" ]]; then
    printf "${INFO:-[INFO]} VISUAL is currently set to ${MAGENTA:-}%s${RESET:-}\\n" "${VISUAL}"
    if read -r -p "${CAT:-[ACTION]} Use this as Quick Settings VISUAL editor? (Y/n): " visual_choice </dev/tty; then
      if [[ "$visual_choice" != [Nn]* ]]; then
        visual_value="${VISUAL}"
      else
        prompt_visual_input=1
      fi
    fi
  else
    prompt_visual_input=1
  fi

  if [[ "$prompt_visual_input" -eq 1 ]]; then
    printf "${INFO:-[INFO]} Optional GUI editor for Quick Settings (examples: neovide, geany, code, codium).\\n"
    if read -r -p "${CAT:-[ACTION]} Enter VISUAL editor command or leave empty to skip: " visual_choice </dev/tty; then
      visual_value="$visual_choice"
    fi
  fi

  if [[ -n "$visual_value" ]]; then
    set_env_default "VISUAL" "$visual_value" " #default visual editor for quick settings (optional)"
    echo "${OK:-[OK]} VISUAL editor set to ${MAGENTA:-}$visual_value${RESET:-}." 2>&1 | tee -a "$log"
  else
    set_env_default "VISUAL" "" " #default visual editor for quick settings (optional)"
    echo "${NOTE:-[NOTE]} VISUAL editor not set (optional)." 2>&1 | tee -a "$log"
  fi
}

# Install waybar-weather on non-NixOS: prefer Arch AUR, otherwise copy prebuilt asset to /usr/bin
install_waybar_weather_binary() {
  local log="$1"
  local APP_NAME="waybar-weather"
  local ASSET="${SCRIPT_DIR:-.}/assets/${APP_NAME}.gz"

  # Helper: log wrappers may not be defined here; reuse INFO/WARN/ERROR if available
  _log() { echo "[${APP_NAME}] $*" 2>&1 | tee -a "$log"; }
  _warn() { echo "[${APP_NAME}] WARN: $*" 1>&2 | tee -a "$log"; }
  _err() { echo "[${APP_NAME}] ERROR: $*" 1>&2 | tee -a "$log"; }

  # NixOS handled by a separate helper
  if grep -qi '^ID=nixos' /etc/os-release 2>/dev/null; then
    _warn "NixOS detected. Use install_waybar_weather_nixos instead."
    return 0
  fi

  # sudo is optional (only used below for the Arch/AUR system-path cleanup).
  local SUDO=""
  if [[ $EUID -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  fi

  if grep -qi '^ID=arch' /etc/os-release 2>/dev/null; then
    if command -v pacman >/dev/null 2>&1 && pacman -Qi waybar-weather >/dev/null 2>&1; then
      _log "waybar-weather already installed via pacman."
      return 0
    fi

    # If no package is installed but a static binary exists, remove it before AUR install
    if [ -x /usr/bin/waybar-weather ] || [ -x /usr/local/bin/waybar-weather ]; then
      _log "Removing waybar-weather static binary"
      ${SUDO} rm -f /usr/bin/waybar-weather /usr/local/bin/waybar-weather || _warn "Failed to remove existing waybar-weather binary."
    fi

    if command -v yay >/dev/null 2>&1; then
      _log "Attempting to install AUR package 'waybar-weather' via yay"
      if yay -S --noconfirm waybar-weather; then
        _log "AUR install succeeded."
        return 0
      else
        _warn "AUR install failed; will fall back to bundled asset."
      fi
    else
      _warn "yay not found on Arch; falling back to bundled asset."
    fi
  fi

  # Asset path validation
  if [[ ! -f "$ASSET" ]]; then
    _err "Asset not found: $ASSET"
    return 1
  fi
  if ! command -v gzip >/dev/null 2>&1; then
    _err "Missing required command: gzip"
    return 1
  fi


  # Pick an install dir that does not require writing to a read-only /usr.
  # Prefer a user-local bin: no sudo, works on rpm-ostree / immutable distros.
  # The Waybar module invokes "waybar-weather" by name, so any PATH dir works.
  local INSTALL_DIR install_sudo=""
  if [ -w /usr/bin ]; then
    INSTALL_DIR="/usr/bin"
  elif [ -n "$SUDO" ] && sudo -n test -w /usr/bin 2>/dev/null; then
    INSTALL_DIR="/usr/bin"
    install_sudo="sudo -n"
  else
    INSTALL_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
    mkdir -p "$INSTALL_DIR"
    case ":$PATH:" in
    *":$INSTALL_DIR:"*) : ;;
    *) _warn "${INSTALL_DIR} is not on PATH; add it so Waybar can find ${APP_NAME}." ;;
    esac
  fi
  local INSTALL_PATH="${INSTALL_DIR}/${APP_NAME}"

  _log "Installing prebuilt binary to ${INSTALL_PATH} from ${ASSET}"
  if ${install_sudo} sh -c "tmp=\$(mktemp '${INSTALL_PATH}.XXXXXX') && gzip -dc '$ASSET' > \"\$tmp\" && chmod 0755 \"\$tmp\" && mv -f \"\$tmp\" '${INSTALL_PATH}'"; then
    if "${INSTALL_PATH}" -h >/dev/null 2>&1; then
      _log "Installed ${APP_NAME} successfully to ${INSTALL_DIR}."
    else
      _warn "${APP_NAME} installed, but a basic self-check did not run."
    fi
  else
    _err "Failed to install ${APP_NAME} to ${INSTALL_PATH}"
    return 1
  fi
}

# Install waybar-weather on NixOS using Go from the system (no version checks)
install_waybar_weather_nixos() {
  local log="$1"
  local APP_NAME="waybar-weather"
  local DEST="$HOME/.local/bin/${APP_NAME}"

  _log() { echo "[${APP_NAME}] $*" 2>&1 | tee -a "$log"; }
  _warn() { echo "[${APP_NAME}] WARN: $*" 1>&2 | tee -a "$log"; }
  _err() { echo "[${APP_NAME}] ERROR: $*" 1>&2 | tee -a "$log"; }

  if ! grep -qi '^ID=nixos' /etc/os-release 2>/dev/null; then
    _warn "Not NixOS; skipping NixOS-specific build."
    return 0
  fi

  if ! command -v go >/dev/null 2>&1; then
    _err "Go toolchain not found in PATH. Ensure NixOS-Hyprland provides go, then re-run."
    return 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    _err "git not found; install git and retry."
    return 1
  fi

  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "${tmp}"' RETURN

  _log "Cloning waybar-weather source"
  if ! git clone --depth 1 https://github.com/wneessen/waybar-weather.git "${tmp}/src" >/dev/null 2>&1; then
    _err "git clone failed"
    return 1
  fi

  if ! (
    cd "${tmp}/src" || { _err "cd failed"; exit 1; }
    _log "Fetching modules"
    go mod download >/dev/null 2>&1 || _warn "go mod download returned non-zero; continuing"
    _log "Building ${APP_NAME}"
    CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o "${APP_NAME}" ./cmd/${APP_NAME}
  ); then
    _err "go build failed"
    return 1
  fi

  mkdir -p "$HOME/.local/bin"
  install -m 0755 "${APP_NAME}" "${DEST}" || { _err "install to ${DEST} failed"; return 1; }

  if printf '%s' "$PATH" | grep -q "$HOME/.local/bin"; then
    :
  else
    _warn "~/.local/bin is not in PATH; add it so Waybar can find ${APP_NAME}."
  fi

  if "${DEST}" -h >/dev/null 2>&1; then
    _log "Installed ${APP_NAME} to ${DEST}"
  else
    _warn "${APP_NAME} installed, but a basic self-check did not run."
  fi
}

# Wrapper: choose NixOS builder or non-NixOS installer automatically
install_waybar_weather() {
  local log="$1"
  if grep -qi '^ID=nixos' /etc/os-release 2>/dev/null; then
    install_waybar_weather_nixos "$log"
  else
    install_waybar_weather_binary "$log"
  fi
}

# Deployed config only reaches the running session when something reloads it.
# copy.sh writes files; it never touches the live compositor, so until you log
# out the deploy and the session disagree: new keybinds are absent, window
# rules and waybar modules are stale, and a regenerated hypridle.conf is
# ignored by the hypridle already running. That reads as "the upgrade didn't
# work" when in fact it landed correctly.
#
# Reloading in place is cheap and safe. hyprctl reload re-reads the config
# without disturbing windows (a bad config is reported via configerrors and
# the session keeps running), Refresh.sh reloads waybar/swaync/rofi exactly as
# the desktop's own refresh keybind does, and Hypridle.sh reload is a no-op
# when hypridle is not running, so it cannot undo the waybar idle-inhibit
# toggle.
#
# Express mode does this automatically, matching its "no optional prompts"
# contract; interactive runs ask. A logout is still worth doing for anything a
# reload cannot pick up (env vars, exec-once entries), which the closing
# message already says.
offer_session_reload() {
  local log="$1"
  local scripts_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"

  # Only meaningful inside a live Hyprland session -- an install run from a
  # TTY before first login has nothing to reload.
  if ! command -v hyprctl >/dev/null 2>&1 || ! hyprctl monitors >/dev/null 2>&1; then
    echo "${NOTE:-[NOTE]} No running Hyprland session detected; skipping reload." 2>&1 | tee -a "$log"
    return 0
  fi

  if [ "${EXPRESS_MODE:-0}" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} Express mode: reloading the running session so the new config takes effect." 2>&1 | tee -a "$log"
  else
    local reload_choice=""
    # Check the terminal exists before reading from it: a bare redirect from a
    # missing /dev/tty makes the shell print its own error before we can
    # handle it.
    if [ ! -r /dev/tty ]; then
      echo "${NOTE:-[NOTE]} No terminal for the reload prompt; skipping. Run '${scripts_dir}/Refresh.sh' and 'hyprctl reload' when convenient." 2>&1 | tee -a "$log"
      return 0
    fi
    printf "\n%.0s" {1..1}
    if ! read -r -p "${CAT:-[ACTION]} Reload Hyprland, Waybar and hypridle now so the new config takes effect? (Y/n): " reload_choice </dev/tty; then
      echo "${NOTE:-[NOTE]} Reload prompt cancelled; skipping." 2>&1 | tee -a "$log"
      return 0
    fi
    case "$reload_choice" in
      [Nn]*)
        echo "${NOTE:-[NOTE]} Skipped. The new config applies after 'hyprctl reload' or your next login." 2>&1 | tee -a "$log"
        return 0
        ;;
    esac
  fi

  if hyprctl reload >/dev/null 2>&1; then
    echo "${OK:-[OK]} - Hyprland config reloaded." 2>&1 | tee -a "$log"
  else
    echo "${WARN:-[WARN]} - hyprctl reload failed; log out and back in to apply the new config." 2>&1 | tee -a "$log"
  fi

  local cfg_errors
  cfg_errors=$(hyprctl configerrors 2>/dev/null | grep -v '^no errors' || true)
  if [ -n "$cfg_errors" ]; then
    echo "${WARN:-[WARN]} - Hyprland reported config errors:" 2>&1 | tee -a "$log"
    printf '%s\n' "$cfg_errors" 2>&1 | tee -a "$log"
  fi

  if [ -x "$scripts_dir/Hypridle.sh" ]; then
    "$scripts_dir/Hypridle.sh" reload >/dev/null 2>&1 || true
    echo "${OK:-[OK]} - hypridle reloaded (no-op if it was not running)." 2>&1 | tee -a "$log"
  fi

  # Started by exec-once at login, so it is absent after an upgrade until the
  # next one. Its own flock makes a duplicate launch harmless.
  if [ -x "$scripts_dir/IdlePowerWatch.sh" ]; then
    setsid -f "$scripts_dir/IdlePowerWatch.sh" >/dev/null 2>&1 || true
  fi

  if [ -x "$scripts_dir/Refresh.sh" ]; then
    "$scripts_dir/Refresh.sh" >/dev/null 2>&1 || true
    echo "${OK:-[OK]} - Waybar, swaync and rofi refreshed." 2>&1 | tee -a "$log"
  fi
}
