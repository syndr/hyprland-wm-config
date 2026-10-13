#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Copy helpers split into phases to keep copy.sh lean.

snapshot_theme_state() {
  local state_dir="$1"
  rm -rf "$state_dir"
  mkdir -p "$state_dir/conf" "$state_dir/extra"

  local theme_files=(
    "$HOME/.config/qt5ct/qt5ct.conf"
    "$HOME/.config/qt6ct/qt6ct.conf"
    "$HOME/.config/Kvantum/kvantum.kvconfig"
    "$HOME/.config/gtk-3.0/settings.ini"
    "$HOME/.config/gtk-4.0/settings.ini"
    "$HOME/.config/xsettingsd/xsettingsd.conf"
    "$HOME/.config/kdeglobals"
    "$HOME/.config/plasmarc"
  )

  for src in "${theme_files[@]}"; do
    [ -f "$src" ] || continue
    local rel="${src#$HOME/.config/}"
    mkdir -p "$state_dir/conf/$(dirname "$rel")"
    cp -p "$src" "$state_dir/conf/$rel"
  done

  # Theme payloads installed by external theme packs (e.g. Hackerer) live
  # inside directories copy_phase2 replaces wholesale. Snapshot them so
  # schemes the shipped configs don't include survive the upgrade —
  # otherwise the restored confs above point at files that no longer exist.
  local payload_dirs=(
    "$HOME/.config/qt5ct/colors"
    "$HOME/.config/qt6ct/colors"
    "$HOME/.config/Kvantum"
  )

  for src in "${payload_dirs[@]}"; do
    [ -d "$src" ] || continue
    local rel="${src#$HOME/.config/}"
    mkdir -p "$state_dir/extra/$(dirname "$rel")"
    cp -rp "$src" "$state_dir/extra/$rel"
  done
}

hackerer_theme_installed() {
  [ -f "$HOME/.config/Kvantum/Hackerer-Dark/Hackerer-Dark.kvconfig" ] \
    && [ -f "$HOME/.config/qt5ct/colors/Hackerer-Dark.colors" ] \
    && [ -f "$HOME/.config/qt6ct/colors/Hackerer-Dark.colors" ] \
    && [ -f "$HOME/.local/share/color-schemes/Hackerer.colors" ]
}

apply_hackerer_theme() {
  # The Hackerer theme now lives in its own repository and is fetched at
  # install time rather than vendored here. See https://github.com/syndr/hackerer-theme
  # $1/$2 (source_root/config_root) are kept for call-site compatibility but unused.
  local log="$3"
  local repo_url="${THEME_REPO_URL:-https://github.com/syndr/hackerer-theme}"
  local repo_ref="${THEME_REPO_REF:-main}"

  if ! command -v git >/dev/null 2>&1; then
    echo "${WARN:-[WARN]} git not found; cannot fetch the Hackerer theme from $repo_url. Skipping (current theme unchanged)." 2>&1 | tee -a "$log"
    return 1
  fi

  local tmp
  tmp="$(mktemp -d)" || {
    echo "${WARN:-[WARN]} Could not create a temp dir to fetch the Hackerer theme. Skipping." 2>&1 | tee -a "$log"
    return 1
  }

  echo "${NOTE:-[NOTE]} Fetching Hackerer theme ('$repo_ref') from $repo_url ..." 2>&1 | tee -a "$log"
  if git clone --depth 1 --branch "$repo_ref" "$repo_url" "$tmp/hackerer-theme" >>"$log" 2>&1; then
    if [ -f "$tmp/hackerer-theme/install.sh" ]; then
      bash "$tmp/hackerer-theme/install.sh" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - Hackerer theme installed from $repo_url." 2>&1 | tee -a "$log"
      rm -rf "$tmp"
      return 0
    fi
    echo "${WARN:-[WARN]} Fetched theme repo has no install.sh. Skipping." 2>&1 | tee -a "$log"
  else
    echo "${WARN:-[WARN]} Could not fetch the Hackerer theme (check network or ref '$repo_ref'). Skipping; current theme unchanged." 2>&1 | tee -a "$log"
  fi
  rm -rf "$tmp"
  return 1
}

prompt_apply_hackerer_theme() {
  local source_root="$1"
  local config_root="$2"
  local log="$3"
  local context="${4:-install}"

  if [ "${EXPRESS_MODE:-0}" -eq 1 ]; then
    if ! hackerer_theme_installed; then
      echo "${NOTE:-[NOTE]} Express mode: leaving Hackerer theme uninstalled and preserving current visual state." 2>&1 | tee -a "$log"
    fi
    return 1
  fi

  while true; do
    if [ "$context" = "update" ]; then
      echo -n "${CAT:-[ACTION]} Install/apply the ${YELLOW:-}Hackerer${RESET:-} Qt/KDE theme after update? (y/n): "
    else
      echo -n "${CAT:-[ACTION]} Install/apply the ${YELLOW:-}Hackerer${RESET:-} Qt/KDE theme now? (y/n): "
    fi
    read apply_theme_choice
    case "$apply_theme_choice" in
    [Yy]*)
      apply_hackerer_theme "$source_root" "$config_root" "$log"
      return 0
      ;;
    [Nn]*)
      echo "${NOTE:-[NOTE]} Leaving current GTK/Qt/KDE theme state unchanged." 2>&1 | tee -a "$log"
      return 1
      ;;
    *)
      echo "${WARN:-[WARN]} - Invalid choice. Please enter Y or N." 2>&1 | tee -a "$log"
      ;;
    esac
  done
}

restore_theme_state() {
  local state_dir="$1"
  local log="$2"
  local restored=0
  [ -d "$state_dir" ] || return 0

  # Exact restore: these files decide which theme is active.
  while IFS= read -r -d '' saved; do
    local rel="${saved#$state_dir/conf/}"
    local dst="$HOME/.config/$rel"
    mkdir -p "$(dirname "$dst")"
    cp -p "$saved" "$dst" 2>&1 | tee -a "$log"
    restored=1
  done < <(find "$state_dir/conf" -type f -print0 2>/dev/null)

  # Fill-in restore: put back theme payloads (color schemes, Kvantum theme
  # dirs) the new release doesn't ship, without overwriting files it does.
  while IFS= read -r -d '' saved; do
    local rel="${saved#$state_dir/extra/}"
    local dst="$HOME/.config/$rel"
    [ -e "$dst" ] && continue
    mkdir -p "$(dirname "$dst")"
    cp -p "$saved" "$dst" 2>&1 | tee -a "$log"
    restored=1
  done < <(find "$state_dir/extra" -type f -print0 2>/dev/null)

  if [ "$restored" -eq 1 ]; then
    echo "${INFO:-[INFO]} Restored local visual theme state from pre-upgrade snapshot." 2>&1 | tee -a "$log"
  fi
}

