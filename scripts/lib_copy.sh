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

# Helper: configure distro-specific fastfetch config if available
_configure_fastfetch_distro_config() {
  local log="${1:-/dev/null}"
  local ff_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
  [ -d "$ff_dir" ] || return 0

  local distro_id=""
  local id_like=""
  if [ -f /etc/os-release ]; then
    distro_id=$(grep -E '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"'\''')
    id_like=$(grep -E '^ID_LIKE=' /etc/os-release | cut -d= -f2 | tr -d '"'\''')
  fi

  local target_cfg=""
  if [ -n "$distro_id" ] && [ -f "$ff_dir/kooldots-${distro_id}.jsonc" ]; then
    target_cfg="$ff_dir/kooldots-${distro_id}.jsonc"
  elif [ -n "$id_like" ]; then
    for like in $id_like; do
      if [ -f "$ff_dir/kooldots-${like}.jsonc" ]; then
        target_cfg="$ff_dir/kooldots-${like}.jsonc"
        break
      fi
    done
  fi

  if [ -n "$target_cfg" ]; then
    cp -f "$target_cfg" "$ff_dir/config.jsonc" 2>&1 | tee -a "$log"
    echo -e "${OK:-[OK]} - Applied $(basename "$target_cfg") as fastfetch config.jsonc" 2>&1 | tee -a "$log"
  fi
}

copy_phase1() {
  local log="$1"
  local run_mode="${2:-${RUN_MODE:-}}"
  local base="${DOTFILES_DIR:-.}"
  local config_root="${WORK_CONFIG_DIR:-$base/config}"
  local dirs="fastfetch swaync"
  for DIR2 in $dirs; do
    local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/$DIR2"
    if [ -d "$DIRPATH" ]; then
      if [ "$run_mode" = "express" ]; then
        echo -e "${NOTE:-[NOTE]} - Express mode: keeping existing ${YELLOW:-}$DIR2${RESET:-} config." 2>&1 | tee -a "$log"
        if [ "$DIR2" = "fastfetch" ] && [ ! -f "$DIRPATH/config.jsonc" ]; then
          _configure_fastfetch_distro_config "$log"
        fi
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
          cp -r "$config_root/$DIR2" "${XDG_CONFIG_HOME:-$HOME/.config}/$DIR2" 2>&1 | tee -a "$log"
          echo -e "${OK:-[OK]} - Replaced $DIR2 with new configuration." 2>&1 | tee -a "$log"
          if [ "$DIR2" = "fastfetch" ]; then
            _configure_fastfetch_distro_config "$log"
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
      cp -r "$config_root/$DIR2" "${XDG_CONFIG_HOME:-$HOME/.config}/$DIR2" 2>&1 | tee -a "$log"
      echo -e "${OK:-[OK]} - Copy completed for ${YELLOW:-}$DIR2${RESET:-}" 2>&1 | tee -a "$log"
      if [ "$DIR2" = "fastfetch" ]; then
        _configure_fastfetch_distro_config "$log"
      fi
    fi
  done

  # Handle ~/.config/rofi: backup existing and ensure an empty directory exists
  local rofi_dir="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"
  # Bare `rofi` calls (no -config) read ~/.config/rofi/config.rasi; a stub that
  # imports the hypr/rofi config keeps them on the installed theme. A directory
  # holding only that stub is already in the target state and is left alone.
  local rofi_stub_line='@import "~/.config/hypr/rofi/config.rasi"'
  if [ -d "$rofi_dir" ] && [ "$(ls -A "$rofi_dir" 2>/dev/null)" = "config.rasi" ] \
    && grep -qxF "$rofi_stub_line" "$rofi_dir/config.rasi" 2>/dev/null; then
    return 0
  fi
  if [ -d "$rofi_dir" ]; then
    if [ -n "$(ls -A "$rofi_dir" 2>/dev/null)" ]; then
      BACKUP_DIR=$(get_backup_dirname)
      mv "$rofi_dir" "$rofi_dir-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
      echo -e "${NOTE:-[NOTE]} - Backed up rofi to $rofi_dir-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
      mkdir -p "$rofi_dir"
      echo -e "${OK:-[OK]} - Created empty rofi directory at $rofi_dir." 2>&1 | tee -a "$log"
      if [ -d "$rofi_dir-backup-$BACKUP_DIR/themes" ]; then
        mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/themes"
        for file in "$rofi_dir-backup-$BACKUP_DIR/themes"/*; do
          [ -e "$file" ] || continue
          cp -n "$file" "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/themes/" >>"$log" 2>&1 || true
        done || true
      fi
      if [ -f "$rofi_dir-backup-$BACKUP_DIR/0-shared-fonts.rasi" ] && [ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/0-shared-fonts.rasi" ]; then
        cp "$rofi_dir-backup-$BACKUP_DIR/0-shared-fonts.rasi" "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/rofi/0-shared-fonts.rasi" >>"$log" 2>&1 || true
      fi
    fi
  else
    mkdir -p "$rofi_dir"
  fi
  printf '/* Bare rofi calls load the hypr/rofi config (theme selector target). */\n%s\n' "$rofi_stub_line" >"$rofi_dir/config.rasi"
}

# Restore symlink targets and custom user-added configs/styles from a waybar
# backup directory into the freshly-copied waybar dir. Shared by both the
# normal in-place upgrade path and the legacy ~/.config/waybar migration path.
_restore_waybar_customizations() {
  local new_dir="$1"
  local backup_dir="$2"
  local file dir symlink symlink_target target_name target_file target_dir BACKUP_FILEw

  for file in "config" "style.css"; do
    symlink="$backup_dir/$file"
    target_file="$new_dir/$file"
    if [ -L "$symlink" ]; then
      symlink_target=$(readlink "$symlink")
      target_name=$(basename "$symlink_target")
      # Normalize legacy names if needed
      case "$target_name" in
        "[TOP] Default"|"[TOP] Default Laptop"|"[TOP] Default (old v"*)
          target_name="${target_name//\[TOP\] /TOP-}"
          target_name="${target_name// Laptop/-Laptop}"
          target_name="${target_name// (old v/-old-v}"
          target_name="${target_name//)/}"
          ;;
        "[BOT] Default"|"[BOT] Default Laptop")
          target_name="${target_name//\[BOT\] /BOT-}"
          target_name="${target_name// Laptop/-Laptop}"
          ;;
      esac
      if [ "$file" = "config" ] && [ -f "$new_dir/configs/$target_name" ]; then
        rm -f "$target_file" && ln -sf "$new_dir/configs/$target_name" "$target_file"
      elif [ "$file" = "style.css" ] && [ -f "$new_dir/style/$target_name" ]; then
        rm -f "$target_file" && ln -sf "$new_dir/style/$target_name" "$target_file"
      fi
    elif [ -f "$symlink" ]; then
      # If backup was a regular file with stale includes, patch them in-place
      rm -f "$target_file" && cp -f "$symlink" "$target_file"
      if [ "$file" = "config" ]; then
        sed -i 's#\$HOME/\.config/waybar/#$HOME/.config/hypr/waybar/#g; s#~/\.config/waybar/#~/.config/hypr/waybar/#g' "$target_file" 2>/dev/null || true
      elif [ "$file" = "style.css" ]; then
        sed -i -E 's#(@import[[:space:]]*["'"'"'])\.\./\.\./\.config/waybar/wallust/colors-waybar\.css(["'"'"'])#\1../../../.config/hypr/waybar/wallust/colors-waybar.css\2#g; s#\.config/waybar/#.config/hypr/waybar/#g' "$target_file" 2>/dev/null || true
      fi
    fi
  done
  for dir in "$backup_dir/configs"/*; do
    [ -e "$dir" ] || continue
    if [ -d "$dir" ]; then
      target_dir="$new_dir/configs/$(basename "$dir")"
      [ -d "$target_dir" ] || cp -r "$dir" "$new_dir/configs/"
    fi
  done
  for file in "$backup_dir/configs"/*; do
    [ -e "$file" ] || continue
    target_file="$new_dir/configs/$(basename "$file")"
    if [ ! -e "$target_file" ]; then
      cp "$file" "$new_dir/configs/"
      sed -i 's#\$HOME/\.config/waybar/#$HOME/.config/hypr/waybar/#g; s#~/\.config/waybar/#~/.config/hypr/waybar/#g' "$target_file" 2>/dev/null || true
    fi
  done || true
  for file in "$backup_dir/style"/*; do
    [ -e "$file" ] || continue
    if [ -d "$file" ]; then
      target_dir="$new_dir/style/$(basename "$file")"
      [ -d "$target_dir" ] || cp -r "$file" "$new_dir/style/"
    else
      target_file="$new_dir/style/$(basename "$file")"
      if [ ! -e "$target_file" ]; then
        cp "$file" "$new_dir/style/"
        sed -i -E 's#(@import[[:space:]]*["'"'"'])\.\./\.\./\.config/waybar/wallust/colors-waybar\.css(["'"'"'])#\1../../../.config/hypr/waybar/wallust/colors-waybar.css\2#g; s#\.config/waybar/#.config/hypr/waybar/#g' "$target_file" 2>/dev/null || true
      fi
    fi
  done || true
  # Fork: ModulesWorkspaces carries the user's workspace overlay, like UserModules.
  for BACKUP_FILEw in "$backup_dir/ModulesWorkspaces" "$backup_dir/UserModules"; do
    [ -f "$BACKUP_FILEw" ] && cp -f "$BACKUP_FILEw" "$new_dir/$(basename "$BACKUP_FILEw")"
  done

  # Ensure config and style.css exist and are valid symlinks; if broken or missing, point to defaults
  if [ ! -e "$new_dir/config" ]; then
    local chassis
    chassis="$(detect_waybar_config 2>/dev/null || echo "desktop")"
    local d_cfg="$new_dir/configs/TOP-Default"
    [ "$chassis" = "laptop" ] && d_cfg="$new_dir/configs/TOP-Default-Laptop"
    [ -f "$d_cfg" ] && rm -f "$new_dir/config" && ln -sf "$d_cfg" "$new_dir/config"
  fi
  if [ ! -e "$new_dir/style.css" ]; then
    local d_stl="$new_dir/style/Extra-Prismatic-Glow.css"
    [ -f "$d_stl" ] && rm -f "$new_dir/style.css" && ln -sf "$d_stl" "$new_dir/style.css"
  fi
}

# Detect a waybar directory whose configs/modules/styles still reference the
# pre-migration "$HOME/.config/waybar/" path, or whose config/style.css links
# are broken, missing, or pointing to stale locations.
_waybar_dir_has_stale_paths() {
  local dir="$1"
  [ -d "$dir" ] || return 1

  # 1. Check if config or style.css symlinks point to legacy path or are broken
  for link in "$dir/config" "$dir/style.css"; do
    if [ -L "$link" ]; then
      local tgt
      tgt="$(readlink "$link" 2>/dev/null || true)"
      if [[ "$tgt" == *".config/waybar"* ]] || [ ! -e "$link" ]; then
        return 0
      fi
    elif [ -f "$link" ]; then
      # Regular file with stale includes is stale
      if grep -rq '\.config/waybar/' "$link" 2>/dev/null; then
        return 0
      fi
    elif [ ! -e "$link" ]; then
      return 0
    fi
  done

  # 2. Check if any file content inside directory has stale .config/waybar references
  if grep -rq '\.config/waybar/' "$dir" 2>/dev/null; then
    return 0
  fi

  return 1
}

# Sync repo-managed Waybar files into an already-installed waybar directory
# without clobbering user-created files. Files shipped by the repo (Modules,
# Modules*, configs/, style/) are refreshed, but anything that only exists in
# the user's install is left in place because rsync runs without --delete.
# User-owned and runtime-generated content is excluded so it is never
# overwritten: UserModules, generated wallust colors, and the top-level
# config/style.css symlinks (the user's active layout/style selection).
_rsync_waybar_system_files() {
  local target_dir="$1"
  local source_dir="$2"
  local log="${3:-/dev/null}"

  [ -d "$source_dir" ] || return 1
  [ -d "$target_dir" ] || return 1

  # Fork: an existing ModulesWorkspaces is the user's workspace overlay.
  local extra_excludes=()
  [ -f "$target_dir/ModulesWorkspaces" ] && extra_excludes+=(--exclude='/ModulesWorkspaces')

  rsync -a \
    --exclude='/UserModules' \
    --exclude='/wallust/' \
    --exclude='/config' \
    --exclude='/style.css' \
    "${extra_excludes[@]}" \
    "$source_dir/" "$target_dir/" >>"$log" 2>&1
}

copy_waybar() {
  local log="$1"
  local run_mode="${2:-${RUN_MODE:-}}"
  local base="${DOTFILES_DIR:-.}"
  local config_root="${WORK_CONFIG_DIR:-$base/config}"
  local DIRW="waybar"
  local OLD_DIRPATHw="${XDG_CONFIG_HOME:-$HOME/.config}/$DIRW"
  local DIRPATHw="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/$DIRW"

  mkdir -p "$(dirname "$DIRPATHw")"

  # One-time migration: a pre-migration install has waybar at the legacy
  # top-level path (~/.config/waybar), but the new hypr-owned path
  # (~/.config/hypr/waybar) does not exist yet. Its configs/modules/styles
  # always reference the old "$HOME/.config/waybar/" path (correct for where
  # they used to live), which breaks the moment they're relocated to a new
  # parent directory -- so always back up, install a fresh repo copy, and
  # restore customizations on top. A bare relocate is never safe here.
  if [ -d "$OLD_DIRPATHw" ] && [ ! -d "$DIRPATHw" ]; then
    echo -e "${NOTE:-[NOTE]} - Detected legacy ${YELLOW:-}$OLD_DIRPATHw${RESET:-}; migrating it to ${YELLOW:-}$DIRPATHw${RESET:-}." 2>&1 | tee -a "$log"
    BACKUP_DIR=$(get_backup_dirname)
    cp -r "$OLD_DIRPATHw" "$OLD_DIRPATHw-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
    echo -e "${NOTE:-[NOTE]} - Backed up $DIRW to $OLD_DIRPATHw-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
    rm -rf "$OLD_DIRPATHw"
    cp -r "$config_root/hypr/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
    _restore_waybar_customizations "$DIRPATHw" "$OLD_DIRPATHw-backup-$BACKUP_DIR"
    echo -e "${OK:-[OK]} - Migrated ${YELLOW:-}$DIRW${RESET:-} config to ${YELLOW:-}$DIRPATHw${RESET:-}." 2>&1 | tee -a "$log"
    return 0
  fi

  if [ -d "$DIRPATHw" ]; then
    # Stale check runs first and bypasses both the express "keep existing"
    # shortcut and the interactive y/n prompt below: a directory with broken
    # path references (e.g. left behind by an earlier/interrupted copy of
    # this dotfiles version) is not something either mode should preserve.
    if _waybar_dir_has_stale_paths "$DIRPATHw"; then
      echo -e "${WARN:-[WARN]} - ${YELLOW:-}$DIRPATHw${RESET:-} still contains pre-migration path references (\$HOME/.config/waybar/...) from an earlier/interrupted copy; module includes and CSS imports are broken as a result. Repairing automatically." 2>&1 | tee -a "$log"
      BACKUP_DIR=$(get_backup_dirname)
      cp -r "$DIRPATHw" "$DIRPATHw-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
      echo -e "${NOTE:-[NOTE]} - Backed up $DIRW to $DIRPATHw-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
      rm -rf "$DIRPATHw" && cp -r "$config_root/hypr/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
      _restore_waybar_customizations "$DIRPATHw" "$DIRPATHw-backup-$BACKUP_DIR"
      echo -e "${OK:-[OK]} - Repaired stale ${YELLOW:-}$DIRW${RESET:-} config at ${YELLOW:-}$DIRPATHw${RESET:-} (runs regardless of express/upgrade mode since the old content was broken, not a preference)." 2>&1 | tee -a "$log"
      return 0
    fi

    if [ "$run_mode" = "express" ]; then
      # Express keeps the user's layout/style choice, but still refreshes the
      # repo-managed Waybar files so dotfiles updates (e.g. new modules) apply.
      echo -e "${NOTE:-[NOTE]} - Express mode: syncing system ${YELLOW:-}$DIRW${RESET:-} files (user-created files preserved)." 2>&1 | tee -a "$log"
      if _rsync_waybar_system_files "$DIRPATHw" "$config_root/hypr/$DIRW" "$log"; then
        echo -e "${OK:-[OK]} - Synced system ${YELLOW:-}$DIRW${RESET:-} files into ${YELLOW:-}$DIRPATHw${RESET:-}." 2>&1 | tee -a "$log"
      else
        echo -e "${WARN:-[WARN]} - ${YELLOW:-}$DIRW${RESET:-} system sync skipped (missing source or target)." 2>&1 | tee -a "$log"
      fi
      return 0
    fi
    while true; do
      echo -n "${CAT:-[ACTION]} Do you want to replace ${YELLOW:-}$DIRW${RESET:-} config? (y/n): "
      read DIR1_CHOICE
      case "$DIR1_CHOICE" in
      [Yy]*)
        BACKUP_DIR=$(get_backup_dirname)
        cp -r "$DIRPATHw" "$DIRPATHw-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
        echo -e "${NOTE:-[NOTE]} - Backed up $DIRW to $DIRPATHw-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
        rm -rf "$DIRPATHw" && cp -r "$config_root/hypr/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
        _restore_waybar_customizations "$DIRPATHw" "$DIRPATHw-backup-$BACKUP_DIR"
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
    cp -r "$config_root/hypr/$DIRW" "$DIRPATHw" 2>&1 | tee -a "$log"
    echo -e "${OK:-[OK]} - Copy completed for ${YELLOW:-}$DIRW${RESET:-}" 2>&1 | tee -a "$log"
  fi
}

copy_phase2() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  local config_root="${WORK_CONFIG_DIR:-$base/config}"
  local DIR="btop cava copyq hypr Kvantum nwg-dock-hyprland qt5ct qt6ct starship swappy wlogout yazi"
  local theme_state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/.theme-state-pre-copy"

  # copy_waybar() (called before copy_phase2) already placed the final
  # waybar content at ~/.config/hypr/waybar (fresh copy, or backed-up and
  # restored from an existing/legacy install). Since waybar now lives
  # underneath hypr/, the blanket "hypr" backup+recopy below would otherwise
  # discard that work and replace it with an untouched repo copy. Stash it
  # aside and put it back once the hypr copy is done.
  local hypr_waybar_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/waybar"
  local hypr_waybar_stash=""
  if [ -d "$hypr_waybar_dir" ]; then
    hypr_waybar_stash="$(mktemp -d "${TMPDIR:-/tmp}/kooldots-waybar-stash.XXXXXX")"
    mv "$hypr_waybar_dir" "$hypr_waybar_stash/waybar" 2>&1 | tee -a "$log"
  fi

  snapshot_theme_state "$theme_state_dir"
  stop_copyq_for_copy "$log"
  # After the stop, so the server has flushed its state into the dir first.
  local copyq_state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/.copyq-state-pre-copy"
  snapshot_copyq_state "$copyq_state_dir"
  for DIR_NAME in $DIR; do
    local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/$DIR_NAME"
    if [ -d "$DIRPATH" ]; then
      echo -e "\n${NOTE:-[NOTE]} - Config for ${YELLOW:-}$DIR_NAME${RESET:-} found, attempting to back up."
      BACKUP_DIR=$(get_backup_dirname)
      mv "$DIRPATH" "$DIRPATH-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
    fi
    if [ -d "$config_root/$DIR_NAME" ]; then
      cp -r "$config_root/$DIR_NAME/" "${XDG_CONFIG_HOME:-$HOME/.config}/$DIR_NAME" 2>&1 | tee -a "$log"
      if [ "$DIR_NAME" = "gtk-3.0" ] && [ -n "$BACKUP_DIR" ] && [ -f "$DIRPATH-backup-$BACKUP_DIR/settings.ini" ]; then
        cp -n "$DIRPATH-backup-$BACKUP_DIR/settings.ini" "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/settings.ini" 2>/dev/null || true
      fi
      echo "${OK:-[OK]} - Copy of config for ${YELLOW:-}$DIR_NAME${RESET:-} completed!" 2>&1 | tee -a "$log"
    else
      echo "${ERROR:-[ERROR]} - Directory config/$DIR_NAME does not exist to copy." 2>&1 | tee -a "$log"
    fi
  done
  restore_theme_state "$theme_state_dir" "$log"
  restore_copyq_state "$log" "$copyq_state_dir"
  start_copyq_after_copy "$log"

  if [ -n "$hypr_waybar_stash" ] && [ -d "$hypr_waybar_stash/waybar" ]; then
    rm -rf "$hypr_waybar_dir"
    mv "$hypr_waybar_stash/waybar" "$hypr_waybar_dir" 2>&1 | tee -a "$log"
    rmdir "$hypr_waybar_stash" 2>/dev/null || true
    echo -e "${NOTE:-[NOTE]} - Restored ${YELLOW:-}waybar${RESET:-} configuration (managed separately by copy_waybar())." 2>&1 | tee -a "$log"
  fi

  # Handle ~/.config/wallust like rofi migration:
  # keep wallust data under ~/.config/hypr/wallust and leave ~/.config/wallust empty
  local wallust_dir="${XDG_CONFIG_HOME:-$HOME/.config}/wallust"
  local hypr_wallust_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/wallust"
  if [ -d "$wallust_dir" ]; then
    if [ -n "$(ls -A "$wallust_dir" 2>/dev/null)" ]; then
      BACKUP_DIR=$(get_backup_dirname)
      mv "$wallust_dir" "$wallust_dir-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
      echo -e "${NOTE:-[NOTE]} - Backed up wallust to $wallust_dir-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
      mkdir -p "$wallust_dir" "$hypr_wallust_dir"
      rsync -a --ignore-existing "$wallust_dir-backup-$BACKUP_DIR/" "$hypr_wallust_dir/" 2>&1 | tee -a "$log" || true
      echo -e "${OK:-[OK]} - Migrated existing wallust files to ${YELLOW:-}$hypr_wallust_dir${RESET:-} and left ${YELLOW:-}$wallust_dir${RESET:-} empty." 2>&1 | tee -a "$log"
    fi
  else
    mkdir -p "$wallust_dir"
  fi
  # Clean up stale GTK-3 Wallust css overrides if present from older versions
  local gtk3_dir="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0"
  if [ -f "$gtk3_dir/colors-wallust.css" ]; then
    rm -f "$gtk3_dir/colors-wallust.css"
    if [ -f "$gtk3_dir/gtk.css" ]; then
      if ! grep -Ev '^[[:space:]]*(/\*.*\*/|@import[[:space:]]+[\x27"]colors-wallust\.css[\x27"];|[[:space:]]*)$' "$gtk3_dir/gtk.css" >/dev/null 2>&1; then
        rm -f "$gtk3_dir/gtk.css"
      else
        sed -i "/@import[[:space:]]*['\"]colors-wallust\.css['\"];/d" "$gtk3_dir/gtk.css" 2>/dev/null || true
      fi
    fi
  fi

  install_terminal_configs "$log"
}

# CopyQ keeps its server socket (.copyq_s) and lock file inside ~/.config/copyq.
# copy_phase2 renames that directory to a backup and copies a fresh one in; a
# server still running through that keeps the old socket inode and nobody can
# reach it any more -- every client, the keybind and the server's own clipboard
# monitor fail with "Cannot connect to server" while the unit looks healthy.
# So the server is stopped before the rename (it flushes its tabs and geometry
# into the old dir, which restore_copyq_state carries over) and started again
# once the new directory is in place.
COPYQ_WAS_ACTIVE=0
COPYQ_WAS_LEGACY=0

copyq_user_manager_reachable() {
  command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1
}

stop_copyq_for_copy() {
  local log="$1"
  COPYQ_WAS_ACTIVE=0
  COPYQ_WAS_LEGACY=0
  if copyq_user_manager_reachable && systemctl --user is-active --quiet copyq.service 2>/dev/null; then
    echo "${NOTE:-[NOTE]} - stopping copyq.service while its config directory is replaced." 2>&1 | tee -a "$log"
    if systemctl --user stop copyq.service >>"$log" 2>&1; then
      COPYQ_WAS_ACTIVE=1
    else
      echo "${WARN:-[WARN]} - could not stop copyq.service; restart it by hand after the upgrade." 2>&1 | tee -a "$log"
    fi
  elif command -v copyq >/dev/null 2>&1 && pgrep -u "$UID" -x copyq >/dev/null 2>&1; then
    echo "${NOTE:-[NOTE]} - asking the running copyq server to exit while its config directory is replaced." 2>&1 | tee -a "$log"
    timeout 5 copyq exit >>"$log" 2>&1 || true
    COPYQ_WAS_LEGACY=1
  fi
}

start_copyq_after_copy() {
  local log="$1"
  if [ "$COPYQ_WAS_ACTIVE" -eq 1 ]; then
    if systemctl --user start copyq.service >>"$log" 2>&1; then
      echo "${OK:-[OK]} - copyq.service started again on the new config directory." 2>&1 | tee -a "$log"
    else
      echo "${WARN:-[WARN]} - copyq.service failed to start; see systemctl --user status copyq.service" 2>&1 | tee -a "$log"
    fi
  elif [ "$COPYQ_WAS_LEGACY" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} - copyq will come back with hyprland-session.target (install_session_units) or at next login." 2>&1 | tee -a "$log"
  fi
}

# Snapshot this run's CopyQ state (encryption keypair, commands, settings,
# themes) before copy_phase2 replaces the directory. Restoring from a snapshot
# taken here, rather than from whichever copyq-backup-* is newest by mtime,
# guarantees the keys that come back are the ones that were just in use.
snapshot_copyq_state() {
  local state_dir="$1"
  local copyq_dir="$HOME/.config/copyq"
  rm -rf "$state_dir"
  [ -d "$copyq_dir" ] || return 0
  mkdir -p "$state_dir"

  local source_path
  for source_path in "$copyq_dir"/* "$copyq_dir"/.[!.]*; do
    [ -e "$source_path" ] || continue
    case "$(basename "$source_path")" in
    copyq.lock | .copyq_s) continue ;;
    esac
    cp -a "$source_path" "$state_dir/" || true
  done
}

restore_copyq_state() {
  local log="$1"
  local state_dir="$2"
  local copyq_dir="$HOME/.config/copyq"

  [ -n "$state_dir" ] && [ -d "$state_dir" ] || return 0
  [ -d "$copyq_dir" ] || return 0

  # copyq.conf included: settings changed in the app win over the repo default,
  # which only applies when there was no previous config.
  local restored_any=0
  local source_path
  for source_path in "$state_dir"/* "$state_dir"/.[!.]*; do
    [ -e "$source_path" ] || continue
    local file_name
    file_name=$(basename "$source_path")
    rm -rf "${copyq_dir:?}/$file_name"
    cp -a "$source_path" "$copyq_dir/$file_name" 2>&1 | tee -a "$log"
    restored_any=1
  done

  chmod 600 "$copyq_dir/copyq.sec" "$copyq_dir/copyq.pub" 2>/dev/null || true

  # Report, don't fail: copy.sh runs under set -e, and aborting here would
  # leave the rest of the install half-done. The snapshot is kept on mismatch.
  local key keys_ok=1
  for key in copyq.sec copyq.pub; do
    [ -f "$state_dir/$key" ] || continue
    if ! cmp -s "$state_dir/$key" "$copyq_dir/$key"; then
      echo "${ERROR:-[ERROR]} - CopyQ encryption key $key was not restored intact; encrypted tabs will not open. A copy is kept at $state_dir/$key." 2>&1 | tee -a "$log"
      keys_ok=0
    fi
  done

  if [ "$restored_any" -eq 1 ]; then
    echo "${OK:-[OK]} - Restored CopyQ state (keys, commands, settings) from pre-copy snapshot." 2>&1 | tee -a "$log"
  fi
  [ "$keys_ok" -eq 1 ] && rm -rf "$state_dir"
  return 0
}

# Sync repo-managed quickshell files into an already-installed quickshell
# directory without clobbering user-created content. Because rsync runs
# without --delete, repo files are refreshed while user-only files and
# directories (e.g. custom quickshell apps) are left untouched. The
# user-tunable/runtime files config.json and qml_color.json are preserved when
# present so a user's shell settings and generated theme colors are not reset
# on upgrade. A non-destructive safety copy is taken first.
sync_quickshell_config() {
  local log="${1:-/dev/null}"
  local base="${DOTFILES_DIR:-.}"
  local config_root="${WORK_CONFIG_DIR:-$base/config}"
  local src_dir="$config_root/quickshell"
  local dest_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"

  [ -d "$src_dir" ] || return 1
  mkdir -p "$dest_dir"

  # Non-destructive safety copy so nothing is ever unrecoverable.
  local BACKUP_DIR
  BACKUP_DIR=$(get_backup_dirname)
  if [ -n "$(ls -A "$dest_dir" 2>/dev/null)" ] && [ ! -d "${dest_dir}-backup-$BACKUP_DIR" ]; then
    cp -r "$dest_dir" "${dest_dir}-backup-$BACKUP_DIR" 2>&1 | tee -a "$log"
    echo "${NOTE:-[NOTE]} - Backed up quickshell to ${dest_dir}-backup-$BACKUP_DIR." 2>&1 | tee -a "$log"
  fi

  # Refresh repo-managed files; exclude user-tunable/runtime files that exist.
  local rsync_args=(-a)
  local f
  for f in config.json qml_color.json; do
    if [ -f "$dest_dir/$f" ]; then
      rsync_args+=(--exclude="/$f")
    fi
  done

  if rsync "${rsync_args[@]}" "$src_dir/" "$dest_dir/" 2>&1 | tee -a "$log"; then
    echo "${OK:-[OK]} - Synced ${YELLOW:-}quickshell${RESET:-} files (user custom apps preserved)." 2>&1 | tee -a "$log"
  else
    echo "${ERROR:-[ERROR]} - Failed to sync ${YELLOW:-}quickshell${RESET:-} config." 2>&1 | tee -a "$log"
    return 1
  fi

  # Install defaults for preserved files only when they are missing.
  for f in config.json qml_color.json; do
    if [ ! -f "$dest_dir/$f" ] && [ -f "$src_dir/$f" ]; then
      cp -f "$src_dir/$f" "$dest_dir/$f" 2>&1 | tee -a "$log"
    fi
  done

  # Ensure overview and qs-hyprview subdirectories exist if missing.
  local sub
  for sub in overview qs-hyprview; do
    if [ ! -d "$dest_dir/$sub" ] && [ -d "$src_dir/$sub" ]; then
      echo "${INFO:-[INFO]} - Copying quickshell $sub config..." 2>&1 | tee -a "$log"
      cp -r "$src_dir/$sub" "$dest_dir/" 2>&1 | tee -a "$log"
    fi
  done

  return 0
}

# Fresh install default: enable Hyprland Lua entrypoint (next release is Lua-only).
enable_fresh_install_lua_config() {
  local log="${1:-/dev/null}"
  local hypr_dir
  local src_entry
  local base="${DOTFILES_DIR:-.}"
  local config_root="${WORK_CONFIG_DIR:-$base/config}"
  hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  src_entry="$config_root/hypr/hyprland.lua"
  if [ ! -f "$src_entry" ] && [ -f "$config_root/hypr/hyprland.lua.disable" ]; then
    src_entry="$config_root/hypr/hyprland.lua.disable"
  fi

  mkdir -p "$hypr_dir"

  if [ -f "$hypr_dir/hyprland.lua" ]; then
    rm -f "$hypr_dir/hyprland.lua.disable" 2>/dev/null || true
    echo "${OK:-[OK]} - Fresh install: Hyprland Lua entrypoint already enabled." 2>&1 | tee -a "$log"
    return 0
  fi

  if [ -f "$hypr_dir/hyprland.lua.disable" ]; then
    mv -f "$hypr_dir/hyprland.lua.disable" "$hypr_dir/hyprland.lua"
    echo "${OK:-[OK]} - Fresh install: enabled default Hyprland Lua config (hyprland.lua)." 2>&1 | tee -a "$log"
    return 0
  fi

  if [ -f "$src_entry" ]; then
    cp -f "$src_entry" "$hypr_dir/hyprland.lua"
    echo "${OK:-[OK]} - Fresh install: installed default Hyprland Lua entrypoint from repo template." 2>&1 | tee -a "$log"
    return 0
  fi

  echo "${WARN:-[WARN]} - Fresh install: no hyprland.lua template found; left Hyprlang entrypoint as-is." 2>&1 | tee -a "$log"
  return 1
}

# Run scripts/migrate-hypr-to-lua.sh after upgrade restores when approved.
migrate_hypr_to_lua_if_needed() {
  local log="${1:-/dev/null}"
  local migrate_flag="${2:-${MIGRATE_HYPR_TO_LUA:-0}}"
  local base="${DOTFILES_DIR:-.}"
  local config_root="${WORK_CONFIG_DIR:-$base/config}"
  local migrate_script="$base/scripts/migrate-hypr-to-lua.sh"
  local hypr_dir
  hypr_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"

  if [ "$migrate_flag" != "1" ]; then
    echo "${NOTE:-[NOTE]} - LUA migration skipped by user choice." 2>&1 | tee -a "$log"
    return 0
  fi

  if [ ! -x "$migrate_script" ] && [ -f "$migrate_script" ]; then
    chmod +x "$migrate_script" 2>/dev/null || true
  fi

  if [ ! -f "$migrate_script" ]; then
    echo "${ERROR:-[ERROR]} - Migration script not found: $migrate_script" 2>&1 | tee -a "$log"
    return 1
  fi

  echo "${INFO:-[INFO]} - Migrating Hyprlang configuration to LUA via migrate-hypr-to-lua.sh..." 2>&1 | tee -a "$log"
  if "$migrate_script" --yes 2>&1 | tee -a "$log"; then
    echo "${OK:-[OK]} - Hyprland configuration migrated to LUA." 2>&1 | tee -a "$log"
    return 0
  fi

  echo "${ERROR:-[ERROR]} - LUA migration failed. Hyprlang config may still be active." 2>&1 | tee -a "$log"
  if [ -f "$hypr_dir/hyprland.lua.disable" ] && [ ! -f "$hypr_dir/hyprland.lua" ]; then
    echo "${NOTE:-[NOTE]} - Lua entrypoint remains disabled at $hypr_dir/hyprland.lua.disable" 2>&1 | tee -a "$log"
  fi
  return 1
}

ensure_lua_keybinds() {
  local log="$1"
  local base="${DOTFILES_DIR:-.}"
  local config_root="${WORK_CONFIG_DIR:-$base/config}"
  local src_root="$config_root/hypr"
  local dst_root="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  local copied=0
  local rel_dir src_dir src_file rel_path dst_file

  for rel_dir in configs UserConfigs lua; do
    src_dir="$src_root/$rel_dir"
    [ -d "$src_dir" ] || continue

    while IFS= read -r -d '' src_file; do
      rel_path="${src_file#$src_root/}"
      dst_file="$dst_root/$rel_path"

      # UserConfigs are protected: only add missing templates
      if [ "$rel_dir" = "UserConfigs" ]; then
        if [ ! -f "$dst_file" ]; then
          mkdir -p "$(dirname "$dst_file")"
          if cp -f "$src_file" "$dst_file" 2>&1 | tee -a "$log"; then
            copied=1
            echo "${NOTE:-[NOTE]} - Added missing user config template: ${YELLOW:-}$rel_path${RESET:-}" 2>&1 | tee -a "$log"
          else
            echo "${ERROR:-[ERROR]} - Failed to add missing user config template: ${YELLOW:-}$rel_path${RESET:-}" 2>&1 | tee -a "$log"
          fi
        fi
      else
        # System directories (configs, lua): always sync/overwrite from repo
        mkdir -p "$(dirname "$dst_file")"
        if cp -f "$src_file" "$dst_file" 2>&1 | tee -a "$log"; then
          copied=1
          echo "${NOTE:-[NOTE]} - Synced system file: ${YELLOW:-}$rel_path${RESET:-}" 2>&1 | tee -a "$log"
        else
          echo "${ERROR:-[ERROR]} - Failed to sync system file: ${YELLOW:-}$rel_path${RESET:-}" 2>&1 | tee -a "$log"
        fi
      fi
    # display-layouts.json rides along with the Lua templates: it is a
    # UserConfigs file like the rest, and UserConfigs are only ever ADDED when
    # missing, so a user's saved display layouts are never overwritten.
    done < <(find "$src_dir" -maxdepth 1 -type f \
                  \( -name '*.lua' -o -name 'display-layouts.json' \) -print0)
  done

  # Sync root-level lua metadata and config files if present
  for root_lua in "$src_root"/*.lua; do
    [ -f "$root_lua" ] || continue
    local root_lua_name
    root_lua_name="$(basename "$root_lua")"
    if [ "$root_lua_name" != "hyprland.lua.disable" ]; then
      cp -f "$root_lua" "$dst_root/$root_lua_name" 2>&1 | tee -a "$log" || true
    fi
  done

  # Ensure canonical system window rules delegate to lua/window_rules.lua (all 93 rules)
  local sys_win_rules="$dst_root/configs/system_window_rules.lua"
  local src_win_rules="$src_root/configs/system_window_rules.lua"
  if [ -f "$src_win_rules" ]; then
    if [ ! -f "$sys_win_rules" ] || grep -q "No active window rules were found" "$sys_win_rules" 2>/dev/null || ! grep -q "window_rules\.lua" "$sys_win_rules" 2>/dev/null; then
      cp -f "$src_win_rules" "$sys_win_rules" 2>&1 | tee -a "$log" || true
      echo "${OK:-[OK]} - Ensured canonical system window rules: ${YELLOW:-}configs/system_window_rules.lua${RESET:-}" 2>&1 | tee -a "$log"
    fi
  fi

  # Patch existing user and system lua configs to fix startup readiness race condition
  for f in "$dst_root/UserConfigs"/*.lua "$dst_root/configs"/*.lua "$dst_root/lua"/*.lua; do
    [ -f "$f" ] || continue
    if grep -q 'break 2;' "$f" 2>/dev/null; then
      sed -i 's/break 2;/break;/g' "$f"
    fi
  done

  if [ "$copied" -eq 1 ]; then
    echo "${OK:-[OK]} - Lua files sync completed." 2>&1 | tee -a "$log"
  else
    echo "${INFO:-[INFO]} - Lua files check: up to date." 2>&1 | tee -a "$log"
  fi
}

# Carry the active rofi theme selection from a backup config.rasi into the
# freshly copied one.
#
# RofiThemeSelector.sh records the choice by appending `@theme "<path>"` to
# config.rasi and commenting the previous line out, so the selection lives in a
# file the installer replaces. That file is deliberately NOT restored wholesale:
# it also carries the `@import` lines a newer release may add. Only the one
# active `@theme` line is moved across.
_carry_rofi_theme_selection() {
  local new_config="$1" backup_config="$2" log="${3:-/dev/null}"
  local active name tmp

  [ -f "$new_config" ] || return 0
  [ -f "$backup_config" ] || return 0

  # The active theme is the LAST uncommented @theme line; a commented-out one
  # starts with `//` and is not matched here.
  active="$(grep -E '^[[:space:]]*@theme[[:space:]]' "$backup_config" 2>/dev/null | tail -n1 || true)"
  [ -n "$active" ] || return 0

  if [ "$(grep -E '^[[:space:]]*@theme[[:space:]]' "$new_config" 2>/dev/null | tail -n1 || true)" = "$active" ]; then
    return 0
  fi

  tmp="$(mktemp)" || return 1
  if awk -v line="$active" '
        !/^[[:space:]]*@theme[[:space:]]/ { print }
        END { print ""; print line }
      ' "$new_config" >"$tmp"; then
    cat "$tmp" >"$new_config"
    rm -f "$tmp"
    name="${active#*\"}"
    name="${name%\"}"
    name="$(basename "$name" .rasi)"
    echo "${OK:-[OK]} - Preserved the rofi theme selection: ${MAGENTA:-}$name${RESET:-}" 2>&1 | tee -a "$log"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# Restore Animations and Monitor Profiles plus key hypr files from backup
restore_hypr_assets() {
  local log="$1"
  local express_mode="$2"
  local base="${DOTFILES_DIR:-.}"
  local config_root="${WORK_CONFIG_DIR:-$base/config}"

  local HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  # Not `local`: see the note on get_backup_dirname. Shadowing the variable makes
  # this look for a backup suffix that no backup was created with.
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_HYPR_PATH="$HYPR_DIR-backup-$BACKUP_DIR"

  if [ -d "$BACKUP_HYPR_PATH" ]; then
    local backup_mode="conf"
    local backup_lua_entry="$BACKUP_HYPR_PATH/hyprland.lua"
    local backup_lua_disabled="$BACKUP_HYPR_PATH/hyprland.lua.disable"
    if [ -f "$backup_lua_entry" ]; then
      backup_mode="lua"
    elif [ -f "$backup_lua_disabled" ]; then
      # Explicit conf marker used by migrate-hypr-to-lua.sh while Lua is disabled.
      backup_mode="conf"
    fi

    # Preserve Lua entrypoint only when the backup was already using Lua mode.
    # Do not auto-enable or disable Lua on fresh install (handled by enable_fresh_install_lua_config).
    local LUA_ENTRY_TEMPLATE="$config_root/hypr/hyprland.lua"
    if [ ! -f "$LUA_ENTRY_TEMPLATE" ] && [ -f "$config_root/hypr/hyprland.lua.disable" ]; then
      LUA_ENTRY_TEMPLATE="$config_root/hypr/hyprland.lua.disable"
    fi
    if [ "${RUN_MODE:-}" != "install" ]; then
      if [ "$backup_mode" = "lua" ]; then
        if [ -f "$LUA_ENTRY_TEMPLATE" ]; then
          cp -f "$LUA_ENTRY_TEMPLATE" "$HYPR_DIR/hyprland.lua" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}hyprland.lua${RESET:-} (lua mode preserved from repo template)" 2>&1 | tee -a "$log"
        elif [ -f "$BACKUP_HYPR_PATH/hyprland.lua" ] && ! grep -Eq 'autogenerated[[:space:]]*=[[:space:]]*true' "$BACKUP_HYPR_PATH/hyprland.lua" 2>/dev/null; then
          # A Hyprland-autogenerated stub is not the user's config; never restore it.
          cp -f "$BACKUP_HYPR_PATH/hyprland.lua" "$HYPR_DIR/hyprland.lua" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - Restored file: ${MAGENTA:-}hyprland.lua${RESET:-} (lua mode preserved from backup)" 2>&1 | tee -a "$log"
        fi
      else
        rm -f "$HYPR_DIR/hyprland.lua" 2>/dev/null || true
        echo "${NOTE:-[NOTE]} - Conf mode detected; skipping Lua entrypoint restore." 2>&1 | tee -a "$log"
      fi
    fi

    if [ "$express_mode" -eq 1 ]; then
      echo "${NOTE:-[NOTE]} Express mode: preserving existing wallpaper effects from backup and skipping animations/monitor profile restores." 2>&1 | tee -a "$log"
      local BACKUP_WALLPAPER_DIR="$BACKUP_HYPR_PATH/wallpaper_effects"
      if [ -d "$BACKUP_WALLPAPER_DIR" ]; then
        rm -rf "$HYPR_DIR/wallpaper_effects"
        cp -r "$BACKUP_WALLPAPER_DIR" "$HYPR_DIR/" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - Restored directory: ${MAGENTA:-}wallpaper_effects${RESET:-}" 2>&1 | tee -a "$log"
      fi
      if [ -f "$BACKUP_HYPR_PATH/.initial_startup_done" ]; then
        cp -f "$BACKUP_HYPR_PATH/.initial_startup_done" "$HYPR_DIR/.initial_startup_done" 2>&1 | tee -a "$log"
        echo "${OK:-[OK]} - Preserved initial startup marker to avoid first-boot resets." 2>&1 | tee -a "$log"
      fi
    else
      echo -e "\n${NOTE:-[NOTE]} Restoring ${SKY_BLUE:-}Animations & Monitor Profiles${RESET:-} into ${YELLOW:-}$HYPR_DIR${RESET:-}..."

      # Fresh installs should apply repo defaults; do not restore a previous wallpaper.
      # RUN_MODE is set by copy.sh (install|upgrade|express) and is visible here.
      # Note: animations is a system directory and remains managed by dotfiles (not restored from backup).
      local DIR_B=("Monitor_Profiles")
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

    # Restore custom Rofi themes and configurations from backup
    local BACKUP_ROFI_DIR="$BACKUP_HYPR_PATH/rofi"
    if [ ! -d "$BACKUP_ROFI_DIR" ] && [ -d "${HYPR_DIR}-${BACKUP_DIR}/rofi" ]; then
      BACKUP_ROFI_DIR="${HYPR_DIR}-${BACKUP_DIR}/rofi"
    fi

    if [ -d "$BACKUP_ROFI_DIR" ]; then
      # 1. Restore custom themes in rofi/themes/
      if [ -d "$BACKUP_ROFI_DIR/themes" ]; then
        mkdir -p "$HYPR_DIR/rofi/themes"
        for theme_file in "$BACKUP_ROFI_DIR/themes"/*; do
          [ -e "$theme_file" ] || continue
          local theme_name
          theme_name="$(basename "$theme_file")"
          if [ ! -e "$HYPR_DIR/rofi/themes/$theme_name" ]; then
            cp -r "$theme_file" "$HYPR_DIR/rofi/themes/$theme_name" 2>&1 | tee -a "$log" || true
            echo "${OK:-[OK]} - Restored custom rofi theme: ${MAGENTA:-}$theme_name${RESET:-}" 2>&1 | tee -a "$log"
          fi
        done
      fi

      # 2. Restore any custom/extra files in rofi/ root
      for rofi_file in "$BACKUP_ROFI_DIR"/*; do
        [ -e "$rofi_file" ] || continue
        [ -d "$rofi_file" ] && continue
        local rname
        rname="$(basename "$rofi_file")"
        if [ ! -e "$HYPR_DIR/rofi/$rname" ]; then
          cp -r "$rofi_file" "$HYPR_DIR/rofi/$rname" 2>&1 | tee -a "$log" || true
          echo "${OK:-[OK]} - Restored custom rofi file: ${MAGENTA:-}$rname${RESET:-}" 2>&1 | tee -a "$log"
        fi
      done

      # 3. Carry the active theme selection into the freshly copied config.rasi.
      #    The file itself is the repo's, so a newer release's imports survive;
      #    only the @theme line the theme picker wrote is moved across.
      _carry_rofi_theme_selection "$HYPR_DIR/rofi/config.rasi" "$BACKUP_ROFI_DIR/config.rasi" "$log"
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
    if [ "${RUN_MODE:-}" != "install" ]; then
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
    fi
  fi
}

# Restore the user's wlogout theme selection after copy_phase2 has replaced
# ~/.config/wlogout with the repo copy.
#
# RofiWlogoutTheme.sh records the choice in .current_theme and applies it by
# copying that theme's style.css, layout and icons over the active ones. Both
# the record and the applied files live under the directory the installer
# replaces, so without this an upgrade silently reverts wlogout to the default
# theme. The repo copy stays the base - a newer release may ship new presets -
# and the saved selection is re-applied on top of it.
restore_wlogout_selection() {
  local log="${1:-/dev/null}"
  local cfg_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local WLOGOUT_DIR="$cfg_home/wlogout"
  # Not `local`: see the note on get_backup_dirname.
  BACKUP_DIR="$(get_backup_dirname)"
  local backup="$WLOGOUT_DIR-backup-$BACKUP_DIR"

  [ -d "$WLOGOUT_DIR" ] || return 0
  [ -d "$backup" ] || return 0

  # A saved custom config and the blur preference are the user's, not the
  # repo's, and both live under the directory that was just replaced.
  if [ -d "$backup/themes/user_backup" ]; then
    mkdir -p "$WLOGOUT_DIR/themes"
    cp -rf "$backup/themes/user_backup" "$WLOGOUT_DIR/themes/" 2>&1 | tee -a "$log" || true
    echo "${OK:-[OK]} - Preserved the saved wlogout config (user_backup)." 2>&1 | tee -a "$log"
  fi
  if [ -f "$backup/.blur_radius" ]; then
    cp -f "$backup/.blur_radius" "$WLOGOUT_DIR/.blur_radius" 2>&1 | tee -a "$log" || true
  fi

  local theme=""
  if [ -f "$backup/.current_theme" ]; then
    theme="$(head -n1 "$backup/.current_theme" 2>/dev/null | tr -d '[:space:]')"
  fi
  if [ -z "$theme" ] || [ "$theme" = "default" ]; then
    return 0
  fi

  local applier="$cfg_home/hypr/scripts/RofiWlogoutTheme.sh"
  if [ ! -f "$applier" ]; then
    echo "${WARN:-[WARN]} - $applier is missing; wlogout is back on the default theme." 2>&1 | tee -a "$log"
    return 0
  fi

  local rc=0
  bash "$applier" --set "$theme" --silent >>"$log" 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "${OK:-[OK]} - Re-applied the wlogout theme: ${MAGENTA:-}$theme${RESET:-}" 2>&1 | tee -a "$log"
  else
    echo "${WARN:-[WARN]} - Could not re-apply the wlogout theme '$theme'; it is back on the default." 2>&1 | tee -a "$log"
  fi
  return 0
}

restore_user_configs() {
  local log="$1"
  local express_mode="$2"
  local old_version="$3"

  local DIRPATH="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  # Not `local`: see the note on get_backup_dirname.
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH="$DIRPATH-backup-$BACKUP_DIR/UserConfigs"

  if [ -z "$BACKUP_DIR" ]; then
    echo "${ERROR:-[ERROR]} - Backup directory name is empty. Exiting." 2>&1 | tee -a "$log"
    exit 1
  fi

  if [ "${RUN_MODE:-}" = "install" ]; then
    if [ -d "$BACKUP_DIR_PATH" ]; then
      echo "${NOTE:-[NOTE]} Preserving existing UserConfigs directory during install." 2>&1 | tee -a "$log"
      rsync -a "$BACKUP_DIR_PATH/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - UserConfigs directory preserved." 2>&1 | tee -a "$log"
    elif [ -d "${DIRPATH}-${BACKUP_DIR}/UserConfigs" ]; then
      echo "${NOTE:-[NOTE]} Preserving existing UserConfigs directory during install." 2>&1 | tee -a "$log"
      rsync -a "${DIRPATH}-${BACKUP_DIR}/UserConfigs/" "$DIRPATH/UserConfigs/" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - UserConfigs directory preserved." 2>&1 | tee -a "$log"
    fi
    return
  fi

  if [ -d "$BACKUP_DIR_PATH" ]; then
    echo -e "${NOTE:-[NOTE]} Restoring previous ${MAGENTA:-}User-Configs${RESET:-}... " 2>&1 | tee -a "$log"
    if [ "$express_mode" -eq 1 ]; then
      echo "${NOTE:-[NOTE]} Express mode: restoring UserConfigs directory automatically." 2>&1 | tee -a "$log"
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
  fi
}

restore_user_scripts() {
  local log="$1"
  local express_mode="$2"

  local DIRSHPATH="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
  # Not `local`: see the note on get_backup_dirname.
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH_S="$DIRSHPATH-backup-$BACKUP_DIR/UserScripts"

  # Fork: repo-owned wrappers that live in UserScripts (they pin this config's
  # paths and are not meant to be edited). Restoring a backup copy over the
  # one this release ships would silently revert wrapper fixes.
  local REPO_OWNED_SCRIPTS=("ScreenHackSelect.sh" "ScreenHackShots.sh")
  local RSYNC_EXCLUDES=() SCRIPT_NAME
  for SCRIPT_NAME in "${REPO_OWNED_SCRIPTS[@]}"; do
    RSYNC_EXCLUDES+=(--exclude "$SCRIPT_NAME")
  done

  if [ -z "$BACKUP_DIR" ]; then
    return 0
  fi

  # Check alternate backup path used by prepare_fresh_install_hypr
  if [ ! -d "$BACKUP_DIR_PATH_S" ] && [ -d "${DIRSHPATH}-${BACKUP_DIR}/UserScripts" ]; then
    BACKUP_DIR_PATH_S="${DIRSHPATH}-${BACKUP_DIR}/UserScripts"
  fi

  if [ ! -d "$BACKUP_DIR_PATH_S" ]; then
    return 0
  fi

  if [ "${RUN_MODE:-}" = "install" ]; then
    echo "${NOTE:-[NOTE]} Preserving existing UserScripts directory during install." 2>&1 | tee -a "$log"
    rsync -a "${RSYNC_EXCLUDES[@]}" "$BACKUP_DIR_PATH_S/" "$DIRSHPATH/UserScripts/" 2>&1 | tee -a "$log"
    echo "${OK:-[OK]} - UserScripts directory preserved." 2>&1 | tee -a "$log"
    chmod +x "$DIRSHPATH/UserScripts/"* 2>/dev/null || true
    return 0
  fi

  echo -e "${NOTE:-[NOTE]} Restoring previous ${MAGENTA:-}User-Scripts${RESET:-}... " 2>&1 | tee -a "$log"

  if [ "$express_mode" -eq 1 ]; then
    echo "${NOTE:-[NOTE]} Restoring UserScripts directory automatically." 2>&1 | tee -a "$log"
    rsync -a "${RSYNC_EXCLUDES[@]}" "$BACKUP_DIR_PATH_S/" "$DIRSHPATH/UserScripts/" 2>&1 | tee -a "$log"
    echo "${OK:-[OK]} - UserScripts directory restored." 2>&1 | tee -a "$log"
  else
    read -r -p "${CAT:-[ACTION]} Do you want to restore your previous UserScripts directory? (Y/n): " restore_userscripts_dir
    if [[ "$restore_userscripts_dir" != [Nn]* ]]; then
      echo "${NOTE:-[NOTE]} Restoring UserScripts directory..." 2>&1 | tee -a "$log"
      rsync -a "${RSYNC_EXCLUDES[@]}" "$BACKUP_DIR_PATH_S/" "$DIRSHPATH/UserScripts/" 2>&1 | tee -a "$log"
      echo "${OK:-[OK]} - UserScripts directory restored." 2>&1 | tee -a "$log"
    else
      echo "${NOTE:-[NOTE]} - Skipped restoring UserScripts." 2>&1 | tee -a "$log"
    fi
  fi

  chmod +x "$DIRSHPATH/UserScripts/"* 2>/dev/null || true
}

restore_terminal_configs() {
  local log="$1"
  local express_mode="$2"

  local GHOSTTY_DIR="${XDG_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}/ghostty"
  # Not `local`: see the note on get_backup_dirname.
  BACKUP_DIR=$(get_backup_dirname)
  local GHOSTTY_BACKUP="$GHOSTTY_DIR-backup-$BACKUP_DIR"

  if [ -d "$GHOSTTY_BACKUP" ]; then
    if [ "$express_mode" -eq 1 ]; then
      echo "${NOTE:-[NOTE]} Express mode: automatically preserving Ghostty config from backup." 2>&1 | tee -a "$log"
      rm -rf "$GHOSTTY_DIR"
      cp -a "$GHOSTTY_BACKUP" "$GHOSTTY_DIR" 2>&1 | tee -a "$log"
      return
    fi

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
  # Not `local`: see the note on get_backup_dirname.
  BACKUP_DIR=$(get_backup_dirname)
  local BACKUP_DIR_PATH_F="$DIRPATH-backup-$BACKUP_DIR"
  local FILES_2_RESTORE=("hyprlock.conf" "hypridle.conf")
  # Fork: a managed hypridle.conf is generated, so its backup is parked, not restored.
  local MANAGED_IDLE=0
  if idle_policy_is_managed; then
    MANAGED_IDLE=1
    FILES_2_RESTORE=("hyprlock.conf")
    park_hypridle_backup "$log" "$BACKUP_DIR_PATH_F"
  fi

  if [ -d "$BACKUP_DIR_PATH_F" ]; then
    if [ "$express_mode" -eq 1 ]; then
      echo "${NOTE:-[NOTE]} Express mode: automatically preserving hyprlock.conf and hypridle.conf from backup." 2>&1 | tee -a "$log"
      for FILE_RESTORE in "${FILES_2_RESTORE[@]}"; do
        local BACKUP_FILE="$BACKUP_DIR_PATH_F/$FILE_RESTORE"
        if [ -f "$BACKUP_FILE" ]; then
          cp -f "$BACKUP_FILE" "$DIRPATH/$FILE_RESTORE" 2>&1 | tee -a "$log"
        fi
      done
      [ "$MANAGED_IDLE" -eq 0 ] && migrate_hypridle_lock_cmd "$log"
      return 0
    fi

    local has_any=0
    for FILE_RESTORE in "${FILES_2_RESTORE[@]}"; do
      [ -f "$BACKUP_DIR_PATH_F/$FILE_RESTORE" ] && has_any=1
    done
    if [ "$has_any" -eq 1 ]; then
      echo -e "\n${NOTE:-[NOTE]} Preserving customized hyprlock.conf / hypridle.conf from backup..." 2>&1 | tee -a "$log"
      for FILE_RESTORE in "${FILES_2_RESTORE[@]}"; do
        local BACKUP_FILE="$BACKUP_DIR_PATH_F/$FILE_RESTORE"
        if [ -f "$BACKUP_FILE" ]; then
          cp -f "$BACKUP_FILE" "$DIRPATH/$FILE_RESTORE" 2>&1 | tee -a "$log"
          echo "${OK:-[OK]} - Preserved previous $FILE_RESTORE from backup." 2>&1 | tee -a "$log"
        fi
      done
    fi
    [ "$MANAGED_IDLE" -eq 0 ] && migrate_hypridle_lock_cmd "$log"
  fi
  return 0
}
# Startup lines that moved out of the user overlay. Session bring-up and
# compositor-state lines are owned by the vendor startup config,
# and long-lived daemons are systemd user units under hyprland-session.target
# (docs/adr/run-session-daemons-as-systemd-user-units.md). Strip the user's
# copies so nothing runs twice. A daemon line is only stripped when its unit was
# actually enabled on this host (the list install_session_units built), so a
# host without the program keeps its exec-once.
migrate_startup_overlay() {
  local log="$1"
  local enabled=" ${2:-} "
  # Lua user layer: commands are string entries of the startup_commands table
  # or exec_once("...") calls. migrate_hypr_to_lua_if_needed has already
  # converted any restored Startup_Apps.conf into this file.
  local user_startup="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/UserConfigs/user_startup.lua"
  local re_entry='^[[:space:]]*"(.*)",?[[:space:]]*$'
  local re_call='^[[:space:]]*exec_once\([[:space:]]*"(.*)"[[:space:]]*\)[[:space:]]*;?[[:space:]]*$'

  [ -f "$user_startup" ] || return 0

  # Fixed substrings that identify a vendor session line regardless of
  # how it was spelled (the uwsm finalize wrapper is a `sh -c`).
  local -a owned_substrings=(
    'uwsm finalize'
    'start hyprland-session.target'
    'dbus-update-activation-environment'
    'import-environment'
  )
  # "command-basename|required substring" pairs for vendor session lines.
  local -a owned_commands=(
    'hyprpm|reload'
    'KeybindsLayoutInit.sh|'
    'HideXwaylandBridge.sh|'
    'Dropterminal.sh|--preload'
    'Hyprsunset.sh|init'
  )
  # "unit|command-basename|required substring" for lines a unit took over.
  local -a daemon_commands=(
    'swww-daemon.service|swww-daemon|'
    'swww-daemon.service|awww-daemon|'
    'swww-daemon.service|WallpaperDaemon.sh|'
    'waybar.service|waybar|'
    'waybar.service|WaybarStartup.sh|'
    'hypridle.service|hypridle|'
    'nm-applet.service|nm-applet|'
    'cliphist-text.service|wl-paste|--type text'
    'cliphist-image.service|wl-paste|--type image'
    'quickshell-overview.service|qs|'
    'copyq.service|copyq|'
    'ags.service|ags|'
    'idle-power-watch.service|IdlePowerWatch.sh|'
    'blueman-applet.service|blueman-applet|'
    'hyprpolkitagent.service|Polkit.sh|'
    'hyprpolkitagent.service|hyprpolkitagent|'
    'plasma-polkit-agent.service|Polkit.sh|'
    'plasma-polkit-agent.service|polkit-kde-authentication-agent-1|'
  )

  local tmp
  tmp=$(mktemp)
  local -a removed=()
  local line cmd base needle entry unit want hit
  while IFS= read -r line || [ -n "$line" ]; do
    cmd=""
    if [[ "$line" =~ $re_call ]] || [[ "$line" =~ $re_entry ]]; then
      cmd="${BASH_REMATCH[1]}"
    fi
    if [ -n "$cmd" ]; then
      hit=0
      base="${cmd%%[[:space:]]*}"
      base="${base##*/}"
      for needle in "${owned_substrings[@]}"; do
        [[ "$cmd" == *"$needle"* ]] && { hit=1; break; }
      done
      if [ "$hit" -eq 0 ]; then
        for entry in "${owned_commands[@]}"; do
          want="${entry#*|}"
          if [ "$base" = "${entry%%|*}" ] && { [ -z "$want" ] || [[ "$cmd" == *"$want"* ]]; }; then
            hit=1; break
          fi
        done
      fi
      if [ "$hit" -eq 0 ]; then
        for entry in "${daemon_commands[@]}"; do
          unit="${entry%%|*}"
          [[ "$enabled" == *" $unit "* ]] || continue
          entry="${entry#*|}"
          want="${entry#*|}"
          if [ "$base" = "${entry%%|*}" ] && { [ -z "$want" ] || [[ "$cmd" == *"$want"* ]]; }; then
            hit=1; break
          fi
        done
      fi
      if [ "$hit" -eq 1 ]; then
        removed+=("$line")
        continue
      fi
    fi
    printf '%s\n' "$line"
  done <"$user_startup" >"$tmp"

  if [ "${#removed[@]}" -eq 0 ]; then
    rm -f "$tmp"
    return 0
  fi

  local backup
  backup="$user_startup.backup-sessionfix-$(date +%Y%m%d-%H%M%S)"
  cp "$user_startup" "$backup"
  mv "$tmp" "$user_startup"
  echo "${NOTE:-[NOTE]} - Removed ${#removed[@]} startup command(s) from UserConfigs/user_startup.lua that the vendor startup config or a systemd unit now owns (backup: $(basename "$backup")):" 2>&1 | tee -a "$log"
  printf '%s\n' "${removed[@]}" | sed 's/^/  - /' | tee -a "$log"
}
