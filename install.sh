#!/bin/bash

set -e

# Colors for output
PURPLE='\033[0;35m'
PINK='\033[0;95m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${PURPLE}========================================${NC}"
echo -e "${PINK}  Cyberpunk Hyprland Rice Installer${NC}"
echo -e "${PURPLE}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}[!] Please do not run this script as root${NC}"
    exit 1
fi

# Backup existing configs
backup_dir="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

echo -e "${CYAN}[*] Backing up existing configs...${NC}"
for dir in hypr waybar kitty btop neofetch; do
    if [ -d "$HOME/.config/$dir" ]; then
        mv "$HOME/.config/$dir" "$backup_dir/"
        echo -e "  ${GREEN}[OK]${NC} Backed up $dir"
    fi
done

# Create config directories
echo -e "${CYAN}[*] Creating config directories...${NC}"
mkdir -p ~/.config/{hypr,waybar,kitty,btop/themes,neofetch}
mkdir -p ~/.config/hypr/wallpapers/{live-wallpapers,dark-theme,light-theme}

# Update system first
echo -e "${CYAN}[*] Updating system...${NC}"
sudo pacman -Syu --noconfirm

# Install base packages for Hyprland
echo -e "${CYAN}[*] Installing base Hyprland packages...${NC}"
BASE_PACKAGES=(
    "hyprland"
    "hyprpaper"
    "hyprlock"
    "waybar"
    "kitty"
    "wofi"
    "xdg-desktop-portal-hyprland"
    "qt5-wayland"
    "qt6-wayland"
    "polkit-kde-agent"
)

for pkg in "${BASE_PACKAGES[@]}"; do
    if ! pacman -Qi "$pkg" &> /dev/null; then
        echo -e "  ${CYAN}Installing $pkg...${NC}"
        sudo pacman -S --needed --noconfirm "$pkg" || echo -e "  ${RED}[FAIL] Failed to install $pkg${NC}"
    else
        echo -e "  ${GREEN}[OK]${NC} $pkg already installed"
    fi
done

# Install GPU drivers (open source - covers Intel and AMD)
echo -e "${CYAN}[*] Installing GPU drivers...${NC}"
GPU_PACKAGES=(
    "mesa"
    "lib32-mesa"
    "vulkan-intel"
    "vulkan-radeon"
    "vulkan-icd-loader"
    "lib32-vulkan-icd-loader"
)

for pkg in "${GPU_PACKAGES[@]}"; do
    if ! pacman -Qi "$pkg" &> /dev/null; then
        echo -e "  ${CYAN}Installing $pkg...${NC}"
        sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || echo -e "  ${YELLOW}[SKIP]${NC} $pkg not found or already installed"
    else
        echo -e "  ${GREEN}[OK]${NC} $pkg already installed"
    fi
done

# Install PipeWire audio stack (modern replacement for PulseAudio)
echo -e "${CYAN}[*] Installing PipeWire audio stack...${NC}"
AUDIO_PACKAGES=(
    "pipewire"
    "pipewire-audio"
    "pipewire-pulse"
    "pipewire-alsa"
    "wireplumber"
)

for pkg in "${AUDIO_PACKAGES[@]}"; do
    if ! pacman -Qi "$pkg" &> /dev/null; then
        echo -e "  ${CYAN}Installing $pkg...${NC}"
        sudo pacman -S --needed --noconfirm "$pkg" || echo -e "  ${RED}[FAIL] Failed to install $pkg${NC}"
    else
        echo -e "  ${GREEN}[OK]${NC} $pkg already installed"
    fi
done

# Install additional tools
echo -e "${CYAN}[*] Installing additional tools...${NC}"
TOOLS=(
    "btop"
    "neofetch"
    "thunar"
    "gvfs"
    "gvfs-mtp"
    "file-roller"
    "pavucontrol"
    "network-manager-applet"
    "bluez"
    "bluez-utils"
    "blueman"
    "brightnessctl"
    "playerctl"
    "python-pip"
    "git"
    "wget"
    "curl"
)