finalize_upgrade_bootstrap_state() {
  local log="$1"
  local upgrade_mode="$2"
  local hypr_dir="$HOME/.config/hypr"
  local startup_marker="$hypr_dir/.initial_startup_done"
  local preserve_marker="$hypr_dir/.preserve_theme_state"

  [ "$upgrade_mode" -eq 1 ] || return 0

  mkdir -p "$hypr_dir"
  : >"$startup_marker"
  rm -f "$preserve_marker"
  echo "${INFO:-[INFO]} Preserved initial boot completion marker for upgrade workflow." 2>&1 | tee -a "$log"
}

copy_phase1() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  local dirs="fastfetch kitty rofi swaync"
  for DIR2 in $dirs; do
    local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/$DIR2"
    if [ -d "$DIRPATH" ]; then
      if [ "${EXPRESS_MODE:-0}" -eq 1 ]; then
        # Preserve every existing file, but still land files that are new in
        # this release (e.g. a rofi theme added for a new picker) — otherwise
        # scripts shipped by the same upgrade reference configs that never
        # arrive on express-upgraded hosts.
        echo -e "${NOTE:-[NOTE]} Express mode: preserving existing ${YELLOW:-}$DIR2${RESET:-} config (adding new files only)." 2>&1 | tee -a "$log"
        cp -rn "$config_root/$DIR2/." "$DIRPATH/" >>"$log" 2>&1 || true
        continue
      fi
      while true; do
        printf "\n${INFO:-[INFO]} Found ${YELLOW:-}$DIR2${RESET:-} config found in ${XDG_CONFIG_HOME:-$HOME/.config}/\n"
        echo -n "${CAT:-[ACTION]} Do you want to replace ${YELLOW:-}$DIR2${RESET:-} config? (y/n): "
        read DIR1_CHOICE
        case "$DIR1_CHOICE" in
        [Yy]*)
          BACKUP_DIR=$(get_backup_dirname)
          mv "$DIRPATH" "$DIRPATH-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
          echo -e "${NOTE:-[NOTE]} - Backed up $DIR2 to $DIRPATH-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
          cp -r "$config_root/$DIR2" "$HOME/.config/$DIR2" 2>&1 | tee -a "$log"
          echo -e "${OK:-[OK]} - Replaced $DIR2 with new configuration." 2>&1 | tee -a "$log"
          if [ "$DIR2" = "rofi" ]; then
            if [ -d "$DIRPATH-backup-$BACKUP_DIR/themes" ]; then
              for file in "$DIRPATH-backup-$BACKUP_DIR/themes"/*; do
                [ -e "$file" ] || continue
                cp -n "$file" "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/themes/" >>"$log" 2>&1 || true
              done || true
            fi
            if [ -f "$DIRPATH-backup-$BACKUP_DIR/0-shared-fonts.rasi" ]; then
              cp "$DIRPATH-backup-$BACKUP_DIR/0-shared-fonts.rasi" "${XDG_CONFIG_HOME:-$HOME/.config}/rofi/0-shared-fonts.rasi" >>"$log" 2>&1
            fi
          fi
          break
          ;;
        [Nn]*)
          echo -e "${NOTE:-[NOTE]} - Skipping ${YELLOW:-}$DIR2${RESET:-}" 2>&1 | tee -a "$log"
          break
          ;;
        *) echo -e "${WARN:-[WARN]} - Invalid choice. Please enter Y or N." ;;
        esac
      done
    else
      cp -r "$config_root/$DIR2" "$HOME/.config/$DIR2" 2>&1 | tee -a "$log"
      echo -e "${OK:-[OK]} - Copy completed for ${YELLOW:-}$DIR2${RESET:-}" 2>&1 | tee -a "$log"
    fi
  done
}

copy_waybar() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  local DIRW="waybar"
  local DIRPATHw="${XDG_CONFIG_HOME:-$HOME/.config}/$DIRW"
  if [ -d "$DIRPATHw" ]; then
    if [ "${EXPRESS_MODE:-0}" -eq 1 ]; then
      echo -e "${NOTE:-[NOTE]} Express mode: preserving existing ${YELLOW:-}$DIRW${RESET:-} config." 2>&1 | tee -a "$log"
      return
    fi
    while true; do
      echo -n "${CAT:-[ACTION]} Do you want to replace ${YELLOW:-}$DIRW${RESET:-} config? (y/n): "
      read DIR1_CHOICE
      case "$DIR1_CHOICE" in
      [Yy]*)
        BACKUP_DIR=$(get_backup_dirname)
        cp -r "$DIRPATHw" "$DIRPATHw-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
        echo -e "${NOTE:-[NOTE]} - Backed up $DIRW to $DIRPATHw-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
        rm -rf "$DIRPATHw" && cp -r "$config_root/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
        for file in "config" "style.css"; do
          symlink="$DIRPATHw-backup-$BACKUP_DIR/$file"
          target_file="$DIRPATHw/$file"
          if [ -L "$symlink" ]; then
            symlink_target=$(readlink "$symlink")
            if [ -f "$symlink_target" ]; then
              rm -f "$target_file" && cp -f "$symlink_target" "$target_file"
            fi
          fi
        done
        for dir in "$DIRPATHw-backup-$BACKUP_DIR/configs"/*; do
          [ -e "$dir" ] || continue
          if [ -d "$dir" ]; then
            target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/configs/$(basename "$dir")"
            [ -d "$target_dir" ] || cp -r "$dir" "${XDG_CONFIG_HOME:-$HOME/.config}/waybar/configs/"
          fi
        done
        for file in "$DIRPATHw-backup-$BACKUP_DIR/configs"/*; do
          [ -e "$file" ] || continue
          target_file="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/configs/$(basename "$file")"
          [ -e "$target_file" ] || cp "$file" "${XDG_CONFIG_HOME:-$HOME/.config}/waybar/configs/"
        done || true
        for file in "$DIRPATHw-backup-$BACKUP_DIR/style"/*; do
          [ -e "$file" ] || continue
          if [ -d "$file" ]; then
            target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style/$(basename "$file")"
            [ -d "$target_dir" ] || cp -r "$file" "${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style/"
          else
            target_file="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style/$(basename "$file")"
            [ -e "$target_file" ] || cp "$file" "${XDG_CONFIG_HOME:-$HOME/.config}/waybar/style/"
          fi
        done || true
        for backup_name in ModulesWorkspaces UserModules; do
          BACKUP_FILEw="$DIRPATHw-backup-$BACKUP_DIR/$backup_name"
          [ -f "$BACKUP_FILEw" ] && cp -f "$BACKUP_FILEw" "$DIRPATHw/$backup_name"
        done
        break
        ;;
      [Nn]*)
        echo -e "${NOTE:-[NOTE]} - Skipping ${YELLOW:-}$DIRW${RESET:-} config replacement." 2>&1 | tee -a "$log"
        break
        ;;
      *) echo -e "${WARN:-[WARN]} - Invalid choice. Please enter Y or N." ;;
      esac
    done
  else
    cp -r "$config_root/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
    echo -e "${OK:-[OK]} - Copy completed for ${YELLOW:-}$DIRW${RESET:-}" 2>&1 | tee -a "$log"
  fi
}

copy_phase2() {
  local log="$1"
  local config_root="${WORK_CONFIG_DIR:-config}"
  local DIR="btop cava copyq hypr Kvantum qt5ct qt6ct starship swappy wallust wlogout yazi"
  local theme_state_dir="${HOME}/.config/.theme-state-pre-copy"

  snapshot_theme_state "$theme_state_dir"
  for DIR_NAME in $DIR; do
    local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/$DIR_NAME"
    if [ -d "$DIRPATH" ]; then
      echo -e "\n${NOTE:-[NOTE]} - Config for ${YELLOW:-}$DIR_NAME${RESET:-} found, attempting to back up."
      BACKUP_DIR=$(get_backup_dirname)
      mv "$DIRPATH" "$DIRPATH-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
    fi
    if [ -d "$config_root/$DIR_NAME" ]; then
      cp -r "$config_root/$DIR_NAME/" "$HOME/.config/$DIR_NAME" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - Copy of config for ${YELLOW:-}$DIR_NAME${RESET:-} completed!" 2>&1 | tee -a "$log"
    else
      echo "${ERROR:-[ERROR]} - Directory $config_root/$DIR_NAME does not exist to copy." 2>&1 | tee -a "$log"
    fi
  done
  restore_theme_state "$theme_state_dir" "$log"
  restore_copyq_state "$log"
  install_terminal_configs "$log"
}

restore_copyq_state() {
  local log="$1"
  local copyq_dir="$HOME/.config/copyq"
  local backup_dir
  backup_dir=$(find "$HOME/.config" -maxdepth 1 -type d -name 'copyq-backup-*' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-)

  [ -n "$backup_dir" ] || return 0
  [ -d "$backup_dir" ] || return 0
  [ -d "$copyq_dir" ] || return 0

  local restored_any=0
  local source_path
  for source_path in "$backup_dir"/*; do
    [ -e "$source_path" ] || continue

    local file_name
    file_name=$(basename "$source_path")
    case "$file_name" in
    copyq.conf | copyq.lock | .copyq_s)
      continue
      ;;
    esac

    if [ -d "$source_path" ]; then
      rm -rf "$copyq_dir/$file_name"
      cp -r "$source_path" "$copyq_dir/$file_name" 2>&1 | tee -a "$log"
    else
      cp -f "$source_path" "$copyq_dir/$file_name" 2>&1 | tee -a "$log"
    fi
    restored_any=1
  done

  if [ "$restored_any" -eq 1 ]; then
    chmod 600 "$copyq_dir/copyq.pub" 2>/dev/null || true
    echo "${OK:-[OK]} - Restored CopyQ stateful files from backup." 2>&1 | tee -a "$log"
  fi
}

ensure_lua_keybinds() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  local src_root="$base/config/hypr"
  local dst_root="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local copied=0
  local rel_dir src_dir src_file rel_path dst_file

  for rel_dir in configs UserConfigs lua; do
    src_dir="$src_root/$rel_dir"
    [ -d "$src_dir" ] || continue

    while IFS= read -r -d '' src_file; do
      rel_path="${src_file#$src_root/}"
      dst_file="$dst_root/$rel_path"

      if [ ! -f "$dst_file" ]; then
        mkdir -p "$(dirname "$dst_file")"
        if cp -f "$src_file" "$dst_file" 2>&1 | tee -a "$log"; then
          copied=1
          echo "${NOTE:-[NOTE]} - Added missing Lua file: ${YELLOW:-}$rel_path${RESET:-}" 2>&1 | tee -a "$log"
        else
          echo "${ERROR:-[ERROR]} - Failed to add missing Lua file: ${YELLOW:-}$rel_path${RESET:-}" 2>&1 | tee -a "$log"
        fi
      fi
    done < <(find "$src_dir" -maxdepth 1 -type f -name '*.lua' -print0)
  done

  if [ "$copied" -eq 1 ]; then
    echo "${OK:-[OK]} - Lua fallback copy completed." 2>&1 | tee -a "$log"
  else
    echo "${INFO:-[INFO]} - Lua fallback check: no missing Lua files detected." 2>&1 | tee -a "$log"
  fi
}

# Restore Animations and Monitor Profiles plus key hypr files from backup
restore_hypr_assets() {
  local log="$1"
  local express_mode="$2"

  local HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local CONFIG_HOME="${XDG_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_HYPR_PATH="$HYPR_DIR-backup-$BACKUP_DIR"

  if [ -d "$BACKUP_HYPR_PATH" ]; then
    local backup_mode="conf"
    if [ -f "$BACKUP_HYPR_PATH/hyprland.lua" ] || [ -f "$CONFIG_HOME/hyprland.lua" ]; then
      backup_mode="lua"
    fi

    # Preserve active Lua entrypoint automatically to avoid dropping users
    # back to hyprland.conf after an upgrade.
    if [ -f "$BACKUP_HYPR_PATH/hyprland.lua" ]; then
      cp -f "$BACKUP_HYPR_PATH/hyprland.lua" "$HYPR_DIR/hyprland.lua" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}hyprland.lua${RESET:-}" 2>&1 | tee -a "$log"
    fi

    if [ "$express_mode" -eq 1 ]; then
      echo "${NOTE:-[NOTE]} Express mode: skipping automatic restoration of animations and monitor profile directories." 2>&1 | tee -a "$log"
    else
      echo -e "\n${NOTE:-[NOTE]} Restoring ${SKY_BLUE:-}Animations & Monitor Profiles${RESET:-} into ${YELLOW:-}$HYPR_DIR${RESET:-}..."

      # Fresh installs should apply repo defaults; do not restore a previous wallpaper.
      # RUN_MODE is set by copy.sh (install|upgrade|express) and is visible here.
      local DIR_B=("Monitor_Profiles" "animations")
      if [ "${RUN_MODE:-}" != "install" ]; then
        DIR_B+=("wallpaper_effects")
      else
        echo "${NOTE:-[NOTE]} Fresh install: skipping restore of wallpaper_effects so default wallpaper applies." 2>&1 | tee -a "$log"
      fi

      for DIR_RESTORE in "${DIR_B[@]}"; do
        local BACKUP_SUBDIR="$BACKUP_HYPR_PATH/$DIR_RESTORE"
        if [ -d "$BACKUP_SUBDIR" ]; then
          cp -r "$BACKUP_SUBDIR" "$HYPR_DIR/" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - Restored directory: ${MAGENTA:-}$DIR_RESTORE${RESET:-}" 2>&1 | tee -a "$log"
        fi
      done
    fi

    # Per-install state files that live directly in hypr/ and would otherwise
    # go with the wholesale directory replace. Always restored, express
    # included -- these are user choices, not config the release owns.
    #   .swaylock_hack  the xscreensaver hack picked via SUPER SHIFT L
    local STATE_FILES=(".swaylock_hack")
    for STATE_FILE in "${STATE_FILES[@]}"; do
      if [ -f "$BACKUP_HYPR_PATH/$STATE_FILE" ]; then
        cp -f "$BACKUP_HYPR_PATH/$STATE_FILE" "$HYPR_DIR/$STATE_FILE" 2>/dev/null \
          && echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}$STATE_FILE${RESET:-}" 2>&1 | tee -a "$log"
      fi
    done

    # Keep monitor/workspace state across upgrades, including express mode.
    if [ "$backup_mode" = "lua" ]; then
      local LUA_USER_DIR="$HYPR_DIR/UserConfigs"
      mkdir -p "$LUA_USER_DIR"

      local BACKUP_LUA_MONITORS=""
      local BACKUP_LUA_WORKSPACES=""
      if [ -f "$BACKUP_HYPR_PATH/UserConfigs/monitors.lua" ]; then
        BACKUP_LUA_MONITORS="$BACKUP_HYPR_PATH/UserConfigs/monitors.lua"
      elif [ -f "$BACKUP_HYPR_PATH/lua/monitors.lua" ]; then
        BACKUP_LUA_MONITORS="$BACKUP_HYPR_PATH/lua/monitors.lua"
      fi
      if [ -f "$BACKUP_HYPR_PATH/UserConfigs/workspaces.lua" ]; then
        BACKUP_LUA_WORKSPACES="$BACKUP_HYPR_PATH/UserConfigs/workspaces.lua"
      elif [ -f "$BACKUP_HYPR_PATH/lua/workspaces.lua" ]; then
        BACKUP_LUA_WORKSPACES="$BACKUP_HYPR_PATH/lua/workspaces.lua"
      fi

      if [ -n "$BACKUP_LUA_MONITORS" ]; then
        cp -f "$BACKUP_LUA_MONITORS" "$LUA_USER_DIR/monitors.lua" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}UserConfigs/monitors.lua${RESET:-}" 2>&1 | tee -a "$log"
      fi
      if [ -n "$BACKUP_LUA_WORKSPACES" ]; then
        cp -f "$BACKUP_LUA_WORKSPACES" "$LUA_USER_DIR/workspaces.lua" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}UserConfigs/workspaces.lua${RESET:-}" 2>&1 | tee -a "$log"
      fi
    else
      local FILE_B=("monitors.conf" "workspaces.conf")
      for FILE_RESTORE in "${FILE_B[@]}"; do
        local BACKUP_FILE="$BACKUP_HYPR_PATH/$FILE_RESTORE"
        if [ -f "$BACKUP_FILE" ]; then
          cp "$BACKUP_FILE" "$HYPR_DIR/$FILE_RESTORE" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}$FILE_RESTORE${RESET:-}" 2>&1 | tee -a "$log"
        fi
      done
    fi
  fi
}

# Helper to extract overlay additions/disables from previous user file vs base
compose_overlay_from_backup() {
  local type="$1" # startup|windowrules
  local base_file="$2"
  local old_user_file="$3"
  local new_user_file="$4"
  local disable_file="$5"

  mkdir -p "$(dirname "$new_user_file")"
  : >"$new_user_file"
  : >"$disable_file"

  if [ "$type" = "startup" ]; then
    grep -E '^\s*exec-once\s*=' "$old_user_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$old_user_file.tmp.exec"
    grep -E '^\s*exec-once\s*=' "$base_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$base_file.tmp.exec"
    comm -23 "$old_user_file.tmp.exec" "$base_file.tmp.exec" >"$new_user_file"
    grep -E '^\s*#\s*exec-once\s*=' "$old_user_file" |
      sed -E 's/^\s*#\s*exec-once\s*=\s*//' |
      sed -E 's/^\s+//;s/\s+$//' |
      grep -Ev '^\$scriptsDir/KeybindsLayoutInit\.sh$' |
      sort -u >"$disable_file"
    rm -f "$old_user_file.tmp.exec" "$base_file.tmp.exec"
  elif [ "$type" = "windowrules" ]; then
    grep -E '^(windowrule|layerrule)\s*=' "$old_user_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$old_user_file.tmp.rules"
    grep -E '^(windowrule|layerrule)\s*=' "$base_file" | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$base_file.tmp.rules"
    comm -23 "$old_user_file.tmp.rules" "$base_file.tmp.rules" >"$new_user_file"
    grep -E '^\s*#\s*(windowrule|layerrule)\s*=' "$old_user_file" | sed -E 's/^\s*#\s*//' | sed -E 's/^\s+//;s/\s+$//' | sort -u >"$disable_file"
    rm -f "$old_user_file.tmp.rules" "$base_file.tmp.rules"
  fi
}

