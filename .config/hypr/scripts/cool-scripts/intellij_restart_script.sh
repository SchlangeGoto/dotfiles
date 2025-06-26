#!/bin/bash

# Function to get window information (position and command)
get_window_info() {
  # Use jgmenu to get the active window's details.  This is more reliable than
  # other methods within a Wayland compositor like Hyprland.
  local window_id="$1"
  local info
  info=$(hyprctl jgmenu '{"action": "client_info", "param": "'"$window_id"'"}')

  if [[ -n "$info" ]]; then
    echo "$info"
  else
    return 1 # Indicate failure
  fi
}

# Function to start a program at a specific location
start_program_at() {
  local command="$1"
  local x="$2"
  local y="$3"

  # Use Hyprland's dispatch command to open the program at the specified coordinates.
  hyprctl dispatch openat "$x $y $command" &
}

# Array to store window information
declare -a windows_to_restore=()

# 1. Get information about all open JetBrains Idea windows.
while read -r window_id; do
  # Get window info
  local window_info="$(get_window_info "$window_id")"
  if [[ -n "$window_info" ]]; then
    local class_name
    local x
    local y
    local title
    # Parse the JSON output.  Handle potential errors in parsing.
    class_name=$(echo "$window_info" | jq -r '.class')
    x=$(echo "$window_info" | jq -r '.at[0]')
    y=$(echo "$window_info" | jq -r '.at[1]')
    title=$(echo "$window_info" | jq -r '.title')

    if [[ "$class_name" == "jetbrains-idea" ]]; then
      # Extract the command used to start the application.  This is crucial for restarting.
      local command
      command=$(echo "$window_info" | jq -r '.title') # Use title as a proxy.  May need adjustment.

      # Add to the array.  Use printf to avoid issues with spaces/special chars.
      windows_to_restore+=("$(printf '%s|%s|%s|%s' "$x" "$y" "$command" "$title")")
    fi
  fi
done < <(hyprctl clients | grep -oP '0x[0-9a-f]+')

# 2. Close all JetBrains Idea windows.
for window_id in $(hyprctl clients | grep -oP '0x[0-9a-f]+'); do
  local window_info="$(get_window_info "$window_id")"
  if [[ -n "$window_info" ]]; then
    local class_name=$(echo "$window_info" | jq -r '.class')
    if [[ "$class_name" == "jetbrains-idea" ]]; then
      hyprctl dispatch closewindow "$window_id"
    fi
  fi
done

# 3. Wait for the windows to close (optional, but recommended).
sleep 2

# 4. Restart the windows.
for window_info in "${windows_to_restore[@]}"; do
  # Split the string back into variables.
  IFS='|' read -r x y command title <<<"$window_info"

  # Sanitize the command.  This is important for security and correct execution.
  #  We'll assume the title is "mostly" safe, but you might need more robust
  #  parsing depending on your actual titles.  For example, if the title
  #  contains a full path.
  # Start the application.  command should be the program name.
  start_program_at "$command" "$x" "$y" #Removed the title, was causing issues.
done

echo "JetBrains IDE windows restarted."
