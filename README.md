# mydots - Cyberpunk Hyprland Rice

Purple/pink themed Hyprland configuration with a cyberpunk aesthetic.

## Components

- **Hyprland** - Wayland compositor
- **Waybar** - Status bar
- **Kitty** - Terminal emulator
- **Hyprpaper** - Wallpaper daemon

## Installation

```bash
# Clone the repo
git clone https://github.com/iceyxsm/mydots.git
cd mydots

# Run install script
chmod +x install.sh
./install.sh
```

## Dependencies

```bash
# Arch Linux
sudo pacman -S hyprland waybar kitty hyprpaper wofi neofetch btop

# AUR packages
yay -S nerd-fonts-jetbrains-mono
```

## Theme

Color scheme based on purple/pink cyberpunk aesthetic:
- Primary: #bd93f9 (purple)
- Accent: #ff79c6 (pink)
- Background: #1a1b26 (dark blue-black)

## Keybindings

- `SUPER + RETURN` - Terminal
- `SUPER + D` - App launcher
- `SUPER + Q` - Close window
- `SUPER + 1-5` - Switch workspace
