#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
#
# Made and brought to by Kiran George
# /* -- ✨ https://github.com/SherLock707 ✨ -- */  ##
# Dropdown Terminal
# Usage: ./Dropdown.sh [-d] [-p|--preload] <terminal_command>
# Example: ./Dropdown.sh foot
#          ./Dropdown.sh -d foot (with debug output)
#          ./Dropdown.sh -p foot (ensure it exists hidden in the scratchpad
#                                 without revealing it — for exec-once at login)
#          ./Dropdown.sh "kitty -e zsh"
#          ./Dropdown.sh "alacritty --working-directory /home/user"

DEBUG=false
PRELOAD=false
SPECIAL_WS="special:scratchpad"
ADDR_FILE="/tmp/dropdown_terminal_addr"

# Dropdown size and position configuration (percentages)
WIDTH_PERCENT=65  # Width as percentage of screen width
HEIGHT_PERCENT=65 # Height as percentage of screen height
Y_PERCENT=10      # Y position as percentage from top (X is auto-centered)

# Animation settings
ANIMATION_DURATION=100 # milliseconds
SLIDE_STEPS=5
SLIDE_DELAY=5 # milliseconds between steps

# Parse arguments
while :; do
  case "$1" in
    -d) DEBUG=true; shift ;;
    -p | --preload) PRELOAD=true; shift ;;
    *) break ;;
  esac
done

TERMINAL_CMD="$1"

# Windows we adopt at spawn must look like the terminal we launch. At login
# this script races other autostarts (xwaylandvideobridge), and a bare
# new-address diff used to grab whichever window mapped first — yanking the
# bridge onto the active workspace front and center. Class is matched
# case-insensitively as a substring so app-id styles like
# org.wezfurlong.wezterm still match "wezterm".
TERM_BIN=$(basename "${TERMINAL_CMD%% *}")

# Debug echo function
# NOTE: must write to stderr — several functions return values via stdout
# command substitution, and debug lines on stdout corrupt those captures.
debug_echo() {
  if [ "$DEBUG" = true ]; then
    echo "$@" >&2
  fi
}

# Validate input
if [ -z "$TERMINAL_CMD" ]; then
  echo "Missing terminal command. Usage: $0 [-d] <terminal_command>"
  echo "Examples:"
  echo "  $0 foot"
  echo "  $0 -d foot (with debug output)"
  echo "  $0 'kitty -e zsh'"
  echo "  $0 'alacritty --working-directory /home/user'"
  echo ""
  echo "Edit the script to modify size and position:"
  echo "  WIDTH_PERCENT  - Width as percentage of screen (default: 50)"
  echo "  HEIGHT_PERCENT - Height as percentage of screen (default: 50)"
  echo "  Y_PERCENT      - Y position from top as percentage (default: 5)"
  echo "  Note: X position is automatically centered"
  exit 1
fi

# Function to get window geometry
get_window_geometry() {
  local addr="$1"
  hyprctl clients -j | jq -r --arg ADDR "$addr" '.[] | select(.address == $ADDR) | "\(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"'
}

# Function to animate window slide down (show)
animate_slide_down() {
  local addr="$1"
  local target_x="$2"
  local target_y="$3"
  local width="$4"
  local height="$5"

  debug_echo "Animating slide down for window $addr to position $target_x,$target_y"

  # Start position (above screen)
  local start_y=$((target_y - height - 50))

  # Calculate step size
  local step_y=$(((target_y - start_y) / SLIDE_STEPS))

  # Move window to start position instantly (off-screen)
  hyprctl dispatch movewindowpixel "exact $target_x $start_y,address:$addr" >/dev/null 2>&1
  sleep 0.05

  # Animate slide down
  for i in $(seq 1 $SLIDE_STEPS); do
    local current_y=$((start_y + (step_y * i)))
    hyprctl dispatch movewindowpixel "exact $target_x $current_y,address:$addr" >/dev/null 2>&1
    sleep 0.03
  done

  # Ensure final position is exact
  hyprctl dispatch movewindowpixel "exact $target_x $target_y,address:$addr" >/dev/null 2>&1
}

# Function to animate window slide up (hide)
animate_slide_up() {
  local addr="$1"
  local start_x="$2"
  local start_y="$3"
  local width="$4"
  local height="$5"

  debug_echo "Animating slide up for window $addr from position $start_x,$start_y"

  # End position (above screen)
  local end_y=$((start_y - height - 50))

  # Calculate step size
  local step_y=$(((start_y - end_y) / SLIDE_STEPS))

  # Animate slide up
  for i in $(seq 1 $SLIDE_STEPS); do
    local current_y=$((start_y - (step_y * i)))
    hyprctl dispatch movewindowpixel "exact $start_x $current_y,address:$addr" >/dev/null 2>&1
    sleep 0.03
  done

  debug_echo "Slide up animation completed"
}

