# Cyberpunk Hyprland Dotfiles

A complete Arch Linux Hyprland setup with cyberpunk (Rose Pine) theme, video wallpapers, and automated installation.

![Theme Preview](preview.png)

## Features

- Rose Pine Cyberpunk Theme - Purple/pink/cyan color scheme
- Video Wallpapers - Live video backgrounds on login AND desktop
- Hyprland - Dynamic tiling Wayland compositor
- hyprlock - Beautiful lock screen with video support
- Waybar - Custom status bar with cyberpunk styling
- SDDM - Custom login theme with video wallpaper support
- PipeWire - Modern audio stack
- Mako - Notification daemon
- Automated Install - One script sets up everything

## Installation

### Prerequisites
- Fresh Arch Linux install (or Arch-based like EndeavourOS)
- Internet connection
- `git` installed

### Quick Install

```bash
git clone https://github.com/iceyxsm/mydots.git
cd mydots
./install.sh
```

### Install Options

```bash
./install.sh --finstall    # FRESH install - deletes everything, starts clean
./install.sh -finstall     # FULL install (default) - keeps files, installs all
./install.sh -minstall     # MINIMAL install - only missing packages
```

### Post-Install
Reboot after installation:
```bash
sudo reboot
```

## Keybindings

| Key | Action |
|-----|--------|
| SUPER + Return | Open terminal (Kitty) |
| SUPER + Q | Close window |
| SUPER + M | Exit Hyprland |
| SUPER + E | Open file manager (Thunar) |
| SUPER + R | Open launcher (Wofi) |
| SUPER + L | Lock screen (hyprlock) |
| SUPER + SHIFT + L | Lock with video wallpaper |
| SUPER + F10 | Start live wallpaper |
| SUPER + SHIFT + F10 | Stop live wallpaper |
| SUPER + H/J/K/L | Move focus |
| SUPER + SHIFT + H/J/K/L | Move window |
| SUPER + 1-9 | Switch workspace |
| SUPER + SHIFT + 1-9 | Move to workspace |

## Video Wallpapers

The installer automatically downloads wallpapers and sets up video backgrounds:

- Login Screen (SDDM) - Video plays on login screen
- Desktop - Same video plays as live wallpaper using mpvpaper
- Lock Screen - Video plays behind lock screen

### Video Wallpaper Locations
- Downloads: `~/.config/hypr/wallpapers/live-wallpapers/`
- First video found is used automatically
- Supports: MP4, WebM, MKV, MOV, AVI

### Manual Video Wallpaper
```bash
# Set specific video
mpvpaper --auto-set --loop HDMI-A-1 /path/to/video.mp4

# Add to autostart
echo 'exec-once = mpvpaper --auto-set --loop --mute=yes "*" "/path/to/video.mp4"' >> ~/.config/hypr/hyprland.conf
```

## Configuration

### Main Config Files
- `~/.config/hypr/hyprland.conf` - Hyprland compositor config
- `~/.config/hypr/hyprlock.conf` - Lock screen config
- `~/.config/waybar/config` - Status bar config
- `~/.config/kitty/kitty.conf` - Terminal config

### GPU Configuration
The installer auto-detects your GPU:
- NVIDIA - Installs proprietary drivers
- AMD - Mesa + amdgpu
- Intel - Mesa + intel
- VMware/VirtualBox - Software rendering (no GPU required)

### VM Support
Running in a VM? The installer detects it and:
- Uses software rendering (no GPU needed)
- Disables blur/shadows for performance
- Enables VMware/VirtualBox guest tools

## Customization

### Change Wallpaper
1. Add images/videos to `~/.config/hypr/wallpapers/`
2. Re-run `./install.sh` or manually set:
```bash
# For static wallpaper
hyprctl hyprpaper wallpaper "monitor,/path/to/image.jpg"

# For video wallpaper
mpvpaper --auto-set --loop "*" "/path/to/video.mp4"
```

### Change Colors
Edit `~/.config/hypr/hyprland.conf`:
```bash
general {
    col.active_border = rgba(c4a7e7ee)    # Purple active
    col.inactive_border = rgba(1f1d2eee)  # Dark inactive
}
```

Rose Pine palette:
- Background: `#191724`
- Surface: `#1f1d2e`
- Text: `#e0def4`
- Purple: `#c4a7e7`
- Pink: `#eb6f92`
- Cyan: `#9ccfd8`

## Hardware Requirements

### Minimum (VM)
- 2 CPU cores
- 4GB RAM
- 20GB disk
- Software rendering works fine

### Recommended (Real Hardware)
- 4+ CPU cores
- 8GB+ RAM
- SSD storage
- Dedicated GPU (NVIDIA/AMD/Intel)

## Troubleshooting

### Black Screen / Crash
```bash
# Check logs
hyprctl logs

# Software rendering mode
export WLR_RENDERER_ALLOW_SOFTWARE=1
Hyprland
```

### Video Wallpaper Not Working
```bash
# Check mpvpaper installed
which mpvpaper

# Check video exists
ls ~/.config/hypr/wallpapers/live-wallpapers/
```

### SDDM Theme Not Showing
```bash
# Restart SDDM
sudo systemctl restart sddm

# Check config
cat /etc/sddm.conf.d/99-hyprland.conf
```

### Login Loop
1. At SDDM, press `Ctrl+Alt+F2`
2. Login and run: `Hyprland`
3. Check error message

## Credits & Thanks

- **Inspiration**: [StealthIQ/dotfiles](https://github.com/StealthIQ/dotfiles) - Base dotfiles structure and setup
- **Hyprland**: [hyprwm/Hyprland](https://github.com/hyprwm/Hyprland) - The compositor
- **Rose Pine Theme**: [rose-pine/rose-pine-theme](https://github.com/rose-pine) - Color palette
- **SDDM Astronaut Theme**: [Keyitdev/sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme) - Login theme
- **Arch Linux**: [archlinux.org](https://archlinux.org) - The best distro

## License

This project is open source. Feel free to use, modify, and share.

## Author

**iceyxsm** - Arch Linux enthusiast and ricer

---

<p align="center">Made with love and caffeine</p>
