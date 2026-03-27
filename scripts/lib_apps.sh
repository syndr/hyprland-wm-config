#!/usr/bin/env bash
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
  local GHOSTTY_SRC="$config_root/ghostty/ghostty.config"
  local GHOSTTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
  local GHOSTTY_DEST="$GHOSTTY_DIR/config"
  if [ -f "$GHOSTTY_SRC" ]; then
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
  update_editor() {
    local editor=$1
    sed -i "s/#env = EDITOR,.*/env = EDITOR,$editor #default editor/" "$config_root/hypr/UserConfigs/01-UserDefaults.conf"
    echo "${OK:-[OK]} Default editor set to ${MAGENTA:-}$editor${RESET:-}." 2>&1 | tee -a "$log"
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
}