cleanup_duplicate_userconfigs() {
  local current_version="$1"
  local log="$2"

  if [ -n "$current_version" ]; then
    echo "${INFO:-[INFO]} Running UserConfigs duplicate cleanup for detected version v$current_version." 2>&1 | tee -a "$log"
  else
    echo "${INFO:-[INFO]} Running UserConfigs duplicate cleanup." 2>&1 | tee -a "$log"
  fi

  # Run de-dupe only for existing installs up to and including v2.3.18.
  # For v2.3.19 and newer, UserConfigs should be left as-is to avoid
  # removing user modifications.
  if version_gte "$current_version" "2.3.19"; then
    echo "${INFO:-[INFO]} Skipping UserConfigs duplicate cleanup for detected version v$current_version (>= 2.3.19)." 2>&1 | tee -a "$log"
    return
  fi

  echo "${INFO:-[INFO]} Running UserConfigs duplicate cleanup for detected version v$current_version (<= 2.3.18)." 2>&1 | tee -a "$log"

  local HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local BASE_DIR="$HYPR_DIR/configs"
  local USER_DIR="$HYPR_DIR/UserConfigs"

  local STARTUP_BASE="$BASE_DIR/Startup_Apps.conf"
  local STARTUP_USER="$USER_DIR/Startup_Apps.conf"
  local WINDOW_BASE="$BASE_DIR/WindowRules.conf"
  local WINDOW_USER="$USER_DIR/WindowRules.conf"
  local KEYBINDS_BASE="$BASE_DIR/Keybinds.conf"
  local KEYBINDS_USER="$USER_DIR/UserKeybinds.conf"
  local ENV_USER="$USER_DIR/ENVariables.conf"

  # Startup_Apps: strip exec-once lines from UserConfigs that are exact
  # duplicates of the base Startup_Apps.conf.
  if [ -f "$STARTUP_BASE" ] && [ -f "$STARTUP_USER" ]; then
    local tmp_startup
    local backup_startup
    backup_startup="$STARTUP_USER.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    tmp_startup=$(mktemp)
    awk '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR==NR {
        if ($0 ~ /^[ \t]*exec-once[ \t]*=/) {
          line=trim($0)
          base[line]=1
        }
        next
      }
      {
        if ($0 ~ /^[ \t]*exec-once[ \t]*=/) {
          line=trim($0)
          if (line in base) next
        }
        print
      }
    ' "$STARTUP_BASE" "$STARTUP_USER" >"$tmp_startup"
    if ! cmp -s "$STARTUP_USER" "$tmp_startup"; then
      cp "$STARTUP_USER" "$backup_startup"
      mv "$tmp_startup" "$STARTUP_USER"
      echo "${NOTE:-[NOTE]} - Removed duplicate Startup_Apps entries matching base config." 2>&1 | tee -a "$log"
    else
      rm -f "$tmp_startup"
    fi
  fi

  # WindowRules: strip windowrule/layerrule lines from UserConfigs that
  # are exact duplicates of the base WindowRules.conf.
  if [ -f "$WINDOW_BASE" ] && [ -f "$WINDOW_USER" ]; then
    local tmp_window
    local backup_window
    backup_window="$WINDOW_USER.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    tmp_window=$(mktemp)
    awk '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR==NR {
        if ($0 ~ /^[ \t]*(windowrule|layerrule)[ \t]*=/) {
          line=trim($0)
          base[line]=1
        }
        next
      }
      {
        if ($0 ~ /^[ \t]*(windowrule|layerrule)[ \t]*=/) {
          line=trim($0)
          if (line in base) next
        }
        print
      }
    ' "$WINDOW_BASE" "$WINDOW_USER" >"$tmp_window"
    if ! cmp -s "$WINDOW_USER" "$tmp_window"; then
      cp "$WINDOW_USER" "$backup_window"
      mv "$tmp_window" "$WINDOW_USER"
      echo "${NOTE:-[NOTE]} - Removed duplicate WindowRules entries matching base config." 2>&1 | tee -a "$log"
    else
      rm -f "$tmp_window"
    fi
  fi

  # Keybinds: strip bind* lines from UserKeybinds.conf that are exact
  # duplicates of the base Keybinds.conf. Comments and unbinds are kept.
  if [ -f "$KEYBINDS_BASE" ] && [ -f "$KEYBINDS_USER" ]; then
    local tmp_keybinds
    local backup_keybinds
    backup_keybinds="$KEYBINDS_USER.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    tmp_keybinds=$(mktemp)
    awk '
      function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
      FNR==NR {
        # Match any Hyprland bind variant: bindd, bindmd, bindld, binded,
        # bindlnd, bindeld, etc.
        if ($0 ~ /^[ \t]*bind[a-z]*[ \t]*=/) {
          line=trim($0)
          base[line]=1
        }
        next
      }
      {
        if ($0 ~ /^[ \t]*bind[a-z]*[ \t]*=/) {
          line=trim($0)
          if (line in base) next
        }
        print
      }
    ' "$KEYBINDS_BASE" "$KEYBINDS_USER" >"$tmp_keybinds"
    if ! cmp -s "$KEYBINDS_USER" "$tmp_keybinds"; then
      cp "$KEYBINDS_USER" "$backup_keybinds"
      mv "$tmp_keybinds" "$KEYBINDS_USER"
      echo "${NOTE:-[NOTE]} - Removed duplicate UserKeybinds entries matching base Keybinds.conf." 2>&1 | tee -a "$log"
    else
      rm -f "$tmp_keybinds"
    fi
  fi

  # ENVariables: keep only the last QT_QPA_PLATFORMTHEME entry in the
  # user overlay so upgrades can normalize older duplicated configs.
  if [ -f "$ENV_USER" ]; then
    local tmp_env
    local backup_env
    backup_env="$ENV_USER.backup-dupfix-$(date +%Y%m%d-%H%M%S)"
    tmp_env=$(mktemp)
    awk '
      /^[ \t]*env[ \t]*=[ \t]*QT_QPA_PLATFORMTHEME,/ { last=$0; next }
      { print }
      END {
        if (last != "") print last
      }
    ' "$ENV_USER" >"$tmp_env"
    if ! cmp -s "$ENV_USER" "$tmp_env"; then
      cp "$ENV_USER" "$backup_env"
      mv "$tmp_env" "$ENV_USER"
      echo "${NOTE:-[NOTE]} - Removed duplicate QT_QPA_PLATFORMTHEME entries from ENVariables.conf." 2>&1 | tee -a "$log"
    else
      rm -f "$tmp_env"
    fi
  fi
}
restore_user_configs() {
  local log="$1"
  local express_mode="$2"
  local old_version="$3"

  local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH="$DIRPATH-backup-$BACKUP_DIR/UserConfigs"
  local BACKUP_CONFIGS_PATH="$DIRPATH-backup-$BACKUP_DIR/configs"

  if [ -z "$BACKUP_DIR" ]; then
    echo "${ERROR:-[ERROR]} - Backup directory name is empty. Exiting." 2>&1 | tee -a "$log"
    exit 1
  fi

  # Fresh install: preserve any existing UserConfigs and stop here.
  if [ "${RUN_MODE:-}" = "install" ]; then
    if [ -d "$BACKUP_DIR_PATH" ]; then
      echo "${NOTE:-[NOTE]} Preserving existing UserConfigs directory during install." 2>&1 | tee -a "$log"
      rsync -a "$BACKUP_DIR_PATH/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - UserConfigs directory preserved." 2>&1 | tee -a "$log"
    fi
    return
  fi

  # Express mode should preserve user-owned config automatically rather than
  # treating skipped prompts as permission to overwrite local state.
  if [ -d "$BACKUP_DIR_PATH" ] && [ "$express_mode" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} Express mode: automatically restoring UserConfigs from backup." 2>&1 | tee -a "$log"
    mkdir -p "$DIRPATH/UserConfigs"
    rsync -a "$BACKUP_DIR_PATH/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
    echo "${OK:-[OK]} - UserConfigs directory restored." 2>&1 | tee -a "$log"
  elif [ -d "$BACKUP_DIR_PATH" ]; then
    local VERSION_FILE
    VERSION_FILE=$(find "$DIRPATH" -maxdepth 1 -name "v*.*.*" | head -n 1)
    local CURRENT_VERSION="999.9.9"
    if [ -n "$old_version" ]; then
      CURRENT_VERSION="$old_version"
    fi

    local TARGET_VERSION="2.3.19"
    local AUTO_RESTORE=0
    if version_gte "$CURRENT_VERSION" "2.3.18"; then
      AUTO_RESTORE=1
    fi

    echo -e "${NOTE:-[NOTE]} Restoring previous ${MAGENTA:-}User-Configs${RESET:-}... " 2>&1 | tee -a "$log"
    printf "${WARNING:-}\\
    █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█\\n\\
            NOTES for RESTORING PREVIOUS CONFIGS\\n\\
    █▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█\\n\\n\\
    The 'UserConfigs' directory is for all your personal settings.\\n\\
    Files in this directory will override the default configurations,\\n\\
    so your customizations are not lost when you update.\\n\\
" >&2

    if version_gte "$CURRENT_VERSION" "$TARGET_VERSION"; then
      if [ "$express_mode" -eq 1 ] || [ "$AUTO_RESTORE" -eq 1 ]; then
        echo "${NOTE:-[NOTE]} Restoring UserConfigs directory automatically." 2>&1 | tee -a "$log"
        rsync -a "$BACKUP_DIR_PATH/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - UserConfigs directory restored." 2>&1 | tee -a "$log"
      else
        read -r -p "${CAT:-[ACTION]} Do you want to restore your previous UserConfigs directory? (Y/n): " restore_userconfigs_dir
        if [[ "$restore_userconfigs_dir" != [Nn]* ]]; then
          echo "${NOTE:-[NOTE]} Restoring UserConfigs directory..." 2>&1 | tee -a "$log"
          rsync -a "$BACKUP_DIR_PATH/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - UserConfigs directory restored." 2>&1 | tee -a "$log"
        else
          echo "${NOTE:-[NOTE]} - Skipped restoring UserConfigs." 2>&1 | tee -a "$log"
        fi
      fi
    else
      echo -e "${NOTE:-[NOTE]} Detected version ${YELLOW:-}v$CURRENT_VERSION${RESET:-} (older than v$TARGET_VERSION). Using legacy restoration mode." 2>&1 | tee -a "$log"

      local FILES_TO_RESTORE=(
        "01-UserDefaults.conf"
        "ENVariables.conf"
        "LaptopDisplay.conf"
        "Laptops.conf"
        "monitors.lua"
        "Startup_Apps.conf"
        "UserDecorations.conf"
        "UserAnimations.conf"
        "UserKeybinds.conf"
        "UserSettings.conf"
        "WorkspaceKeybinds.conf"
        "workspaces.lua"
        "WindowRules.conf"
      )

      for FILE_NAME in "${FILES_TO_RESTORE[@]}"; do
        local BACKUP_FILE="$BACKUP_DIR_PATH/$FILE_NAME"
        if [ -f "$BACKUP_FILE" ]; then
          if [ "$FILE_NAME" = "Startup_Apps.conf" ]; then
            compose_overlay_from_backup "startup" "$DIRPATH/configs/Startup_Apps.conf" "$BACKUP_FILE" "$DIRPATH/UserConfigs/Startup_Apps.conf" "$DIRPATH/UserConfigs/Startup_Apps.disable"
            echo "${OK:-[OK]} - Migrated overlay for ${YELLOW:-}$FILE_NAME${RESET:-}" 2>&1 | tee -a "$log"
            continue
          fi
          if [ "$FILE_NAME" = "WindowRules.conf" ]; then
            compose_overlay_from_backup "windowrules" "$DIRPATH/configs/WindowRules.conf" "$BACKUP_FILE" "$DIRPATH/UserConfigs/WindowRules.conf" "$DIRPATH/UserConfigs/WindowRules.disable"
            echo "${OK:-[OK]} - Migrated overlay for ${YELLOW:-}$FILE_NAME${RESET:-}" 2>&1 | tee -a "$log"
            continue
          fi
          if [ "$express_mode" -eq 1 ] || [ "$AUTO_RESTORE" -eq 1 ]; then
            if cp "$BACKUP_FILE" "$DIRPATH/UserConfigs/$FILE_NAME"; then
              echo "${OK:-[OK]} - $FILE_NAME restored!" 2>&1 | tee -a "$log"
            else
              echo "${ERROR:-[ERROR]} - Failed to restore $FILE_NAME!" 2>&1 | tee -a "$log"
            fi
          else
            printf "\n${INFO:-[INFO]} Found ${YELLOW:-}$FILE_NAME${RESET:-} in hypr backup...\n"
            read -r -p "${CAT:-[ACTION]} Do you want to restore ${YELLOW:-}$FILE_NAME${RESET:-} from backup? (Y/n): " file_restore

            if [[ "$file_restore" != [Nn]* ]]; then
              if cp "$BACKUP_FILE" "$DIRPATH/UserConfigs/$FILE_NAME"; then
                echo "${OK:-[OK]} - $FILE_NAME restored!" 2>&1 | tee -a "$log"
              else
                echo "${ERROR:-[ERROR]} - Failed to restore $FILE_NAME!" 2>&1 | tee -a "$log"
              fi
            else
              echo "${NOTE:-[NOTE]} - Skipped restoring $FILE_NAME." 2>&1 | tee -a "$log"
            fi
          fi
        fi
      done
    fi
  fi

  if [ -d "$BACKUP_CONFIGS_PATH" ]; then
    local restored_system_lua=0
    local lua_file
    mkdir -p "$DIRPATH/configs"
    while IFS= read -r -d '' lua_file; do
      cp -f "$lua_file" "$DIRPATH/configs/"
      restored_system_lua=1
    done < <(find "$BACKUP_CONFIGS_PATH" -maxdepth 1 -type f -name 'system_*.lua' -print0)
    if [ "$restored_system_lua" -eq 1 ]; then
      echo "${OK:-[OK]} - Restored migrated system Lua overlays to $DIRPATH/configs." 2>&1 | tee -a "$log"
    fi
  fi

  # Always run de-dupe based on the installed dotfiles version so that
  # express mode and standard mode behave consistently. Prefer the
  # pre-upgrade version (old_version) if provided so we still clean up
  # legacy duplicates when upgrading to a newer release that no longer
  # needs the fix.
  local detected_version="$old_version"
  if [ -z "$detected_version" ]; then
    detected_version=$(get_installed_dotfiles_version)
  fi
  if [ -n "$detected_version" ]; then
    cleanup_duplicate_userconfigs "$detected_version" "$log"
  fi
}

