#!/bin/bash

# Diesel Dotfiles Package Installer
# Installs selected packages based on user choices (yay only)

# Colors (matching main installer theme)
ORANGE='\033[0;33m'
BRIGHT_ORANGE='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Global variables
FAILED_PACKAGES=()
INSTALLED_PACKAGES=()
SKIPPED_PACKAGES=()

# Source the package lists
if [[ ! -f "pkglist.sh" ]]; then
    echo -e "${RED}✗ Package list file 'pkglist.sh' not found!${NC}"
    echo -e "${RED}  Please ensure pkglist.sh exists in the right directory.${NC}"
    exit 1
fi

source "../pkglist.sh"

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
    local bar_length=50
    
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
    printf "\r${ORANGE}Progress: ${WHITE}[${GREEN}%s${WHITE}] ${BRIGHT_ORANGE}%3d%%${WHITE} (${ORANGE}%d${WHITE}/${ORANGE}%d${WHITE}) ${GRAY}Installing: ${WHITE}%s${NC}" \
           "$bar" "$percentage" "$current" "$total" "$package_name"
    
    # Add newline when complete
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Function to check if package is already installed
is_package_installed() {
    local package="$1"
    
    # Use yay to check if package is installed
    if yay -Qq "$package" &>/dev/null; then
        return 0
    fi
    
    # For packages with multiple names, check the base name
    local base_name=$(echo "$package" | cut -d' ' -f1)
    if [[ "$base_name" != "$package" ]] && yay -Qq "$base_name" &>/dev/null; then
        return 0
    fi
    
    return 1
}

# Function to install package with yay
install_package() {
    local package="$1"
    local display_name="$2"
    local current="$3"
    local total="$4"
    
    # Show progress bar
    draw_progress_bar "$current" "$total" "$display_name"
    
    # Suppress yay output and install package
    if yay -S --needed --noconfirm $package &>/dev/null; then
        printf "\r%-80s\r" " "  # Clear the line
        print_status "success" "$display_name installed successfully"
        INSTALLED_PACKAGES+=("$display_name")
        return 0
    else
        printf "\r%-80s\r" " "  # Clear the line
        print_status "error" "Failed to install $display_name"
        FAILED_PACKAGES+=("$display_name")
        return 1
    fi
}

# Function to install selected packages from an array
install_selected_packages() {
    local -n package_array=$1
    local category_name="$2"
    
    echo
    print_status "info" "Installing $category_name..."
    echo
    
    local selected_count=0
    for package_key in "${!package_array[@]}"; do
        if [[ "${package_array[$package_key]}" == "true" ]]; then
            ((selected_count++))
        fi
    done
    
    if [[ $selected_count -eq 0 ]]; then
        print_status "warning" "No $category_name selected, skipping..."
        return 0
    fi
    
    local current=0
    for package_key in "${!package_array[@]}"; do
        if [[ "${package_array[$package_key]}" == "true" ]]; then
            ((current++))
            
            # Get package name
            local package_name="${PACKAGE_NAMES[$package_key]:-$package_key}"
            
            # Check if already installed
            local first_package=$(echo "$package_name" | cut -d' ' -f1)
            if is_package_installed "$first_package"; then
                draw_progress_bar "$current" "$selected_count" "$package_key (skipped - already installed)"
                printf "\r%-80s\r" " "  # Clear the line
                print_status "warning" "$package_key is already installed, skipping..."
                SKIPPED_PACKAGES+=("$package_key")
                continue
            fi
            
            # Install the package with yay
            install_package "$package_name" "$package_key" "$current" "$selected_count"
        fi
    done
    
    echo
}

# Function to install essential packages
install_essentials() {
    print_status "info" "Installing essential packages..."
    echo
    
    # Check if essentials are already installed
    local missing_essentials=()
    for package in "${ESSENTIALS_PACKAGES[@]}"; do
        if ! is_package_installed "$package"; then
            missing_essentials+=("$package")
        fi
    done
    
    if [[ ${#missing_essentials[@]} -eq 0 ]]; then
        print_status "success" "All essential packages are already installed"
        return 0
    fi
    
    print_status "installing" "Installing ${#missing_essentials[@]} essential packages..."
    echo
    
    # Install all missing essentials with yay
    local current=0
    for package in "${missing_essentials[@]}"; do
        ((current++))
        
        # Show progress bar
        draw_progress_bar "$current" "${#missing_essentials[@]}" "$package"
        
        if yay -S --needed --noconfirm "$package" &>/dev/null; then
            printf "\r%-80s\r" " "  # Clear the line
            print_status "success" "$package installed"
            INSTALLED_PACKAGES+=("$package")
        else
            printf "\r%-80s\r" " "  # Clear the line
            print_status "error" "Failed to install $package"
            FAILED_PACKAGES+=("$package")
        fi
    done
    
    echo
}

# Function to update system
update_system() {
    print_status "info" "Updating all packages with yay..."
    echo
    
    # Update all packages (both repo and AUR) with yay
    if yay -Syu --noconfirm; then
        print_status "success" "All packages updated successfully"
    else
        print_status "warning" "Package update had some issues, continuing..."
    fi
    
    echo
}

# Function to show installation summary
show_summary() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                        INSTALLATION SUMMARY                                ║"
    echo -e "╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
        echo -e "${GREEN}✓ Successfully Installed (${#INSTALLED_PACKAGES[@]}):${NC}"
        for package in "${INSTALLED_PACKAGES[@]}"; do
            echo -e "  ${GREEN}•${NC} $package"
        done
        echo
    fi
    
    if [[ ${#SKIPPED_PACKAGES[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Skipped (already installed) (${#SKIPPED_PACKAGES[@]}):${NC}"
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
        echo -e "${RED}You may need to install these packages manually later.${NC}"
        echo
    fi
    
    local total_selected=$((${#INSTALLED_PACKAGES[@]} + ${#SKIPPED_PACKAGES[@]} + ${#FAILED_PACKAGES[@]}))
    local success_rate=0
    if [[ $total_selected -gt 0 ]]; then
        success_rate=$(( (${#INSTALLED_PACKAGES[@]} + ${#SKIPPED_PACKAGES[@]}) * 100 / total_selected ))
    fi
    
    echo -e "${ORANGE}Installation Statistics:${NC}"
    echo -e "  Total packages processed: $total_selected"
    echo -e "  Success rate: ${success_rate}%"
    echo
    
    if [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
        print_status "success" "All packages installed successfully!"
    else
        print_status "warning" "Installation completed with some failures"
    fi
}

# Function to clean up
cleanup() {
    print_status "info" "Cleaning up package cache..."
    
    # Clean yay cache (handles both pacman and AUR cache)
    yay -Sc --noconfirm &>/dev/null
    
    print_status "success" "Cleanup completed"
}

# Main installation function
main() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                         PACKAGE INSTALLATION                               ║"
    echo -e "╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Check for required command
    if ! command -v yay &>/dev/null; then
        print_status "error" "yay not found! Please install yay first."
        print_status "info" "Install yay with: git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
        exit 1
    fi
    
    # Update system first
    update_system
    
    # Install essential packages
    install_essentials
    
    # Install selected packages by category
    install_selected_packages DEV_TOOLS "Development Tools"
    install_selected_packages APPLICATIONS "Applications"
    install_selected_packages SYSTEM_UTILS "System Utilities"
    
    # Clean up
    cleanup
    
    # Show summary
    show_summary
    
    # Return appropriate exit code
    if [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi