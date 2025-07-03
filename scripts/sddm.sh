#!/bin/bash

# SDDM Display Manager Installer
# Installs SDDM display manager and configures system for optimal performance

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

# SDDM packages
sddm_packages=(
  qt6-5compat
  qt6-declarative
  qt6-svg
  sddm
)

# Login managers to disable
conflicting_login_managers=(
  lightdm
  gdm3
  gdm
  lxdm
  lxdm-gtk3
)

# Global variables
FAILED_STEPS=()
COMPLETED_STEPS=()
SKIPPED_STEPS=()
REBOOT_REQUIRED=false

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
    local step_name="$3"
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
    
    # Print progress bar with step info
    printf "\r${ORANGE}Progress: ${WHITE}[${GREEN}%s${WHITE}] ${BRIGHT_ORANGE}%3d%%${WHITE} (${ORANGE}%d${WHITE}/${ORANGE}%d${WHITE}) ${GRAY}%s${NC}" \
           "$bar" "$percentage" "$current" "$total" "$step_name"
    
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

# Function to check if service is enabled
is_service_enabled() {
    local service="$1"
    systemctl is-enabled "$service" &>/dev/null
}

# Function to check if service is active
is_service_active() {
    local service="$1"
    systemctl is-active --quiet "$service" &>/dev/null
}