# Function to get monitor info including scale and name of focused monitor
get_monitor_info() {
  local monitor_data=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.x) \(.y) \(.width) \(.height) \(.scale) \(.name)"')
  if [ -z "$monitor_data" ] || [[ "$monitor_data" =~ ^null ]]; then
    debug_echo "Error: Could not get focused monitor information"
    return 1
  fi
  echo "$monitor_data"
}

# Function to calculate dropdown position with proper scaling and centering
calculate_dropdown_position() {
  local monitor_info=$(get_monitor_info)

  if [ $? -ne 0 ] || [ -z "$monitor_info" ]; then
    debug_echo "Error: Failed to get monitor info, using fallback values"
    echo "100 100 800 600 fallback-monitor"
    return 1
  fi

  local mon_x=$(echo $monitor_info | cut -d' ' -f1)
  local mon_y=$(echo $monitor_info | cut -d' ' -f2)
  local mon_width=$(echo $monitor_info | cut -d' ' -f3)
  local mon_height=$(echo $monitor_info | cut -d' ' -f4)
  local mon_scale=$(echo $monitor_info | cut -d' ' -f5)
  local mon_name=$(echo $monitor_info | cut -d' ' -f6)

  debug_echo "Monitor info: x=$mon_x, y=$mon_y, width=$mon_width, height=$mon_height, scale=$mon_scale"

  # Validate scale value and provide fallback
  if [ -z "$mon_scale" ] || [ "$mon_scale" = "null" ] || [ "$mon_scale" = "0" ]; then
    debug_echo "Invalid scale value, using 1.0 as fallback"
    mon_scale="1.0"
  fi

  # Calculate logical dimensions by dividing physical dimensions by scale
  local logical_width logical_height
  if command -v bc >/dev/null 2>&1; then
    # Use bc for precise floating point calculation
    logical_width=$(echo "scale=0; $mon_width / $mon_scale" | bc | cut -d'.' -f1)
    logical_height=$(echo "scale=0; $mon_height / $mon_scale" | bc | cut -d'.' -f1)
  else
    # Fallback to integer math (multiply by 100 for precision, then divide)
    local scale_int=$(echo "$mon_scale" | sed 's/\.//' | sed 's/^0*//')
    if [ -z "$scale_int" ]; then scale_int=100; fi

    logical_width=$(((mon_width * 100) / scale_int))
    logical_height=$(((mon_height * 100) / scale_int))
  fi

  # Ensure we have valid integer values
  if ! [[ "$logical_width" =~ ^-?[0-9]+$ ]]; then logical_width=$mon_width; fi
  if ! [[ "$logical_height" =~ ^-?[0-9]+$ ]]; then logical_height=$mon_height; fi

  debug_echo "Physical resolution: ${mon_width}x${mon_height}"
  debug_echo "Logical resolution: ${logical_width}x${logical_height} (physical ÷ scale)"

  # Calculate window dimensions based on LOGICAL space percentages
  local width=$((logical_width * WIDTH_PERCENT / 100))
  local height=$((logical_height * HEIGHT_PERCENT / 100))

  # Calculate Y position from top based on percentage of LOGICAL height
  local y_offset=$((logical_height * Y_PERCENT / 100))

  # Calculate centered X position in LOGICAL space
  local x_offset=$(((logical_width - width) / 2))

  # Apply monitor offset to get final positions in logical coordinates
  local final_x=$((mon_x + x_offset))
  local final_y=$((mon_y + y_offset))

  debug_echo "Window size: ${width}x${height} (logical pixels)"
  debug_echo "Final position: x=$final_x, y=$final_y (logical coordinates)"
  debug_echo "Hyprland will scale these to physical coordinates automatically"

  echo "$final_x $final_y $width $height $mon_name"
}

# Get the current workspace
CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')

# Function to get stored terminal address
get_terminal_address() {
  if [ -f "$ADDR_FILE" ] && [ -s "$ADDR_FILE" ]; then
    cut -d' ' -f1 "$ADDR_FILE"
  fi
}

