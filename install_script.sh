#!/bin/bash

# Diesel Dotfiles Install Script
# Beautiful TUI installer with orange theme

# Colors
ORANGE='\033[0;33m'
BRIGHT_ORANGE='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Box drawing characters
TOP_LEFT="╭"
TOP_RIGHT="╮"
BOTTOM_LEFT="╰"
BOTTOM_RIGHT="╯"
HORIZONTAL="─"
VERTICAL="│"
T_DOWN="┬"
T_UP="┴"
T_RIGHT="├"
T_LEFT="┤"
CROSS="┼"

# Global variables
NVIDIA_DETECTED=false
YAY_INSTALLED=false
BASEDEVEL_INSTALLED=false
GRUB_INSTALLED=false
OTHER_DM_INSTALLED=false
OTHER_BOOTLOADER_INSTALLED=false
OTHER_AUDIO_DAEMON_INSTALLED=false
ZSH_SHELL_DETECTED=false
HYPRLAND_INSTALLED=false
BACKUP_CHOICE=false
PIPEWIRE_CHOICE=false
SDDM_CHOICE=true
ZSH_CHOICE=true
SECURE_BOOT_CHOICE=false

# Package selection arrays (loaded from pkglist.sh)
declare -A DEV_TOOLS
declare -A APPLICATIONS
declare -A SYSTEM_UTILS

# Function to print centered text
center_text() {
    local text="$1"
    local width="${2:-80}"
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%*s%s%*s\n" $padding "" "$text" $padding ""
}

# Function to draw a box
draw_box() {
    local width="$1"
    local height="$2"
    local title="$3"
    
    # Top border
    printf "${ORANGE}${TOP_LEFT}"
    for ((i=1; i<width-1; i++)); do
        printf "${HORIZONTAL}"
    done
    printf "${TOP_RIGHT}${NC}\n"
    
    # Title line if provided
    if [[ -n "$title" ]]; then
        printf "${ORANGE}${VERTICAL}${NC}"
        center_text "${BRIGHT_ORANGE}${title}${NC}" $((width-2))
        printf "${ORANGE}${VERTICAL}${NC}\n"
        
        # Separator
        printf "${ORANGE}${T_RIGHT}"
        for ((i=1; i<width-1; i++)); do
            printf "${HORIZONTAL}"
        done
        printf "${T_LEFT}${NC}\n"
    fi
    
    # Content lines
    for ((i=0; i<height-3; i++)); do
        printf "${ORANGE}${VERTICAL}${NC}"
        printf "%*s" $((width-2)) ""
        printf "${ORANGE}${VERTICAL}${NC}\n"
    done
    
    # Bottom border
    printf "${ORANGE}${BOTTOM_LEFT}"
    for ((i=1; i<width-1; i++)); do
        printf "${HORIZONTAL}"
    done
    printf "${BOTTOM_RIGHT}${NC}\n"
}

