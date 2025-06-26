#!/usr/bin/env bash
#  ┓ ┏┏┓┓┏┳┓┏┓┳┓  ┏┓┏┓┓ ┏┓┏┓┏┳┓
#  ┃┃┃┣┫┗┫┣┫┣┫┣┫━━┗┓┣ ┃ ┣ ┃  ┃ 
#  ┗┻┛┛┗┗┛┻┛┛┗┛┗  ┗┛┗┛┗┛┗┛┗┛ ┻ 
#                              



ANIMATION_CONFIGS="$HOME/.config/hypr/UserConfigs/Animations"
ANIMATIONS_CONF="$HOME/.config/hypr/configs/Animations.conf"
ROFI_THEME="$HOME/.config/rofi/applets/waybarSelect.rasi"

main() {
    choice=$(find "$ANIMATION_CONFIGS" -mindepth 1 -maxdepth 1 -type f -printf "%f\n" | rofi -dmenu -theme "$ROFI_THEME")

    if [[ -n "$choice" ]]; then
        ln -sf "$ANIMATION_CONFIGS/$choice" "$ANIMATIONS_CONF"
        
        # Restart
        hyprctl reload

        # Send a notification (optional)
        notify-send -e -h string:x-canonical-private-synchronous:waybar_notif "Animations Style" "Switched to: $choice"
    fi
}

main

