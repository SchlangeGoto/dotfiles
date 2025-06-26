#!/usr/bin/env bash

#########################################################################
#                                                                       #
#  ████████╗██╗  ██╗███████╗███╗   ███╗███████╗    ███████╗███████╗██╗  #
#  ╚══██╔══╝██║  ██║██╔════╝████╗ ████║██╔════╝    ██╔════╝██╔════╝██║  #
#     ██║   ███████║█████╗  ██╔████╔██║█████╗      ███████╗█████╗  ██║  #
#     ██║   ██╔══██║██╔══╝  ██║╚██╔╝██║██╔══╝      ╚════██║██╔══╝  ██║  #
#     ██║   ██║  ██║███████╗██║ ╚═╝ ██║███████╗    ███████║███████╗███████╗  #
#     ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝    ╚══════╝╚══════╝╚══════╝  #
#                                                                       #
#########################################################################
#
# Theme Selector Script for Hyprland
# This script allows you to select and apply themes to your Hyprland desktop
# It handles configurations for waybar, rofi, wallpapers, swaync, GTK, and more

#------------------------------------------------------------------------------
# Configuration: Paths to various configuration files and directories
#------------------------------------------------------------------------------

# Base directories
SCRIPTS="$HOME/.config/hypr/scripts"    # Scripts directory
THEME_DIR="$HOME/.config/themes"        # Themes directory
CONFIG_DIR="$HOME/.config/hypr/configs" # Hyprland configs
HYPR_DIR="$HOME/.config/hypr"

# Waybar configuration
WAYBAR_CONFIG="$HOME/.config/waybar/config" # Waybar config file
WAYBAR_CSS="$HOME/.config/waybar/style.css" # Waybar CSS file

# Rofi configuration
ROFI_DIR="$HOME/.config/rofi"                               # Rofi directory
ROFI_THEME="$HOME/.config/rofi/applets/waybarSelect.rasi"   # Rofi theme file
ROFI_COLORS="$HOME/.config/rofi/applets/shared/colors.rasi" # Rofi colors file

# Wallpaper configuration
WALLS_LINK="$HOME/.config/hypr/"                             # Wallpaper symlink directory
mpv_wallpaper_dir="$HOME/.config/hypr/current_mpv_wallpaper" # Directory for video wallpapers
mpv_wallpaper_symlink="$mpv_wallpaper_dir/current_video"     # Symlink to current video wallpaper

# Notification configuration
SWAYNC_DIR="$HOME/.config/swaync" # Swaync notification directory

# Kitty configuration
KITTY_DIR="$HOME/.config/kitty"

# Vesktop configuration
VESKTOP_DIR="$HOME/.config/vesktop"

# Zathura PDF Viewer configuration
ZATHURA_DIR="$HOME/.config/zathura"

# btop system monitor configuration
BTOP_DIR="$HOME/.config/btop"

# MPV configuration
MPV_DIR="$HOME/.config/mpv"

# BAT configuration
BAT_DIR="$HOME/.config/bat"

# CAVA configuration
CAVA_DIR="$HOME/.config/cava"

# FZF configuration
FZF_DIR="$HOME/.config/fzf"

# Yazi configuration
YAZI_DIR="$HOME/.config/yazi"

# Intellij configuration, put your intellij version here
INTELLIJ_DIR="$HOME/.config/JetBrains/IntelliJIdea2025.1/options"

# Script to kill wallpaper daemons
kill_script="$SCRIPTS/killswww-mpvpaper.sh" # Script to kill wallpaper daemons

# Get the currently focused monitor
focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