# Function to get stored monitor name
get_terminal_monitor() {
  if [ -f "$ADDR_FILE" ] && [ -s "$ADDR_FILE" ]; then
    cut -d' ' -f2 "$ADDR_FILE"
  fi
}

# Function to get stored terminal class (recorded at adopt time)
get_terminal_class() {
  if [ -f "$ADDR_FILE" ] && [ -s "$ADDR_FILE" ]; then
    cut -d' ' -f3 "$ADDR_FILE"
  fi
}

# The stored window counts as our dropdown only if it is the same window we
# adopted: address AND class must both match what was recorded. Identity is
# checked against the file, not against $TERM_BIN, so the keybind toggles
# the existing dropdown even when invoked with a different terminal than the
# one that preloaded it — and a poisoned or reused address never qualifies.
terminal_exists() {
  local addr=$(get_terminal_address)
  local class=$(get_terminal_class)
  if [ -n "$addr" ] && [ -n "$class" ]; then
    hyprctl clients -j | jq -e --arg ADDR "$addr" --arg CLS "$class" \
      'any(.[]; .address == $ADDR and .class == $CLS)' >/dev/null 2>&1
  else
    return 1
  fi
}

# Function to check if terminal is in special workspace
terminal_in_special() {
  local addr=$(get_terminal_address)
  if [ -n "$addr" ]; then
    hyprctl clients -j | jq -e --arg ADDR "$addr" 'any(.[]; .address == $ADDR and .workspace.name == "special:scratchpad")' >/dev/null 2>&1
  else
    return 1
  fi
}

