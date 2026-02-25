#!/bin/bash

# Colors for output
PURPLE='\033[0;35m'
PINK='\033[0;95m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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

# Check for multilib support (required for lib32 packages)
echo -e "${CYAN}[*] Checking system configuration...${NC}"
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo -e "  ${YELLOW}[WARN]${NC} Multilib not enabled - required for 32-bit libraries"
    echo -e "  ${CYAN}[*] Enabling multilib...${NC}"
    sudo sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/s/#\[multilib\]/[multilib]/' /etc/pacman.conf
    sudo sed -i '/^\[multilib\]$/,/^#Include = \/etc\/pacman.d\/mirrorlist$/s/^#Include = \/etc\/pacman.d\/mirrorlist$/Include = \/etc\/pacman.d\/mirrorlist/' /etc/pacman.conf
    sudo pacman -Syu --noconfirm
    echo -e "  ${GREEN}[OK]${NC} Multilib enabled"
fi

# Check for base-devel (required for makepkg/AUR)
if ! pacman -Qg base-devel &> /dev/null; then
    echo -e "  ${CYAN}[*] Installing base-devel (required for AUR)...${NC}"
    sudo pacman -S --needed --noconfirm base-devel
    echo -e "  ${GREEN}[OK]${NC} base-devel installed"
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
sudo pacman -Syu --noconfirm || {
    echo -e "${RED}[!] System update failed${NC}"
    exit 1
}

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
    "sddm"
)

for pkg in "${BASE_PACKAGES[@]}"; do
    if ! pacman -Qi "$pkg" &> /dev/null; then
        echo -e "  ${CYAN}Installing $pkg...${NC}"
        sudo pacman -S --needed --noconfirm "$pkg" || echo -e "  ${YELLOW}[WARN]${NC} Failed to install $pkg, continuing..."
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
        sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || echo -e "  ${YELLOW}[SKIP]${NC} $pkg not found or skipped"
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
        sudo pacman -S --needed --noconfirm "$pkg" || echo -e "  ${YELLOW}[WARN]${NC} Failed to install $pkg, continuing..."
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
        sudo pacman -S --needed --noconfirm "$pkg" || echo -e "  ${YELLOW}[WARN]${NC} Failed to install $pkg, continuing..."
    else
        echo -e "  ${GREEN}[OK]${NC} $pkg already installed"
    fi
done

# Install fonts (nerd-fonts-jetbrains-mono from AUR, others from repos)
echo -e "${CYAN}[*] Installing fonts...${NC}"

# Install fonts from official repos first
REPO_FONTS=(
    "ttf-font-awesome"
    "noto-fonts"
    "noto-fonts-emoji"
)

for font in "${REPO_FONTS[@]}"; do
    if ! pacman -Qi "$font" &> /dev/null; then
        echo -e "  ${CYAN}Installing $font...${NC}"
        sudo pacman -S --needed --noconfirm "$font" || echo -e "  ${YELLOW}[WARN]${NC} Failed to install $font"
    else
        echo -e "  ${GREEN}[OK]${NC} $font already installed"
    fi
done

# Enable services
echo -e "${CYAN}[*] Enabling system services...${NC}"
sudo systemctl enable --now bluetooth.service || echo -e "  ${YELLOW}[WARN]${NC} Bluetooth service failed"
sudo systemctl enable --now NetworkManager.service || echo -e "  ${YELLOW}[WARN]${NC} NetworkManager failed"

# Enable SDDM display manager
echo -e "${CYAN}[*] Enabling SDDM display manager...${NC}"
sudo systemctl enable sddm.service || echo -e "  ${YELLOW}[WARN]${NC} SDDM enable failed"
echo -e "  ${GREEN}[OK]${NC} SDDM configured"

# Verify hyprland.desktop exists
if [ ! -f "/usr/share/wayland-sessions/hyprland.desktop" ]; then
    echo -e "${YELLOW}[WARN]${NC} hyprland.desktop not found, creating..."
    sudo mkdir -p /usr/share/wayland-sessions
    sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
    echo -e "  ${GREEN}[OK]${NC} hyprland.desktop created"
fi

# Configure SDDM to use Hyprland as default session
echo -e "${CYAN}[*] Configuring SDDM default session...${NC}"
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/hyprland.conf > /dev/null << EOF
[Autologin]
Session=hyprland.desktop
EOF
echo -e "  ${GREEN}[OK]${NC} Hyprland set as default session"

# Install yay AUR helper (safely)
echo -e "${CYAN}[*] Installing yay AUR helper...${NC}"
if ! command -v yay &> /dev/null; then
    YAY_BUILD_DIR="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$YAY_BUILD_DIR" || {
        echo -e "${YELLOW}[WARN]${NC} Failed to clone yay, continuing without AUR packages..."
        YAY_FAILED=1
    }
    if [ -z "$YAY_FAILED" ]; then
        (cd "$YAY_BUILD_DIR" && makepkg -si --noconfirm) || {
            echo -e "${YELLOW}[WARN]${NC} Failed to build yay, continuing without AUR packages..."
            YAY_FAILED=1
        }
    fi
    rm -rf "$YAY_BUILD_DIR"
else
    echo -e "  ${GREEN}[OK]${NC} yay already installed"
fi

# Install nerd font from AUR if yay is available
if [ -z "$YAY_FAILED" ] && command -v yay &> /dev/null; then
    echo -e "  ${CYAN}Installing nerd-fonts-jetbrains-mono from AUR...${NC}"
    yay -S --noconfirm nerd-fonts-jetbrains-mono 2>/dev/null || echo -e "  ${YELLOW}[WARN]${NC} Failed to install JetBrains Nerd Font"
