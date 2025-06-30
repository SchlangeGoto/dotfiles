#!/bin/bash

# PipeWire Audio System Installer
# Installs PipeWire and configures audio services

# Colors
ORANGE='\033[0;33m'
BRIGHT_ORANGE='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# PipeWire packages
pipewire_packages=(
    pipewire
    wireplumber
    pipewire-audio
    pipewire-alsa
    pipewire-pulse
    sof-firmware
)

# Force reinstall packages (to fix potential issues)
force_reinstall_packages=(
    pipewire-pulse
)

# PipeWire services to enable
pipewire_services=(
    "pipewire.socket"
    "pipewire-pulse.socket"
    "wireplumber.service"
    "pipewire.service"
)

# Global variables
FAILED_STEPS=()
COMPLETED_STEPS=()
SKIPPED_STEPS=()

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
        "configuring")
            echo -e "${PURPLE}⚙ ${message}${NC}"
            ;;
    esac
}

# Function to draw progress bar
draw_progress_bar() {
    local current="$1"
    local total="$2"
    local item_name="$3"
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
    
    # Print progress bar with item info
    printf "\r${ORANGE}Progress: ${WHITE}[${GREEN}%s${WHITE}] ${BRIGHT_ORANGE}%3d%%${WHITE} (${ORANGE}%d${WHITE}/${ORANGE}%d${WHITE}) ${GRAY}%s${NC}" \
           "$bar" "$percentage" "$current" "$total" "$item_name"
    
    # Add newline when complete
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Function to check if package is installed
is_package_installed() {
    local package="$1"
    pacman -Qq "$package" &>/dev/null
}

# Function to disable PulseAudio
disable_pulseaudio() {
    print_status "configuring" "Disabling PulseAudio to avoid conflicts..."
    
    local pulseaudio_services=(
        "pulseaudio.socket"
        "pulseaudio.service"
    )
    
    local disabled_any=false
    for service in "${pulseaudio_services[@]}"; do
        if systemctl --user is-enabled "$service" &>/dev/null; then
            if systemctl --user disable --now "$service" &>/dev/null; then
                print_status "success" "Disabled $service"
                disabled_any=true
            else
                print_status "warning" "Failed to disable $service (might not be critical)"
            fi
        fi
    done
    
    if [[ "$disabled_any" == true ]]; then
        print_status "success" "PulseAudio services disabled"
        COMPLETED_STEPS+=("PulseAudio Cleanup")
    else
        print_status "success" "No PulseAudio services to disable"
        COMPLETED_STEPS+=("PulseAudio Cleanup")
    fi
}

# Function to install PipeWire packages
install_pipewire_packages() {
    print_status "installing" "Installing PipeWire packages..."
    echo
    
    local current=0
    local total=${#pipewire_packages[@]}
    local failed_packages=()
    
    for package in "${pipewire_packages[@]}"; do
        ((current++))
        draw_progress_bar "$current" "$total" "$package"
        
        if sudo pacman -S --needed --noconfirm "$package" &>/dev/null; then
            printf "\r%-80s\r" " "  # Clear the line
            print_status "success" "$package installed"
        else
            printf "\r%-80s\r" " "  # Clear the line
            print_status "error" "Failed to install $package"
            failed_packages+=("$package")
        fi
    done
    
    echo
    
    if [[ ${#failed_packages[@]} -eq 0 ]]; then
        print_status "success" "All PipeWire packages installed successfully"
        COMPLETED_STEPS+=("Package Installation")
        return 0
    else
        print_status "error" "Some packages failed to install"
        FAILED_STEPS+=("Package Installation")
        return 1
    fi
}

# Function to force reinstall critical packages
force_reinstall_packages() {
    print_status "installing" "Force reinstalling critical packages..."
    echo
    
    local current=0
    local total=${#force_reinstall_packages[@]}
    local failed_packages=()
    
    for package in "${force_reinstall_packages[@]}"; do
        ((current++))
        draw_progress_bar "$current" "$total" "$package (force reinstall)"
        
        if sudo pacman -S --noconfirm "$package" &>/dev/null; then
            printf "\r%-80s\r" " "  # Clear the line
            print_status "success" "$package reinstalled"
        else
            printf "\r%-80s\r" " "  # Clear the line
            print_status "warning" "Failed to reinstall $package"
            failed_packages+=("$package")
        fi
    done
    
    echo
    
    if [[ ${#failed_packages[@]} -eq 0 ]]; then
        print_status "success" "All packages reinstalled successfully"
        COMPLETED_STEPS+=("Force Reinstall")
    else
        print_status "warning" "Some packages failed to reinstall (might not be critical)"
        COMPLETED_STEPS+=("Force Reinstall")
    fi
}

# Function to enable PipeWire services
enable_pipewire_services() {
    print_status "configuring" "Enabling PipeWire services..."
    echo
    
    local current=0
    local total=${#pipewire_services[@]}
    local failed_services=()
    
    for service in "${pipewire_services[@]}"; do
        ((current++))
        draw_progress_bar "$current" "$total" "$service"
        
        if systemctl --user enable --now "$service" &>/dev/null; then
            printf "\r%-80s\r" " "  # Clear the line
            print_status "success" "$service enabled and started"
        else
            printf "\r%-80s\r" " "  # Clear the line
            print_status "error" "Failed to enable $service"
            failed_services+=("$service")
        fi
    done
    
    echo
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        print_status "success" "All PipeWire services enabled successfully"
        COMPLETED_STEPS+=("Service Configuration")
        return 0
    else
        print_status "error" "Some services failed to start"
        FAILED_STEPS+=("Service Configuration")
        return 1
    fi
}

# Function to verify PipeWire status
verify_pipewire_status() {
    print_status "configuring" "Verifying PipeWire installation..."
    
    # Check if PipeWire is running
    if systemctl --user is-active --quiet pipewire.service; then
        print_status "success" "PipeWire service is running"
    else
        print_status "warning" "PipeWire service may not be running properly"
    fi
    
    # Check if WirePlumber is running
    if systemctl --user is-active --quiet wireplumber.service; then
        print_status "success" "WirePlumber service is running"
    else
        print_status "warning" "WirePlumber service may not be running properly"
    fi
    
    # Check if pipewire-pulse is working
    if pgrep -x pipewire-pulse &>/dev/null; then
        print_status "success" "PipeWire PulseAudio compatibility is active"
    else
        print_status "info" "PipeWire PulseAudio compatibility will start when needed"
    fi
    
    COMPLETED_STEPS+=("Status Verification")
}

# Function to show installation summary
show_summary() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                  PIPEWIRE INSTALLATION SUMMARY               ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    if [[ ${#COMPLETED_STEPS[@]} -gt 0 ]]; then
        echo -e "${GREEN}✓ Completed Steps (${#COMPLETED_STEPS[@]}):${NC}"
        for step in "${COMPLETED_STEPS[@]}"; do
            echo -e "  ${GREEN}•${NC} $step"
        done
        echo
    fi
    
    if [[ ${#SKIPPED_STEPS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Skipped Steps (${#SKIPPED_STEPS[@]}):${NC}"
        for step in "${SKIPPED_STEPS[@]}"; do
            echo -e "  ${YELLOW}•${NC} $step"
        done
        echo
    fi
    
    if [[ ${#FAILED_STEPS[@]} -gt 0 ]]; then
        echo -e "${RED}✗ Failed Steps (${#FAILED_STEPS[@]}):${NC}"
        for step in "${FAILED_STEPS[@]}"; do
            echo -e "  ${RED}•${NC} $step"
        done
        echo
        print_status "warning" "Some steps failed - audio may not work properly"
        echo
    fi
    
    # Show important information
    echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                         IMPORTANT                            ║"
    echo -e "║                                                               ║"
    echo -e "║   ${GREEN}PipeWire is now your audio system!${NC}${BRIGHT_ORANGE}                      ║"
    echo -e "║                                                               ║"
    echo -e "║   • Audio applications should work immediately                ║"
    echo -e "║   • PulseAudio applications are compatible                    ║"
    echo -e "║   • Use 'wpctl' command for audio control                    ║"
    echo -e "║   • Old 'pulseaudio' commands still work                     ║"
    echo -e "║                                                               ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    local total_steps=$((${#COMPLETED_STEPS[@]} + ${#SKIPPED_STEPS[@]} + ${#FAILED_STEPS[@]}))
    local success_rate=0
    if [[ $total_steps -gt 0 ]]; then
        success_rate=$(( (${#COMPLETED_STEPS[@]} + ${#SKIPPED_STEPS[@]}) * 100 / total_steps ))
    fi
    
    echo -e "${ORANGE}Installation Statistics:${NC}"
    echo -e "  Total steps: $total_steps"
    echo -e "  Success rate: ${success_rate}%"
    echo
    
    if [[ ${#FAILED_STEPS[@]} -eq 0 ]]; then
        print_status "success" "PipeWire installation completed successfully!"
        print_status "info" "Your audio system is ready to use"
    else
        print_status "warning" "Installation completed with some failures"
        print_status "info" "You may need to manually fix audio configuration"
    fi
}

# Main function
main() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                    PIPEWIRE AUDIO INSTALLER                  ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_status "error" "This script should not be run as root!"
        print_status "info" "Please run as a regular user (sudo will be used when needed)"
        exit 1
    fi
    
    # Check for required commands
    if ! command -v pacman &>/dev/null; then
        print_status "error" "This script is for Arch Linux (pacman not found)"
        exit 1
    fi
    
    # Main installation steps
    local steps=(
        "disable_pulseaudio"
        "install_pipewire_packages"
        "force_reinstall_packages"
        "enable_pipewire_services"
        "verify_pipewire_status"
    )
    
    local current_step=0
    local total_steps=${#steps[@]}
    
    for step_function in "${steps[@]}"; do
        ((current_step++))
        
        case "$step_function" in
            "disable_pulseaudio")
                $step_function
                ;;
            "install_pipewire_packages")
                $step_function
                ;;
            "force_reinstall_packages")
                $step_function
                ;;
            "enable_pipewire_services")
                $step_function
                ;;
            "verify_pipewire_status")
                $step_function
                ;;
        esac
        
        echo
    done
    
    # Show summary
    show_summary
    
    # Return appropriate exit code
    if [[ ${#FAILED_STEPS[@]} -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"