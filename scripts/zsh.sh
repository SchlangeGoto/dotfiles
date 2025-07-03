#!/bin/bash

# ZSH Shell Installer
# Installs ZSH, Oh My Zsh, plugins, and configures shell for optimal experience

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
MAGENTA='\033[0;35m'
SKY_BLUE='\033[1;36m'
NC='\033[0m' # No Color

# Global variables
FAILED_STEPS=()
COMPLETED_STEPS=()
SKIPPED_STEPS=()
SHELL_CHANGE_REQUIRED=false
ZSH_CORE_PACKAGES=()
ZSH_ADDITIONAL_PACKAGES=()
CURRENT_SHELL=""

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
        "note")
            echo -e "${SKY_BLUE}📝 ${message}${NC}"
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

# Function to detect current shell
detect_current_shell() {
    print_status "info" "Detecting current shell configuration..."
    
    CURRENT_SHELL=$(basename "$SHELL")
    local user_shell=$(getent passwd "$USER" | cut -d: -f7 | xargs basename)
    
    print_status "success" "Current shell: $CURRENT_SHELL"
    print_status "info" "User default shell: $user_shell"
    
    if [[ "$user_shell" != "zsh" ]]; then
        SHELL_CHANGE_REQUIRED=true
        print_status "note" "Shell change will be required after installation"
    else
        print_status "success" "ZSH is already the default shell"
    fi
    
    COMPLETED_STEPS+=("Shell Detection")
}

# Function to initialize package arrays
initialize_packages() {
    print_status "info" "Initializing package lists..."
    
    # Core ZSH packages
    ZSH_CORE_PACKAGES=(
        "zsh"
        "zsh-completions"
        "lsd"
        "mercurial"
    )
    
    # Additional packages
    ZSH_ADDITIONAL_PACKAGES=(
        "fzf"
    )
    
    print_status "success" "Package lists initialized"
    print_status "info" "Core packages: ${#ZSH_CORE_PACKAGES[@]}"
    print_status "info" "Additional packages: ${#ZSH_ADDITIONAL_PACKAGES[@]}"
    
    COMPLETED_STEPS+=("Package Initialization")
}

