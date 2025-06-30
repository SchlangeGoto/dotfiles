#!/bin/bash

# Font Package Installer
# Installs essential fonts using yay

# Colors
ORANGE='\033[0;33m'
BRIGHT_ORANGE='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Font packages
fonts=(
  adobe-source-code-pro-fonts 
  noto-fonts-emoji
  otf-font-awesome 
  ttf-droid 
  ttf-fira-code
  ttf-fantasque-nerd
  ttf-jetbrains-mono 
  ttf-jetbrains-mono-nerd
  ttf-victor-mono
  noto-fonts
)

# Global variables
FAILED_PACKAGES=()
INSTALLED_PACKAGES=()
SKIPPED_PACKAGES=()

# Function to print status messages
print_status() {
    local status="$1"
    local message="$2"
    
    case "$status" in
        "info")
            echo -e "${ORANGE}ℹ ${message}${NC}"
            ;;
        "success")
            echo -e "${GREEN}✓ ${message}${NC}"
            ;;
        "error")
            echo -e "${RED}✗ ${message}${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠ ${message}${NC}"
            ;;
        "installing")
            echo -e "${BLUE}📦 ${message}${NC}"
            ;;
    esac
}

# Function to draw progress bar
draw_progress_bar() {
    local current="$1"
    local total="$2"
    local package_name="$3"
    local bar_length=40
    
    local percentage=$((current * 100 / total))
    local filled_length=$((current * bar_length / total))
    
    # Create the progress bar
    local bar=""
    for ((i=0; i<filled_length; i++)); do
        bar+="█"
    done
    for ((i=filled_length; i<bar_length; i++)); do
        bar+="░"
    done
    
    # Print progress bar with package info
    printf "\r${ORANGE}Progress: ${WHITE}[${GREEN}%s${WHITE}] ${BRIGHT_ORANGE}%3d%%${WHITE} (${ORANGE}%d${WHITE}/${ORANGE}%d${WHITE}) ${GRAY}%s${NC}" \
           "$bar" "$percentage" "$current" "$total" "$package_name"
    
    # Add newline when complete
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Function to check if package is already installed
is_package_installed() {
    local package="$1"
    yay -Qq "$package" &>/dev/null
}

# Function to install fonts
install_fonts() {
    print_status "info" "Installing font packages..."
    echo
    
    # Check which fonts need to be installed
    local missing_fonts=()
    for font in "${fonts[@]}"; do
        if ! is_package_installed "$font"; then
            missing_fonts+=("$font")
        else
            SKIPPED_PACKAGES+=("$font")
        fi
    done
    
    if [[ ${#missing_fonts[@]} -eq 0 ]]; then
        print_status "success" "All fonts are already installed"
        return 0
    fi
    
    print_status "installing" "Installing ${#missing_fonts[@]} font packages..."
    echo
    
    # Install missing fonts
    local current=0
    for font in "${missing_fonts[@]}"; do
        ((current++))
        
        # Show progress bar
        draw_progress_bar "$current" "${#missing_fonts[@]}" "$font"
        
        if yay -S --needed --noconfirm "$font" &>/dev/null; then
            printf "\r%-80s\r" " "  # Clear the line
            print_status "success" "$font installed"
            INSTALLED_PACKAGES+=("$font")
        else
            printf "\r%-80s\r" " "  # Clear the line
            print_status "error" "Failed to install $font"
            FAILED_PACKAGES+=("$font")
        fi
    done
    
    echo
}

# Function to update font cache
update_font_cache() {
    print_status "info" "Updating font cache..."
    
    if fc-cache -fv &>/dev/null; then
        print_status "success" "Font cache updated"
    else
        print_status "warning" "Font cache update had issues"
    fi
    
    echo
}

# Function to show installation summary
show_summary() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                    FONT INSTALLATION SUMMARY                 ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
        echo -e "${GREEN}✓ Successfully Installed (${#INSTALLED_PACKAGES[@]}):${NC}"
        for package in "${INSTALLED_PACKAGES[@]}"; do
            echo -e "  ${GREEN}•${NC} $package"
        done
        echo
    fi
    
    if [[ ${#SKIPPED_PACKAGES[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Already Installed (${#SKIPPED_PACKAGES[@]}):${NC}"
        for package in "${SKIPPED_PACKAGES[@]}"; do
            echo -e "  ${YELLOW}•${NC} $package"
        done
        echo
    fi
    
    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        echo -e "${RED}✗ Failed to Install (${#FAILED_PACKAGES[@]}):${NC}"
        for package in "${FAILED_PACKAGES[@]}"; do
            echo -e "  ${RED}•${NC} $package"
        done
        echo
        print_status "warning" "You may need to install failed packages manually"
        echo
    fi
    
    local total_fonts=${#fonts[@]}
    local success_count=$((${#INSTALLED_PACKAGES[@]} + ${#SKIPPED_PACKAGES[@]}))
    local success_rate=$((success_count * 100 / total_fonts))
    
    echo -e "${ORANGE}Installation Statistics:${NC}"
    echo -e "  Total fonts: $total_fonts"
    echo -e "  Success rate: ${success_rate}%"
    echo
    
    if [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
        print_status "success" "All fonts installed successfully!"
        print_status "info" "You may need to restart applications to see new fonts"
    else
        print_status "warning" "Installation completed with some failures"
    fi
}

# Main function
main() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                       FONT INSTALLER                         ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Check for required command
    if ! command -v yay &>/dev/null; then
        print_status "error" "yay not found! Please install yay first."
        exit 1
    fi
    
    # Install fonts
    install_fonts
    
    # Update font cache
    update_font_cache
    
    # Show summary
    show_summary
    
    # Return appropriate exit code
    if [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"