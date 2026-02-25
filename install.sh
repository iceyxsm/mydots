#!/bin/bash

# Arch Linux configuration installation script

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Arch Linux configurations..."

# Create yay config directory
mkdir -p "$HOME/.config/yay"
ln -sf "$DOTFILES_DIR/yay/config.json" "$HOME/.config/yay/config.json"

# System configs (requires sudo)
echo "Installing pacman config (requires sudo)..."
sudo ln -sf "$DOTFILES_DIR/pacman/pacman.conf" "/etc/pacman.conf"

echo "Arch Linux configurations installed successfully!"
