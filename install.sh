#!/bin/bash

# Backup existing configs
backup_dir="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

for dir in hypr waybar kitty; do
    if [ -d "$HOME/.config/$dir" ]; then
        mv "$HOME/.config/$dir" "$backup_dir/"
    fi
done

# Create config directories
mkdir -p ~/.config/{hypr,waybar,kitty}
mkdir -p ~/wallpapers

# Copy configs
cp -r .config/hypr/* ~/.config/hypr/
cp -r .config/waybar/* ~/.config/waybar/
cp -r .config/kitty/* ~/.config/kitty/

# Copy dotfiles
cp .bashrc ~/.bashrc
cp .bash_profile ~/.bash_profile
cp .zshrc ~/.zshrc
cp .vimrc ~/.vimrc
cp .tmux.conf ~/.tmux.conf
cp .gitconfig ~/.gitconfig

echo "Installation complete!"
echo "Backup saved to: $backup_dir"
echo "Please add your wallpaper to ~/wallpapers/cyberpunk.jpg"
echo "Then reload Hyprland with: hyprctl reload"
