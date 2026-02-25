#!/bin/bash

# Cyberpunk Hyprland Rice Installer
# Modes: --finstall (fresh), -finstall (full/default), -minstall (minimal)

# Colors
PURPLE='\033[0;35m'
PINK='\033[0;95m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
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
            echo "Cyberpunk Hyprland Rice Installer"
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

echo -e "${PURPLE}========================================${NC}"
echo -e "${PINK}  Cyberpunk Hyprland Rice Installer${NC}"
echo -e "${CYAN}  Mode: ${MODE}${NC}"
echo -e "${PURPLE}========================================${NC}"
echo ""

# Request sudo access at start
echo -e "${CYAN}[*] Requesting sudo access...${NC}"
if ! sudo -v; then
    echo -e "${RED}[!] Sudo access required. Please run again with sudo permissions.${NC}"
    exit 1
fi

# Keep sudo alive in background
(while true; do sudo -n true; sleep 60; done 2>/dev/null &)
SUDO_PID=$!

# Cleanup sudo keepalive on exit
cleanup() {
    kill $SUDO_PID 2>/dev/null
}
trap cleanup EXIT

# Check if running as root (don't allow)
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}[!] Please do not run this script as root${NC}"
    exit 1
fi

# FRESH INSTALL MODE - NUCLEAR OPTION
if [ "$MODE" = "fresh" ]; then
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  WARNING: FRESH INSTALL MODE${NC}"
    echo -e "${RED}  This will DELETE all configs and packages!${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo -e "${YELLOW}This will:${NC}"
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
    
    echo -e "${CYAN}[*] FRESH INSTALL: Removing packages...${NC}"
    
    # Get list of explicitly installed packages (excluding base and essential)
    echo -e "  ${CYAN}Analyzing installed packages...${NC}"
    
    # Create list of packages to keep
    KEEP_PKGS="base base-devel linux linux-firmware pacman git curl wget yay"
    
    # Remove all packages not in keep list
    echo -e "  ${YELLOW}Removing non-essential packages...${NC}"
    pacman -Qeq | while read pkg; do
        if ! echo "$KEEP_PKGS" | grep -qw "$pkg"; then
            echo -e "  ${CYAN}Removing: $pkg${NC}"
            sudo pacman -Rns --noconfirm "$pkg" 2>/dev/null || true
        fi
    done
    
    echo -e "${CYAN}[*] FRESH INSTALL: Cleaning configs...${NC}"
    # Remove all .config except essential
    for dir in ~/.config/*; do
        [ -d "$dir" ] || continue
        dir_name=$(basename "$dir")
        echo -e "  ${CYAN}Removing: ~/.config/$dir_name${NC}"
        rm -rf "$dir"
    done
    
    # Clean other common locations
    rm -rf ~/.local/share/{applications,flatpak} 2>/dev/null || true
    rm -rf ~/.themes ~/.icons 2>/dev/null || true
    
    echo -e "${GREEN}[OK]${NC} System cleaned. Installing fresh..."
    echo ""
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

# Backup existing configs (skip for minimal mode, always do for fresh)
if [ "$MODE" != "minimal" ]; then
    backup_dir="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    echo -e "${CYAN}[*] Backing up existing configs...${NC}"
    for dir in hypr waybar kitty btop neofetch mako; do
        if [ -d "$HOME/.config/$dir" ]; then
            mv "$HOME/.config/$dir" "$backup_dir/"
            echo -e "  ${GREEN}[OK]${NC} Backed up $dir"
        fi
    done
fi

# Create config directories
echo -e "${CYAN}[*] Creating config directories...${NC}"
mkdir -p ~/.config/{hypr,waybar,kitty,btop/themes,neofetch,mako}
mkdir -p ~/.config/hypr/wallpapers/{live-wallpapers,dark-theme,light-theme}
mkdir -p ~/Pictures

# Update system first (always do this)
echo -e "${CYAN}[*] Updating system...${NC}"
sudo pacman -Syu --noconfirm || {
    echo -e "${RED}[!] System update failed${NC}"
    exit 1
}

# Function to install package (respects minimal mode)
install_pkg() {
    local pkg="$1"
    local required="${2:-0}"
    
    if [ "$MODE" = "minimal" ] && pacman -Qi "$pkg" &> /dev/null; then
        echo -e "  ${GREEN}[OK]${NC} $pkg already installed (skipping in minimal mode)"
        return 0
    fi
    
    if ! pacman -Qi "$pkg" &> /dev/null; then
        echo -e "  ${CYAN}Installing $pkg...${NC}"
        sudo pacman -S --needed --noconfirm "$pkg" || {
            if [ "$required" = "1" ]; then
                echo -e "  ${RED}[FAIL]${NC} Required package $pkg failed"
                return 1
            else
                echo -e "  ${YELLOW}[WARN]${NC} Failed to install $pkg, continuing..."
            fi
        }
    else
        echo -e "  ${GREEN}[OK]${NC} $pkg already installed"
    fi
}

# Install base packages for Hyprland
echo -e "${CYAN}[*] Installing base Hyprland packages...${NC}"
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
    "polkit-kde-agent"
    "sddm"
)

for pkg in "${BASE_PACKAGES[@]}"; do
    install_pkg "$pkg" 1
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
    install_pkg "$pkg"
done

# Check for NVIDIA GPU and auto-install appropriate driver
echo -e "${CYAN}[*] Checking for NVIDIA GPU...${NC}"
if lspci -nn | grep -i 'vga\|3d\|display' | grep -i nvidia &> /dev/null; then
    echo -e "  ${GREEN}[OK]${NC} NVIDIA GPU detected!"
    
    # Extract PCI ID
    PCI_ID=$(lspci -nn | grep -i 'vga\|3d\|display' | grep -i nvidia | grep -oP '\[10de:\K[0-9a-f]+' | head -n1 | tr '[:lower:]' '[:upper:]')
    
    if [ -n "$PCI_ID" ]; then
        echo -e "  ${CYAN}PCI ID: ${PCI_ID}${NC}"
        
        # Determine driver based on PCI ID
        case "$PCI_ID" in
            # Blackwell RTX 5000
            2B85|2B87|2C05|2C07|2D05|2D07)
                DRIVER="nvidia-open-dkms"
                DESC="RTX 5000 series"
                ;;
            # Ada Lovelace RTX 4000
            2684|2685|2686|2687|2688|2689|26B0|26B1|26B2|26B3|26B5|26B6|2704|2705|2730|2750|2780|2781|2782|2783|2786|2787|27A0|27B0|27B1|27B2|27B3|27B6|27B7|27B8|27B9|27BA|27BB|27E0)
                DRIVER="nvidia-open-dkms"
                DESC="RTX 4000 series"
                ;;
            # Ampere RTX 3000
            2204|2206|2207|2208|220A|2216|222F|2230|2231|2232|2233|2235|2236|2237|2414|2420|2438|2482|2484|2486|2487|2488|2489|24B0|24B1|24B6|24B7|24B8|24B9|24BA|24C9|24DC|24DD|24E0|24FA|2503|2504|2507|2508|2520|2523|2531|2544|2560|2571|2582|2583|2584|25B0|25B2|25B6|25B8|25E0|25E2|25E5|25F0|25F8|25F9|25FA)
                DRIVER="nvidia-dkms"
                DESC="RTX 3000 series"
                ;;
            # Turing RTX 2000/GTX 1600
            1E02|1E04|1E07|1E09|1E30|1E36|1E78|1E81|1E82|1E84|1E87|1E90|1EB0|1EB1|1EB5|1EB6|1EC2|1EC7|1ED0|1ED1|1ED3|1EDF|1F02|1F03|1F06|1F07|1F08|1F10|1F11|1F12|1F14|1F15|1F36|1F42|1F47|1F54|1F76|1F82|1F83|1F91|1F95|1F96|1F97|1F98|1F99|1F9C|1F9D|1FA0|1FB0|1FB1|1FB2|1FB6|1FB7|1FB8|1FB9|1FBC|1FDD|1FF0|1FF2|1FF9|2182|2184|2187|2188|2189|21C4|21D1)
                DRIVER="nvidia-dkms"
                DESC="RTX 2000/GTX 1600 series"
                ;;
            # Pascal GTX 1000
            1582|15F0|15F7|15F8|15F9|1617|1618|1619|161A|179C|17C2|17C8|1B00|1B02|1B06|1B30|1B34|1B38|1B80|1B81|1B82|1B83|1B84|1B87|1BA0|1BA1|1BA2|1BB0|1BB1|1BB3|1BB4|1BB5|1BB6|1BB7|1BB8|1BB9|1BC7|1BE0|1BE1|1C02|1C03|1C07|1C09|1C20|1C21|1C22|1C30|1C31|1C60|1C61|1C62|1C81|1C82|1C83|1C8C|1C8D|1C8F|1CB1|1CB2|1CB3|1CB6|1D01|1D02|1D10|1D11|1D12|1D13|1D16|1D33|1D34|1D35|1D36|1D52|1D71|1D81|1DB1|1DB3|1DB4|1DB5|1DB6|1DB7|1DB8)
                DRIVER="nvidia-dkms"
                DESC="GTX 1000 series"
                ;;
            # Maxwell GTX 900/750
            13C0|13C1|13C2|13C3|13D7|13D8|13D9|13DA|13F0|13F1|13F2|13F3|13F8|13F9|13FA|13FB|1401|1402|1406|1407|1427|1430|1431|1436|1613)
                DRIVER="nvidia-dkms"
                DESC="GTX 900 series"
                ;;
            # Kepler - LEGACY (AUR)
            0FC0|0FC1|0FC2|0FC6|0FC8|0FC9|0FCD|0FCE|0FD1|0FD2|0FD3|0FD4|0FD5|0FD8|0FD9|0FDF|0FE0|0FE1|0FE2|0FE3|0FE4|1001|1004|1005|1007|1008|100A|100C|1021|1022|1023|1024|1026|1027|1028|1029|103A|103C|1180|1183|1184|1185|1187|1188|1189|118A|118E|118F|1193|1194|1195|1198|1199|119A|119D|119E|119F|11A0|11A1|11A2|11A3|11A7|11B4|11B6|11B7|11B8|11BA|11BC|11BD|11BE|11BF|11C0|11C2|11C3|11C4|11C5|11C6|11C8|11CB|11E0|11E1|11E2|11E3|11E7|11FA|11FC|1280|1281|1282|1284|1286|1287|1288|1289|128B|1290|1291|1292|1293|1295|1296|1298|1299|12B9|12BA)
                DRIVER="nvidia-470xx-dkms"
                DESC="GTX 600/700 series (LEGACY)"
                AUR=1
                ;;
            # Fermi - VERY LEGACY (AUR)
            06C0|06C4|06CA|06CD|06D1|06D2|06D8|06D9|06DA|06DC|06DD|06DE|06DF|0DC0|0DC4|0DC5|0DC6|0DCD|0DCE|0DD1|0DD2|0DD6|0DE0|0DE1|0DE2|0DE3|0DE4|0DE5|0DE7|0DE8|0DE9|0DEA|0DEB|0DEC|0DED|0DEE|0DEF|0DF0|0DF1|0DF2|0DF3|0DF4|0DF5|0DF6|0DF7|0DF8|0DF9|0DFA|0DFC|0E22|0E23|0E24|0E30|0E31|0E3A|0E3B|0F00|0F01|0F02|0F03|0E3C|0E3D|0E3E|0FCD)
                DRIVER="nvidia-390xx-dkms"
                DESC="GTX 400/500 series (LEGACY)"
                AUR=1
                ;;
            # Unknown - default to nvidia-dkms
            *)
                DRIVER="nvidia-dkms"
                DESC="Unknown NVIDIA GPU"
                ;;
        esac
        
        echo -e "  ${GREEN}[OK]${NC} Detected: ${DESC}"
        echo -e "  ${CYAN}[*] Installing ${DRIVER}...${NC}"
        
        # Check if already installed (minimal mode)
        if [ "$MODE" = "minimal" ] && pacman -Qi "$DRIVER" &> /dev/null; then
            echo -e "  ${GREEN}[OK]${NC} ${DRIVER} already installed (minimal mode)"
        else
            # Blacklist nouveau
            if lsmod | grep -q nouveau 2>/dev/null; then
                echo -e "  ${CYAN}[*] Blacklisting nouveau...${NC}"
                echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null
                echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf > /dev/null
            fi
            
            # Install driver
            if [ "$AUR" = "1" ]; then
                echo -e "  ${YELLOW}[WARN]${NC} Legacy GPU - requires AUR package"
                if command -v yay &> /dev/null; then
                    yay -S --noconfirm "$DRIVER" 2>/dev/null || echo -e "  ${YELLOW}[WARN]${NC} Failed to install $DRIVER"
                else
                    echo -e "  ${YELLOW}[WARN]${NC} yay not available, skipping NVIDIA driver"
                fi
            else
                sudo pacman -S --needed --noconfirm "$DRIVER" nvidia-utils lib32-nvidia-utils 2>/dev/null || echo -e "  ${YELLOW}[WARN]${NC} Failed to install NVIDIA driver"
            fi
            
            # Configure if installed
            if pacman -Qi "$DRIVER" &> /dev/null 2>&1 || [ "$DRIVER" = "nvidia-dkms" -a -d "/usr/lib/nvidia" ]; then
                echo -e "  ${CYAN}[*] Configuring NVIDIA...${NC}"
                # Early module loading
                if ! grep -q "nvidia" /etc/mkinitcpio.conf 2>/dev/null; then
                    sudo sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
                fi
                # DRM KMS
                if [ ! -f "/etc/modprobe.d/nvidia.conf" ]; then
                    echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
                fi
                sudo mkinitcpio -P 2>/dev/null || true
                echo -e "  ${GREEN}[OK]${NC} NVIDIA driver installed and configured"
            fi
        fi
    else
        echo -e "  ${YELLOW}[WARN]${NC} Could not detect PCI ID, skipping NVIDIA driver"
    fi
else
    echo -e "  ${GREEN}[OK]${NC} No NVIDIA GPU detected - using Mesa drivers"
fi

# Install PipeWire audio stack
echo -e "${CYAN}[*] Installing PipeWire audio stack...${NC}"
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
echo -e "${CYAN}[*] Installing fonts...${NC}"
REPO_FONTS=(
    "ttf-font-awesome"
    "noto-fonts"
    "noto-fonts-emoji"
)

for font in "${REPO_FONTS[@]}"; do
    install_pkg "$font"
done

# Enable services
echo -e "${CYAN}[*] Enabling system services...${NC}"
sudo systemctl enable --now bluetooth.service 2>/dev/null || echo -e "  ${YELLOW}[WARN]${NC} Bluetooth service failed"
sudo systemctl enable --now NetworkManager.service 2>/dev/null || echo -e "  ${YELLOW}[WARN]${NC} NetworkManager failed"

# Enable SDDM display manager
echo -e "${CYAN}[*] Enabling SDDM display manager...${NC}"
sudo systemctl enable sddm.service 2>/dev/null || echo -e "  ${YELLOW}[WARN]${NC} SDDM enable failed"
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
echo -e "[Autologin]\nSession=hyprland.desktop" | sudo tee /etc/sddm.conf.d/hyprland.conf > /dev/null
echo -e "  ${GREEN}[OK]${NC} Hyprland set as default session"

# Configure NetworkManager WiFi backend
echo -e "${CYAN}[*] Configuring NetworkManager WiFi backend...${NC}"
sudo mkdir -p /etc/NetworkManager/NetworkManager.conf
echo -e "[device]\nwifi.backend=iwd" | sudo tee /etc/NetworkManager/NetworkManager.conf.d/wifi-backend.conf > /dev/null
echo -e "  ${GREEN}[OK]${NC} Using iwd for WiFi (faster connection)"

# Install yay AUR helper (if not in minimal mode or yay missing)
if [ "$MODE" != "minimal" ] || ! command -v yay &> /dev/null; then
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
    
    # Install AUR packages if yay available
    if [ -z "$YAY_FAILED" ] && command -v yay &> /dev/null; then
        echo -e "  ${CYAN}Installing nerd-fonts-jetbrains-mono from AUR...${NC}"
        yay -S --noconfirm nerd-fonts-jetbrains-mono 2>/dev/null || echo -e "  ${YELLOW}[WARN]${NC} Failed to install JetBrains Nerd Font"
        
        echo -e "  ${CYAN}Installing cliphist from AUR...${NC}"
        yay -S --noconfirm cliphist 2>/dev/null || echo -e "  ${YELLOW}[WARN]${NC} Failed to install cliphist"
        
        echo -e "${CYAN}[*] Installing SDDM Astronaut theme (AUR)...${NC}"
        yay -S --noconfirm sddm-astronaut-theme 2>/dev/null || echo -e "  ${YELLOW}[WARN]${NC} sddm-astronaut-theme install failed"
    fi
fi

# Enable PipeWire services
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
if [ "$MODE" != "minimal" ]; then
    echo -e "${CYAN}[*] Installing gdown for wallpaper downloads...${NC}"
    if ! command -v gdown &> /dev/null; then
        pip install --user gdown || echo -e "  ${YELLOW}[WARN]${NC} Failed to install gdown"
        export PATH="$HOME/.local/bin:$PATH"
    else
        echo -e "  ${GREEN}[OK]${NC} gdown already installed"
    fi
    
    # Download wallpapers from Google Drive
    if command -v gdown &> /dev/null; then
        echo -e "${CYAN}[*] Downloading live wallpapers from Google Drive...${NC}"
        GDRIVE_FOLDER="https://drive.google.com/drive/folders/1oS6aUxoW6DGoqzu_S3pVBlgicGPgIoYq"
        gdown --folder "$GDRIVE_FOLDER" -O ~/.config/hypr/wallpapers/live-wallpapers/ --remaining-ok 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}[OK]${NC} Live wallpapers downloaded successfully!"
        else
            echo -e "  ${YELLOW}[WARN]${NC} Live wallpaper download failed. Will use local themes as fallback."
        fi
    fi
fi

# Copy configs (skip for minimal mode if configs exist)
if [ "$MODE" != "minimal" ]; then
    echo -e "${CYAN}[*] Copying configuration files...${NC}"
    if [ -d ".config/hypr" ]; then
        find .config/hypr -type f ! -name "hyprpaper.conf" -exec cp {} ~/.config/hypr/ \; 2>/dev/null
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
    if [ -d ".config/mako" ]; then
        cp -r .config/mako/* ~/.config/mako/ 2>/dev/null && echo -e "  ${GREEN}[OK]${NC} Mako notification config copied"
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
    
    # Determine default wallpaper
    echo -e "${CYAN}[*] Configuring wallpaper...${NC}"
    FALLBACK_WALLPAPER="$HOME/.config/hypr/wallpapers/dark-theme/dark-wall1.jpg"
    
    if [ -d ~/.config/hypr/wallpapers/live-wallpapers ] && [ "$(ls -A ~/.config/hypr/wallpapers/live-wallpapers/ 2>/dev/null)" ]; then
        LIVE_WALL=$(ls ~/.config/hypr/wallpapers/live-wallpapers/ | head -n1)
        DEFAULT_WALLPAPER="$HOME/.config/hypr/wallpapers/live-wallpapers/$LIVE_WALL"
        echo -e "  ${GREEN}[OK]${NC} Using live wallpaper: $LIVE_WALL"
    else
        DEFAULT_WALLPAPER="$FALLBACK_WALLPAPER"
        echo -e "  ${YELLOW}[WARN]${NC} Live wallpapers not available, using fallback"
    fi
    
    # Generate hyprpaper.conf
    cat > ~/.config/hypr/hyprpaper.conf << EOF
preload = $DEFAULT_WALLPAPER
wallpaper = ,$DEFAULT_WALLPAPER
splash = false
ipc = on
EOF
    echo -e "  ${GREEN}[OK]${NC} hyprpaper.conf configured with: $(basename "$DEFAULT_WALLPAPER")"
    
    # Set SDDM wallpaper
    if [ -d "/usr/share/sddm/themes/sddm-astronaut-theme" ]; then
        echo -e "${CYAN}[*] Setting SDDM wallpaper...${NC}"
        if [ -f "$DEFAULT_WALLPAPER" ]; then
            sudo cp "$DEFAULT_WALLPAPER" /usr/share/sddm/themes/sddm-astronaut-theme/background.jpg 2>/dev/null && \
                echo -e "  ${GREEN}[OK]${NC} SDDM wallpaper set" || \
                echo -e "  ${YELLOW}[WARN]${NC} Failed to copy SDDM wallpaper"
        fi
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
echo -e "${CYAN}     Mode: ${MODE}${NC}"
echo -e "${PURPLE}========================================${NC}"
echo ""

if [ "$MODE" != "minimal" ] && [ -n "$backup_dir" ]; then
    echo -e "${GREEN}Backup saved to:${NC} ${CYAN}$backup_dir${NC}"
    echo ""
fi

echo -e "${GREEN}Configuration locations:${NC}"
echo -e "  - Hyprland: ${CYAN}~/.config/hypr/${NC}"
echo -e "  - Waybar: ${CYAN}~/.config/waybar/${NC}"
echo -e "  - Kitty: ${CYAN}~/.config/kitty/${NC}"
echo -e "  - btop: ${CYAN}~/.config/btop/${NC}"
echo -e "  - Neofetch: ${CYAN}~/.config/neofetch/${NC}"
echo -e "  - Wallpapers: ${CYAN}~/.config/hypr/wallpapers/${NC}"
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
echo -e "  - Screenshot (full): ${CYAN}SUPER + Print${NC}"
echo -e "  - Screenshot (region): ${CYAN}SUPER + SHIFT + S${NC}"
echo -e "  - Clipboard history: ${CYAN}SUPER + V${NC}"
echo -e "  - Reload Hyprland: ${CYAN}hyprctl reload${NC}"
echo ""
echo -e "${GREEN}Enjoy your cyberpunk rice!${NC}"
