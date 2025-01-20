#!/bin/bash

set -euo pipefail
IFS=$'\n\t'
trap 'echo "[ERROR] Script failed at line $LINENO"; exit 1' ERR

log() {
    echo -e "\033[1;32m[INFO]\033[0m $1"
}

warn() {
    echo -e "\033[1;33m[WARN]\033[0m $1"
}

error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        error "$1 is not installed. Aborting."
        exit 1
    fi
}

install_package() {
    if ! command -v "$1" &>/dev/null; then
        log "Installing $1..."
        case "$PACKAGE_MANAGER" in
        brew) brew install "$1" ;;
        apt-get) sudo apt-get install -y "$1" ;;
        yum) sudo yum install -y "$1" ;;
        *)
            error "Unsupported package manager: $PACKAGE_MANAGER"
            exit 1
            ;;
        esac
    else
        log "$1 is already installed"
    fi
}

clone_repo() {
    local REPO_SSH="git@github.com:golergka/dotfiles.git"
    local REPO_HTTPS="https://github.com/golergka/dotfiles.git"
    local TARGET_DIR="$HOME/dotfiles"

    if [ -d "$TARGET_DIR" ]; then
        log "Dotfiles repository already exists at $TARGET_DIR"
        return
    fi

    log "Attempting to clone repository via SSH: $REPO_SSH"
    if git clone "$REPO_SSH" "$TARGET_DIR"; then
        log "Successfully cloned repository via SSH."
    else
        warn "SSH clone failed. Falling back to HTTPS: $REPO_HTTPS"
        if git clone "$REPO_HTTPS" "$TARGET_DIR"; then
            log "Successfully cloned repository via HTTPS."
        else
            error "Failed to clone repository via SSH and HTTPS. Aborting."
            exit 1
        fi
    fi
}

# Detect OS
OS="$(uname -s)"
case "$OS" in
Darwin)
    log "Detected macOS"
    PACKAGE_MANAGER="brew"
    ;;
Linux)
    log "Detected Linux"
    if command -v apt-get &>/dev/null; then
        PACKAGE_MANAGER="apt-get"
    elif command -v yum &>/dev/null; then
        PACKAGE_MANAGER="yum"
    else
        error "Unsupported Linux distribution"
        exit 1
    fi
    ;;
*)
    error "Unsupported operating system: $OS"
    exit 1
    ;;
esac

# Ensure required commands are available
check_command git
check_command curl

# Install Zsh
install_package zsh

# Install Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    log "Oh My Zsh is already installed"
fi

# Clone dotfiles repository
clone_repo

# Symlink dotfiles
log "Setting up dotfiles..."
ln -sf "$HOME/dotfiles/.zshrc_common" "$HOME/.zshrc_common"

# Machine-specific setup
if [ ! -f "$HOME/.zshrc_local" ]; then
    log "Creating machine-specific ~/.zshrc_local..."
    touch "$HOME/.zshrc_local"
    echo "# Machine-specific zsh configuration" >>"$HOME/.zshrc_local"
fi

# Change default shell to Zsh
if [ "$SHELL" != "$(which zsh)" ]; then
    log "Changing default shell to Zsh..."
    chsh -s "$(which zsh)"
else
    log "Zsh is already the default shell"
fi

log "Setup complete! Please restart your terminal."
