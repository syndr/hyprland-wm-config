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

  local base_startup="$hypr_dir/configs/Startup_Apps.conf"
  local user_startup="$hypr_dir/UserConfigs/Startup_Apps.conf"
  if [ -f "$base_startup" ] && [ -f "$user_startup" ]; then
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