restore_user_scripts() {
  local log="$1"
  local express_mode="$2"

  local DIRSHPATH="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH_S="$DIRSHPATH-backup-$BACKUP_DIR/UserScripts"
  local SCRIPTS_TO_RESTORE=("RofiBeats.sh" "Weather.py" "Weather.sh")

  # Repo-owned scripts that happen to live in UserScripts. They are thin
  # wrappers around packaged tools -- they pin this config's paths and are not
  # meant to be edited -- so the express rsync below must not restore a stale
  # copy over the one this release ships. Without the exclusion a wrapper fix
  # lands once and is silently reverted by the next express upgrade.
  local REPO_OWNED_SCRIPTS=("ScreenHackSelect.sh" "ScreenHackShots.sh")

  if [ -d "$BACKUP_DIR_PATH_S" ] && [ "$express_mode" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} Express mode: automatically restoring UserScripts from backup." 2>&1 | tee -a "$log"
    mkdir -p "$DIRSHPATH/UserScripts"
    local RSYNC_EXCLUDES=()
    for SCRIPT_NAME in "${REPO_OWNED_SCRIPTS[@]}"; do
      RSYNC_EXCLUDES+=(--exclude "$SCRIPT_NAME")
    done
    rsync -a "${RSYNC_EXCLUDES[@]}" "$BACKUP_DIR_PATH_S/" "$DIRSHPATH/UserScripts/" 2>&1 | tee -a "$log"
    echo "${OK:-[OK]} - UserScripts directory restored (release versions kept for: ${REPO_OWNED_SCRIPTS[*]})." 2>&1 | tee -a "$log"
    return
  fi

  if [ -d "$BACKUP_DIR_PATH_S" ] && [ "$express_mode" -eq 0 ]; then
    echo -e "${NOTE:-[NOTE]} Restoring previous ${MAGENTA:-}User-Scripts${RESET:-}..." 2>&1 | tee -a "$log"

    for SCRIPT_NAME in "${SCRIPTS_TO_RESTORE[@]}"; do
      local BACKUP_SCRIPT="$BACKUP_DIR_PATH_S/$SCRIPT_NAME"
      if [ -f "$BACKUP_SCRIPT" ]; then
        printf "\n${INFO:-[INFO]} Found ${YELLOW:-}$SCRIPT_NAME${RESET:-} in hypr backup...\n"
        read -r -p "${CAT:-[ACTION]} Do you want to restore ${YELLOW:-}$SCRIPT_NAME${RESET:-} from backup? (y/N): " script_restore

        if [[ "$script_restore" == [Yy]* ]]; then
          if cp "$BACKUP_SCRIPT" "$DIRSHPATH/UserScripts/$SCRIPT_NAME"; then
            echo "${OK:-[OK]} - $SCRIPT_NAME restored!" 2>&1 | tee -a "$log"
          else
            echo "${ERROR:-[ERROR]} - Failed to restore $SCRIPT_NAME!" 2>&1 | tee -a "$log"
          fi
        else
          echo "${NOTE:-[NOTE]} - Skipped restoring $SCRIPT_NAME." 2>&1 | tee -a "$log"
        fi
      fi
    done
  fi
}