# Function to spawn terminal and capture its address
spawn_terminal() {
  debug_echo "Creating new dropdown terminal with command: $TERMINAL_CMD"

  # Calculate dropdown position for later use
  local pos_info=$(calculate_dropdown_position)
  if [ $? -ne 0 ]; then
    debug_echo "Warning: Using fallback positioning"
  fi

  local target_x=$(echo $pos_info | cut -d' ' -f1)
  local target_y=$(echo $pos_info | cut -d' ' -f2)
  local width=$(echo $pos_info | cut -d' ' -f3)
  local height=$(echo $pos_info | cut -d' ' -f4)
  local monitor_name=$(echo $pos_info | cut -d' ' -f5)

  debug_echo "Target position: ${target_x},${target_y}, size: ${width}x${height}"

  # Get window count before spawning
  local windows_before=$(hyprctl clients -j)
  local count_before=$(echo "$windows_before" | jq 'length')

  # Launch terminal directly in special workspace to avoid visible spawn
  hyprctl dispatch exec "[float; size $width $height; workspace special:scratchpad silent] $TERMINAL_CMD"

  # Wait for the new window to appear (poll up to ~3s; terminals routinely
  # take >100ms to map). Only accept a window that landed on the scratchpad
  # workspace with a matching class — the exec rule above guarantees ours
  # does, and unrelated windows mapping concurrently (xwaylandvideobridge at
  # login) must never be adopted, moved, and pinned by mistake.
  local new_addr=""
  local i
  for i in $(seq 1 30); do
    new_addr=$(comm -13 \
      <(echo "$windows_before" | jq -r '.[].address' | sort) \
      <(hyprctl clients -j | jq -r --arg WS "$SPECIAL_WS" --arg BIN "$TERM_BIN" \
        '.[] | select(.workspace.name == $WS)
             | select((.class // "") | ascii_downcase | contains($BIN | ascii_downcase))
             | .address' | sort) |
      head -1)
    if [ -n "$new_addr" ] && [ "$new_addr" != "null" ]; then
      break
    fi
    sleep 0.1
  done

  if [ -n "$new_addr" ] && [ "$new_addr" != "null" ]; then
    # Store address, monitor, and class — class is the identity token
    # terminal_exists() checks on later invocations.
    local new_class=$(hyprctl clients -j | jq -r --arg ADDR "$new_addr" '.[] | select(.address == $ADDR) | .class')
    echo "$new_addr $monitor_name $new_class" >"$ADDR_FILE"
    debug_echo "Terminal created with address: $new_addr ($new_class) in special workspace on monitor $monitor_name"

    if [ "$PRELOAD" = true ]; then
      debug_echo "Preload mode: leaving terminal parked in $SPECIAL_WS"
      return 0
    fi

    # Small delay to ensure it's properly in special workspace
    sleep 0.2

    # Now bring it back with the same animation as subsequent shows
    # Use movetoworkspacesilent to avoid affecting workspace history
    hyprctl dispatch movetoworkspacesilent "$CURRENT_WS,address:$new_addr"
    hyprctl dispatch pin "address:$new_addr"
    animate_slide_down "$new_addr" "$target_x" "$target_y" "$width" "$height"

    return 0
  fi

  debug_echo "Failed to get terminal address"
  return 1
}

# Main logic
if [ "$PRELOAD" = true ]; then
  # exec-once path: make sure a dropdown exists in the scratchpad, but never
  # reveal or focus anything at login.
  if terminal_exists; then
    debug_echo "Preload: dropdown already exists"
  else
    spawn_terminal
  fi
  exit 0
fi

if terminal_exists; then
  TERMINAL_ADDR=$(get_terminal_address)
  debug_echo "Found existing terminal: $TERMINAL_ADDR"
  focused_monitor=$(get_monitor_info | awk '{print $6}')
  dropdown_monitor=$(get_terminal_monitor)
  if [ "$focused_monitor" != "$dropdown_monitor" ]; then
    debug_echo "Monitor focus changed: moving dropdown to $focused_monitor"
    # Calculate new position for focused monitor
    pos_info=$(calculate_dropdown_position)
    target_x=$(echo $pos_info | cut -d' ' -f1)
    target_y=$(echo $pos_info | cut -d' ' -f2)
    width=$(echo $pos_info | cut -d' ' -f3)
    height=$(echo $pos_info | cut -d' ' -f4)
    monitor_name=$(echo $pos_info | cut -d' ' -f5)
    # Move and resize window
    hyprctl dispatch movewindowpixel "exact $target_x $target_y,address:$TERMINAL_ADDR"
    hyprctl dispatch resizewindowpixel "exact $width $height,address:$TERMINAL_ADDR"
    # Update ADDR_FILE (keep the recorded class)
    echo "$TERMINAL_ADDR $monitor_name $(get_terminal_class)" >"$ADDR_FILE"
  fi

  if terminal_in_special; then
    debug_echo "Bringing terminal from scratchpad with slide down animation"

    # Calculate target position
    pos_info=$(calculate_dropdown_position)
    target_x=$(echo $pos_info | cut -d' ' -f1)
    target_y=$(echo $pos_info | cut -d' ' -f2)
    width=$(echo $pos_info | cut -d' ' -f3)
    height=$(echo $pos_info | cut -d' ' -f4)

    # Use movetoworkspacesilent to avoid affecting workspace history
    hyprctl dispatch movetoworkspacesilent "$CURRENT_WS,address:$TERMINAL_ADDR"
    hyprctl dispatch pin "address:$TERMINAL_ADDR"

    # Set size and animate slide down
    hyprctl dispatch resizewindowpixel "exact $width $height,address:$TERMINAL_ADDR"
    animate_slide_down "$TERMINAL_ADDR" "$target_x" "$target_y" "$width" "$height"

    hyprctl dispatch focuswindow "address:$TERMINAL_ADDR"
  else
    debug_echo "Hiding terminal to scratchpad with slide up animation"

    # Get current geometry for animation
    geometry=$(get_window_geometry "$TERMINAL_ADDR")
    if [ -n "$geometry" ]; then
      curr_x=$(echo $geometry | cut -d' ' -f1)
      curr_y=$(echo $geometry | cut -d' ' -f2)
      curr_width=$(echo $geometry | cut -d' ' -f3)
      curr_height=$(echo $geometry | cut -d' ' -f4)

      debug_echo "Current geometry: ${curr_x},${curr_y} ${curr_width}x${curr_height}"

      # Animate slide up first
      animate_slide_up "$TERMINAL_ADDR" "$curr_x" "$curr_y" "$curr_width" "$curr_height"

      # Small delay then move to special workspace and unpin
      sleep 0.1
      hyprctl dispatch pin "address:$TERMINAL_ADDR" # Unpin (toggle)
      hyprctl dispatch movetoworkspacesilent "$SPECIAL_WS,address:$TERMINAL_ADDR"
    else
      debug_echo "Could not get window geometry, moving to scratchpad without animation"
      hyprctl dispatch pin "address:$TERMINAL_ADDR"
      hyprctl dispatch movetoworkspacesilent "$SPECIAL_WS,address:$TERMINAL_ADDR"
    fi
  fi
else
  debug_echo "No existing terminal found, creating new one"
  if spawn_terminal; then
    TERMINAL_ADDR=$(get_terminal_address)
    if [ -n "$TERMINAL_ADDR" ]; then
      hyprctl dispatch focuswindow "address:$TERMINAL_ADDR"
    fi
  fi
fi
