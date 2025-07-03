#!/bin/bash

# Diesel Dotfiles Copy Script
# Copies dotfiles with proper permissions and executable handling

# Colors
ORANGE='\033[0;33m'
BRIGHT_ORANGE='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/../dotfiles"
HOME_DIR="$HOME"
COPY_COUNT=0
ERROR_COUNT=0

# Array to store files that failed to copy
declare -a FAILED_FILES

# Function to print messages
print_info() {
    echo -e "${ORANGE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to draw progress bar
draw_progress_bar() {
    local current="$1"
    local total="$2"
    local item_name="$3"
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
    
    # Print progress bar with item info
    printf "\r${ORANGE}Progress: ${WHITE}[${GREEN}%s${WHITE}] ${BRIGHT_ORANGE}%3d%%${WHITE} (${ORANGE}%d${WHITE}/${ORANGE}%d${WHITE}) ${GRAY}Copying: ${WHITE}%s${NC}" \
           "$bar" "$percentage" "$current" "$total" "$item_name"
    
    # Add newline when complete
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Function to copy a file or directory with error handling
copy_item() {
    local src="$1"
    local dest="$2"
    local item_name="$3"
    local current="$4"
    local total="$5"
    
    # Show progress bar
    draw_progress_bar "$current" "$total" "$item_name"
    
    if [[ -d "$src" ]]; then
        if cp -r "$src" "$dest" 2>/dev/null; then
            printf "\r%-80s\r" " "  # Clear the line
            print_success "Copied directory: $item_name"
            ((COPY_COUNT++))
            return 0
        else
            printf "\r%-80s\r" " "  # Clear the line
            print_error "Failed to copy directory: $item_name"
            FAILED_FILES+=("$item_name (directory)")
            ((ERROR_COUNT++))
            return 1
        fi
    elif [[ -f "$src" ]]; then
        if cp "$src" "$dest" 2>/dev/null; then
            printf "\r%-80s\r" " "  # Clear the line
            print_success "Copied file: $item_name"
            ((COPY_COUNT++))
            return 0
        else
            printf "\r%-80s\r" " "  # Clear the line
            print_error "Failed to copy file: $item_name"
            FAILED_FILES+=("$item_name (file)")
            ((ERROR_COUNT++))
            return 1
        fi
    else
        printf "\r%-80s\r" " "  # Clear the line
        print_warning "Skipping unknown item type: $item_name"
        return 1
    fi
}

# Function to count total items to be copied
count_items() {
    local count=0
    
    # Count .config if it exists
    if [[ -d "$DOTFILES_DIR/.config" ]]; then
        ((count++))
    fi
    
    # Count other files and directories (excluding .config)
    while IFS= read -r -d '' item; do
        local item_name=$(basename "$item")
        if [[ "$item_name" != ".config" ]]; then
            ((count++))
        fi
    done < <(find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
    
    echo "$count"
}

# Main copy function
copy_dotfiles() {
    print_info "Starting dotfiles copy process..."
    
    # Check if dotfiles directory exists
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        print_error "Dotfiles directory not found: $DOTFILES_DIR"
        print_error "Please ensure the dotfiles directory exists in the correct location"
        return 1
    fi
    
    print_info "Source directory: $DOTFILES_DIR"
    print_info "Target directory: $HOME_DIR"
    echo
    
    # Count total items for progress bar
    local total_items=$(count_items)
    local current_item=0
    
    print_info "Found $total_items items to copy"
    echo
    
    # Copy .config directory if it exists
    if [[ -d "$DOTFILES_DIR/.config" ]]; then
        ((current_item++))
        
        # Show progress for .config
        draw_progress_bar "$current_item" "$total_items" ".config directory"
        
        # Create .config directory if it doesn't exist
        if [[ ! -d "$HOME_DIR/.config" ]]; then
            if mkdir -p "$HOME_DIR/.config" 2>/dev/null; then
                printf "\r%-80s\r" " "  # Clear the line
                print_info "Created .config directory"
            else
                printf "\r%-80s\r" " "  # Clear the line
                print_error "Failed to create .config directory"
                ((ERROR_COUNT++))
                return 1
            fi
        fi
        
        # Copy contents of .config directory
        if cp -r "$DOTFILES_DIR/.config/"* "$HOME_DIR/.config/" 2>/dev/null; then
            printf "\r%-80s\r" " "  # Clear the line
            print_success "Copied .config directory contents"
            ((COPY_COUNT++))
            
            # Set executable permissions for script files
            print_info "Setting executable permissions for scripts..."
            chmod +x "$HOME/.config/hypr/scripts/"* 2>&1
            chmod +x "$HOME/.config/rofi/scripts/"* 2>&1
        else
            printf "\r%-80s\r" " "  # Clear the line
            print_error "Failed to copy .config directory contents"
            FAILED_FILES+=(".config (directory contents)")
            ((ERROR_COUNT++))
        fi
    fi
    
    # Copy all other files and directories from dotfiles (excluding .config)
    while IFS= read -r -d '' item; do
        local item_name=$(basename "$item")
        
        # Skip .config as we handled it separately
        if [[ "$item_name" == ".config" ]]; then
            continue
        fi
        
        ((current_item++))
        local dest_item="$HOME_DIR/$item_name"
        copy_item "$item" "$dest_item" "$item_name" "$current_item" "$total_items"
        
    done < <(find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
    
    echo
    print_info "Copy operation completed!"
    
    # Summary
    if [[ $ERROR_COUNT -eq 0 ]]; then
        print_success "✓ All dotfiles copied successfully! ($COPY_COUNT items)"
        return 0
    else
        print_warning "Copy completed with $ERROR_COUNT errors out of $((COPY_COUNT + ERROR_COUNT)) items"
        
        if [[ ${#FAILED_FILES[@]} -gt 0 ]]; then
            echo
            print_error "Failed to copy the following items:"
            for failed_item in "${FAILED_FILES[@]}"; do
                echo -e "  ${RED}•${NC} $failed_item"
            done
        fi
        return 1
    fi

    # Run user settings configuration
    user_settings
}

user_settings() {
    print_info "Configuring user settings..."
    echo
    
    # setting up for nvidia
    if lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq nvidia; then
        print_info "Nvidia GPU detected. Setting up proper env's and configs"
        sed -i '/env = LIBVA_DRIVER_NAME,nvidia/s/^#//' config/hypr/configs/env.conf
        sed -i '/env = __GLX_VENDOR_LIBRARY_NAME,nvidia/s/^#//' config/hypr/configs/env.conf
        sed -i '/env = NVD_BACKEND,direct/s/^#//' config/hypr/configs/env.conf
        sed -i '/env = GBM_BACKEND,nvidia-drm/s/^#//' config/hypr/configs/env.conf
        sed -i '/env = ELECTRON_OZONE_PLATFORM_HINT,auto/s/^#//' config/hypr/configs/env.conf
        sed -i '/env = MOZ_DISABLE_RDD_SANDBOX,1/s/^#//' config/hypr/configs/env.conf
        sed -i '/env = EGL_PLATFORM,wayland/s/^#//' config/hypr/configs/env.conf
        print_success "Nvidia configurations applied"
    fi

    # Dual boot Windows question
    if ask_yn "Do you dual boot with Windows?" "n"; then
        timedatectl set-local-rtc 1 --adjust-system-clock
        print_info "Adjusted system clock for Windows"
    fi
    echo

    set_keyboard_layout
    configure_neovim_desktop
}

# Function to configure Neovim desktop entry
configure_neovim_desktop() {
    print_info "Checking for Neovim installation..."
    
    # Check if neovim is installed
    if ! command -v nvim &> /dev/null; then
        print_warning "Neovim is not installed, skipping setting to default editor"
        return 0
    fi
    
    print_success "Neovim found, making executable"
    
    local desktop_file="/usr/share/applications/nvim.desktop"
    
    # Check if desktop file exists
    if [[ ! -f "$desktop_file" ]]; then
        print_warning "Neovim desktop file not found at $desktop_file"
        return 0
    fi
    
    print_info "Modifying Neovim desktop entry..."
    
    # Create a temporary file with the modifications
    if sudo awk '
        /^Terminal=true$/ { print "Terminal=false"; next }
        /^Exec=nvim %F$/ { print "Exec=kitty -e nvim %F"; next }
        { print }
    ' "$desktop_file" > /tmp/nvim.desktop.tmp; then
        
        # Replace the original file with the modified version
        if sudo mv /tmp/nvim.desktop.tmp "$desktop_file"; then
            print_success "Neovim desktop entry configured successfully"
            print_info "• Terminal changed to false"
            print_info "• Exec changed to use kitty terminal"
        else
            print_error "Failed to update desktop file"
            # Clean up temp file
            sudo rm -f /tmp/nvim.desktop.tmp 2>/dev/null
            return 1
        fi
    else
        print_error "Failed to modify desktop file"
        return 1
    fi
}

set_keyboard_layout() {
    # Detect the current keyboard layout
    layout=$(detect_layout)

    if [[ "$layout" == "(unset)" ]]; then
        while true; do
            printf "\n%.0s" {1..1}
            echo -e "${YELLOW}
    █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█
            STOP AND READ
    █▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█
    !!! IMPORTANT WARNING !!!
${NC}The Default Keyboard Layout could not be detected
You need to set it Manually
    ${YELLOW}!!! WARNING !!!${NC}
Setting a wrong Keyboard Layout will cause Hyprland to crash
If you are not sure, just type ${YELLOW}us${NC}
${ORANGE}You can change later in ~/.config/hypr/configs/input.conf${NC}
${BRIGHT_ORANGE} NOTE:${NC}
-  You can also set more than 2 keyboard layouts
-  For example: ${YELLOW}us, kr, gb, ru${NC}
"
            printf "\n%.0s" {1..1}
            
            echo -n "Please enter the correct keyboard layout: "
            read new_layout
            if [[ -n "$new_layout" ]]; then
                layout="$new_layout"
                break
            else
                print_error "Please enter a keyboard layout."
            fi
        done
    fi

    print_info "Detecting keyboard layout to prepare proper Hyprland Settings"

    # Prompt the user to confirm whether the detected layout is correct
    while true; do
        print_info "Current keyboard layout is ${BRIGHT_ORANGE}$layout${NC}"
        echo -n "Is this correct? [y/n] "
        read keyboard_layout
        case $keyboard_layout in
            [yY])
                awk -v layout="$layout" '/kb_layout/ {$0 = "  kb_layout = " layout} 1' config/hypr/configs/input.conf > temp.conf
                mv temp.conf config/hypr/configs/input.conf
                
                print_success "kb_layout ${BRIGHT_ORANGE}$layout${NC} configured in settings."
                break ;;
            [nN])
                printf "\n%.0s" {1..2}
                echo -e "${YELLOW}
    █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█
            STOP AND READ
    █▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█
    !!! IMPORTANT WARNING !!!
${NC}The Default Keyboard Layout could not be detected
You need to set it Manually
    ${YELLOW}!!! WARNING !!!${NC}
Setting a wrong Keyboard Layout will cause Hyprland to crash
If you are not sure, just type ${YELLOW}us${NC}
${ORANGE}You can change later in ~/.config/hypr/configs/input.conf${NC}
${BRIGHT_ORANGE} NOTE:${NC}
-  You can also set more than 2 keyboard layouts
-  For example: ${YELLOW}us, kr, gb, ru${NC}
"
                printf "\n%.0s" {1..1}
                
                echo -n "Please enter the correct keyboard layout: "
                read new_layout
                awk -v new_layout="$new_layout" '/kb_layout/ {$0 = "  kb_layout = " new_layout} 1' config/hypr/configs/input.conf > temp.conf
                mv temp.conf config/hypr/configs/input.conf
                print_success "kb_layout ${BRIGHT_ORANGE}$new_layout${NC} configured in settings."
                break ;;
            *)
                print_error "Please enter either 'y' or 'n'." ;;
        esac
    done
}

# Function to detect keyboard layout using localectl or setxkbmap
detect_layout() {
    if command -v localectl >/dev/null 2>&1; then
        layout=$(localectl status --no-pager | awk '/X11 Layout/ {print $3}')
        if [ -n "$layout" ]; then
            echo "$layout"
        fi
    elif command -v setxkbmap >/dev/null 2>&1; then
        layout=$(setxkbmap -query | grep layout | awk '{print $2}')
        if [ -n "$layout" ]; then
            echo "$layout"
        fi
    fi
}

# Function to show help
show_help() {
    echo -e "${BRIGHT_ORANGE}Diesel Dotfiles Copy Script${NC}"
    echo
    echo "This script copies dotfiles from the dotfiles directory to your home directory"
    echo "with proper permissions and error handling."
    echo
    echo -e "${ORANGE}Usage:${NC}"
    echo "  $0 [OPTIONS]"
    echo
    echo -e "${ORANGE}Options:${NC}"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Verbose output"
    echo
    echo -e "${ORANGE}Features:${NC}"
    echo "  • Recursive copying of directories"
    echo "  • Sets executable permissions for script files"
    echo "  • Handles .config directory specially"
    echo "  • Comprehensive error handling and reporting"
    echo "  • Detailed copy statistics"
    echo "  • Visual progress bar"
}

# Parse command line arguments
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo -e "${BRIGHT_ORANGE}╔═════════════════════════════════════════════════════════════════════════════╗"
    echo -e "║                        DIESEL DOTFILES COPY                                ║"
    echo -e "╚═════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Run the copy process
    if copy_dotfiles; then
        echo
        print_success "✓ Dotfiles installation completed successfully!"
        
        exit 0
    else
        echo
        print_error "✗ Dotfiles installation completed with errors"
        print_info "Check the error messages above for details"
        exit 1
    fi
}

# Run main function
main "$@"