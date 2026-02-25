# mydots - Cyberpunk Hyprland Rice

A fully dynamic, cyberpunk-themed Hyprland configuration with purple/pink aesthetics, animated wallpapers, and system monitoring.

## Features

- Cyberpunk purple/pink color scheme (Rose Pine inspired)
- Animated live wallpapers from Google Drive
- System monitoring (CPU, Memory, Disk, Network)
- Smooth animations and blur effects
- Dynamic username detection
- Automatic config backup
- Fully customizable

## Screenshots

The setup includes:
- Hyprland with custom keybindings and animations
- Waybar with real-time system stats
- Kitty terminal with transparency and blur
- btop for detailed system monitoring
- neofetch with custom ASCII art
- Animated cyberpunk wallpapers

## Installation

### Fresh Arch Linux Install (Terminal Only)

If you're starting from a fresh Arch terminal-only install:

```bash
# 1. Install git first
sudo pacman -S git

# 2. Clone the repo
git clone https://github.com/iceyxsm/mydots.git
cd mydots

# 3. Run the install script (it will install everything)
chmod +x install.sh
./install.sh

# 4. Reboot
sudo reboot

# 5. Select Hyprland from your display manager
# Or start manually with: Hyprland
```

### Existing Hyprland Setup

If you already have Hyprland installed:

```bash
# Clone the repo
git clone https://github.com/iceyxsm/mydots.git
cd mydots

# Run install script
chmod +x install.sh
./install.sh

# Reload Hyprland
hyprctl reload
```

### What the script does:

1. Backs up existing configs with timestamp
2. Updates system packages
3. Installs Hyprland and all dependencies:
   - Base: hyprland, hyprpaper, waybar, kitty, wofi
   - Portals: xdg-desktop-portal-hyprland
   - Qt support: qt5-wayland, qt6-wayland
   - Tools: btop, neofetch, thunar, pavucontrol
   - Services: NetworkManager, Bluetooth
   - Fonts: JetBrainsMono Nerd Font, Font Awesome
4. Enables system services (NetworkManager, Bluetooth)
5. Downloads animated wallpapers from Google Drive
6. Copies all configuration files
7. Sets up btop custom theme
8. Configures neofetch
9. Fully dynamic - uses $HOME and works for any user

### Wallpapers

Wallpapers are automatically downloaded to:
```
~/.config/hypr/wallpapers/
├── live-wallpapers/    # Animated cyberpunk wallpapers (from Google Drive)
├── dark-theme/         # Static dark wallpapers
└── light-theme/        # Static light wallpapers
```

## Dependencies

All installed automatically by the install script:

### Base Hyprland
- hyprland
- hyprpaper
- waybar
- kitty
- wofi
- xdg-desktop-portal-hyprland
- qt5-wayland, qt6-wayland
- polkit-kde-agent

### Tools & Utilities
- btop (system monitor)
- neofetch (system info)
- thunar (file manager)
- gvfs, gvfs-mtp (file system support)
- pavucontrol (audio control)
- network-manager-applet
- bluez, bluez-utils, blueman (Bluetooth)
- brightnessctl (brightness control)
- playerctl (media control)

### Fonts
- ttf-jetbrains-mono-nerd
- ttf-font-awesome
- noto-fonts
- noto-fonts-emoji

### Python
- python-pip (for gdown wallpaper downloads)

## Post-Installation

After running the install script:

```bash
# Reload Hyprland
hyprctl reload

# Test system monitor
btop

# Test neofetch
neofetch
```

## Keybindings

- `SUPER + RETURN` - Open terminal (kitty)
- `SUPER + Q` - Close window
- `SUPER + M` - Exit Hyprland
- `SUPER + E` - File manager (thunar)
- `SUPER + V` - Toggle floating
- `SUPER + D` - App launcher (wofi)
- `SUPER + P` - Pseudo tiling
- `SUPER + J` - Toggle split
- `SUPER + Arrow Keys` - Move focus
- `SUPER + 1-5` - Switch workspaces
- `SUPER + SHIFT + 1-5` - Move window to workspace
- `SUPER + Mouse Left` - Move window
- `SUPER + Mouse Right` - Resize window

## Customization

### Change wallpaper:
Edit `.config/hypr/hyprpaper.conf` and change the path to any wallpaper in the wallpapers folder:
```bash
preload = ~/.config/hypr/wallpapers/live-wallpapers/your-wallpaper.jpg
wallpaper = ,~/.config/hypr/wallpapers/live-wallpapers/your-wallpaper.jpg
```

### Modify colors:
- Waybar: `.config/waybar/style.css`
- Kitty: `.config/kitty/kitty.conf`
- Hyprland borders: `.config/hypr/hyprland.conf`

### System monitoring:
- btop config: `~/.config/btop/btop.conf`
- Waybar modules: `.config/waybar/config`

## Theme Colors

Color scheme based on Rose Pine with cyberpunk enhancements:
- Primary Purple: `#c4a7e7`
- Accent Pink: `#eb6f92`
- Cyan: `#9ccfd8`
- Yellow: `#f6c177`
- Background: `#191724`
- Foreground: `#e0def4`

## Components

- **Hyprland** - Wayland compositor with animations
- **Waybar** - Status bar with system monitoring
- **Kitty** - GPU-accelerated terminal
- **Hyprpaper** - Wallpaper daemon
- **btop** - Resource monitor
- **neofetch** - System info display
- **wofi** - Application launcher

## Dynamic Features

The setup is fully dynamic:
- Uses $HOME for all paths (no hardcoded usernames)
- Timestamped backups (~/.config_backup_YYYYMMDD_HHMMSS)
- Automatic package installation detection (pacman/yay)
- Error handling with fallbacks
- Works on any Arch-based system
- Automatic wallpaper download and placement

## Troubleshooting

### Wallpapers not loading:
```bash
# Manually download from Google Drive
# Link: https://drive.google.com/drive/folders/1oS6aUxoW6DGoqzu_S3pVBlgicGPgIoYq
# Place in: ~/.config/hypr/wallpapers/live-wallpapers/
```

### Waybar not showing:
```bash
# Restart waybar
killall waybar
waybar &
```

### Font issues:
```bash
# Install JetBrainsMono Nerd Font
yay -S nerd-fonts-jetbrains-mono
fc-cache -fv
```

## Credits

Special thanks to [StealthIQ/dotfiles](https://github.com/StealthIQ/dotfiles) for inspiration.
