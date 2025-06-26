#!/bin/bash

# Application class or title for Vesktop (adjust if needed)
vesktop_identifier="class:vesktop" # You might need to use title instead

get_focused_window() {
  hyprctl activewindow -j | jq -r '.address'
}

if pgrep -f vesktop >/dev/null; then
  # Get the currently focused window
  previous_focus=$(get_focused_window)

  # Focus the Vesktop window
  hyprctl dispatch focuswindow "$vesktop_identifier"
  # sleep 0.3

  # Send Ctrl+R to refresh using wtype
  wtype -M ctrl r
  sleep 0.2
  # Switch back to the previously focused window (if it's not Vesktop)
  current_focus=$(get_focused_window)
  if [[ "$previous_focus" != "$current_focus" ]]; then
    hyprctl dispatch focuswindow "address:$previous_focus"
    echo "Switched back to the previous window: $previous_focus"
  else
    echo "Did not switch back, either still on Vesktop or previous focus was the same."
  fi
else
  echo "Vesktop is not running."
fi
