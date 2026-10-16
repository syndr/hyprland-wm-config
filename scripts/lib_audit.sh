#!/usr/bin/env bash
# Post-upgrade audit helpers for Hyprland dotfiles.

run_post_upgrade_audit() {
  local log="$1"
  local hypr_dir="$HOME/.config/hypr"
  local waybar_dir="$HOME/.config/waybar"
  local issues=0

  audit_note() {
    echo "${NOTE:-[NOTE]} audit: $1" 2>&1 | tee -a "$log"
  }

  audit_warn() {
    echo "${WARN:-[WARN]} audit: $1" 2>&1 | tee -a "$log"
    issues=$((issues + 1))
  }

  local base_keybinds="$hypr_dir/configs/Keybinds.conf"
  local user_keybinds="$hypr_dir/UserConfigs/UserKeybinds.conf"
  if [ -f "$base_keybinds" ] && [ -f "$user_keybinds" ]; then
    local duplicate_binds
    duplicate_binds=$(
      awk '
        function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        FNR==NR {
          if ($0 ~ /^[ \t]*bind[a-z]*[ \t]*=/) base[trim($0)]=1
          next
        }
        {
          if ($0 ~ /^[ \t]*bind[a-z]*[ \t]*=/) {
            line=trim($0)
            if (line in base) print line
          }
        }
      ' "$base_keybinds" "$user_keybinds" | sort -u
    )
    if [ -n "$duplicate_binds" ]; then
      audit_warn "duplicate bind lines still exist between Keybinds.conf and UserKeybinds.conf"
      printf '%s\n' "$duplicate_binds" | sed 's/^/  - /' | tee -a "$log"
    fi
  fi

  if [ -f "$base_keybinds" ] && [ -f "$user_keybinds" ]; then
    # Same key chord bound in both files, even with different actions: both
    # binds fire on every press (the desktop-zoom double bind went unnoticed
    # for this reason). Submap bodies are skipped and a chord the user
    # explicitly `unbind`s before rebinding is not reported.
    local duplicate_chords
    duplicate_chords=$(
      awk '
        function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        function chord(rest,   n, parts, mods) {
          n = split(rest, parts, ",")
          if (n < 2) return ""
          mods = toupper(trim(parts[1]))
          gsub(/\$MAINMOD/, "SUPER", mods)
          gsub(/[ \t]+/, " ", mods)
          return mods " " tolower(trim(parts[2]))
        }
        FNR == 1 { insub = 0 }
        /^[ \t]*submap[ \t]*=/ { insub = (trim($0) !~ /=[ \t]*reset$/); next }
        insub { next }
        FNR == NR {
          if ($0 ~ /^[ \t]*bind[a-z]*[ \t]*=/) { l = $0; sub(/^[ \t]*bind[a-z]*[ \t]*=[ \t]*/, "", l); base[chord(l)] = 1 }
          next
        }
        /^[ \t]*unbind[ \t]*=/ { l = $0; sub(/^[ \t]*unbind[ \t]*=[ \t]*/, "", l); unbound[chord(l)] = 1; next }
        /^[ \t]*bind[a-z]*[ \t]*=/ {
          l = $0; sub(/^[ \t]*bind[a-z]*[ \t]*=[ \t]*/, "", l); c = chord(l)
          if (c != "" && (c in base) && !(c in unbound)) print c
        }
      ' "$base_keybinds" "$user_keybinds" | sort -u
    )
    if [ -n "$duplicate_chords" ]; then
      audit_warn "the same key chord is bound in both Keybinds.conf and UserKeybinds.conf (both fire on every press)"
      printf '%s\n' "$duplicate_chords" | sed 's/^/  - /' | tee -a "$log"
    fi
  fi

  local base_startup="$hypr_dir/configs/Startup_Apps.conf"
  local user_startup="$hypr_dir/UserConfigs/Startup_Apps.conf"
  # Only meaningful while the vendor file is actually sourced. Startup is now
  # owned by systemd user units plus the vendor configs/Startup_Session.conf,
  # so hyprland.conf deliberately does not source $configs/Startup_Apps.conf --
  # the file stays on disk untouched to keep upstream merges clean, and lines
  # shared with the overlay are not duplicates because only one copy is ever read.
  local base_startup_sourced=0
  if grep -Eq '^[[:space:]]*source[[:space:]]*=[[:space:]]*\$configs/Startup_Apps\.conf' \
      "$hypr_dir/hyprland.conf" 2>/dev/null; then
    base_startup_sourced=1
  fi
  if [ "$base_startup_sourced" -eq 1 ] && [ -f "$base_startup" ] && [ -f "$user_startup" ]; then
    local duplicate_exec
    duplicate_exec=$(
      awk '
        function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        FNR==NR {
          if ($0 ~ /^[ \t]*exec-once[ \t]*=/) base[trim($0)]=1
          next
        }
        {
          if ($0 ~ /^[ \t]*exec-once[ \t]*=/) {
            line=trim($0)
            if (line in base) print line
          }
        }
      ' "$base_startup" "$user_startup" | sort -u
    )
    if [ -n "$duplicate_exec" ]; then
      audit_warn "duplicate exec-once lines still exist between Startup_Apps.conf and User overlay"
      printf '%s\n' "$duplicate_exec" | sed 's/^/  - /' | tee -a "$log"
    fi
  fi

  local hyprland_conf="$hypr_dir/hyprland.conf"
  if [ -f "$hyprland_conf" ]; then
    if ! grep -Eq '^[[:space:]]*source[[:space:]]*=[[:space:]]*\$configs/WindowRules\.conf' "$hyprland_conf"; then
      audit_warn "vendor WindowRules.conf is not sourced in hyprland.conf"
    fi
    if grep -Eq '^[[:space:]]*source[[:space:]]*=[[:space:]]*\$UserConfigs/Laptops\.conf' "$hyprland_conf"; then
      local chassis_type_file="$hypr_dir/.chassis_type"
      local chassis_type=""
      [ -f "$chassis_type_file" ] && chassis_type=$(tr '[:upper:]' '[:lower:]' <"$chassis_type_file" | tr -d '[:space:]')
      local laptops_conf="$hypr_dir/UserConfigs/Laptops.conf"
      local laptop_display_conf="$hypr_dir/UserConfigs/LaptopDisplay.conf"
      if [ "$chassis_type" != "laptop" ] &&
         {
           grep -Eq '^[[:space:]]*(bindl|exec-once)[[:space:]]*=' "$laptops_conf" 2>/dev/null ||
           grep -Eq '^[[:space:]]*monitor[[:space:]]*=' "$laptop_display_conf" 2>/dev/null
         }; then
        audit_warn "desktop host has active laptop-only config in Laptops.conf or LaptopDisplay.conf"
      fi
    fi
  fi

  # Session daemons (wallpaper, waybar, hypridle, ...) are systemd user units
  # pulled in by hyprland-session.target, and the target itself is started by
  # the exec-once in configs/Startup_Session.conf (or by uwsm). Any link in
  # that chain missing is the "Hyprland boots to a grey screen" failure.
  if [ -f "$hyprland_conf" ] &&
     ! grep -Eq '^[[:space:]]*source[[:space:]]*=[[:space:]]*\$configs/Startup_Session\.conf' "$hyprland_conf"; then
    audit_warn "configs/Startup_Session.conf is not sourced in hyprland.conf; hyprland-session.target and compositor-state startup never run"
  fi
  if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
    local unit_state
    unit_state=$(systemctl --user is-enabled hyprland-session.target 2>/dev/null || true)
    if [ "$unit_state" != "enabled" ]; then
      audit_warn "hyprland-session.target is not enabled (state: ${unit_state:-missing}); waybar, hypridle and the wallpaper daemon will not start at login"
    fi
    local daemon_unit
    for daemon_unit in waybar.service hypridle.service; do
      unit_state=$(systemctl --user is-enabled "$daemon_unit" 2>/dev/null || true)
      if [ "$unit_state" = "masked" ]; then
        audit_warn "$daemon_unit is masked; hyprland-session.target cannot start it (systemctl --user unmask $daemon_unit)"
      fi
    done
    local session_wants
    session_wants=" $(systemctl --user show -p Wants --value hyprland-session.target 2>/dev/null || true) "
    for daemon_unit in waybar.service swww-daemon.service; do
      case "$session_wants" in
        *" $daemon_unit "*) ;;
        *) audit_warn "$daemon_unit is not wanted by hyprland-session.target (expected from install_session_units)" ;;
      esac
    done
    local failed_units
    failed_units=$(systemctl --user list-units --state=failed --plain --no-legend 2>/dev/null | awk '{print $1}')
    for daemon_unit in $session_wants; do
      case " $failed_units " in
        *" $daemon_unit "*) audit_warn "$daemon_unit (wanted by hyprland-session.target) is in failed state: systemctl --user status $daemon_unit" ;;
      esac
    done
    # CopyQ's socket lives in ~/.config/copyq. A server that survived that
    # directory being replaced stays "active" but nothing can connect to it,
    # not even its own clipboard monitor, so the failed-state check above
    # never sees it. Ask the server a trivial question instead.
    if systemctl --user is-active --quiet copyq.service 2>/dev/null \
       && command -v copyq >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1 \
       && ! timeout 5 copyq eval 1 >/dev/null 2>&1; then
      audit_warn "copyq.service is active but its socket is unreachable (config dir replaced under the running server?): systemctl --user restart copyq.service"
    fi
  fi

  local modules_workspaces="$waybar_dir/ModulesWorkspaces"
  if [ -f "$modules_workspaces" ] && ! grep -q '"all-outputs"[[:space:]]*:[[:space:]]*false' "$modules_workspaces"; then
    audit_warn "Waybar ModulesWorkspaces does not pin workspaces per output"
  fi

  local qt5ct_conf="$HOME/.config/qt5ct/qt5ct.conf"
  if [ -f "$qt5ct_conf" ] && grep -Eq '^general="Fira Code' "$qt5ct_conf"; then
    audit_warn "qt5ct general font is set to Fira Code, which usually means monospace UI"
  fi

  local qt6ct_conf="$HOME/.config/qt6ct/qt6ct.conf"
  if [ -f "$qt6ct_conf" ] && grep -Eq '^general="Fira Code' "$qt6ct_conf"; then
    audit_warn "qt6ct general font is set to Fira Code, which usually means monospace UI"
  fi

  local initial_boot="$hypr_dir/initial-boot.sh"
  if [ -f "$initial_boot" ] && grep -q 'gsettings set org.gnome.desktop.interface gtk-theme' "$initial_boot"; then
    if ! grep -q 'Preserving existing local GTK/Qt/Kvantum theme state' "$initial_boot"; then
      audit_warn "initial-boot.sh still force-applies default visual themes"
    fi
  fi

  local env_conf="$hypr_dir/UserConfigs/ENVariables.conf"
  if [ -f "$env_conf" ] && [ "$(grep -c '^env = QT_QPA_PLATFORMTHEME,' "$env_conf")" -gt 1 ]; then
    audit_warn "ENVariables.conf defines QT_QPA_PLATFORMTHEME more than once"
  fi

  # hypridle.conf is generated from UserConfigs/IdleSettings.conf. A deployed
  # file without the generator's banner means the generation step was skipped
  # or a stale hand-edited file was restored over the top -- either way the
  # knobs in IdleSettings.conf are silently doing nothing.
  local hypridle_conf="$hypr_dir/hypridle.conf"
  local idle_settings="$hypr_dir/UserConfigs/IdleSettings.conf"
  if [ -f "$hypridle_conf" ] && [ -f "$idle_settings" ]; then
    local idle_managed
    idle_managed=$(read_idle_knob "$idle_settings" KOOL_IDLE_MANAGED 1)
    case "$idle_managed" in
      0|false|no|off|FALSE|No|Off|NO|OFF) ;;
      *)
        if ! grep -q '^# Written by scripts/GenerateHypridle.sh' "$hypridle_conf"; then
          audit_warn "hypridle.conf is not the generated file; IdleSettings.conf knobs are inert (run scripts/GenerateHypridle.sh --restart)"
        fi
        ;;
    esac
  fi

  if [ "$issues" -eq 0 ]; then
    audit_note "no high-signal upgrade regressions detected"
  else
    audit_warn "detected $issues high-signal issue(s); review the audit notes above"
  fi
}