restore_terminal_configs() {
  local log="$1"
  local express_mode="$2"

  local GHOSTTY_DIR="${XDG_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}/ghostty"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local GHOSTTY_BACKUP="$GHOSTTY_DIR-backup-$BACKUP_DIR"

  if [ -d "$GHOSTTY_BACKUP" ] && [ "$express_mode" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} Express mode: skipping Ghostty restore prompt." 2>&1 | tee -a "$log"
    return
  fi

  if [ -d "$GHOSTTY_BACKUP" ] && [ "$express_mode" -eq 0 ]; then
    echo -e "${NOTE:-[NOTE]} Restore previous ${MAGENTA:-}Ghostty${RESET:-} config?" 2>&1 | tee -a "$log"
    read -r -p "${CAT:-[ACTION]} Do you want to restore Ghostty config from backup? (y/N): " restore_ghostty
    if [[ "$restore_ghostty" == [Yy]* ]]; then
      rm -rf "$GHOSTTY_DIR"
      cp -a "$GHOSTTY_BACKUP" "$GHOSTTY_DIR" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - Ghostty config restored." 2>&1 | tee -a "$log"
    else
      echo "${NOTE:-[NOTE]} - Skipped restoring Ghostty config." 2>&1 | tee -a "$log"
    fi
  fi
}
# The swaylock-plugin screensaver release changed the stock lock_cmd, but
# hypridle.conf is user-owned and gets restored from backup on upgrades — a
# restored pre-release file would silently keep locking with plain hyprlock.
# Migrate the old stock locker in place (same pattern as the Quickshell
# startup-command migration). Custom lock_cmd lines and any suffix after the
# locker (e.g. the IdleWatchdog spawn) are left untouched; idempotent.
migrate_hypridle_lock_cmd() {
  local log="$1"
  local conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf"
  [ -f "$conf" ] || return 0
  grep -Eq '^[[:space:]]*lock_cmd[[:space:]]*=[[:space:]]*\(?[[:space:]]*pidof hyprlock \|\| hyprlock' "$conf" || return 0
  local locker='$scriptsDir/SwaylockScreensaver.sh'
  grep -Eq '^\$scriptsDir[[:space:]]*=' "$conf" || locker='$HOME/.config/hypr/scripts/SwaylockScreensaver.sh'
  sed -i -E "s#^([[:space:]]*lock_cmd[[:space:]]*=[[:space:]]*)\(?[[:space:]]*pidof hyprlock \|\| hyprlock[[:space:]]*\)?#\1(${locker} || hyprlock)#" "$conf"
  echo "${OK:-[OK]} - hypridle.conf: migrated lock_cmd to the swaylock-plugin screensaver launcher." 2>&1 | tee -a "$log"
}

