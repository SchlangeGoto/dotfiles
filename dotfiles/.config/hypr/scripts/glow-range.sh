#!/bin/bash

# Get user input for shadow range
selected=$(rofi -dmenu -mesg "Enter Shadow Range:" -lines 0)

# Check if user entered a value
if [ -n "$selected" ]; then
  # Verify input is a valid number
  if [[ "$selected" =~ ^[0-9]+$ ]]; then
    # Apply the selected shadow range
    hyprctl keyword decoration:shadow:range "$selected"

    # Show notification to confirm the change
    notify-send "Hyprland" "Shadow range set to $selected" -t 2000
  else
    # Show error notification if input is not a number
    notify-send "Error" "Please enter a valid number" -t 2000
  fi
fi