# Function to install ZSH core packages
install_zsh_core_packages() {
    print_status "installing" "Installing ZSH core packages..."
    echo
    
    local current=0
    local total=${#ZSH_CORE_PACKAGES[@]}
    local failed_packages=()
    
    for package in "${ZSH_CORE_PACKAGES[@]}"; do
        ((current++))
        draw_progress_bar "$current" "$total" "$package"
        
        if is_package_installed "$package"; then
            printf "\r%-80s\r" " "  # Clear the line
            print_status "success" "$package already installed"
        elif sudo pacman -S --needed --noconfirm "$package" &>/dev/null; then
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
        print_status "success" "All ZSH core packages installed successfully"
        COMPLETED_STEPS+=("Core Package Installation")
        return 0
    else
        print_status "error" "Some core packages failed to install"
        FAILED_STEPS+=("Core Package Installation")
        return 1
    fi
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
    print_status "configuring" "Installing Oh My Zsh framework..."
    
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        print_status "success" "Oh My Zsh already installed"
        COMPLETED_STEPS+=("Oh My Zsh Installation")
        return 0
    fi
    
    print_status "installing" "Downloading and installing Oh My Zsh..."
    
    # Install Oh My Zsh
    if sh -c "$(curl -fsSL https://install.ohmyz.sh)" "" --unattended &>/dev/null; then
        print_status "success" "Oh My Zsh installed successfully"
        COMPLETED_STEPS+=("Oh My Zsh Installation")
        return 0
    else
        print_status "error" "Failed to install Oh My Zsh"
        FAILED_STEPS+=("Oh My Zsh Installation")
        return 1
    fi
}

# Function to install ZSH plugins
install_zsh_plugins() {
    print_status "configuring" "Installing ZSH plugins..."
    
    local plugins=(
        "zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions"
        "zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting.git"
    )
    
    local failed_plugins=()
    local current=0
    local total=${#plugins[@]}
    
    for plugin_info in "${plugins[@]}"; do
        ((current++))
        local plugin_name=$(echo "$plugin_info" | cut -d':' -f1)
        local plugin_url=$(echo "$plugin_info" | cut -d':' -f2-)
        local plugin_dir="$HOME/.oh-my-zsh/custom/plugins/$plugin_name"
        
        draw_progress_bar "$current" "$total" "$plugin_name"
        
        if [[ -d "$plugin_dir" ]]; then
            printf "\r%-80s\r" " "  # Clear the line
            print_status "success" "$plugin_name already installed"
        else
            printf "\r%-80s\r" " "  # Clear the line
            print_status "installing" "Installing $plugin_name..."
            
            if git clone "$plugin_url" "$plugin_dir" &>/dev/null; then
                print_status "success" "$plugin_name installed"
            else
                print_status "error" "Failed to install $plugin_name"
                failed_plugins+=("$plugin_name")
            fi
        fi
    done
    
    echo
    
    if [[ ${#failed_plugins[@]} -eq 0 ]]; then
        print_status "success" "All ZSH plugins installed successfully"
        COMPLETED_STEPS+=("Plugin Installation")
        return 0
    else
        print_status "error" "Some plugins failed to install"
        FAILED_STEPS+=("Plugin Installation")
        return 1
    fi
}

# Function to backup and configure ZSH files
configure_zsh_files() {
    print_status "configuring" "Configuring ZSH configuration files..."
    
    local config_files=(".zshrc" ".zprofile")
    local backup_created=false
    
    # Create backups if files exist
    for config_file in "${config_files[@]}"; do
        if [[ -f "$HOME/$config_file" ]]; then
            local backup_file="$HOME/${config_file}-backup-$(date +%Y%m%d-%H%M%S)"
            if cp "$HOME/$config_file" "$backup_file"; then
                print_status "success" "Backed up $config_file to $(basename "$backup_file")"
                backup_created=true
            else
                print_status "warning" "Failed to backup $config_file"
            fi
        fi
    done
    
    # Create a basic .zshrc configuration
    print_status "configuring" "Creating ZSH configuration..."
    
    local zshrc_content='# ZSH Configuration
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    colored-man-pages
    command-not-found
)

source $ZSH/oh-my-zsh.sh

# User configuration
export LANG=en_US.UTF-8
export EDITOR="nano"

# Aliases
alias ll="lsd -la"
alias ls="lsd"
alias la="lsd -a"
alias l="lsd -l"
alias tree="lsd --tree"

# History configuration
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS

# Auto-completion
autoload -U compinit
compinit

# FZF integration
if command -v fzf >/dev/null 2>&1; then
    source /usr/share/fzf/key-bindings.zsh
    source /usr/share/fzf/completion.zsh
fi
'

    if echo "$zshrc_content" > "$HOME/.zshrc"; then
        print_status "success" "ZSH configuration created"
    else
        print_status "error" "Failed to create ZSH configuration"
        FAILED_STEPS+=("ZSH Configuration")
        return 1
    fi
    
    # Create .zprofile
    local zprofile_content='# ZSH Profile
# Add user bin to PATH
if [[ -d "$HOME/.local/bin" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# Add user scripts to PATH
if [[ -d "$HOME/bin" ]]; then
    export PATH="$HOME/bin:$PATH"
fi
'

    if echo "$zprofile_content" > "$HOME/.zprofile"; then
        print_status "success" "ZSH profile created"
    else
        print_status "warning" "Failed to create ZSH profile"
    fi
    
    if [[ "$backup_created" == true ]]; then
        print_status "note" "Original configuration files have been backed up"
    fi
    
    COMPLETED_STEPS+=("ZSH Configuration")
}

# Function to install additional packages
install_additional_packages() {
    print_status "installing" "Installing additional ZSH packages..."
    echo
    
    local current=0
    local total=${#ZSH_ADDITIONAL_PACKAGES[@]}
    local failed_packages=()
    
    for package in "${ZSH_ADDITIONAL_PACKAGES[@]}"; do
        ((current++))
        draw_progress_bar "$current" "$total" "$package"
        
        if is_package_installed "$package"; then
            printf "\r%-80s\r" " "  # Clear the line
            print_status "success" "$package already installed"
        elif sudo pacman -S --needed --noconfirm "$package" &>/dev/null; then
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
        print_status "success" "All additional packages installed successfully"
        COMPLETED_STEPS+=("Additional Package Installation")
        return 0
    else
        print_status "error" "Some additional packages failed to install"
        FAILED_STEPS+=("Additional Package Installation")
        return 1
    fi
}

# Function to change default shell
change_default_shell() {
    if [[ "$SHELL_CHANGE_REQUIRED" != true ]]; then
        print_status "success" "ZSH is already the default shell"
        COMPLETED_STEPS+=("Shell Configuration")
        return 0
    fi
    
    print_status "configuring" "Changing default shell to ZSH..."
    
    local zsh_path=$(command -v zsh)
    if [[ -z "$zsh_path" ]]; then
        print_status "error" "ZSH executable not found"
        FAILED_STEPS+=("Shell Configuration")
        return 1
    fi
    
    print_status "info" "ZSH path: $zsh_path"
    print_status "note" "You may be prompted for your password to change the shell"
    
    # Attempt to change shell with retries
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        print_status "configuring" "Attempt $attempt of $max_attempts to change shell..."
        
        if chsh -s "$zsh_path"; then
            print_status "success" "Default shell changed to ZSH successfully"
            print_status "note" "Please log out and log back in for the change to take effect"
            COMPLETED_STEPS+=("Shell Configuration")
            return 0
        else
            print_status "warning" "Authentication failed or error occurred"
            ((attempt++))
            
            if [[ $attempt -le $max_attempts ]]; then
                print_status "info" "Please try again..."
                sleep 2
            fi
        fi
    done
    
    print_status "error" "Failed to change default shell after $max_attempts attempts"
    print_status "info" "You can manually change it later with: chsh -s $zsh_path"
    FAILED_STEPS+=("Shell Configuration")
    return 1
}

# Function to show installation summary
show_summary() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                    ZSH INSTALLATION SUMMARY                  ║"
    echo -e "╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Show shell information
    echo -e "${ORANGE}Shell Information:${NC}"
    echo -e "  Current shell: $CURRENT_SHELL"
    echo -e "  ZSH path: $(command -v zsh 2>/dev/null || echo 'Not found')"
    if [[ "$SHELL_CHANGE_REQUIRED" == true ]]; then
        echo -e "  Status: ${YELLOW}Shell change required${NC} (please log out and back in)"
    else
        echo -e "  Status: ${GREEN}ZSH is default shell${NC}"
    fi
    echo
    
    # Show installed components
    echo -e "${ORANGE}Installed Components:${NC}"
    echo -e "  • ZSH Shell and completions"
    echo -e "  • Oh My Zsh framework"
    echo -e "  • ZSH plugins (autosuggestions, syntax highlighting)"
    echo -e "  • Enhanced utilities (lsd, fzf)"
    echo -e "  • Custom configuration files"
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
    
    # Show next steps
    if [[ ${#FAILED_STEPS[@]} -eq 0 ]]; then
        echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
        echo -e "║                         NEXT STEPS                           ║"
        echo -e "║                                                               ║"
        if [[ "$SHELL_CHANGE_REQUIRED" == true ]]; then
            echo -e "║   ${GREEN}1.${NC}${BRIGHT_ORANGE} Log out and log back in to activate ZSH             ║"
            echo -e "║   ${GREEN}2.${NC}${BRIGHT_ORANGE} Open a new terminal to enjoy your ZSH setup         ║"
        else
            echo -e "║   ${GREEN}1.${NC}${BRIGHT_ORANGE} Open a new terminal to enjoy your ZSH setup         ║"
        fi
        echo -e "║   ${GREEN}3.${NC}${BRIGHT_ORANGE} Customize ~/.zshrc for your preferences             ║"
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
        print_status "success" "ZSH installation completed successfully!"
        if [[ "$SHELL_CHANGE_REQUIRED" == true ]]; then
            print_status "note" "Please log out and back in to activate ZSH"
        fi
    else
        print_status "warning" "Installation completed with some failures"
    fi
}

# Main function
main() {
    clear
    echo -e "${BRIGHT_ORANGE}╔═══════════════════════════════════════════════════════════════╗"
    echo -e "║                       ZSH SHELL INSTALLER                    ║"
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
    
    if ! command -v git &>/dev/null; then
        print_status "error" "Git is required but not installed"
        print_status "info" "Please install git first: sudo pacman -S git"
        exit 1
    fi
    
    if ! command -v curl &>/dev/null; then
        print_status "error" "Curl is required but not installed"
        print_status "info" "Please install curl first: sudo pacman -S curl"
        exit 1
    fi
    
    # Main installation steps
    local steps=(
        "detect_current_shell"
        "initialize_packages"
        "install_zsh_core_packages"
        "install_oh_my_zsh"
        "install_zsh_plugins"
        "configure_zsh_files"
        "install_additional_packages"
        "change_default_shell"
    )
    
    local current_step=0
    local total_steps=${#steps[@]}
    
    for step_function in "${steps[@]}"; do
        ((current_step++))
        
        $step_function
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