# hypridle.conf stopped being a user-owned file in 2.3.26: it is generated
# from UserConfigs/IdleSettings.conf (see adjust_idle_dpms_policy in
# lib_detect.sh). Restoring the backup over the top would put a stale,
# hand-edited file back and defeat the whole mechanism, so on the first
# managed upgrade the backup is parked next to it instead of being restored.
# KOOL_IDLE_MANAGED=0 keeps the old behavior.
idle_policy_is_managed() {
  local prefs="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/IdleSettings.conf"
  [ -f "$prefs" ] || prefs="${WORK_CONFIG_DIR:-config}/hypr/UserConfigs/IdleSettings.conf"
  case "$(read_idle_knob "$prefs" KOOL_IDLE_MANAGED 1)" in
    0|false|no|off|FALSE|No|Off|NO|OFF) return 1 ;;
    *) return 0 ;;
  esac
}

park_hypridle_backup() {
  local log="$1" backup_dir="$2"
  local src="$backup_dir/hypridle.conf"
  local dst="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf.pre-managed"
  [ -f "$src" ] || return 0
  [ -e "$dst" ] && return 0
  cp "$src" "$dst" 2>/dev/null || return 0
  echo "${NOTE:-[NOTE]} hypridle.conf is now generated from UserConfigs/IdleSettings.conf." 2>&1 | tee -a "$log"
  echo "${NOTE:-[NOTE]} Your previous file was kept as hypridle.conf.pre-managed for reference." 2>&1 | tee -a "$log"
}