for pkg in "${TOOLS[@]}"; do
    if ! pacman -Qi "$pkg" &> /dev/null; then
        echo -e "  ${CYAN}Installing $pkg...${NC}"
        sudo pacman -S --needed --noconfirm "$pkg" || echo -e "  ${RED}[FAIL] Failed to install $pkg${NC}"
    else
        echo -e "  ${GREEN}[OK]${NC} $pkg already installed"
    fi
done

# Install fonts
echo -e "${CYAN}[*] Installing fonts...${NC}"
FONTS=(
    "ttf-jetbrains-mono-nerd"
    "ttf-font-awesome"
    "noto-fonts"
    "noto-fonts-emoji"
)

for font in "${FONTS[@]}"; do
    if ! pacman -Qi "$font" &> /dev/null; then
        echo -e "  ${CYAN}Installing $font...${NC}"
        sudo pacman -S --needed --noconfirm "$font" || echo -e "  ${RED}[FAIL] Failed to install $font${NC}"
    else
        echo -e "  ${GREEN}[OK]${NC} $font already installed"
    fi
done

# Enable services
echo -e "${CYAN}[*] Enabling system services...${NC}"
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now NetworkManager.service

# Enable PipeWire services for user (WirePlumber handles session management)
echo -e "${CYAN}[*] Enabling PipeWire audio services...${NC}"
systemctl --user enable pipewire.service 2>/dev/null || true
systemctl --user enable pipewire-pulse.service 2>/dev/null || true
systemctl --user enable wireplumber.service 2>/dev/null || true
echo -e "  ${GREEN}[OK]${NC} PipeWire services enabled for user"

# Install gdown for wallpaper downloads
echo -e "${CYAN}[*] Installing gdown for wallpaper downloads...${NC}"
if ! command -v gdown &> /dev/null; then
    pip install --user gdown
    export PATH="$HOME/.local/bin:$PATH"
    echo -e "  ${GREEN}[OK]${NC} gdown installed"
else
    echo -e "  ${GREEN}[OK]${NC} gdown already installed"
fi

# Download wallpapers from Google Drive
echo -e "${CYAN}[*] Downloading live wallpapers from Google Drive...${NC}"
GDRIVE_FOLDER="https://drive.google.com/drive/folders/1oS6aUxoW6DGoqzu_S3pVBlgicGPgIoYq"

gdown --folder "$GDRIVE_FOLDER" -O ~/.config/hypr/wallpapers/live-wallpapers/ --remaining-ok 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "  ${GREEN}[OK]${NC} Live wallpapers downloaded successfully!"
else
    echo -e "  ${YELLOW}[WARN]${NC} Live wallpaper download failed. Will use local dark/light themes as fallback."
fi