# Function to install SDDM packages
install_sddm_packages() {
    print_status "installing" "Installing SDDM display manager and dependencies..."
    echo
    
    local packages_to_install=()
    local current=0
    local total=${#sddm_packages[@]}
    local failed_packages=()
    
    for package in "${sddm_packages[@]}"; do
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
        print_status "success" "All SDDM packages installed successfully"
        COMPLETED_STEPS+=("Package Installation")
        return 0
    else
        print_status "error" "Some packages failed to install: ${failed_packages[*]}"
        FAILED_STEPS+=("Package Installation")
        return 1
    fi
}

# Function to disable conflicting login managers
disable_conflicting_managers() {
    print_status "configuring" "Checking for conflicting login managers..."
    
    local found_managers=()
    local disabled_managers=()
    local failed_to_disable=()
    
    # Check for installed conflicting managers
    for manager in "${conflicting_login_managers[@]}"; do
        if is_package_installed "$manager"; then
            found_managers+=("$manager")
        fi
    done
    
    if [[ ${#found_managers[@]} -eq 0 ]]; then
        print_status "success" "No conflicting login managers found"
        COMPLETED_STEPS+=("Conflict Resolution")
        return 0
    fi
    
    print_status "warning" "Found conflicting login managers: ${found_managers[*]}"
    
    # Disable conflicting services
    for manager in "${found_managers[@]}"; do
        local service_name="${manager}.service"
        
        # Check if service exists and is enabled
        if systemctl list-unit-files | grep -q "^$service_name"; then
            if is_service_enabled "$service_name" || is_service_active "$service_name"; then
                print_status "configuring" "Disabling $manager service..."
                
                if sudo systemctl disable "$service_name" --now &>/dev/null; then
                    print_status "success" "$manager service disabled"
                    disabled_managers+=("$manager")
                else
                    print_status "error" "Failed to disable $manager service"
                    failed_to_disable+=("$manager")
                fi
            else
                print_status "info" "$manager service already disabled"
                disabled_managers+=("$manager")
            fi
        else
            print_status "info" "No service found for $manager"
        fi
    done
    
    # Additional check with systemctl for any active managers
    for manager in "${conflicting_login_managers[@]}"; do
        if is_service_active "$manager"; then
            print_status "warning" "$manager is still active, attempting to stop..."
            if sudo systemctl stop "$manager" &>/dev/null; then
                print_status "success" "$manager stopped"
            else
                print_status "error" "Failed to stop $manager"
                failed_to_disable+=("$manager")
            fi
        fi
    done
    
    if [[ ${#failed_to_disable[@]} -eq 0 ]]; then
        print_status "success" "Conflicting login managers handled successfully"
        COMPLETED_STEPS+=("Conflict Resolution")
        return 0
    else
        print_status "warning" "Some managers could not be disabled: ${failed_to_disable[*]}"
        FAILED_STEPS+=("Conflict Resolution")
        return 1
    fi
}

# Function to enable SDDM service
enable_sddm_service() {
    print_status "configuring" "Configuring SDDM service..."
    
    # Check if SDDM is already enabled
    if is_service_enabled "sddm.service"; then
        print_status "success" "SDDM service already enabled"
        COMPLETED_STEPS+=("Service Configuration")
        return 0
    fi
    
    # Enable SDDM service
    print_status "configuring" "Enabling SDDM service..."
    if sudo systemctl enable sddm.service &>/dev/null; then
        print_status "success" "SDDM service enabled successfully"
        COMPLETED_STEPS+=("Service Configuration")
        REBOOT_REQUIRED=true
        return 0
    else
        print_status "error" "Failed to enable SDDM service"
        FAILED_STEPS+=("Service Configuration")
        return 1
    fi
}

# Function to create wayland sessions directory
create_wayland_sessions_dir() {
    print_status "configuring" "Checking Wayland sessions directory..."
    
    local wayland_sessions_dir="/usr/share/wayland-sessions"
    
    if [[ -d "$wayland_sessions_dir" ]]; then
        print_status "success" "Wayland sessions directory already exists"
        COMPLETED_STEPS+=("Directory Setup")
        return 0
    fi
    
    print_status "configuring" "Creating Wayland sessions directory..."
    if sudo mkdir -p "$wayland_sessions_dir" &>/dev/null; then
        print_status "success" "Wayland sessions directory created"
        COMPLETED_STEPS+=("Directory Setup")
        return 0
    else
        print_status "error" "Failed to create Wayland sessions directory"
        FAILED_STEPS+=("Directory Setup")
        return 1
    fi
}

# Function to configure SDDM
configure_sddm() {
    print_status "configuring" "Configuring SDDM settings..."
    
    local sddm_conf_dir="/etc/sddm.conf.d"
    local sddm_conf_file="$sddm_conf_dir/10-wayland.conf"
    
    # Create SDDM config directory if it doesn't exist
    if [[ ! -d "$sddm_conf_dir" ]]; then
        if sudo mkdir -p "$sddm_conf_dir" &>/dev/null; then
            print_status "success" "Created SDDM config directory"
        else
            print_status "error" "Failed to create SDDM config directory"
            FAILED_STEPS+=("SDDM Configuration")
            return 1
        fi
    fi
    
    # Check if Wayland configuration already exists
    if [[ -f "$sddm_conf_file" ]] && grep -q "DisplayServer=wayland" "$sddm_conf_file"; then
        print_status "success" "SDDM Wayland configuration already exists"
        COMPLETED_STEPS+=("SDDM Configuration")
        return 0
    fi
    
    # Create Wayland configuration for SDDM
    print_status "configuring" "Creating SDDM Wayland configuration..."
    
    local wayland_config="[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1"
    
    if echo "$wayland_config" | sudo tee "$sddm_conf_file" &>/dev/null; then
        print_status "success" "SDDM Wayland configuration created"
        COMPLETED_STEPS+=("SDDM Configuration")
        return 0
    else
        print_status "error" "Failed to create SDDM configuration"
        FAILED_STEPS+=("SDDM Configuration")
        return 1
    fi
}

# Function to show installation summary
show_summary() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                    SDDM INSTALLATION SUMMARY                 ║"
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
        print_status "warning" "Some steps failed - manual intervention may be required"
        echo
    fi
    
    # Show reboot requirement
    if [[ "$REBOOT_REQUIRED" == true ]]; then
        echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
        echo -e "║                         IMPORTANT                            ║"
        echo -e "║                                                               ║"
        echo -e "║   ${RED}REBOOT REQUIRED${NC}${BRIGHT_ORANGE} to activate SDDM display manager!      ║"
        echo -e "║                                                               ║"
        echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo
    fi
    
    # Show post-installation information
    echo -e "${ORANGE}Post-Installation Information:${NC}"
    echo -e "  • SDDM is now your default display manager"
    echo -e "  • Wayland sessions directory: ${GRAY}/usr/share/wayland-sessions${NC}"
    echo -e "  • SDDM configuration: ${GRAY}/etc/sddm.conf.d/${NC}"
    echo -e "  • Service status: ${GRAY}systemctl status sddm${NC}"
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
        print_status "success" "SDDM installation completed successfully!"
        if [[ "$REBOOT_REQUIRED" == true ]]; then
            print_status "warning" "Please reboot your system to start using SDDM"
        fi
    else
        print_status "warning" "Installation completed with some failures"
    fi
}

# Main function
main() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                   SDDM DISPLAY MANAGER INSTALLER             ║"
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
    
    # Check for systemctl
    if ! command -v systemctl &>/dev/null; then
        print_status "error" "systemctl not found - systemd is required"
        exit 1
    fi
    
    print_status "info" "This installer will:"
    echo -e "  ${GRAY}• Install SDDM display manager and dependencies${NC}"
    echo -e "  ${GRAY}• Disable conflicting login managers${NC}"
    echo -e "  ${GRAY}• Configure SDDM for Wayland support${NC}"
    echo -e "  ${GRAY}• Enable SDDM service${NC}"
    echo
    
    # Main installation steps
    local steps=(
        "install_sddm_packages"
        "disable_conflicting_managers"
        "create_wayland_sessions_dir"
        "configure_sddm"
        "enable_sddm_service"
    )
    
    local current_step=0
    local total_steps=${#steps[@]}
    
    for step_function in "${steps[@]}"; do
        ((current_step++))
        
        case "$step_function" in
            "install_sddm_packages")
                $step_function
                ;;
            "disable_conflicting_managers")
                $step_function
                ;;
            "create_wayland_sessions_dir")
                $step_function
                ;;
            "configure_sddm")
                $step_function
                ;;
            "enable_sddm_service")
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