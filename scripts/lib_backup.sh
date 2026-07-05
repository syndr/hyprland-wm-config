#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Backup helper utilities shared by copy.sh (and future scripts).

# Backup-directory suffix shared across a single installer run.
#
# Every backup created during a run and every later restore must agree on this
# name. Callers use command substitution -- $(get_backup_dirname) -- so a
# function-local cache would not survive the subshell; instead copy.sh exports
# KOOL_RUN_BACKUP_SUFFIX once in the parent shell and we honor it here. Without
# it (standalone callers) we fall back to a fresh timestamp.
get_backup_dirname() {
  # Fork: copy.sh exports an authoritative per-run suffix; honor it first.
  if [ -n "${KOOL_RUN_BACKUP_SUFFIX:-}" ]; then
    printf '%s\n' "$KOOL_RUN_BACKUP_SUFFIX"
    return
  fi
  # Upstream: self-caching exported BACKUP_DIR so repeated subshell calls agree.
  if [ -n "${BACKUP_DIR:-}" ]; then
    printf '%s\n' "$BACKUP_DIR"
    return
  fi
  BACKUP_DIR="back-up_$(date +"%m%d_%H%M")"
  export BACKUP_DIR
  printf '%s\n' "$BACKUP_DIR"
}

# Move a directory to a timestamped backup alongside the original.
# Usage: backup_dir "/path/to/dir" [logfile]
backup_dir() {
  local dir="$1"
  local log="${2:-/dev/null}"
  local backup_suffix

  [ -z "$dir" ] && return 1
  backup_suffix=$(get_backup_dirname)
  mv "$dir" "${dir}-backup-${backup_suffix}" 2>&1 | tee -a "$log"
}

# Cleanup old backups under ${XDG_CONFIG_HOME:-$HOME/.config}, keeping the newest for each base dir.
# mode: "auto" (no prompts) or "prompt" (asks before delete); log optional.
cleanup_backups() {
  local mode="${1:-prompt}"
  local log="${2:-/dev/null}"
  local CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
  local BACKUP_PREFIX="-backup"

  for DIR in "$CONFIG_DIR"/*; do
    [ -d "$DIR" ] || continue
    local BACKUP_DIRS=()

    for BACKUP in "$DIR"$BACKUP_PREFIX*; do
      [ -d "$BACKUP" ] && BACKUP_DIRS+=("$BACKUP")
    done

    [ ${#BACKUP_DIRS[@]} -gt 1 ] || continue

    # Determine latest backup by mtime
    local latest_backup="${BACKUP_DIRS[0]}"
    for BACKUP in "${BACKUP_DIRS[@]}"; do
      [ "$BACKUP" -nt "$latest_backup" ] && latest_backup="$BACKUP"
    done

    if [ "$mode" = "auto" ]; then
      for BACKUP in "${BACKUP_DIRS[@]}"; do
        if [ "$BACKUP" != "$latest_backup" ]; then
          rm -rf "$BACKUP"
        fi
      done
      echo "${INFO:-[INFO]} Express mode: trimmed backups for ${YELLOW:-}${DIR##*/}${RESET:-}, keeping ${MAGENTA:-}${latest_backup##*/}${RESET:-}." 2>&1 | tee -a "$log"
      continue
    fi

    printf "\n%s Found multiple backups for: %s\n" "${INFO:-[INFO]}" "${DIR##*/}"
    echo "${YELLOW:-}Backups:${RESET:-}"
    for BACKUP in "${BACKUP_DIRS[@]}"; do
      echo "  - ${BACKUP##*/}"
    done
    echo -n "${CAT:-[ACTION]} Delete older backups and keep only the latest? (y/N): "
    read back_choice
    if [[ "$back_choice" == [Yy]* ]]; then
      for BACKUP in "${BACKUP_DIRS[@]}"; do
        if [ "$BACKUP" != "$latest_backup" ]; then
          rm -rf "$BACKUP"
          echo "Deleted: ${BACKUP##*/}"
        fi
      done
      echo "Kept: ${latest_backup##*/}"
    fi
  done
}