restore_hypr_files() {
  local log="$1"
  local express_mode="$2"

  local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH_F="$DIRPATH-backup-$BACKUP_DIR"
  local FILES_2_RESTORE=("hyprlock.conf" "hypridle.conf")
  local MANAGED_IDLE=0
  if idle_policy_is_managed; then
    MANAGED_IDLE=1
    FILES_2_RESTORE=("hyprlock.conf")
    park_hypridle_backup "$log" "$BACKUP_DIR_PATH_F"
  fi

  if [ -d "$BACKUP_DIR_PATH_F" ] && [ "$express_mode" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} Express mode: automatically restoring user-owned hypr files from backup." 2>&1 | tee -a "$log"
    for FILE_RESTORE in "${FILES_2_RESTORE[@]}"; do
      local BACKUP_FILE="$BACKUP_DIR_PATH_F/$FILE_RESTORE"
      if [ -f "$BACKUP_FILE" ]; then
        if cp "$BACKUP_FILE" "$DIRPATH/$FILE_RESTORE"; then
          echo "${OK:-[OK]} - $FILE_RESTORE restored." 2>&1 | tee -a "$log"
        else
          echo "${ERROR:-[ERROR]} - Failed to restore $FILE_RESTORE!" 2>&1 | tee -a "$log"
        fi
      fi
    done
    [ "$MANAGED_IDLE" -eq 0 ] && migrate_hypridle_lock_cmd "$log"
    return 0
  fi

  if [ -d "$BACKUP_DIR_PATH_F" ] && [ "$express_mode" -eq 0 ]; then
    echo -e "${NOTE:-[NOTE]} Restoring some files in ${MAGENTA:-}${XDG_CONFIG_HOME:-$HOME/.config}/hypr directory${RESET:-}..." 2>&1 | tee -a "$log"

    for FILE_RESTORE in "${FILES_2_RESTORE[@]}"; do
      local BACKUP_FILE="$BACKUP_DIR_PATH_F/$FILE_RESTORE"
      if [ -f "$BACKUP_FILE" ]; then
        echo -e "\n${INFO:-[INFO]} Found ${YELLOW:-}$FILE_RESTORE${RESET:-} in hypr backup..."
        read -r -p "${CAT:-[ACTION]} Do you want to restore ${YELLOW:-}$FILE_RESTORE${RESET:-} from backup? (y/N): " file2restore

        if [[ "$file2restore" == [Yy]* ]]; then
          if cp "$BACKUP_FILE" "$DIRPATH/$FILE_RESTORE"; then
            echo "${OK:-[OK]} - $FILE_RESTORE restored!" 2>&1 | tee -a "$log"
          else
            echo "${ERROR:-[ERROR]} - Failed to restore $FILE_RESTORE!" 2>&1 | tee -a "$log"
          fi
        else
          echo "${NOTE:-[NOTE]} - Skipped restoring $FILE_RESTORE." 2>&1 | tee -a "$log"
        fi
      else
        echo "${NOTE:-[NOTE]} - Backup file $BACKUP_FILE does not exist. Skipping." 2>&1 | tee -a "$log"
      fi
    done
    [ "$MANAGED_IDLE" -eq 0 ] && migrate_hypridle_lock_cmd "$log"
  fi
  return 0
}
