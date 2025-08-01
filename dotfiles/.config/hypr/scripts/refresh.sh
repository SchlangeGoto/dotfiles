#!/usr/bin/env bash
#  ┳┓┏┓┏┓┳┓┏┓┏┓┓┏
#  ┣┫┣ ┣ ┣┫┣ ┗┓┣┫
#  ┛┗┗┛┻ ┛┗┗┛┗┛┛┗
#

# kill already running processes
_ps=(waybar rofi swaync)
for _prs in "${_ps[@]}"; do
  if pidof "${_prs}" >/dev/null; then
    pkill "${_prs}"
  fi
done
#Reload hyprland.conf
hyprctl reload

# relaunch waybar
sleep 1
waybar &

# relaunch swaync
sleep 0.5
swaync >/dev/null 2>&1 &

# execute discord refresh script
./reload-discord.sh

exit 0
