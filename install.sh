#!/bin/bash

# Request sudo access FIRST (before anything else)
if ! sudo -v 2>/dev/null; then
    echo "[ERROR] Sudo access required. Please run: sudo ./install.sh"
    exit 1
fi

# Keep sudo alive in background
(while true; do sudo -n true; sleep 60; done 2>/dev/null &)
SUDO_PID=$!
trap "kill $SUDO_PID 2>/dev/null" EXIT

# Colors - All green theme
GREEN='\033[0;32m'
CYAN='\033[0;32m'
PURPLE='\033[0;32m'
PINK='\033[0;32m'
YELLOW='\033[0;32m'
RED='\033[0;32m'
NC='\033[0m'

# Default mode
MODE="full"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --finstall)
            MODE="fresh"
            shift
            ;;
        -finstall)
            MODE="full"
            shift
            ;;
        -minstall)
            MODE="minimal"
            shift
            ;;
        -h|--help)
            echo "Cyberpunk Theme Installer"
            echo "Made by iceyxsm"
            echo ""
            echo "Usage: ./install.sh [OPTION]"
            echo ""
            echo "Options:"
            echo "  --finstall    FRESH install - DELETES all configs and packages"
            echo "                (keeps: git, pacman, yay, base system)"
            echo ""
            echo "  -finstall     FULL install - Maintains files and apps (DEFAULT)"
            echo "                Backs up existing configs, installs all packages"
            echo ""
            echo "  -minstall     MINIMAL install - Maintains existing packages"
            echo "                Only installs missing packages, preserves configs"
            echo ""
            echo "Examples:"
            echo "  ./install.sh --finstall    # Nuclear option - start fresh"
            echo "  ./install.sh -finstall     # Standard install (default)"
            echo "  ./install.sh -minstall     # Just add missing stuff"
            exit 0
            ;;
    esac
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Cyberpunk Theme Installer${NC}"
echo -e "${GREEN}       Made by iceyxsm${NC}"
echo -e "${GREEN}       Mode: ${MODE}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if running as root (don't allow)
if [ "$EUID" -eq 0 ]; then 
    echo -e "${GREEN}[!] Please do not run this script as root${NC}"
    exit 1
fi