#------------------------------------------------------------------------------
# Function: set_mpvpaper_wallpaper
# Sets a video file as wallpaper using mpvpaper
# Arguments:
#   $1 - Path to the video file
#------------------------------------------------------------------------------
set_mpvpaper_wallpaper() {
  local video_path="$1"
  # Copy current Wal
  cp "$video_path.png" $HOME/.cache/wallcache/.wallpaper_current
  # convert and resize the current wallpaper & make it image for rofi with blur
  magick "$video_path.png" -strip -resize 1000 -gravity center -extent 1000 -blur "30x30" -quality 90 $HOME/.config/rofi/images/currentWalBlur.thumb

  # convert and resize the current wallpaper & make it image for rofi without blur
  magick "$video_path.png" -strip -resize 1000 -gravity center -extent 1000 -quality 90 $HOME/.config/rofi/images/currentWal.thumb

  # convert and resize the current wallpaper & make it image for rofi with square format
  magick "$video_path.png" -strip -thumbnail 500x500^ -gravity center -extent 500x500 $HOME/.config/rofi/images/currentWal.sqre

  # convert and resize the square formatted & make it image for rofi with drawing polygon
  magick $HOME/.config/rofi/images/currentWal.sqre \( -size 500x500 xc:white -fill "rgba(0,0,0,0.7)" -draw "polygon 400,500 500,500 500,0 450,0" -fill black -draw "polygon 500,500 500,0 450,500" \) -alpha Off -compose CopyOpacity -composite $HOME/.config/rofi/images/currentWalQuad.png && mv $HOME/.config/rofi/images/currentWalQuad.png $HOME/.config/rofi/images/currentWalQuad.quad

  # Clean up the directory and create a fresh one
  rm -rf "$mpv_wallpaper_dir"/*
  mkdir -p "$mpv_wallpaper_dir"

  # Create a symlink to the current video
  ln -sf "$video_path" "$mpv_wallpaper_symlink"

  # Set the wallpaper with mpvpaper
  mpvpaper -p -f $focused_monitor "$video_path"

  # Check if mpvpaper worked
  if [ $? -ne 0 ]; then
    echo "Error setting wallpaper with mpvpaper" >&2
    return 1
  fi

  # Kill swww if it's running (we're using mpvpaper instead)
  pkill swww-daemon 2>/dev/null || true

  # Create the kill script for later use
  echo "#!/bin/bash
killall swww-daemon
" >"$kill_script"
  chmod +x "$kill_script"

  return 0
}

#------------------------------------------------------------------------------
# Function: set_swww_wallpaper
# Sets an image file as wallpaper using swww
# Arguments:
#   $1 - Path to the image file
#------------------------------------------------------------------------------
set_swww_wallpaper() {
  # Make sure swww daemon is running
  swww query || swww-daemon --format xrgb &

  local image_path="$1"

  # Animation parameters for swww
  FPS=144
  TYPE="any"
  DURATION=2
  BEZIER=".43,1.19,1,.4"
  SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION"

  # Copy currentWal
  cp "$image_path" $HOME/.cache/wallcache/.wallpaper_current

  # convert and resize the current wallpaper & make it image for rofi with blur
  magick "$image_path" -strip -resize 1000 -gravity center -extent 1000 -blur "30x30" -quality 90 $HOME/.config/rofi/images/currentWalBlur.thumb

  # convert and resize the current wallpaper & make it image for rofi without blur
  magick "$image_path" -strip -resize 1000 -gravity center -extent 1000 -quality 90 $HOME/.config/rofi/images/currentWal.thumb

  # convert and resize the current wallpaper & make it image for rofi with square format
  magick "$image_path" -strip -thumbnail 500x500^ -gravity center -extent 500x500 $HOME/.config/rofi/images/currentWal.sqre

  # convert and resize the square formatted & make it image for rofi with drawing polygon
  magick $HOME/.config/rofi/images/currentWal.sqre \( -size 500x500 xc:white -fill "rgba(0,0,0,0.7)" -draw "polygon 400,500 500,500 500,0 450,0" -fill black -draw "polygon 500,500 500,0 450,500" \) -alpha Off -compose CopyOpacity -composite $HOME/.config/rofi/images/currentWalQuad.png && mv $HOME/.config/rofi/images/currentWalQuad.png $HOME/.config/rofi/images/currentWalQuad.quad

  # Kill mpvpaper if running (we're using swww instead)
  pkill mpvpaper 2>/dev/null || true
  sleep 0.7

  # Set the wallpaper with swww
  swww img -o "$focused_monitor" "$image_path" $SWWW_PARAMS

  # Check if swww worked
  if [ $? -ne 0 ]; then
    echo "Error setting wallpaper with swww" >&2
    return 1
  fi

  # Create the kill script for later use
  echo "#!/bin/bash
killall mpvpaper
" >"$kill_script"
  chmod +x "$kill_script"

  return 0
}

#------------------------------------------------------------------------------
# Function: apply_waybar
# Applies the waybar theme from the selected theme
#------------------------------------------------------------------------------
apply_waybar() {
  # Set path for style.css
  local CSS_PATH="$THEME_DIR/$choice/waybar/style.css"

  # Check if the waybar style file exists
  if [[ ! -f "$CSS_PATH" ]]; then
    notify-send -e "Waybar Theme Error" "'$CSS_PATH' not found."
    return 1
  fi

  # Create symlink to the new waybar style
  ln -sf "$CSS_PATH" "$WAYBAR_CSS"
}

#------------------------------------------------------------------------------
# Function: apply_rofi
# Applies the rofi theme from the selected theme
#------------------------------------------------------------------------------
apply_rofi() {
  # Set path for rofi theme files
  local ROFI_THEME_DIR="$THEME_DIR/$choice/rofi"

  # Check if all necessary rofi theme files exist
  if [[ ! -f "$ROFI_THEME_DIR/colors.rasi" ]]; then
    notify-send -e "Rofi Theme Error" "'$ROFI_THEME_DIR/colors.rasi' not found."
    return 1
  fi

  # Create symlinks to the new rofi theme files
  ln -sf "$ROFI_THEME_DIR/colors.rasi" "$ROFI_DIR/colors.rasi"
}

#------------------------------------------------------------------------------
# Function: set_wallpaper
# Sets the wallpaper from the selected theme
#------------------------------------------------------------------------------
set_wallpaper() {
  # Set path for Theme Wall folder
  local THEME_WALLS="$THEME_DIR/$choice/walls"

  # SWWW animation parameters
  FPS=144
  TYPE="any"
  DURATION=2
  BEZIER=".43,1.19,1,.4"
  SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION"

  # If there's no default wallpaper, choose a random one
  if [[ ! -f "$THEME_WALLS/$choice" ]]; then
    swww-daemon
    notify-send -e "Choosing random wallpaper" "No default wallpaper found. Choosing a random one. To set a default Wall, name it $choice" >&2
    image=$(find "$THEME_WALLS/" -type f -print0 | shuf -z -n 1 | xargs -0 basename)

    if [[ -z "$image" ]]; then
      notify-send -e "Error: No wallpapers found" "'$THEME_WALLS' Is empty" >&2
      return 1
    fi
  fi

  local wallpath=$THEME_DIR/$choice/walls/$image

  # Use the appropriate method based on file type
  if [[ "$image" =~ \.(mp4|webm|mov|wevm|mkv|gif|avi)$ ]]; then
    # For video files, use mpvpaper
    set_mpvpaper_wallpaper "$wallpath"
  else
    # For image files, use swww
    set_swww_wallpaper "$wallpath"
  fi

  # Notify the user and create a symlink to the wallpapers directory
  notify-send -e "Wallpaper set" "Set wallpaper to $choice, you can change it with(look hyprland.conf keybinds)"
  ln -sf "$THEME_WALLS/" "$WALLS_LINK"
  return 0
}

#------------------------------------------------------------------------------
# Function: apply_swaync
# Applies the swaync notification theme from the selected theme
#------------------------------------------------------------------------------
apply_swaync() {
  # Set path for swaync Theme dir
  local SWAYNC_THEME_DIR="$THEME_DIR/$choice/swaync"

  # Check if the swaync config file exists
  if [[ ! -f "$SWAYNC_THEME_DIR/config.json" ]]; then
    notify-send -e "Swaync Theme Error" "'$SWAYNC_THEME_DIR/config.json' not found."
  fi

  # Check if the swaync style file exists
  if [[ ! -f "$SWAYNC_THEME_DIR/style.css" ]]; then
    notify-send -e "Swaync Theme Error" "'$SWAYNC_THEME_DIR/style.css' not found."
  fi

  # Create symlinks to the new swaync theme files
  ln -sf "$SWAYNC_THEME_DIR/config.json" "$SWAYNC_DIR/config.json"
  ln -sf "$SWAYNC_THEME_DIR/style.css" "$SWAYNC_DIR/style.css"
}

#------------------------------------------------------------------------------
# Function: apply_gtk_qt
# Applies the GTK and QT themes from the selected theme
#------------------------------------------------------------------------------
apply_gtk_qt() {
  # Set GTK Theme path
  local GTK_THEME_PATH="$THEME_DIR/$choice/GTK-Themes-in-here/$choice"
  # Set QT Theme path
  local QT_THEME_PATH="$THEME_DIR/$choice/QT-Themes-in-here/$choice"

  # Convert spaces to dashes for theme names
  cleaned_choice=$(echo "$choice" | tr ' ' '-')

  # Check if the GTK theme exists
  if [[ ! -e "$GTK_THEME_PATH" ]]; then
    notify-send -e "GTK Theme Error" "'$GTK_THEME_PATH' not found."
  fi

  # Check if the QT theme exists
  if [[ ! -e "$QT_THEME_PATH" ]]; then
    notify-send -e "QT Theme Error" "'$QT_THEME_PATH' not found."
  fi

  # Apply the themes
  kvantummanager --set "$cleaned_choice"
  gsettings set org.gnome.desktop.interface gtk-theme "$choice" &>/dev/null
}

#------------------------------------------------------------------------------
# Function: apply_misc
# Applies miscellaneous Hyprland configurations from the selected theme
#------------------------------------------------------------------------------
apply_misc() {
  # Set misc path
  local MISC_PATH="$THEME_DIR/$choice/hypr/misc.conf"

  # Check if the misc config file exists
  if [[ ! -f "$MISC_PATH" ]]; then
    notify-send -e "Hypr misc Error" "'$MISC_PATH' not found."
  fi

  # Create a symlink to the new misc config
  ln -sf "$MISC_PATH" "$CONFIG_DIR/misc.conf"
}

#------------------------------------------------------------------------------
# Function: apply_sddm
# Applies the SDDM login manager theme from the selected theme
#------------------------------------------------------------------------------
apply_sddm() {
  # Set SDDM config file path
  local SDDM_CONF_PATH="$THEME_DIR/$choice/sddm/sddm.conf"

  # Check if the SDDM config file exists
  if [[ ! -f "$SDDM_CONF_PATH" ]]; then
    notify-send -e "SDDM Theme Error" "'$SDDM_CONF_PATH' not found."
  fi

  # Create a symlink to the new SDDM config
  ln -sf "$SDDM_CONF_PATH" "/etc/sddm.conf"
}

#------------------------------------------------------------------------------
# Function: apply_kitty
# Applies the kitty terminal theme from the selected theme
#------------------------------------------------------------------------------
apply_kitty() {
  # Set Kitty Theme dir
  local KITTY_THEME_DIR="$THEME_DIR/$choice/kitty"

  # Check if the kitty config files exist
  if [[ ! -f "$KITTY_THEME_DIR/kitty.conf" ]]; then
    notify-send -e "Kitty Config Error" "'$KITTY_THEME_DIR/kitty.conf' not found."
  fi

  if [[ ! -f "$KITTY_THEME_DIR/colors.conf" ]]; then
    notify-send -e "Kitty colors Error" "'$KITTY_THEME_DIR/colors.conf' not found."
  fi

  # Create symlinks to the new kitty config files
  ln -sf "$KITTY_THEME_DIR/kitty.conf" "$KITTY_DIR/kitty.conf"
  ln -sf "$KITTY_THEME_DIR/colors.conf" "$KITTY_DIR/colors.conf"
}

#------------------------------------------------------------------------------
# Function: apply_yazi
# Applies the yazi file manager theme from the selected theme
#------------------------------------------------------------------------------
apply_yazi() {
  # This function only checks if yazi theme exist
  if [[ ! -f "$THEME_DIR/$choice/yazi/theme.toml" ]]; then
    notify-send -e "Yazi theme Error" "'$THEME_DIR/$choice/yazi/theme.toml' not found."
  fi

  ln -sf "$YAZI_DIR/theme.toml" "$THEME_DIR/$choice/yazi/theme.toml"
}

#------------------------------------------------------------------------------
# Function: apply_spicetify
# Applies the spicetify theme from the selected theme
#------------------------------------------------------------------------------
apply_spicetify() {
  # Run apply script, for setting the theme look in the file
  "$THEME_DIR/$choice/set-spicetify.sh"
}

#------------------------------------------------------------------------------
# Function: apply_vesktop
# Applies the vesktop theme from the selected theme
#------------------------------------------------------------------------------
apply_vesktop() {
  # Set Vesktop theme path
  local VESKTOP_THEME_CSS="$THEME_DIR/$choice/vesktop/theme.css"

  # Check if the css file exist
  if [[ ! -f "$VESKTOP_THEME_CSS" ]]; then
    notify-send -e "Vesktop theme Error" "'$VESKTOP_THEME_CSS' not found."
  fi

  # Create symlinks to the Vesktop css file
  ln -sf "$VESKTOP_THEME_CSS" "$VESKTOP_DIR/themes/theme.css"
}

#------------------------------------------------------------------------------
# Function: apply_vesktop
# Applies the vesktop theme from the selected theme
#------------------------------------------------------------------------------
apply_zathura() {
  # Set Zathura config path
  local ZATHURA_CONFIG_PATH="$THEME_DIR/$choice/zathura/zathurarc"

  # Check if config file exist
  if [[ ! -f "$ZATHURA_CONFIG_PATH" ]]; then
    notify-send -e "Zathura config Error" "'$ZATHURA_CONFIG_PATH' not found."
  fi

  # Create symlink to the Zathura config file
  ln -sf "$ZATHURA_CONFIG_PATH" "$ZATHURA_DIR/zathurarc"
  echo "$ZATHURA_CONFIG_PATH" "$ZATHURA_DIR/zathurarc"
}

#------------------------------------------------------------------------------
# Function: apply_btop
# Applies the btop theme from the selected theme
#------------------------------------------------------------------------------
apply_btop() {
  # Set btop config path
  local BTOP_CONFIG_PATH="$THEME_DIR/$choice/btop/btop.conf"

  # Check if config file exist
  if [[ ! -f "$BTOP_CONFIG_PATH" ]]; then
    notify-send -e "Btop config Error" "'$BTOP_CONFIG_PATH' not found."
  fi

  # Create symlink to the btop config file
  ln -sf "$BTOP_CONFIG_PATH" "$BTOP_DIR/btop.conf"
}

#------------------------------------------------------------------------------
# Function: apply_mpv
# Applies the config from the selected theme
#------------------------------------------------------------------------------
apply_mpv() {
  # Set mpv config path
  local MPV_CONFIG_PATH="$THEME_DIR/$choice/mpv/mpv.conf"

  # Check if config file exist
  if [[ ! -f "$MPV_CONFIG_PATH" ]]; then
    notify-send -e "MPV config Error" "'$MPV_CONFIG_PATH' not found."
  fi

  # Create symlink to the mpv config file
  ln -sf "$MPV_CONFIG_PATH" "$MPV_DIR/mpv.conf"
}

#------------------------------------------------------------------------------
# Function: apply_bat
# Applies the bat config from the selected theme
#------------------------------------------------------------------------------
apply_bat() {
  # Set bat config path
  local BAT_CONFIG_PATH="$THEME_DIR/$choice/bat/config"

  # Check if config file exist
  if [[ ! -f "$BAT_CONFIG_PATH" ]]; then
    notify-send -e "BAT config Error" "'$BAT_CONFIG_PATH' not found."
  fi

  # Create symlink to the bat config file
  ln -sf "$BAT_CONFIG_PATH" "$BAT_DIR/config"
}

#------------------------------------------------------------------------------
# Function: apply_cava
# Applies the cava config from the selected theme
#------------------------------------------------------------------------------
apply_cava() {
  # Set cava config path
  local CAVA_CONFIG_PATH="$THEME_DIR/$choice/cava/config"

  # Check if config file exist
  if [[ ! -f "$CAVA_CONFIG_PATH" ]]; then
    notify-send -e "CAVA config Error" "'$CAVA_CONFIG_PATH' not found."
  fi

  # Create symlink to the cava config file
  ln -sf "$CAVA_CONFIG_PATH" "$CAVA_DIR/config"
}
#------------------------------------------------------------------------------
# Function: apply_fzf
# Applies the fzf config from the selected theme
#------------------------------------------------------------------------------
apply_fzf() {
  # Set fzf config path
  local FZF_CONFIG_PATH="$THEME_DIR/$choice/fzf/config"

  # Check if config file exist
  if [[ ! -f "$FZF_CONFIG_PATH" ]]; then
    notify-send -e "FZF config Error" "'$FZF_CONFIG_PATH' not found."
  fi

  # Create symlink to the fzf config file
  ln -sf "$FZF_CONFIG_PATH" "$FZF_DIR/config"
}

#------------------------------------------------------------------------------
# Function: apply_intellij
# Applies the intellij theme
#------------------------------------------------------------------------------
apply_intellij() {
  # Set fzf config path
  local INTELLIJ_THEME_PATH="$THEME_DIR/$choice/intellij"

  # Check if laf.xml file exist
  if [[ ! -f "$INTELLIJ_THEME_PATH/laf.xml" ]]; then
    notify-send -e "Intellij laf.xml config Error" "'$INTELLIJ_THEME_PATH/laf.xml' not found."
  fi

  # Check if colors.scheme.xml file exist
  if [[ ! -f "$INTELLIJ_THEME_PATH/colors.scheme.xml" ]]; then
    notify-send -e "Intellij colors.scheme.xml config Error" "'$INTELLIJ_THEME_PATH/colors.scheme.xml' not found."
  fi

  # Create symlink to the laf.xml file
  ln -sf "$INTELLIJ_THEME_PATH/laf.xml" "$INTELLIJ_DIR/laf.xml"

  # Create symlink to the colors.scheme.xml file
  ln -sf "$INTELLIJ_THEME_PATH/colors.scheme.xml" "$INTELLIJ_DIR/colors.scheme.xml"
}

#------------------------------------------------------------------------------
# Function: apply_intellij
# Applies the intellij theme
#------------------------------------------------------------------------------
apply_hyprlock() {
  # Set hyprlock config path
  local HYPRLOCK_CONFIG_PATH="$THEME_DIR/$choice/hypr/hyprlock.conf"

  # Check if config file exist
  if [[ ! -f "$HYPRLOCK_CONFIG_PATH" ]]; then
    notify-send -e "HYPRLOCK config Error" "'$HYPRLOCK_CONFIG_PATH' not found."
  fi

  # Create symlink to the fzf config file
  ln -sf "$HYPRLOCK_CONFIG_PATH" "$HYPR_DIR/hyprlock.conf"

}

#------------------------------------------------------------------------------
# Function: main
# Main function that runs the theme selector and applies the chosen theme
#------------------------------------------------------------------------------
main() {
  # Show a rofi menu to select a theme
  choice=$(find "$THEME_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | rofi -i -dmenu -theme "$ROFI_THEME")

  # If a theme was selected, apply it
  if [[ -n "$choice" ]]; then
    # Apply each component of the theme
    apply_waybar
    apply_rofi
    set_wallpaper
    apply_swaync
    apply_gtk_qt
    apply_misc
    apply_sddm
    apply_kitty
    apply_yazi
    apply_spicetify
    apply_vesktop
    apply_zathura
    apply_btop
    apply_mpv
    apply_bat
    apply_cava
    apply_fzf
    apply_intellij
    apply_hyprlock

    # Refresh the desktop to apply changes
    sleep 4
    $SCRIPTS/refresh.sh

    # Notify the user that the theme has been applied
    notify-send -e -h string:x-canonical-private-synchronous:waybar_notif "System Theme" "Switched to: $choice"
  fi
}

# Run the main function
main
