#!/bin/bash

# NVIDIA Driver Installer
# Installs NVIDIA drivers and configures system for optimal performance

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

# Global variables
FAILED_STEPS=()
COMPLETED_STEPS=()
SKIPPED_STEPS=()
REBOOT_REQUIRED=false
GPU_ARCH=""
USE_OPEN_KERNEL=false
NVIDIA_PACKAGES=()

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

# Function to detect GPU architecture
detect_gpu_architecture() {
    print_status "info" "Detecting NVIDIA GPU architecture..."
    
    # Check if nvidia-smi is available
    if command -v nvidia-smi &>/dev/null; then
        local gpu_info=$(nvidia-smi --query-gpu=name,pci.device_id --format=csv,noheader,nounits 2>/dev/null)
        if [[ -n "$gpu_info" ]]; then
            local device_id=$(echo "$gpu_info" | cut -d',' -f2 | tr -d ' ')
            local gpu_name=$(echo "$gpu_info" | cut -d',' -f1)
            print_status "success" "Detected GPU: $gpu_name (Device ID: $device_id)"
            
            # Convert hex device ID to decimal for comparison
            local device_id_decimal=$((16#${device_id}))
            
            # NV160+ architectures start from device ID 0x1F00 (RTX 20 series)
            # This covers Turing, Ampere, Ada Lovelace, and Hopper architectures
            if [[ $device_id_decimal -ge 7936 ]]; then  # 0x1F00 = 7936
                GPU_ARCH="NV160+"
                USE_OPEN_KERNEL=true
            else
                GPU_ARCH="Legacy"
                USE_OPEN_KERNEL=false
            fi
        fi
    fi
    
    # Fallback: Try lspci
    if [[ -z "$GPU_ARCH" ]]; then
        local pci_info=$(lspci | grep -i nvidia | grep -i vga)
        if [[ -n "$pci_info" ]]; then
            print_status "info" "Found NVIDIA GPU via lspci: $pci_info"
            
            # Extract device ID from lspci output
            local device_id=$(echo "$pci_info" | grep -oE '[0-9a-fA-F]{4}:[0-9a-fA-F]{4}' | cut -d':' -f2)
            if [[ -n "$device_id" ]]; then
                local device_id_decimal=$((16#${device_id}))
                
                if [[ $device_id_decimal -ge 7936 ]]; then
                    GPU_ARCH="NV160+"
                    USE_OPEN_KERNEL=true
                else
                    GPU_ARCH="Legacy"
                    USE_OPEN_KERNEL=false
                fi
            fi
        fi
    fi
    
    # Manual detection if automatic methods failed
    if [[ -z "$GPU_ARCH" ]]; then
        print_status "warning" "Could not automatically detect GPU architecture"
        echo
        print_status "info" "Please help identify your GPU:"
        echo
        echo "Common NVIDIA GPU series and their architectures:"
        echo "  • GTX 16 series (GTX 1660, etc.) - Legacy"
        echo "  • RTX 20 series (RTX 2060, 2070, 2080, etc.) - NV160+"
        echo "  • RTX 30 series (RTX 3060, 3070, 3080, 3090, etc.) - NV160+"
        echo "  • RTX 40 series (RTX 4060, 4070, 4080, 4090, etc.) - NV160+"
        echo "  • GTX 10 series and older - Legacy"
        echo
        
        while true; do
            read -p "Does your GPU support the open kernel module? (RTX 20+ series) [y/N]: " response
            case "$response" in
                [Yy]|[Yy][Ee][Ss])
                    GPU_ARCH="NV160+ (Manual)"
                    USE_OPEN_KERNEL=true
                    break
                    ;;
                [Nn]|[Nn][Oo]|"")
                    GPU_ARCH="Legacy (Manual)"
                    USE_OPEN_KERNEL=false
                    break
                    ;;
                *)
                    print_status "warning" "Please answer yes (y) or no (n)"
                    ;;
            esac
        done
    fi
    
    # Set NVIDIA packages based on architecture
    if [[ "$USE_OPEN_KERNEL" == true ]]; then
        NVIDIA_PACKAGES=(
            nvidia-open-dkms
            nvidia-settings
            nvidia-utils
            libva
            libva-nvidia-driver
        )
        print_status "success" "Using open kernel module for $GPU_ARCH architecture"
    else
        NVIDIA_PACKAGES=(
            nvidia-dkms
            nvidia-settings
            nvidia-utils
            libva
            libva-nvidia-driver
        )
        print_status "success" "Using proprietary kernel module for $GPU_ARCH architecture"
    fi
    
    COMPLETED_STEPS+=("GPU Detection")
}

# Function to remove conflicting hyprland packages
remove_conflicting_packages() {
    print_status "configuring" "Checking for conflicting Hyprland packages..."
    
    local conflicting_packages=(
        "hyprland-git"
        "hyprland-nvidia"
        "hyprland-nvidia-git"
        "hyprland-nvidia-hidpi-git"
    )
    
    local found_conflicts=()
    for pkg in "${conflicting_packages[@]}"; do
        if is_package_installed "$pkg"; then
            found_conflicts+=("$pkg")
        fi
    done
    
    if [[ ${#found_conflicts[@]} -gt 0 ]]; then
        print_status "warning" "Removing conflicting Hyprland packages..."
        for pkg in "${found_conflicts[@]}"; do
            if sudo pacman -R --noconfirm "$pkg" &>/dev/null; then
                print_status "success" "Removed $pkg"
            else
                print_status "warning" "Failed to remove $pkg (might not be critical)"
            fi
        done
        COMPLETED_STEPS+=("Conflict Resolution")
    else
        print_status "success" "No conflicting packages found"
        COMPLETED_STEPS+=("Conflict Resolution")
    fi
}

# Function to install NVIDIA packages
install_nvidia_packages() {
    print_status "installing" "Installing NVIDIA packages and kernel headers..."
    echo
    
    # Get kernel modules
    local kernels=($(cat /usr/lib/modules/*/pkgbase 2>/dev/null | sort -u))
    
    if [[ ${#kernels[@]} -eq 0 ]]; then
        print_status "error" "No kernel modules found!"
        FAILED_STEPS+=("Package Installation")
        return 1
    fi
    
    # Prepare package list
    local packages_to_install=()
    
    # Add kernel headers
    for kernel in "${kernels[@]}"; do
        packages_to_install+=("${kernel}-headers")
    done
    
    # Add NVIDIA packages (already set based on GPU architecture)
    packages_to_install+=("${NVIDIA_PACKAGES[@]}")
    
    # Install packages
    local current=0
    local total=${#packages_to_install[@]}
    local failed_packages=()
    
    for package in "${packages_to_install[@]}"; do
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
        print_status "success" "All NVIDIA packages installed successfully"
        COMPLETED_STEPS+=("Package Installation")
        REBOOT_REQUIRED=true
        return 0
    else
        print_status "error" "Some packages failed to install"
        FAILED_STEPS+=("Package Installation")
        return 1
    fi
}

# Function to configure mkinitcpio
configure_mkinitcpio() {
    print_status "configuring" "Configuring mkinitcpio for NVIDIA..."
    
    local mkinitcpio_conf="/etc/mkinitcpio.conf"
    
    if grep -qE '^MODULES=.*nvidia.*nvidia_modeset.*nvidia_uvm.*nvidia_drm' "$mkinitcpio_conf"; then
        print_status "success" "NVIDIA modules already configured in mkinitcpio.conf"
        COMPLETED_STEPS+=("mkinitcpio Configuration")
    else
        print_status "configuring" "Adding NVIDIA modules to mkinitcpio.conf..."
        
        if sudo sed -Ei 's/^(MODULES=\([^\)]*)\)/\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$mkinitcpio_conf"; then
            print_status "success" "NVIDIA modules added to mkinitcpio.conf"
            COMPLETED_STEPS+=("mkinitcpio Configuration")
            REBOOT_REQUIRED=true
        else
            print_status "error" "Failed to modify mkinitcpio.conf"
            FAILED_STEPS+=("mkinitcpio Configuration")
            return 1
        fi
    fi
    
    # Rebuild initramfs
    print_status "configuring" "Rebuilding initramfs..."
    if sudo mkinitcpio -P &>/dev/null; then
        print_status "success" "Initramfs rebuilt successfully"
    else
        print_status "warning" "Initramfs rebuild had warnings (might still work)"
    fi
}

# Function to configure NVIDIA modprobe
configure_nvidia_modprobe() {
    print_status "configuring" "Configuring NVIDIA kernel module options..."
    
    local nvidia_conf="/etc/modprobe.d/nvidia.conf"
    local nvidia_options="options nvidia_drm modeset=1 fbdev=1"
    
    if [[ -f "$nvidia_conf" ]] && grep -q "nvidia_drm modeset=1 fbdev=1" "$nvidia_conf"; then
        print_status "success" "NVIDIA modprobe options already configured"
        COMPLETED_STEPS+=("Modprobe Configuration")
    else
        print_status "configuring" "Adding NVIDIA modprobe options..."
        
        if echo "$nvidia_options" | sudo tee -a "$nvidia_conf" &>/dev/null; then
            print_status "success" "NVIDIA modprobe options added"
            COMPLETED_STEPS+=("Modprobe Configuration")
            REBOOT_REQUIRED=true
        else
            print_status "error" "Failed to configure NVIDIA modprobe options"
            FAILED_STEPS+=("Modprobe Configuration")
            return 1
        fi
    fi
}

# Function to configure GRUB bootloader
configure_grub() {
    local grub_config="/etc/default/grub"
    
    if [[ ! -f "$grub_config" ]]; then
        return 0  # Not a GRUB system
    fi
    
    print_status "configuring" "GRUB bootloader detected - configuring..."
    
    local grub_updated=false
    
    # Check and add nvidia-drm.modeset=1
    if ! sudo grep -q "nvidia-drm.modeset=1" "$grub_config"; then
        sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia-drm.modeset=1"/' "$grub_config"
        print_status "success" "Added nvidia-drm.modeset=1 to GRUB"
        grub_updated=true
    fi
    
    # Check and add nvidia_drm.fbdev=1
    if ! sudo grep -q "nvidia_drm.fbdev=1" "$grub_config"; then
        sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia_drm.fbdev=1"/' "$grub_config"
        print_status "success" "Added nvidia_drm.fbdev=1 to GRUB"
        grub_updated=true
    fi
    
    # Regenerate GRUB configuration if updated
    if [[ "$grub_updated" == true ]]; then
        print_status "configuring" "Regenerating GRUB configuration..."
        if sudo grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null; then
            print_status "success" "GRUB configuration regenerated"
            COMPLETED_STEPS+=("GRUB Configuration")
            REBOOT_REQUIRED=true
        else
            print_status "error" "Failed to regenerate GRUB configuration"
            FAILED_STEPS+=("GRUB Configuration")
            return 1
        fi
    else
        print_status "success" "GRUB already configured for NVIDIA"
        COMPLETED_STEPS+=("GRUB Configuration")
    fi
}

# Function to configure systemd-boot
configure_systemd_boot() {
    local loader_config="/boot/loader/loader.conf"
    
    if [[ ! -f "$loader_config" ]]; then
        return 0  # Not a systemd-boot system
    fi
    
    print_status "configuring" "systemd-boot detected - configuring..."
    
    local entries_dir="/boot/loader/entries"
    local conf_files=($(find "$entries_dir" -name "*.conf" 2>/dev/null))
    
    if [[ ${#conf_files[@]} -eq 0 ]]; then
        print_status "warning" "No systemd-boot entries found"
        return 0
    fi
    
    local updated=false
    for conf_file in "${conf_files[@]}"; do
        # Create backup if it doesn't exist
        if [[ ! -f "${conf_file}.bak" ]]; then
            sudo cp "$conf_file" "${conf_file}.bak"
            print_status "info" "Created backup: $(basename "$conf_file").bak"
        fi
        
        # Update options line
        if ! grep -q "nvidia-drm.modeset=1" "$conf_file" || ! grep -q "nvidia_drm.fbdev=1" "$conf_file"; then
            # Clean up existing nvidia options and add new ones
            local current_options=$(grep "^options" "$conf_file" | sed 's/\b nvidia-drm.modeset=[^ ]*\b//g' | sed 's/\b nvidia_drm.fbdev=[^ ]*\b//g')
            sudo sed -i "/^options/c\\${current_options} nvidia-drm.modeset=1 nvidia_drm.fbdev=1" "$conf_file"
            print_status "success" "Updated $(basename "$conf_file")"
            updated=true
        fi
    done
    
    if [[ "$updated" == true ]]; then
        print_status "success" "systemd-boot configuration updated"
        COMPLETED_STEPS+=("systemd-boot Configuration")
        REBOOT_REQUIRED=true
    else
        print_status "success" "systemd-boot already configured for NVIDIA"
        COMPLETED_STEPS+=("systemd-boot Configuration")
    fi
}

# Function to show installation summary
show_summary() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                   NVIDIA INSTALLATION SUMMARY                ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Show GPU and driver info
    echo -e "${ORANGE}GPU Information:${NC}"
    echo -e "  Architecture: $GPU_ARCH"
    if [[ "$USE_OPEN_KERNEL" == true ]]; then
        echo -e "  Driver Type: ${GREEN}Open Kernel Module${NC} (nvidia-open-dkms)"
    else
        echo -e "  Driver Type: ${YELLOW}Proprietary Kernel Module${NC} (nvidia-dkms)"
    fi
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
        echo -e "║   ${RED}REBOOT REQUIRED${NC}${BRIGHT_ORANGE} to activate NVIDIA drivers!             ║"
        echo -e "║                                                               ║"
        echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo
    fi
    
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
        print_status "success" "NVIDIA installation completed successfully!"
        if [[ "$REBOOT_REQUIRED" == true ]]; then
            print_status "warning" "Please reboot your system to activate the drivers"
        fi
    else
        print_status "warning" "Installation completed with some failures"
    fi
}

# Main function
main() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                     NVIDIA DRIVER INSTALLER                  ║"
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
        "detect_gpu_architecture"
        "remove_conflicting_packages"
        "install_nvidia_packages"
        "configure_mkinitcpio"
        "configure_nvidia_modprobe"
        "configure_grub"
        "configure_systemd_boot"
    )
    
    local current_step=0
    local total_steps=${#steps[@]}
    
    for step_function in "${steps[@]}"; do
        ((current_step++))
        
        case "$step_function" in
            "detect_gpu_architecture")
                $step_function
                ;;
            "remove_conflicting_packages")
                $step_function
                ;;
            "install_nvidia_packages")
                $step_function
                ;;
            "configure_mkinitcpio")
                $step_function
                ;;
            "configure_nvidia_modprobe")
                $step_function
                ;;
            "configure_grub")
                $step_function
                ;;
            "configure_systemd_boot")
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