# FRESH INSTALL MODE - NUCLEAR OPTION
if [ "$MODE" = "fresh" ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  WARNING: FRESH INSTALL MODE${NC}"
    echo -e "${GREEN}  This will DELETE all configs and packages!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${GREEN}This will:${NC}"
    echo "  - Remove all packages except: base, git, pacman, yay"
    echo "  - Delete all dotfiles in ~/.config/"
    echo "  - Delete wallpapers and themes"
    echo "  - Keep: /home files (Documents, Downloads, etc.)"
    echo ""
    read -p "Are you sure? Type 'NUKE' to continue: " confirm
    if [ "$confirm" != "NUKE" ]; then
        echo -e "${GREEN}Aborted.${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}[*] FRESH INSTALL: Removing packages...${NC}"
    
    # Get list of explicitly installed packages (excluding base and essential)
    echo -e "  ${GREEN}Analyzing installed packages...${NC}"
    
    # Create list of packages to keep
    KEEP_PKGS="base base-devel linux linux-firmware pacman git curl wget yay"
    
    # Remove all packages not in keep list
    echo -e "  ${GREEN}Removing non-essential packages...${NC}"
    pacman -Qeq | while read pkg; do
        if ! echo "$KEEP_PKGS" | grep -qw "$pkg"; then
            echo -e "  ${GREEN}Removing: $pkg${NC}"
            sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null || true
        fi
    done
    
    echo -e "${GREEN}[*] FRESH INSTALL: Cleaning configs...${NC}"
    # Remove all .config except essential
    for dir in ~/.config/*; do
        [ -d "$dir" ] || continue
        dir_name=$(basename "$dir")
        echo -e "  ${GREEN}Removing: ~/.config/$dir_name${NC}"
        rm -rf "$dir"
    done
    
    # Clean other common locations
    rm -rf ~/.local/share/{applications,flatpak} 2>/dev/null || true
    rm -rf ~/.themes ~/.icons 2>/dev/null || true
    
    echo -e "${GREEN}[OK] System cleaned. Installing fresh...${NC}"
    echo ""
fi

# Check for multilib support (required for lib32 packages)
echo -e "${GREEN}[*] Checking system configuration...${NC}"
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo -e "  ${GREEN}[WARN] Multilib not enabled - required for 32-bit libraries${NC}"
    echo -e "  ${GREEN}[*] Enabling multilib...${NC}"
    sudo sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/s/#\[multilib\]/[multilib]/' /etc/pacman.conf
    sudo sed -i '/^\[multilib\]$/,/^#Include = \/etc\/pacman.d\/mirrorlist$/s/^#Include = \/etc\/pacman.d\/mirrorlist$/Include = \/etc\/pacman.d\/mirrorlist/' /etc/pacman.conf
    sudo pacman -Syu --noconfirm
    echo -e "  ${GREEN}[OK] Multilib enabled${NC}"
fi

# Check for base-devel (required for makepkg/AUR)
if ! pacman -Qg base-devel &> /dev/null; then
    echo -e "  ${GREEN}[*] Installing base-devel (required for AUR)...${NC}"
    sudo pacman -S --needed --noconfirm base-devel
    echo -e "  ${GREEN}[OK] base-devel installed${NC}"
fi

# Backup existing configs (skip for minimal mode, always do for fresh)
if [ "$MODE" != "minimal" ]; then
    backup_dir="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    echo -e "${GREEN}[*] Backing up existing configs...${NC}"
    for dir in hypr waybar kitty btop neofetch mako; do
        if [ -d "$HOME/.config/$dir" ]; then
            mv "$HOME/.config/$dir" "$backup_dir/"
            echo -e "  ${GREEN}[OK] Backed up $dir${NC}"
        fi
    done
fi

# Create config directories
echo -e "${GREEN}[*] Creating config directories...${NC}"
mkdir -p ~/.config/{hypr,waybar,kitty,btop/themes,neofetch,mako}
mkdir -p ~/.config/hypr/wallpapers/{live-wallpapers,dark-theme,light-theme}
mkdir -p ~/Pictures

# Copy local wallpapers FIRST (but DON'T overwrite user files)
echo -e "${GREEN}[*] Checking local wallpapers...${NC}"

# Only copy dark-theme wallpapers if folder is empty
if [ -d ".config/hypr/wallpapers/dark-theme" ]; then
    DARK_COUNT=$(ls -1 ~/.config/hypr/wallpapers/dark-theme/ 2>/dev/null | wc -l)
    if [ "$DARK_COUNT" -eq 0 ]; then
        # Folder is empty, copy defaults
        cp -r .config/hypr/wallpapers/dark-theme/* ~/.config/hypr/wallpapers/dark-theme/ 2>/dev/null
        echo -e "  ${GREEN}[OK] Default dark theme wallpapers copied${NC}"
    else
        echo -e "  ${GREEN}[OK] User dark theme wallpapers kept ($DARK_COUNT files)${NC}"
    fi
fi

# Only copy light-theme wallpapers if folder is empty
if [ -d ".config/hypr/wallpapers/light-theme" ]; then
    LIGHT_COUNT=$(ls -1 ~/.config/hypr/wallpapers/light-theme/ 2>/dev/null | wc -l)
    if [ "$LIGHT_COUNT" -eq 0 ]; then
        cp -r .config/hypr/wallpapers/light-theme/* ~/.config/hypr/wallpapers/light-theme/ 2>/dev/null
        echo -e "  ${GREEN}[OK] Default light theme wallpapers copied${NC}"
    else
        echo -e "  ${GREEN}[OK] User light theme wallpapers kept ($LIGHT_COUNT files)${NC}"
    fi
fi

# Update system first (always do this)
echo -e "${GREEN}[*] Updating system...${NC}"
sudo pacman -Syu --noconfirm || {
    echo -e "${GREEN}[!] System update failed${NC}"
    exit 1
}

# Function to install package (respects minimal mode)
install_pkg() {
    local pkg="$1"
    local required="${2:-0}"
    
    if [ "$MODE" = "minimal" ] && pacman -Qi "$pkg" &> /dev/null; then
        echo -e "  ${GREEN}[OK] $pkg already installed (skipping in minimal mode)${NC}"
        return 0
    fi
    
    if ! pacman -Qi "$pkg" &> /dev/null; then
        echo -e "  ${GREEN}Installing $pkg...${NC}"
        sudo pacman -S --needed --noconfirm "$pkg" || {
            if [ "$required" = "1" ]; then
                echo -e "  ${GREEN}[FAIL] Required package $pkg failed${NC}"
                return 1
            else
                echo -e "  ${GREEN}[WARN] Failed to install $pkg, continuing...${NC}"
            fi
        }
    else
        echo -e "  ${GREEN}[OK] $pkg already installed${NC}"
    fi
}

# Install base packages for Hyprland
echo -e "${GREEN}[*] Installing base Hyprland packages...${NC}"
BASE_PACKAGES=(
    "hyprland"
    "hyprpaper"
    "hyprlock"
    "hypridle"
    "waybar"
    "kitty"
    "wofi"
    "mako"
    "grim"
    "slurp"
    "wl-clipboard"
    "xdg-desktop-portal-hyprland"
    "qt5-wayland"
    "qt6-wayland"
    "qt6-declarative"
    "polkit-kde-agent"
    "sddm"
    "mpv"
    "qt6-multimedia-ffmpeg"
    "jq"
)

for pkg in "${BASE_PACKAGES[@]}"; do
    install_pkg "$pkg" 1
done

# Detect GPU and install only required drivers
echo -e "${GREEN}[*] Detecting GPU...${NC}"

HAS_NVIDIA=false
HAS_INTEL=false
HAS_AMD=false
HAS_VMWARE=false

# Check for VMware/VirtualBox
if lspci -nn | grep -i 'vga\|3d\|display' | grep -i vmware &> /dev/null; then
    HAS_VMWARE=true
    echo -e "  ${GREEN}[OK] VMware SVGA detected (Virtual Machine)${NC}"
    echo -e "  ${GREEN}[WARN] Running in VM - software rendering will be used${NC}"
fi

# Check for NVIDIA
if lspci -nn | grep -i 'vga\|3d\|display' | grep -i nvidia &> /dev/null; then
    HAS_NVIDIA=true
    echo -e "  ${GREEN}[OK] NVIDIA GPU detected${NC}"
fi

# Check for Intel
if lspci -nn | grep -i 'vga\|3d\|display' | grep -i intel &> /dev/null; then
    HAS_INTEL=true
    echo -e "  ${GREEN}[OK] Intel GPU detected${NC}"
fi

# Check for AMD
if lspci -nn | grep -i 'vga\|3d\|display' | grep -i amd &> /dev/null || \
   lspci -nn | grep -i 'vga\|3d\|display' | grep -i advanced &> /dev/null; then
    HAS_AMD=true
    echo -e "  ${GREEN}[OK] AMD GPU detected${NC}"
fi

# Install base mesa (always needed)
echo -e "${GREEN}[*] Installing GPU drivers...${NC}"
install_pkg "mesa"
install_pkg "lib32-mesa"

# Install Intel drivers only if Intel GPU detected
if [ "$HAS_INTEL" = true ]; then
    echo -e "  ${GREEN}Installing Intel drivers...${NC}"
    install_pkg "vulkan-intel"
fi

# Install AMD drivers only if AMD GPU detected
if [ "$HAS_AMD" = true ]; then
    echo -e "  ${GREEN}Installing AMD drivers...${NC}"
    install_pkg "vulkan-radeon"
fi

# Always install ICD loader
install_pkg "vulkan-icd-loader"
install_pkg "lib32-vulkan-icd-loader"

# Install PipeWire audio stack
echo -e "${GREEN}[*] Installing PipeWire audio stack...${NC}"
AUDIO_PACKAGES=(
    "pipewire"
    "pipewire-audio"
    "pipewire-pulse"
    "pipewire-alsa"
    "wireplumber"
)

for pkg in "${AUDIO_PACKAGES[@]}"; do
    install_pkg "$pkg"
done

# Install additional tools
echo -e "${GREEN}[*] Installing additional tools...${NC}"
TOOLS=(
    "btop"
    "thunar"
    "gvfs"
    "gvfs-mtp"
    "file-roller"
    "pavucontrol"
    "network-manager-applet"
    "wireless_tools"
    "iw"
    "iwd"
    "linux-firmware"
    "wireless-regdb"
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
    install_pkg "$pkg"
done

# Install fonts
echo -e "${GREEN}[*] Installing fonts...${NC}"
REPO_FONTS=(
    "ttf-font-awesome"
    "noto-fonts"
    "noto-fonts-emoji"
)

for font in "${REPO_FONTS[@]}"; do
    install_pkg "$font"
done

# Enable services
echo -e "${GREEN}[*] Enabling system services...${NC}"
sudo systemctl enable --now bluetooth.service 2>/dev/null || echo -e "  ${GREEN}[WARN] Bluetooth service failed${NC}"
sudo systemctl enable --now NetworkManager.service 2>/dev/null || echo -e "  ${GREEN}[WARN] NetworkManager failed${NC}"

# Enable SDDM display manager
echo -e "${GREEN}[*] Enabling SDDM display manager...${NC}"
sudo systemctl enable sddm.service 2>/dev/null || echo -e "  ${GREEN}[WARN] SDDM enable failed${NC}"
sudo rm -rf /var/lib/sddm/.cache/ 2>/dev/null || true
echo -e "  ${GREEN}[OK] SDDM enabled - will be active after reboot${NC}"

# Verify hyprland.desktop exists
if [ ! -f "/usr/share/wayland-sessions/hyprland.desktop" ]; then
    echo -e "${GREEN}[WARN] hyprland.desktop not found, creating...${NC}"
    sudo mkdir -p /usr/share/wayland-sessions
    sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=/usr/bin/Hyprland
Type=Application
DesktopNames=Hyprland
XDG_CURRENT_DESKTOP=Hyprland
NoDisplay=false
EOF
    sudo chmod 644 /usr/share/wayland-sessions/hyprland.desktop
    echo -e "  ${GREEN}[OK] hyprland.desktop created${NC}"
fi

# Create SDDM config
echo -e "${GREEN}[*] Creating SDDM session fix...${NC}"
sudo mkdir -p /etc/sddm.conf.d
sudo rm -f /etc/sddm.conf.d/hyprland.conf 2>/dev/null || true
sudo rm -f /etc/sddm.conf.d/10-wayland.conf 2>/dev/null || true

sudo tee /etc/sddm.conf.d/99-hyprland.conf > /dev/null << 'EOF'
[General]
DisplayServer=x11
GreeterEnvironment=QT_QPA_PLATFORM=xcb
DefaultSession=hyprland.desktop

[Theme]
Current=sddm-astronaut-theme
EOF

SDDM_CONF="/etc/sddm.conf"
if [ -f "$SDDM_CONF" ]; then
    sudo cp "$SDDM_CONF" "$SDDM_CONF.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
fi

sudo tee "$SDDM_CONF" > /dev/null << 'EOF'
[General]
DisplayServer=x11
GreeterEnvironment=QT_QPA_PLATFORM=xcb
DefaultSession=hyprland.desktop
InputMethod=qtvirtualkeyboard

[Theme]
Current=sddm-astronaut-theme
EOF

echo -e "  ${GREEN}[OK] SDDM config created${NC}"

# Create Hyprland environment file
echo -e "${GREEN}[*] Creating Hyprland environment config...${NC}"
mkdir -p ~/.config/hypr
sudo mkdir -p /etc/environment.d

if lspci -nn | grep -i vmware &> /dev/null || lspci -nn | grep -i virtualbox &> /dev/null; then
    VM_FIXES="# Virtual Machine fixes
WLR_RENDERER_ALLOW_SOFTWARE=1
WLR_NO_HARDWARE_CURSORS=1
WLR_BACKEND=wayland"
else
    VM_FIXES="# NVIDIA fixes
WLR_NO_HARDWARE_CURSORS=1
WLR_RENDERER_ALLOW_SOFTWARE=1"
fi

cat > ~/.config/hypr/environment.conf << EOF
$VM_FIXES
XDG_SESSION_TYPE=wayland
XDG_CURRENT_DESKTOP=Hyprland
QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=qt5ct
SDL_VIDEODRIVER=wayland
MOZ_ENABLE_WAYLAND=1
EOF

sudo tee /etc/environment.d/99-hyprland.conf > /dev/null << 'EOF'
WLR_NO_HARDWARE_CURSORS=1
WLR_RENDERER_ALLOW_SOFTWARE=1
XDG_SESSION_TYPE=wayland
QT_QPA_PLATFORM=wayland
EOF

echo -e "  ${GREEN}[OK] Environment config created${NC}"

# Configure NetworkManager
echo -e "${GREEN}[*] Configuring NetworkManager WiFi backend...${NC}"
sudo mkdir -p /etc/NetworkManager/NetworkManager.conf.d
echo -e "[device]\nwifi.backend=iwd" | sudo tee /etc/NetworkManager/NetworkManager.conf.d/wifi-backend.conf > /dev/null
echo -e "  ${GREEN}[OK] Using iwd for WiFi${NC}"

# Install neofetch from AUR
echo -e "${GREEN}[*] Installing neofetch (AUR)...${NC}"
if ! command -v neofetch &> /dev/null; then
    if ! command -v yay &> /dev/null; then
        YAY_TEMP="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay.git "$YAY_TEMP" 2>/dev/null && \
            (cd "$YAY_TEMP" && makepkg -si --noconfirm 2>/dev/null)
        rm -rf "$YAY_TEMP"
    fi
    if command -v yay &> /dev/null; then
        yay -S --noconfirm neofetch 2>/dev/null
    fi
fi

# Install yay and AUR packages
if [ "$MODE" != "minimal" ] || ! command -v yay &> /dev/null; then
    echo -e "${GREEN}[*] Installing yay AUR helper...${NC}"
    if ! command -v yay &> /dev/null; then
        YAY_BUILD_DIR="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay.git "$YAY_BUILD_DIR" || YAY_FAILED=1
        if [ -z "$YAY_FAILED" ]; then
            (cd "$YAY_BUILD_DIR" && makepkg -si --noconfirm) || YAY_FAILED=1
        fi
        rm -rf "$YAY_BUILD_DIR"
    fi
    
    if [ -z "$YAY_FAILED" ] && command -v yay &> /dev/null; then
        yay -S --noconfirm nerd-fonts-jetbrains-mono 2>/dev/null || true
        yay -S --noconfirm cliphist 2>/dev/null || true
        yay -S --noconfirm --rebuildtree sddm-astronaut-theme 2>/dev/null || true
        yay -S --noconfirm mpvpaper 2>/dev/null || true
    fi
fi

# Enable PipeWire services
systemctl --user enable pipewire.service 2>/dev/null || true
systemctl --user enable pipewire-pulse.service 2>/dev/null || true
systemctl --user enable wireplumber.service 2>/dev/null || true

# Install gdown
echo -e "${GREEN}[*] Installing gdown for wallpaper downloads...${NC}"
if ! command -v gdown &> /dev/null; then
    install_pkg "python-pipx"
    pipx install gdown 2>/dev/null || pip install --user gdown 2>/dev/null || true
    export PATH="$HOME/.local/bin:$PATH"
fi

# Download wallpapers
if [ "$MODE" != "minimal" ]; then
    if command -v gdown &> /dev/null; then
        LIVE_DIR="$HOME/.config/hypr/wallpapers/live-wallpapers"
        MARKER_FILE="$LIVE_DIR/.downloaded"
        
        if [ -d "$LIVE_DIR" ]; then
            IMG_COUNT=$(find "$LIVE_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) 2>/dev/null | wc -l)
        else
            IMG_COUNT=0
            mkdir -p "$LIVE_DIR"
        fi
        
        if [ "$IMG_COUNT" -ge 2 ] || [ -f "$MARKER_FILE" ]; then
            echo -e "${GREEN}[*] Wallpapers already exist ($IMG_COUNT images), skipping download${NC}"
            touch "$MARKER_FILE"
        else
            echo -e "${GREEN}[*] Downloading wallpapers from Google Drive...${NC}"
            GDRIVE_FOLDER="https://drive.google.com/drive/folders/1oS6aUxoW6DGoqzu_S3pVBlgicGPgIoYq"
            gdown --folder "$GDRIVE_FOLDER" -O "$LIVE_DIR" --remaining-ok --no-cookies 2>&1
            touch "$MARKER_FILE"
        fi
    fi
fi

# Copy configs
if [ "$MODE" != "minimal" ]; then
    echo -e "${GREEN}[*] Copying configuration files...${NC}"
    if [ -d ".config/hypr" ]; then
        if lspci -nn | grep -i 'vga\|3d\|display' | grep -iE 'vmware|virtualbox' &> /dev/null; then
            cp .config/hypr/hyprland-vm.conf ~/.config/hypr/hyprland.conf 2>/dev/null || true
        else
            cp .config/hypr/hyprland.conf ~/.config/hypr/ 2>/dev/null || true
        fi
        cp .config/hypr/*.conf ~/.config/hypr/ 2>/dev/null || true
        if [ -d ".config/hypr/scripts" ]; then
            mkdir -p ~/.config/hypr/scripts
            cp .config/hypr/scripts/*.sh ~/.config/hypr/scripts/ 2>/dev/null || true
            chmod +x ~/.config/hypr/scripts/*.sh 2>/dev/null || true
        fi
    fi
    cp -r .config/waybar/* ~/.config/waybar/ 2>/dev/null || true
    cp -r .config/kitty/* ~/.config/kitty/ 2>/dev/null || true
    cp -r .config/btop/* ~/.config/btop/ 2>/dev/null || true
    cp -r .config/neofetch/* ~/.config/neofetch/ 2>/dev/null || true
    cp -r .config/mako/* ~/.config/mako/ 2>/dev/null || true
    
    # Configure wallpaper
    echo -e "${GREEN}[*] Configuring wallpaper...${NC}"
    LIVE_DIR="$HOME/.config/hypr/wallpapers/live-wallpapers"
    DARK_DIR="$HOME/.config/hypr/wallpapers/dark-theme"
    
    LIVE_IMG=$(find "$LIVE_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) 2>/dev/null | head -n1)
    if [ -n "$LIVE_IMG" ]; then
        DEFAULT_WALLPAPER="$LIVE_IMG"
        echo -e "  ${GREEN}[OK] Using LIVE wallpaper: $(basename $LIVE_IMG)${NC}"
    elif [ -d "$DARK_DIR" ]; then
        DARK_IMG=$(find "$DARK_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | head -n1)
        if [ -n "$DARK_IMG" ]; then
            DEFAULT_WALLPAPER="$DARK_IMG"
            echo -e "  ${GREEN}[OK] Using DARK THEME wallpaper: $(basename $DARK_IMG)${NC}"
        fi
    fi
    
    if [ -n "$DEFAULT_WALLPAPER" ]; then
        cat > ~/.config/hypr/hyprpaper.conf << EOF
preload = $DEFAULT_WALLPAPER
wallpaper = ,$DEFAULT_WALLPAPER
splash = false
ipc = on
EOF
        sed -i "s|path = .*|path = $DEFAULT_WALLPAPER|" "$HOME/.config/hypr/hyprlock.conf" 2>/dev/null || true
        
        # SDDM wallpaper with VIDEO support
        if [ -d "/usr/share/sddm/themes/sddm-astronaut-theme" ]; then
            echo -e "${GREEN}[*] Setting SDDM wallpaper...${NC}"
            
            VIDEO_WALL=""
            if [ -d "$LIVE_DIR" ]; then
                VIDEO_WALL=$(find "$LIVE_DIR" -type f \( -iname "*.mp4" -o -iname "*.webm" \) 2>/dev/null | head -n1)
            fi
            
            THEME_CONFIG="/usr/share/sddm/themes/sddm-astronaut-theme/Themes/astronaut.conf"
            if [ ! -f "$THEME_CONFIG" ]; then
                THEME_CONFIG=$(find /usr/share/sddm/themes/sddm-astronaut-theme/Themes/ -name "*.conf" 2>/dev/null | head -n1)
            fi
            
            if [ -n "$VIDEO_WALL" ]; then
                echo -e "  ${GREEN}[OK] Using VIDEO wallpaper for SDDM!${NC}"
                sudo cp "$VIDEO_WALL" /usr/share/sddm/themes/sddm-astronaut-theme/background.mp4
                sudo chmod 644 /usr/share/sddm/themes/sddm-astronaut-theme/background.mp4
                
                sudo tee /usr/share/sddm/themes/sddm-astronaut-theme/theme.conf.user > /dev/null << EOF
[General]
Background="background.mp4"
CropBackground="true"
FormPosition="left"
HaveFormBackground="false"
PartialBlur="false"
FullBlur="false"
BlurRadius="0"
Blur="false"
EOF
                
                if [ -f "$THEME_CONFIG" ]; then
                    sudo sed -i 's|Background=.*|Background="background.mp4"|g' "$THEME_CONFIG" 2>/dev/null || true
                    sudo sed -i 's|FormPosition=.*|FormPosition="left"|g' "$THEME_CONFIG" 2>/dev/null || true
                    sudo sed -i 's|CropBackground=.*|CropBackground="true"|g' "$THEME_CONFIG" 2>/dev/null || true
                    sudo sed -i 's|PartialBlur=.*|PartialBlur="false"|g' "$THEME_CONFIG" 2>/dev/null || true
                    sudo sed -i 's|FullBlur=.*|FullBlur="false"|g' "$THEME_CONFIG" 2>/dev/null || true
                    sudo sed -i 's|BlurRadius=.*|BlurRadius="0"|g' "$THEME_CONFIG" 2>/dev/null || true
                fi
            else
                sudo cp "$DEFAULT_WALLPAPER" /usr/share/sddm/themes/sddm-astronaut-theme/background.jpg
                sudo chmod 644 /usr/share/sddm/themes/sddm-astronaut-theme/background.jpg
                
                sudo tee /usr/share/sddm/themes/sddm-astronaut-theme/theme.conf.user > /dev/null << EOF
[General]
Background="background.jpg"
CropBackground="true"
FormPosition="left"
HaveFormBackground="false"
PartialBlur="false"
FullBlur="false"
BlurRadius="0"
Blur="false"
EOF
                
                if [ -f "$THEME_CONFIG" ]; then
                    sudo sed -i 's|Background=.*|Background="background.jpg"|g' "$THEME_CONFIG" 2>/dev/null || true
                    sudo sed -i 's|PartialBlur=.*|PartialBlur="false"|g' "$THEME_CONFIG" 2>/dev/null || true
                    sudo sed -i 's|FullBlur=.*|FullBlur="false"|g' "$THEME_CONFIG" 2>/dev/null || true
                    sudo sed -i 's|BlurRadius=.*|BlurRadius="0"|g' "$THEME_CONFIG" 2>/dev/null || true
                fi
            fi
        fi
    fi
fi

# Fix permissions
sudo chown -R "$USER:$USER" "$HOME" 2>/dev/null || true

# Final summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}     Installation Complete!${NC}"
echo -e "${GREEN}     Mode: ${MODE}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ "$MODE" != "minimal" ] && [ -n "$backup_dir" ]; then
    echo -e "${GREEN}Backup saved to: $backup_dir${NC}"
    echo ""
fi

echo -e "${GREEN}Do you want to reboot now? (y/N): ${NC}"
read -r reboot_choice
if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Rebooting...${NC}"
    sudo reboot
else
    echo -e "${GREEN}Reboot skipped. Run 'sudo reboot' when ready.${NC}"
fi
