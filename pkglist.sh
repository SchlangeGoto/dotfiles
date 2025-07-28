#!/bin/bash

# Diesel Dotfiles Package Lists
# This file contains all package selections for the installer

# Dev Tools - Development and programming tools
DEV_TOOLS=(
    ["intellij-community"]=true
    ["intellij-ultimate"]=false
    ["java-jdk"]=true
    ["neovim"]=true
    ["git"]=true
    ["fzf"]=true
)

# Applications - User applications and software
APPLICATIONS=(
    ["brave browser"]=true
    ["zen browser"]=true
    ["obsidian"]=true
    ["spotify"]=true
    ["vencord"]=true
    ["calculator"]=true
    ["clock"]=true
    ["zathura"]=true
    ["qimgv"]=true
    ["yazi"]=true
    ["steam"]=true
)

# System Utilities - System tools and utilities
SYSTEM_UTILS=(
    ["fastfetch"]=true
    ["btop"]=true
    ["cava"]=true
    ["lsd"]=true
    ["xorg-eyes"]=true
)

# Essential packages (will be installed automatically)
ESSENTIALS_PACKAGES=(
    "bc"
    "cliphist"
    "ddcci-driver-linux-dkms"
    "ddcutil"
    "file-roller"
    "grim"
    "hypridle"
    "hyprlock"
    "hyprpicker"
    "hyprpolkitagent"
    "hyprshade"
    "hyprshot"
    "hyprsunset"
    "imagemagick"
    "jq"
    "kitty"
    "kvantum"
    "kvantum-qt5"
    "libadwaita-without-adwaita-git"
    "mpvpaper"
    "nemo"
    "nemo-fileroller"
    "network-manager-applet"
    "nwg-displays"
    "nwg-look"
    "qt5-wayland"
    "qt5ct"
    "qt6ct"
    "rofi-wayland"
    "slurp"
    "swaync"
    "swww"
    "udiskie"
    "waybar"
    "wlogout"
    "wlroots"
    "wtype"
    "xdg-desktop-portal-gtk"
    "xdg-desktop-portal-hyprland"
    "yad"
)

# Package mappings - Maps display names to actual package names
# yay will handle both official repo and AUR packages automatically
declare -A PACKAGE_NAMES=(
    # Dev Tools
    ["intellij-community"]="intellij-idea-community-edition"
    ["intellij-ultimate"]="intellij-idea-ultimate-edition"
    ["java-jdk"]="jdk21-openjdk"
    ["neovim"]="neovim"
    ["git"]="git"
    ["fzf"]="fzf"
    
    # Applications
    ["brave browser"]="brave-bin"
    ["zen browser"]="zen-browser-bin"
    ["obsidian"]="obsidian"
    ["spotify"]="spotify-launcher"
    ["vencord"]="vencord"
    ["calculator"]="gnome-calculator"
    ["clock"]="gnome-clocks"
    ["zathura"]="zathura zathura-pdf-mupdf"
    ["qimgv"]="qimgv"
    ["yazi"]="yazi"
    ["steam"]="steam"
    
    # System Utils
    ["btop"]="btop"
    ["cava"]="cava"
    ["lsd"]="lsd"
    ["xorg-eyes"]="xorg-xeyes"
)