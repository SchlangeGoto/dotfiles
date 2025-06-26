#!/bin/bash

# Get the window ID and properties of IntelliJ IDEA
INTELLIJ_WINDOW=$(hyprctl clients -j | jq '.[] | select(.initialClass | contains("jetbrains-idea"))')

if [ -z "$INTELLIJ_WINDOW" ]; then
  echo "No IntelliJ window found running"
  exit 1
fi

# Extract window information
WINDOW_ID=$(echo "$INTELLIJ_WINDOW" | jq -r '.address')
WORKSPACE=$(echo "$INTELLIJ_WINDOW" | jq -r '.workspace.id')
POSITION_X=$(echo "$INTELLIJ_WINDOW" | jq -r '.at[0]')
POSITION_Y=$(echo "$INTELLIJ_WINDOW" | jq -r '.at[1]')
SIZE_WIDTH=$(echo "$INTELLIJ_WINDOW" | jq -r '.size[0]')
SIZE_HEIGHT=$(echo "$INTELLIJ_WINDOW" | jq -r '.size[1]')

# Save window properties to temporary file
echo "WORKSPACE=$WORKSPACE" >/tmp/intellij_window_props
echo "POSITION_X=$POSITION_X" >>/tmp/intellij_window_props
echo "POSITION_Y=$POSITION_Y" >>/tmp/intellij_window_props
echo "SIZE_WIDTH=$SIZE_WIDTH" >>/tmp/intellij_window_props
echo "SIZE_HEIGHT=$SIZE_HEIGHT" >>/tmp/intellij_window_props

echo "Saved window properties to /tmp/intellij_window_props"
echo "Closing IntelliJ IDEA..."

# Close IntelliJ gracefully
hyprctl dispatch closewindow "address:$WINDOW_ID"

# Wait a moment for IntelliJ to close properly
sleep 2

# Read window properties
source /tmp/intellij_window_props

# Find the correct IntelliJ launcher
INTELLIJ_LAUNCHER=""
for cmd in idea intellij-idea intellij-idea-ultimate "jetbrains-idea"; do
  if command -v "$cmd" >/dev/null 2>&1; then
    INTELLIJ_LAUNCHER="$cmd"
    break
  fi
done

# If not found in PATH, check common locations
if [ -z "$INTELLIJ_LAUNCHER" ]; then
  for path in "/opt/intellij-idea/bin/idea.sh" "/opt/idea/bin/idea.sh" "/usr/share/intellij-idea/bin/idea.sh" "/opt/jetbrains/idea/bin/idea.sh"; do
    if [ -x "$path" ]; then
      INTELLIJ_LAUNCHER="$path"
      break
    fi
  done
fi

# If still not found, try to locate it
if [ -z "$INTELLIJ_LAUNCHER" ]; then
  INTELLIJ_LAUNCHER=$(find /opt /usr/share -name "idea.sh" -type f -executable 2>/dev/null | head -1)
fi

if [ -z "$INTELLIJ_LAUNCHER" ]; then
  echo "Could not find IntelliJ IDEA launcher. Please specify the full path."
  exit 1
fi

# Start IntelliJ IDEA
echo "Starting IntelliJ IDEA using launcher: $INTELLIJ_LAUNCHER"
"$INTELLIJ_LAUNCHER" &

# Wait for the window to appear - increased wait time
sleep 5

# Find the new IntelliJ window
NEW_INTELLIJ_WINDOW=$(hyprctl clients -j | jq '.[] | select(.initialClass | contains("jetbrains-idea"))')
NEW_WINDOW_ID=$(echo "$NEW_INTELLIJ_WINDOW" | jq -r '.address')

if [ -z "$NEW_WINDOW_ID" ]; then
  echo "Failed to find new IntelliJ window"
  exit 1
fi

# Move to the correct workspace
hyprctl dispatch workspace "$WORKSPACE"

# Position and resize the window
hyprctl dispatch movewindowpixel "exact $POSITION_X $POSITION_Y,address:$NEW_WINDOW_ID"
hyprctl dispatch resizewindowpixel "exact $SIZE_WIDTH $SIZE_HEIGHT,address:$NEW_WINDOW_ID"

echo "IntelliJ IDEA restarted and positioned at previous location"
