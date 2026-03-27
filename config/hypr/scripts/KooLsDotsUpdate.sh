#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# simple bash script to check if update is available by comparing local version and github version

# Optional flags
force_update=0
case "${1:-}" in
  -f|--force)
    force_update=1
    ;;
  -h|--help)
    echo "Usage: $0 [--force]"
    echo "  --force    Skip version check and run the update path immediately."
    exit 0
    ;;
esac

# Local Paths
local_dir="$HOME/.config/hypr"
iDIR="$HOME/.config/swaync/images/"
local_version=$(find "$local_dir" -maxdepth 1 -name 'v*' -printf '%f\n' 2>/dev/null | sort -V | tail -n 1 | sed 's/^v//')
update_config_file="$HOME/.config/hypr/UserConfigs/KooLsDotsUpdate.conf"

if [ -f "$update_config_file" ]; then
  # shellcheck disable=SC1090
  . "$update_config_file"
fi

KooL_Dots_DIR="${KOOL_DOTS_DIR:-${HYPRLAND_DOTS_DIR:-$HOME/hyprland-wm-config}}"
fallback_repo_dir="$HOME/Hyprland-Dots"
repo_url="${KOOL_DOTS_REPO_URL:-${HYPRLAND_DOTS_REPO_URL:-https://github.com/syndr/hyprland-wm-config.git}}"
branch="${KOOL_DOTS_BRANCH:-${HYPRLAND_DOTS_BRANCH:-main}}"

if [ ! -d "$KooL_Dots_DIR" ] && [ -d "$fallback_repo_dir" ]; then
  KooL_Dots_DIR="$fallback_repo_dir"
fi

run_update() {
  if [ -d "$KooL_Dots_DIR" ]; then
    if ! command -v kitty &> /dev/null; then
      notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Kitty terminal not found. Please install Kitty terminal."
      exit 1
    fi
    kitty -e bash -c "
      cd \"$KooL_Dots_DIR\" &&
      git stash -u &&
      git fetch --all --tags &&
      if git rev-parse --abbrev-ref --symbolic-full-name \"@{u}\" >/dev/null 2>&1; then
        git pull --ff-only
      elif git show-ref --verify --quiet \"refs/remotes/origin/$branch\"; then
        git merge --ff-only \"origin/$branch\"
      else
        echo 'No upstream branch configured for update.' &&
        exit 1
      fi &&
      ./copy.sh &&
      notify-send -u critical -i \"$iDIR/ja.png\" 'Update Completed:' 'Kindly log out and relogin to take effect'
    "
  else
    if ! command -v kitty &> /dev/null; then
      notify-send -i "$iDIR/error.png" "E-R-R-O-R" "Kitty terminal not found. Please install Kitty terminal."
      exit 1
    fi
    kitty -e bash -c "
      git clone --depth=1 --branch \"$branch\" \"$repo_url\" \"$KooL_Dots_DIR\" &&
      cd \"$KooL_Dots_DIR\" &&
      chmod +x copy.sh &&
      ./copy.sh &&
      notify-send -u critical -i \"$iDIR/ja.png\" 'Update Completed:' 'Kindly log out and relogin to take effect'
    "
  fi
}

if [ "$force_update" -eq 1 ]; then
  run_update
  exit 0
fi

# exit if cannot find local version
if [ -z "$local_version" ]; then
  notify-send -i "$iDIR/error.png" 'ERROR !?!?!!' "Unable to find KooL's dots version. Exiting."
  exit 1
fi

# GitHub URL - KooL's dots
github_url="${repo_url%.git}/tree/$branch/config/hypr/"
# Check for required tools (curl)
if ! command -v curl &> /dev/null; then
  notify-send -i "$iDIR/error.png" "Need curl:" "curl not found. Please install curl."
  exit 1
fi

# Fetch the version from GitHub URL - KooL's dots
github_version=$(curl -fsSL -A "Mozilla/5.0" "$github_url" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | sort -V | tail -n 1 | sed 's/v//')

# Cant find  GitHub URL - KooL's dots version
if [ -z "$github_version" ]; then
  notify-send -i "$iDIR/error.png" 'KooL Hyprland:' "Unable to determine GitHub version."
  exit 1
fi

# Comparing local and github versions
if [ "$(echo -e "$github_version\n$local_version" | sort -V | head -n 1)" = "$github_version" ]; then
   notify-send -i "$iDIR/note.png" "KooL Hyprland:" "No update available"
  exit 0
else
  # update available
  notify_cmd_base="notify-send -t 10000 -A action1=Update -A action2=NO -h string:x-canonical-private-synchronous:shot-notify"
  notify_cmd_shot="${notify_cmd_base} -i $iDIR/ja.png"

  response=$($notify_cmd_shot "KooL Hyprland:" "Update available! Update now?")

  case "$response" in
    "action1")
      run_update
      ;;
    "action2")
      exit 0
      ;;
  esac
fi