else
    echo -e "  ${YELLOW}[WARN]${NC} Skipping AUR fonts (yay not available)"
fi

# Install sddm-astronaut-theme from AUR if yay is available
if [ -z "$YAY_FAILED" ] && command -v yay &> /dev/null; then
    echo -e "${CYAN}[*] Installing SDDM Astronaut theme (AUR)...${NC}"
    yay -S --noconfirm sddm-astronaut-theme 2>/dev/null || echo -e "  ${YELLOW}[WARN]${NC} sddm-astronaut-theme install failed"
fi

# Enable PipeWire services for user (WirePlumber handles session management)
echo -e "${CYAN}[*] Enabling PipeWire audio services...${NC}"
systemctl --user enable pipewire.service 2>/dev/null || true
systemctl --user enable pipewire-pulse.service 2>/dev/null || true
systemctl --user enable wireplumber.service 2>/dev/null || true
echo -e "  ${GREEN}[OK]${NC} PipeWire services enabled for user"

# Configure SDDM theme (only if astronaut theme was installed)
if [ -d "/usr/share/sddm/themes/sddm-astronaut-theme" ]; then
    echo -e "${CYAN}[*] Configuring SDDM theme...${NC}"
    sudo tee /etc/sddm.conf.d/theme.conf > /dev/null << EOF
[Theme]
Current=sddm-astronaut-theme
EOF
    echo -e "  ${GREEN}[OK]${NC} Astronaut theme configured"
else
    echo -e "  ${YELLOW}[WARN]${NC} Astronaut theme not found, using default SDDM theme"
fi

# Install gdown for wallpaper downloads
echo -e "${CYAN}[*] Installing gdown for wallpaper downloads...${NC}"
if ! command -v gdown &> /dev/null; then
    pip install --user gdown || echo -e "  ${YELLOW}[WARN]${NC} Failed to install gdown"
    export PATH="$HOME/.local/bin:$PATH"
else
    echo -e "  ${GREEN}[OK]${NC} gdown already installed"
fi

# Download wallpapers from Google Drive
echo -e "${CYAN}[*] Downloading live wallpapers from Google Drive...${NC}"
GDRIVE_FOLDER="https://drive.google.com/drive/folders/1oS6aUxoW6DGoqzu_S3pVBlgicGPgIoYq"

if command -v gdown &> /dev/null; then
    gdown --folder "$GDRIVE_FOLDER" -O ~/.config/hypr/wallpapers/live-wallpapers/ --remaining-ok 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}[OK]${NC} Live wallpapers downloaded successfully!"
    else
        echo -e "  ${YELLOW}[WARN]${NC} Live wallpaper download failed. Will use local themes as fallback."
    fi
else
    echo -e "  ${YELLOW}[WARN]${NC} gdown not available, skipping live wallpaper download"
fi

# Copy configs FIRST (but don't overwrite hyprpaper.conf later)
echo -e "${CYAN}[*] Copying configuration files...${NC}"
if [ -d ".config/hypr" ]; then
    # Copy everything EXCEPT hyprpaper.conf (we'll generate it)
    find .config/hypr -type f ! -name "hyprpaper.conf" -exec cp {} ~/.config/hypr/ \; 2>/dev/null
    # Copy directories
    cp -r .config/hypr/wallpapers ~/.config/hypr/ 2>/dev/null || true
    echo -e "  ${GREEN}[OK]${NC} Hyprland configs copied"
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
if [ -d ~/.config/hypr/wallpapers/live-wallpapers ] && [ "$(ls -A ~/.config/hypr/wallpapers/live-wallpapers/ 2>/dev/null)" ]; then
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

# Set SDDM wallpaper (live if available, else dark)
if [ -d "/usr/share/sddm/themes/sddm-astronaut-theme" ]; then
    echo -e "${CYAN}[*] Setting SDDM wallpaper...${NC}"
    if [ -f "$DEFAULT_WALLPAPER" ]; then
        sudo cp "$DEFAULT_WALLPAPER" /usr/share/sddm/themes/sddm-astronaut-theme/background.jpg 2>/dev/null && \
            echo -e "  ${GREEN}[OK]${NC} SDDM wallpaper set" || \
            echo -e "  ${YELLOW}[WARN]${NC} Failed to copy SDDM wallpaper"
    fi
fi

# SDDM is enabled with Hyprland as default
echo -e "${CYAN}[*] Display Manager configured${NC}"
echo -e "  ${GREEN}[OK]${NC} SDDM will provide graphical login screen"
echo -e "  ${GREEN}[OK]${NC} Hyprland is the default session"
echo -e "  ${GREEN}[OK]${NC} hyprlock works for locking (SUPER+L)"

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
echo -e "  ${PINK}2.${NC} SDDM login screen will appear (Hyprland is default)"
echo -e "  ${PINK}3.${NC} Enter password and login - cyberpunk desktop loads"
echo ""
echo -e "${PURPLE}After logging in:${NC}"
echo -e "  - Test btop: ${CYAN}btop${NC}"
echo -e "  - Test neofetch: ${CYAN}neofetch${NC}"
echo -e "  - Lock screen: ${CYAN}SUPER + L${NC}"
echo -e "  - Reload Hyprland: ${CYAN}hyprctl reload${NC}"
echo ""
echo -e "${GREEN}Enjoy your cyberpunk rice!${NC}"