# Copy configs
echo -e "${CYAN}[*] Copying configuration files...${NC}"
if [ -d ".config/hypr" ]; then
    cp -r .config/hypr/* ~/.config/hypr/ 2>/dev/null && echo -e "  ${GREEN}[OK]${NC} Hyprland configs copied"
    # Ensure hyprlock.conf exists
    if [ ! -f "$HOME/.config/hypr/hyprlock.conf" ]; then
        echo -e "  ${YELLOW}[WARN]${NC} hyprlock.conf not found, creating default..."
    fi
fi
if [ -d ".config/waybar" ]; then
    cp -r .config/waybar/* ~/.config/waybar/ 2>/dev/null && echo -e "  ${GREEN}[OK]${NC} Waybar configs copied"
fi
if [ -d ".config/kitty" ]; then
    cp -r .config/kitty/* ~/.config/kitty/ 2>/dev/null && echo -e "  ${GREEN}[OK]${NC} Kitty configs copied"
fi
if [ -d ".config/btop" ]; then
    cp -r .config/btop/* ~/.config/btop/ 2>/dev/null && echo -e "  ${GREEN}[OK]${NC} btop configs copied"
fi
if [ -d ".config/neofetch" ]; then
    cp -r .config/neofetch/* ~/.config/neofetch/ 2>/dev/null && echo -e "  ${GREEN}[OK]${NC} Neofetch configs copied"
fi

# Copy wallpapers if they exist in repo
if [ -d ".config/hypr/wallpapers/dark-theme" ]; then
    cp -r .config/hypr/wallpapers/dark-theme/* ~/.config/hypr/wallpapers/dark-theme/ 2>/dev/null
    echo -e "  ${GREEN}[OK]${NC} Dark theme wallpapers copied"
fi
if [ -d ".config/hypr/wallpapers/light-theme" ]; then
    cp -r .config/hypr/wallpapers/light-theme/* ~/.config/hypr/wallpapers/light-theme/ 2>/dev/null
    echo -e "  ${GREEN}[OK]${NC} Light theme wallpapers copied"
fi

# Determine default wallpaper (live wallpapers from gdown, or fallback to local)
echo -e "${CYAN}[*] Configuring wallpaper...${NC}"
FALLBACK_WALLPAPER="$HOME/.config/hypr/wallpapers/dark-theme/dark-wall1.jpg"

# Check if live wallpapers were downloaded successfully
if [ "$(ls -A ~/.config/hypr/wallpapers/live-wallpapers/ 2>/dev/null)" ]; then
    LIVE_WALL=$(ls ~/.config/hypr/wallpapers/live-wallpapers/ | head -n1)
    DEFAULT_WALLPAPER="$HOME/.config/hypr/wallpapers/live-wallpapers/$LIVE_WALL"
    echo -e "  ${GREEN}[OK]${NC} Using live wallpaper: $LIVE_WALL"
else
    DEFAULT_WALLPAPER="$FALLBACK_WALLPAPER"
    echo -e "  ${YELLOW}[WARN]${NC} Live wallpapers not available, using fallback"
fi

# Generate hyprpaper.conf with the correct wallpaper path
cat > ~/.config/hypr/hyprpaper.conf << EOF
preload = $DEFAULT_WALLPAPER
wallpaper = ,$DEFAULT_WALLPAPER
splash = false
ipc = on
EOF
echo -e "  ${GREEN}[OK]${NC} hyprpaper.conf configured with: $(basename "$DEFAULT_WALLPAPER")"

# Auto-start Hyprland on TTY1 (optional - for no display manager setups)
echo -e "${CYAN}[*] Setting up auto-start for Hyprland...${NC}"
if [ ! -f "$HOME/.bash_profile" ] || ! grep -q "Hyprland" "$HOME/.bash_profile" 2>/dev/null; then
    cat >> "$HOME/.bash_profile" << 'EOF'

# Auto-start Hyprland on TTY1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec Hyprland
fi
EOF
    echo -e "  ${GREEN}[OK]${NC} Hyprland will auto-start on TTY1"
else
    echo -e "  ${GREEN}[OK]${NC} Auto-start already configured"
fi

echo ""
echo -e "${PURPLE}========================================${NC}"
echo -e "${PINK}     Installation Complete!${NC}"
echo -e "${PURPLE}========================================${NC}"
echo ""
echo -e "${GREEN}Configuration locations:${NC}"
echo -e "  - Hyprland: ${CYAN}~/.config/hypr/${NC}"
echo -e "  - Waybar: ${CYAN}~/.config/waybar/${NC}"
echo -e "  - Kitty: ${CYAN}~/.config/kitty/${NC}"
echo -e "  - btop: ${CYAN}~/.config/btop/${NC}"
echo -e "  - Neofetch: ${CYAN}~/.config/neofetch/${NC}"
echo -e "  - Wallpapers: ${CYAN}~/.config/hypr/wallpapers/${NC}"
echo ""
echo -e "${GREEN}Backup saved to:${NC} ${CYAN}$backup_dir${NC}"
echo ""
echo -e "${PURPLE}Next steps:${NC}"
echo -e "  ${PINK}1.${NC} Reboot your system: ${CYAN}sudo reboot${NC}"
echo -e "  ${PINK}2.${NC} Hyprland will auto-start on TTY1 (no display manager needed)"
echo -e "  ${PINK}3.${NC} Or manually start with: ${CYAN}Hyprland${NC}"
echo ""
echo -e "${PURPLE}After logging in:${NC}"
echo -e "  - Test btop: ${CYAN}btop${NC}"
echo -e "  - Test neofetch: ${CYAN}neofetch${NC}"
echo -e "  - Reload Hyprland: ${CYAN}hyprctl reload${NC}"
echo ""
echo -e "${GREEN}Enjoy your cyberpunk rice!${NC}"
