#!/bin/bash

# Diesel Dotfiles Package Lists
# This file contains all package selections for the installer

# Dev Tools - Development and programming tools
DEV_TOOLS=(
    ["intellij"]=true
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
    ["btop"]=true
    ["cava"]=true
    ["lsd"]=true
    ["xorg-eyes"]=true
)

# Essential packages (will be installed automatically)
ESSENTIALS_PACKAGES=(
    "hyprland"
    "waybar"
    "kitty"
    "rofi"
    "dunst"
    "swww"
    "hyprpicker-git"
    "grim"
    "slurp"
    "wl-clipboard"
    "xdg-desktop-portal-hyprland"
    "polkit-gnome"
    "thunar"
    "thunar-volman"
    "tumbler"
    "ffmpegthumbs"
)

# Package mappings - Maps display names to actual package names
# yay will handle both official repo and AUR packages automatically
declare -A PACKAGE_NAMES=(
    # Dev Tools
    ["intellij"]="intellij-idea-community-edition"
    ["java-jdk"]="jdk-openjdk"
    ["neovim"]="neovim"
    ["git"]="git"
    ["fzf"]="fzf"
    
    # Applications
    ["brave browser"]="brave-bin"
    ["zen browser"]="zen-browser-bin"
    ["obsidian"]="obsidian"
    ["spotify"]="spotify"
    ["vencord"]="vencord-desktop-bin"
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