# Function to load package lists from external file
load_package_lists() {
    local pkglist_file="pkglist.sh"
    
    if [[ ! -f "$pkglist_file" ]]; then
        echo -e "${RED}✗ Package list file '$pkglist_file' not found!${NC}"
        echo -e "${RED}  Please ensure pkglist.sh exists in the same directory as this script.${NC}"
        exit 1
    fi
    
    # Source the package list file
    source "$pkglist_file"
    
    # Verify that arrays were loaded
    if [[ ${#DEV_TOOLS[@]} -eq 0 ]] || [[ ${#APPLICATIONS[@]} -eq 0 ]] || [[ ${#SYSTEM_UTILS[@]} -eq 0 ]]; then
        echo -e "${RED}✗ Failed to load package arrays from $pkglist_file${NC}"
        echo -e "${RED}  Please check the format of your pkglist.sh file.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Package lists loaded successfully${NC}"
}

# Function to show the Diesel ASCII logo
show_logo() {
    clear
    echo -e "${BRIGHT_ORANGE}"
    cat << "EOF"


                       _____________                 ______                                      
                       ___  __ \__(_)___________________  /                                      
                       __  / / /_  /_  _ \_  ___/  _ \_  /                                       
                       _  /_/ /_  / /  __/(__  )/  __/  /                                        
                       /_____/ /_/  \___//____/ \___//_/                                         
                                                                                              
                	    🔥 Arch + Hyprland Dotfiles 🔥                             


┌─ INSTALLATION SETUP ─────────────────────────────────────────────────────────┐
│                                                                              │
│                    Welcome to the Diesel dotfiles installer!                 │
│                This script will set up your blazing fast Arch +              │
│                             Hyprland environment.                            │
│                                                                              │
│                          Keep it fast. Keep it clean.                        │
│                             	  🔥 DIESEL 🔥                                │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"
    echo
    center_text "${GRAY}Press Enter to continue...${NC}" 80
    read -r
}

# Function to show loading animation
loading_animation() {
    local text="$1"
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local delay=0.1
    
    for ((i=0; i<20; i++)); do
        for ((j=0; j<${#chars}; j++)); do
            printf "\r${ORANGE}${chars:$j:1} ${text}${NC}"
            sleep $delay
        done
    done
    printf "\r${GREEN}✓ ${text}${NC}\n"
}

# Function to ask yes/no question
ask_yn() {
    local question="$1"
    local default="$2"
    local response
    
    while true; do
        if [[ "$default" == "y" ]]; then
            printf "${ORANGE}${question} ${WHITE}[Y/n]${NC}: "
        else
            printf "${ORANGE}${question} ${WHITE}[y/N]${NC}: "
        fi
        
        read -r response
        response=${response,,} # Convert to lowercase
        
        if [[ -z "$response" ]]; then
            response="$default"
        fi
        
        case "$response" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo -e "${RED}Please answer yes or no.${NC}" ;;
        esac
    done
}

# Function to check system requirements
check_requirements() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                            SYSTEM CHECKS                                    ║"
    echo -e "╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Load package lists first
    load_package_lists
    
    # Check if running on Arch Linux
    if ! command -v pacman &> /dev/null; then
        echo -e "${RED}✗ This script is designed for Arch Linux only!${NC}"
        echo -e "${RED}  Please install Arch Linux first.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Arch Linux detected${NC}"
    
    # Check if Hyprland is installed
    if command -v Hyprland &> /dev/null; then
        HYPRLAND_INSTALLED=true
        echo -e "${GREEN}✓ Hyprland is installed${NC}"
    else
        echo -e "${RED}✗ Hyprland is not installed!${NC}"
        echo -e "${RED}  Please install Hyprland first: pacman -S hyprland${NC}"
        exit 1
    fi
    
    # Check base-devel
    if pacman -Qq base-devel &> /dev/null; then
        BASEDEVEL_INSTALLED=true
        echo -e "${GREEN}✓ base-devel is installed${NC}"
    else
        echo -e "${RED}✗ base-devel is not installed${NC}"
        echo -e "${YELLOW}  Installing base-devel...${NC}"
        sudo pacman -S --needed base-devel
        BASEDEVEL_INSTALLED=true
    fi
    
    # Check for NVIDIA
    if lspci | grep -i nvidia &> /dev/null; then
        NVIDIA_DETECTED=true
        echo -e "${YELLOW}⚠ NVIDIA GPU detected${NC}"
    else
        echo -e "${GREEN}✓ No NVIDIA GPU detected${NC}"
    fi
    
    # Check for yay
    if command -v yay &> /dev/null; then
        YAY_INSTALLED=true
        echo -e "${GREEN}✓ yay is installed${NC}"
    else
        echo -e "${RED}✗ yay is not installed${NC}"
        echo -e "${YELLOW}  Installing yay...${NC}"
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
        YAY_INSTALLED=true
    fi

    # Check for ZSH shell
    if echo "$SHELL" | grep -q "zsh" || \
       getent passwd "$USER" | cut -d: -f7 | grep -q "zsh" || \
       [ "$0" = "zsh" ] || \
       [ -n "$ZSH_VERSION" ]; then
        ZSH_SHELL_DETECTED=true
        echo -e "${YELLOW}⚠ ZSH shell detected${NC}"
    else
        echo -e "${GREEN}✓ No ZSH shell in use${NC}"
    fi

    # Check for other audio daemons
    if systemctl --user list-unit-files | grep -E "(pulseaudio|jack)" | grep -q enabled || \
       pgrep -x "pulseaudio" >/dev/null 2>&1 || \
       pgrep -x "jackd" >/dev/null 2>&1 || \
       pgrep -x "jackdbus" >/dev/null 2>&1 || \
       systemctl --user is-active pulseaudio >/dev/null 2>&1 || \
       systemctl --user is-active jack >/dev/null 2>&1; then
        OTHER_AUDIO_DAEMON_INSTALLED=true
        echo -e "${YELLOW}⚠ Other audio daemon detected${NC}"
    else
        echo -e "${GREEN}✓ No conflicting audio daemons${NC}"
    fi
    
    # Check for other bootloaders
    if command -v systemd-boot >/dev/null 2>&1 || \
       command -v rEFInd >/dev/null 2>&1 || \
       command -v lilo >/dev/null 2>&1 || \
       command -v syslinux >/dev/null 2>&1 || \
       [ -d /boot/loader ] || \
       [ -f /boot/refind_linux.conf ] || \
       [ -f /boot/syslinux/syslinux.cfg ] || \
       [ -f /etc/lilo.conf ]; then
        OTHER_BOOTLOADER_INSTALLED=true
        echo -e "${YELLOW}⚠ Other bootloader detected${NC}"
    else
        echo -e "${GREEN}✓ No conflicting bootloaders${NC}"
    fi
    
    # Check for other display managers
    if systemctl list-unit-files | grep -E "(gdm|lightdm|lxdm)" | grep -q enabled; then
        OTHER_DM_INSTALLED=true
        echo -e "${YELLOW}⚠ Other display manager detected${NC}"
    else
        echo -e "${GREEN}✓ No conflicting display managers${NC}"
    fi
    
    echo
    echo -e "${GRAY}Press Enter to continue...${NC}"
    read -r
}

# Function to show selection menu
show_selection_menu() {
    local title="$1"
    local -n array_ref=$2
    local keys=()
    
    # Get array keys
    for key in "${!array_ref[@]}"; do
        keys+=("$key")
    done
    
    while true; do
        clear
        echo -e "${BRIGHT_ORANGE}╔═════════════════════════════════════════════════════════════════════════════╗"
        printf "║%*s║\n" 77 "$(center_text "$title" 75)"
        echo -e "╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${ORANGE}Use ${WHITE}SPACE${ORANGE} to toggle, ${WHITE}A${ORANGE} to toggle all, ${WHITE}ENTER${ORANGE} to continue${NC}"
        echo
        
        local i=0
        for key in "${keys[@]}"; do
            local status="✗"
            local color="${RED}"
            if [[ "${array_ref[$key]}" == "true" ]]; then
                status="✓"
                color="${GREEN}"
            fi
            
            printf "${GRAY}%2d.${NC} %s${color}%s${NC} %s\n" $((i+1)) "[" "$status" "] $key"
            ((i++))
        done
        
        echo
        printf "${GRAY}%2s.${NC} [${GREEN}✓${NC}] ${ORANGE}Toggle All${NC}\n" "A"
        printf "${GRAY}%2s.${NC} ${ORANGE}Continue${NC}\n" "↵"
        echo
        printf "${ORANGE}Select option: ${NC}"
        
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#keys[@]} ]]; then
            local key="${keys[$((choice-1))]}"
            if [[ "${array_ref[$key]}" == "true" ]]; then
                array_ref[$key]=false
            else
                array_ref[$key]=true
            fi
        elif [[ "${choice,,}" == "a" ]]; then
            # Toggle all
            local all_true=true
            for key in "${keys[@]}"; do
                if [[ "${array_ref[$key]}" == "false" ]]; then
                    all_true=false
                    break
                fi
            done
            
            for key in "${keys[@]}"; do
                if [[ "$all_true" == "true" ]]; then
                    array_ref[$key]=false
                else
                    array_ref[$key]=true
                fi
            done
        elif [[ -z "$choice" ]]; then
            break
        fi
    done
}

# Function to create backup
create_backup() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    BACKUP_DIR="$HOME/.dotfiles-backup-$timestamp"
    
    print_info "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing files that would be overwritten
    if [[ -d "$HOME/.config" ]]; then
        print_info "Backing up existing .config directory..."
        if ! cp -r "$HOME/.config" "$BACKUP_DIR/config-backup" 2>/dev/null; then
            print_warning "Failed to backup .config directory"
        fi
    fi
    
    # Backup other dotfiles in home directory
    for file in "$HOME"/.*; do
        if [[ -f "$file" ]] && [[ ! "$file" =~ ^\.$|^\.\.$|^\.bash_history$|^\.lesshst$ ]]; then
            local filename=$(basename "$file")
            if [[ -f "$DOTFILES_DIR/$filename" ]]; then
                print_info "Backing up existing $filename..."
                if ! cp "$file" "$BACKUP_DIR/" 2>/dev/null; then
                    print_warning "Failed to backup $filename"
                fi
            fi
        fi
    done
    
    print_success "Backup created at: $BACKUP_DIR"
}

# Function to gather user preferences
gather_preferences() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                          USER PREFERENCES                                   ║"
    echo -e "╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Backup question
    if ask_yn "Do you want to create a backup of your current .config directory? \n the installation of the dotfiles could override your current settings" "y"; then
        BACKUP_CHOICE=true
    fi
    echo

    # Grub question (if other Boot loader detected)
    if [[ "$OTHER_BOOTLOADER_INSTALLED" ]]; then
        if ask_yn "Another boot loader is installed. Do you want to use Grub instead?" "y"; then
            GRUB_INSTALLED=true
        else
            GRUB_INSTALLED=false
        fi
        echo
    else
        GRUB_INSTALLED=true
    fi
    
    # PipeWire question (if other Audio Daemon detected)
    if [[ "$OTHER_AUDIO_DAEMON_INSTALLED" ]]; then
        if ask_yn "Another audio daemon is installed. Do you want to use PipeWire instead?" "y"; then
            PIPEWIRE_CHOICE=true
        else
            PIPEWIRE_CHOICE=false
        fi
        echo
    else
        PIPEWIRE_CHOICE=true
    fi
    
    # SDDM question (if other DM detected)
    if [[ "$OTHER_DM_INSTALLED" ]]; then
        if ask_yn "Another display manager is installed. Do you want to use SDDM instead?" "y"; then
            SDDM_CHOICE=true
        else
            SDDM_CHOICE=false
        fi
        echo
    else
        SDDM_CHOICE=true
    fi
    
    # zsh question (if other shell detected)
    if [[ "$ZSH_SHELL_DETECTED" ]]; then
        if ask_yn "Another shell is installed. Do you want to use Zsh instead?" "y"; then
            ZSH_CHOICE=true
        else
            ZSH_CHOICE=false
        fi
        echo
    else
        ZSH_CHOICE=true
    fi

    # Secure boot (commented for future)
    # if ask_yn "Do you want to enable Secure Boot support?" "n"; then
    #     SECURE_BOOT_CHOICE=true
    # fi
    echo -e "${GRAY}# Secure boot support will be added in future versions${NC}"

    # Final questions
    clear
    echo -e "${BRIGHT_ORANGE}╔═════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                          PACKAGE SELECTION                                  ║"
    echo -e "╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Package selections
    show_selection_menu "DEV TOOLS" DEV_TOOLS
    show_selection_menu "APPLICATIONS" APPLICATIONS
    show_selection_menu "SYSTEM UTILITIES" SYSTEM_UTILS
    
}

# Function to show confirmation
show_confirmation() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                         INSTALLATION SUMMARY                                ║"
    echo -e "╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    echo -e "${ORANGE}System Configuration:${NC}"
    echo -e "  NVIDIA Support: $([[ $NVIDIA_DETECTED == true ]] && echo -e "${GREEN}Yes${NC}" || echo -e "${GRAY}No${NC}")"
    echo -e "  Backup .config: $([[ $BACKUP_CHOICE == true ]] && echo -e "${GREEN}Yes${NC}" || echo -e "${GRAY}No${NC}")"
    echo -e "  PipeWire: $([[ $PIPEWIRE_CHOICE == true ]] && echo -e "${GREEN}Yes${NC}" || echo -e "${GRAY}No${NC}")"
    echo -e "  SDDM: $([[ $SDDM_CHOICE == true ]] && echo -e "${GREEN}Yes${NC}" || echo -e "${GRAY}No${NC}")"
    echo -e "  Zsh Shell: $([[ $ZSH_CHOICE == true ]] && echo -e "${GREEN}Yes${NC}" || echo -e "${GRAY}No${NC}")"
    echo -e "  Grub: $([[ $GRUB_INSTALLED == true ]] && echo -e "${GREEN}Yes${NC}" || echo -e "${GRAY}No${NC}")"
    echo
    
    echo -e "${ORANGE}Dev Tools:${NC}"
    for tool in "${!DEV_TOOLS[@]}"; do
        if [[ "${DEV_TOOLS[$tool]}" == "true" ]]; then
            echo -e "  ${GREEN}✓${NC} $tool"
        fi
    done
    echo
    
    echo -e "${ORANGE}Applications:${NC}"
    for app in "${!APPLICATIONS[@]}"; do
        if [[ "${APPLICATIONS[$app]}" == "true" ]]; then
            echo -e "  ${GREEN}✓${NC} $app"
        fi
    done
    echo
    
    echo -e "${ORANGE}System Utilities:${NC}"
    for util in "${!SYSTEM_UTILS[@]}"; do
        if [[ "${SYSTEM_UTILS[$util]}" == "true" ]]; then
            echo -e "  ${GREEN}✓${NC} $util"
        fi
    done
    echo
    
    if ! ask_yn "${BRIGHT_ORANGE}Do you want to proceed with the installation?" "y"; then
        echo -e "${RED}Installation cancelled.${NC}"
        exit 0
    fi
}

# Function to execute installation
execute_installation() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                           INSTALLATION                                      ║"
    echo -e "╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Create backup first
    create_backup


    if [[ "$NVIDIA_DETECTED" == "true" ]]; then
        echo -e "${ORANGE}Setting up NVIDIA settings and drivers...${NC}"
        if [[ -f "scripts/nvidia.sh" ]]; then
            bash scripts/nvidia.sh
        else
            echo -e "${YELLOW}⚠ NVIDIA setup script not found, skipping...${NC}"
        fi
    fi
    
    if [[ "$PIPEWIRE_CHOICE" == "true" ]]; then
        echo -e "${ORANGE}Setting up PipeWire...${NC}"
        if [[ -f "scripts/pipewire.sh" ]]; then
            bash scripts/pipewire.sh
        else
            echo -e "${YELLOW}⚠ PipeWire setup script not found, skipping...${NC}"
        fi
    fi
    
    if [[ "$SDDM_CHOICE" == "true" ]]; then
        echo -e "${ORANGE}Setting up SDDM...${NC}"
        if [[ -f "scripts/sddm.sh" ]]; then
            bash scripts/sddm.sh
        else
            echo -e "${YELLOW}⚠ SDDM setup script not found, skipping...${NC}"
        fi
    fi
    
    if [[ "$ZSH_CHOICE" == "true" ]]; then
        echo -e "${ORANGE}Setting up Zsh...${NC}"
        if [[ -f "scripts/zsh.sh" ]]; then
            bash scripts/zsh.sh
        else
            echo -e "${YELLOW}⚠ Zsh setup script not found, skipping...${NC}"
        fi
    fi

    #Installing fonts
    if [[ -f "scripts/fonts.sh" ]]; then
        bash scripts/fonts.sh
    else
        echo -e "${YELLOW}⚠ Fonts setup script not found, skipping...${NC}"
    fi

    # Install selected packages - This is the main addition
    echo -e "${ORANGE}Installing packages...${NC}"
    if [[ -f "scripts/install-packages.sh" ]]; then
        # Export the arrays so the package installer can access them
        export -A DEV_TOOLS
        export -A APPLICATIONS
        export -A SYSTEM_UTILS
        
        # Make the script executable and run it
        chmod +x scripts/install-packages.sh
        if bash scripts/install-packages.sh; then
            echo -e "${GREEN}✓ Package installation completed successfully${NC}"
        else
            echo -e "${YELLOW}⚠ Package installation completed with some issues${NC}"
            echo -e "${GRAY}  Check the summary above for details${NC}"
        fi
    else
        echo -e "${RED}✗ Package installation script not found!${NC}"
        echo -e "${RED}  Please ensure scripts/install-packages.sh exists${NC}"
    fi
    
    # Copy dotfiles
    echo -e "${ORANGE}Copying dotfiles...${NC}"
    if [[ -f "scripts/copy-dotfiles.sh" ]]; then
        chmod +x scripts/copy-dotfiles.sh
        if bash scripts/copy-dotfiles.sh; then
            echo -e "${GREEN}✓ Dotfiles copied successfully${NC}"
        else
            echo -e "${YELLOW}⚠ Dotfiles copying completed with some issues${NC}"
            echo -e "${GRAY}  Check the output above for details${NC}"
        fi
    else
        echo -e "${RED}✗ Dotfiles copy script not found!${NC}"
        echo -e "${RED}  Please ensure scripts/copy-dotfiles.sh exists${NC}"
    fi    
    
    echo
    echo -e "${BRIGHT_ORANGE}╔═════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                        INSTALLATION COMPLETE                                ║"
    echo -e "╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}✓ Installation completed successfully!${NC}"
    echo
    echo -e "${ORANGE}Next steps:${NC}"
    echo -e "  1. ${WHITE}Reboot your system${NC} to apply all changes"
    echo -e "  2. ${WHITE}Log in${NC} using your display manager"
    echo -e "  3. ${WHITE}Enjoy${NC} your new Diesel dotfiles setup!"
    echo
    
    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Some packages failed to install. You can manually install them later:${NC}"
        for package in "${FAILED_PACKAGES[@]}"; do
            echo -e "    ${GRAY}•${NC} $package"
        done
        echo
    fi
    
    echo -e "${GRAY}Press Enter to exit...${NC}"
    read -r
}

# Main function
main() {
    show_logo
    check_requirements
    gather_preferences
    show_confirmation
    execute_installation
}

# Run main function
main "$@"