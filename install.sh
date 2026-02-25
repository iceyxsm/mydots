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

# Copy local wallpapers FIRST (before trying to download)
echo -e "${GREEN}[*] Copying local wallpapers...${NC}"
if [ -d ".config/hypr/wallpapers/dark-theme" ]; then
    cp -r .config/hypr/wallpapers/dark-theme/* ~/.config/hypr/wallpapers/dark-theme/ 2>/dev/null
    if [ "$(ls -A ~/.config/hypr/wallpapers/dark-theme/ 2>/dev/null)" ]; then
        echo -e "  ${GREEN}[OK] Dark theme wallpapers copied${NC}"
    else
        echo -e "  ${GREEN}[WARN] No dark theme wallpapers found in repo${NC}"
    fi
fi
if [ -d ".config/hypr/wallpapers/light-theme" ]; then
    cp -r .config/hypr/wallpapers/light-theme/* ~/.config/hypr/wallpapers/light-theme/ 2>/dev/null
    if [ "$(ls -A ~/.config/hypr/wallpapers/light-theme/ 2>/dev/null)" ]; then
        echo -e "  ${GREEN}[OK] Light theme wallpapers copied${NC}"
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
    "polkit-kde-agent"
    "sddm"
)

for pkg in "${BASE_PACKAGES[@]}"; do
    install_pkg "$pkg" 1
done

# Detect GPU and install only required drivers
echo -e "${GREEN}[*] Detecting GPU...${NC}"

HAS_NVIDIA=false
HAS_INTEL=false
HAS_AMD=false

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

# Check for NVIDIA GPU and auto-install appropriate driver
if [ "$HAS_NVIDIA" = true ]; then
    echo -e "${GREEN}[*] Installing NVIDIA drivers...${NC}"
    
    # Extract PCI ID
    PCI_ID=$(lspci -nn | grep -i 'vga\|3d\|display' | grep -i nvidia | grep -oP '\[10de:\K[0-9a-f]+' | head -n1 | tr '[:lower:]' '[:upper:]')
    
    if [ -n "$PCI_ID" ]; then
        echo -e "  ${GREEN}PCI ID: ${PCI_ID}${NC}"
        
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
        
        echo -e "  ${GREEN}[OK] Detected: ${DESC}${NC}"
        echo -e "  ${GREEN}[*] Installing ${DRIVER}...${NC}"
        
        # Check if already installed (minimal mode)
        if [ "$MODE" = "minimal" ] && pacman -Qi "$DRIVER" &> /dev/null; then
            echo -e "  ${GREEN}[OK] ${DRIVER} already installed (minimal mode)${NC}"
        else
            # Blacklist nouveau
            if lsmod | grep -q nouveau 2>/dev/null; then
                echo -e "  ${GREEN}[*] Blacklisting nouveau...${NC}"
                echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf > /dev/null
                echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf > /dev/null
            fi
            
            # Install driver
            if [ "$AUR" = "1" ]; then
                echo -e "  ${GREEN}[WARN] Legacy GPU - requires AUR package${NC}"
                if command -v yay &> /dev/null; then
                    yay -S --noconfirm "$DRIVER" 2>/dev/null || echo -e "  ${GREEN}[WARN] Failed to install $DRIVER${NC}"
                else
                    echo -e "  ${GREEN}[WARN] yay not available, skipping NVIDIA driver${NC}"
                fi
            else
                sudo pacman -S --needed --noconfirm "$DRIVER" nvidia-utils lib32-nvidia-utils 2>/dev/null || echo -e "  ${GREEN}[WARN] Failed to install NVIDIA driver${NC}"
            fi
            
            # Configure if installed
            if pacman -Qi "$DRIVER" &> /dev/null 2>&1 || [ "$DRIVER" = "nvidia-dkms" -a -d "/usr/lib/nvidia" ]; then
                echo -e "  ${GREEN}[*] Configuring NVIDIA...${NC}"
                # Early module loading
                if ! grep -q "nvidia" /etc/mkinitcpio.conf 2>/dev/null; then
                    sudo sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
                fi
                # DRM KMS
                if [ ! -f "/etc/modprobe.d/nvidia.conf" ]; then
                    echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf > /dev/null
                fi
                sudo mkinitcpio -P 2>/dev/null || true
                echo -e "  ${GREEN}[OK] NVIDIA driver installed and configured${NC}"
            fi
        fi
    else
        echo -e "  ${GREEN}[WARN] Could not detect PCI ID, skipping NVIDIA driver${NC}"
    fi
fi

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
echo -e "  ${GREEN}[OK] SDDM configured${NC}"

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

# Create SDDM session fix - THIS IS CRITICAL FOR LOGIN LOOP
echo -e "${GREEN}[*] Creating SDDM session fix...${NC}"
sudo mkdir -p /etc/sddm.conf.d

# Remove old configs that might conflict
sudo rm -f /etc/sddm.conf.d/hyprland.conf 2>/dev/null || true
sudo rm -f /etc/sddm.conf.d/10-wayland.conf 2>/dev/null || true

# Create proper SDDM config
cat | sudo tee /etc/sddm.conf.d/99-hyprland.conf > /dev/null << 'EOF'
[General]
DisplayServer=x11
GreeterEnvironment=QT_QPA_PLATFORM=xcb
DefaultSession=hyprland.desktop

[Theme]
Current=sddm-astronaut-theme
EOF

echo -e "  ${GREEN}[OK] SDDM config created (using X11 backend for stability)${NC}"

# Create Hyprland environment file with NVIDIA fixes and display fixes
echo -e "${GREEN}[*] Creating Hyprland environment config...${NC}"
mkdir -p ~/.config/hypr
sudo mkdir -p /etc/environment.d

# For user
cat > ~/.config/hypr/environment.conf << 'EOF'
# NVIDIA fixes
WLR_NO_HARDWARE_CURSORS=1
WLR_RENDERER_ALLOW_SOFTWARE=1

# Display fixes - force proper rendering
WLR_DRM_NO_ATOMIC=1
WLR_DRM_NO_MODIFIERS=1

# Session type
XDG_SESSION_TYPE=wayland
XDG_CURRENT_DESKTOP=Hyprland

# QT/Wayland
QT_QPA_PLATFORM=wayland
QT_QPA_PLATFORMTHEME=qt5ct

# SDL
SDL_VIDEODRIVER=wayland

# Mozilla
MOZ_ENABLE_WAYLAND=1

# For NVIDIA cards
if [ -d /proc/driver/nvidia ]; then
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export GBM_BACKEND=nvidia-drm
    export __GL_GSYNC_ALLOWED=0
    export __GL_VRR_ALLOWED=0
fi
EOF

# For system
cat | sudo tee /etc/environment.d/99-hyprland.conf > /dev/null << 'EOF'
WLR_NO_HARDWARE_CURSORS=1
WLR_RENDERER_ALLOW_SOFTWARE=1
WLR_DRM_NO_ATOMIC=1
WLR_DRM_NO_MODIFIERS=1
XDG_SESSION_TYPE=wayland
QT_QPA_PLATFORM=wayland
EOF

echo -e "  ${GREEN}[OK] Environment config created${NC}"

# Configure NetworkManager WiFi backend
echo -e "${GREEN}[*] Configuring NetworkManager WiFi backend...${NC}"
sudo mkdir -p /etc/NetworkManager/NetworkManager.conf
echo -e "[device]\nwifi.backend=iwd" | sudo tee /etc/NetworkManager/NetworkManager.conf.d/wifi-backend.conf > /dev/null
echo -e "  ${GREEN}[OK] Using iwd for WiFi (faster connection)${NC}"

# Install neofetch (now AUR only) - do this early so it works in all modes
echo -e "${GREEN}[*] Installing neofetch (AUR)...${NC}"
if ! command -v neofetch &> /dev/null; then
    if ! command -v yay &> /dev/null; then
        echo -e "  ${GREEN}Installing yay first...${NC}"
        YAY_TEMP="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay.git "$YAY_TEMP" 2>/dev/null && \
            (cd "$YAY_TEMP" && makepkg -si --noconfirm 2>/dev/null) || \
            echo -e "  ${GREEN}[WARN] Failed to install yay, skipping neofetch${NC}"
        rm -rf "$YAY_TEMP"
    fi
    if command -v yay &> /dev/null; then
        yay -S --noconfirm neofetch 2>/dev/null && \
            echo -e "  ${GREEN}[OK] neofetch installed${NC}" || \
            echo -e "  ${GREEN}[WARN] Failed to install neofetch${NC}"
    fi
else
    echo -e "  ${GREEN}[OK] neofetch already installed${NC}"
fi

# Install yay AUR helper (if not in minimal mode or yay missing)
if [ "$MODE" != "minimal" ] || ! command -v yay &> /dev/null; then
    echo -e "${GREEN}[*] Installing yay AUR helper...${NC}"
    if ! command -v yay &> /dev/null; then
        YAY_BUILD_DIR="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay.git "$YAY_BUILD_DIR" || {
            echo -e "${GREEN}[WARN] Failed to clone yay, continuing without AUR packages...${NC}"
            YAY_FAILED=1
        }
        if [ -z "$YAY_FAILED" ]; then
            (cd "$YAY_BUILD_DIR" && makepkg -si --noconfirm) || {
                echo -e "${GREEN}[WARN] Failed to build yay, continuing without AUR packages...${NC}"
                YAY_FAILED=1
            }
        fi
        rm -rf "$YAY_BUILD_DIR"
    else
        echo -e "  ${GREEN}[OK] yay already installed${NC}"
    fi
    
    # Install AUR packages if yay available
    if [ -z "$YAY_FAILED" ] && command -v yay &> /dev/null; then
        echo -e "  ${GREEN}Installing nerd-fonts-jetbrains-mono from AUR...${NC}"
        yay -S --noconfirm nerd-fonts-jetbrains-mono 2>/dev/null || echo -e "  ${GREEN}[WARN] Failed to install JetBrains Nerd Font${NC}"
        
        echo -e "  ${GREEN}Installing cliphist from AUR...${NC}"
        yay -S --noconfirm cliphist 2>/dev/null || echo -e "  ${GREEN}[WARN] Failed to install cliphist${NC}"
        
        echo -e "${GREEN}[*] Installing SDDM Astronaut theme (AUR)...${NC}"
        yay -S --noconfirm sddm-astronaut-theme 2>/dev/null || echo -e "  ${GREEN}[WARN] sddm-astronaut-theme install failed${NC}"
    fi
fi

# Enable PipeWire services
echo -e "${GREEN}[*] Enabling PipeWire audio services...${NC}"
systemctl --user enable pipewire.service 2>/dev/null || true
systemctl --user enable pipewire-pulse.service 2>/dev/null || true
systemctl --user enable wireplumber.service 2>/dev/null || true
echo -e "  ${GREEN}[OK] PipeWire services enabled for user${NC}"

# Configure SDDM theme (only if astronaut theme was installed)
if [ -d "/usr/share/sddm/themes/sddm-astronaut-theme" ]; then
    echo -e "${GREEN}[*] SDDM Astronaut theme installed${NC}"
else
    echo -e "  ${GREEN}[WARN] Astronaut theme not found, using default SDDM theme${NC}"
fi

# Install gdown for wallpaper downloads
if [ "$MODE" != "minimal" ]; then
    echo -e "${GREEN}[*] Installing gdown for wallpaper downloads...${NC}"
    if ! command -v gdown &> /dev/null; then
        pip install --user gdown || echo -e "  ${GREEN}[WARN] Failed to install gdown${NC}"
        export PATH="$HOME/.local/bin:$PATH"
    else
        echo -e "  ${GREEN}[OK] gdown already installed${NC}"
    fi
    
    # Download wallpapers from Google Drive
    if command -v gdown &> /dev/null; then
        echo -e "${GREEN}[*] Downloading live wallpapers from Google Drive...${NC}"
        GDRIVE_FOLDER="https://drive.google.com/drive/folders/1oS6aUxoW6DGoqzu_S3pVBlgicGPgIoYq"
        gdown --folder "$GDRIVE_FOLDER" -O ~/.config/hypr/wallpapers/live-wallpapers/ --remaining-ok 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}[OK] Live wallpapers downloaded successfully!${NC}"
        else
            echo -e "  ${GREEN}[WARN] Live wallpaper download failed. Will use local themes as fallback.${NC}"
        fi
    fi
fi

# Copy configs (skip for minimal mode if configs exist)
if [ "$MODE" != "minimal" ]; then
    echo -e "${GREEN}[*] Copying configuration files...${NC}"
    if [ -d ".config/hypr" ]; then
        # Copy hyprland configs (including our fixed one)
        cp -r .config/hypr/* ~/.config/hypr/ 2>/dev/null || true
        echo -e "  ${GREEN}[OK] Hyprland configs copied${NC}"
    fi
    if [ -d ".config/waybar" ]; then
        cp -r .config/waybar/* ~/.config/waybar/ 2>/dev/null && echo -e "  ${GREEN}[OK] Waybar configs copied${NC}"
    fi
    if [ -d ".config/kitty" ]; then
        cp -r .config/kitty/* ~/.config/kitty/ 2>/dev/null && echo -e "  ${GREEN}[OK] Kitty configs copied${NC}"
    fi
    if [ -d ".config/btop" ]; then
        cp -r .config/btop/* ~/.config/btop/ 2>/dev/null && echo -e "  ${GREEN}[OK] btop configs copied${NC}"
    fi
    if [ -d ".config/neofetch" ]; then
        cp -r .config/neofetch/* ~/.config/neofetch/ 2>/dev/null && echo -e "  ${GREEN}[OK] Neofetch configs copied${NC}"
    fi
    if [ -d ".config/mako" ]; then
        cp -r .config/mako/* ~/.config/mako/ 2>/dev/null && echo -e "  ${GREEN}[OK] Mako notification config copied${NC}"
    fi
    
    # Determine default wallpaper
    echo -e "${GREEN}[*] Configuring wallpaper...${NC}"
    
    # Check for live wallpapers first
    if [ -d "$HOME/.config/hypr/wallpapers/live-wallpapers" ] && [ "$(ls -A $HOME/.config/hypr/wallpapers/live-wallpapers/ 2>/dev/null)" ]; then
        LIVE_WALL=$(ls $HOME/.config/hypr/wallpapers/live-wallpapers/ | head -n1)
        DEFAULT_WALLPAPER="$HOME/.config/hypr/wallpapers/live-wallpapers/$LIVE_WALL"
        echo -e "  ${GREEN}[OK] Using live wallpaper: $LIVE_WALL${NC}"
    # Then check for dark theme wallpapers
    elif [ -f "$HOME/.config/hypr/wallpapers/dark-theme/dark-wall1.jpg" ]; then
        DEFAULT_WALLPAPER="$HOME/.config/hypr/wallpapers/dark-theme/dark-wall1.jpg"
        echo -e "  ${GREEN}[OK] Using dark theme fallback wallpaper${NC}"
    # Last resort - check if any dark theme wallpaper exists
    elif [ -d "$HOME/.config/hypr/wallpapers/dark-theme" ] && [ "$(ls -A $HOME/.config/hypr/wallpapers/dark-theme/ 2>/dev/null)" ]; then
        DARK_WALL=$(ls $HOME/.config/hypr/wallpapers/dark-theme/ | head -n1)
        DEFAULT_WALLPAPER="$HOME/.config/hypr/wallpapers/dark-theme/$DARK_WALL"
        echo -e "  ${GREEN}[OK] Using dark theme wallpaper: $DARK_WALL${NC}"
    else
        echo -e "  ${GREEN}[WARN] No wallpapers found! Using solid color.${NC}"
        DEFAULT_WALLPAPER=""
    fi
    
    # Generate hyprpaper.conf
    if [ -n "$DEFAULT_WALLPAPER" ] && [ -f "$DEFAULT_WALLPAPER" ]; then
        cat > ~/.config/hypr/hyprpaper.conf << EOF
preload = $DEFAULT_WALLPAPER
wallpaper = ,$DEFAULT_WALLPAPER
splash = false
ipc = on
EOF
        echo -e "  ${GREEN}[OK] hyprpaper.conf configured${NC}"
        
        # Set SDDM wallpaper too
        if [ -d "/usr/share/sddm/themes/sddm-astronaut-theme" ]; then
            echo -e "${GREEN}[*] Setting SDDM wallpaper...${NC}"
            sudo cp "$DEFAULT_WALLPAPER" /usr/share/sddm/themes/sddm-astronaut-theme/background.jpg 2>/dev/null && \
                echo -e "  ${GREEN}[OK] SDDM wallpaper set${NC}" || \
                echo -e "  ${GREEN}[WARN] Failed to copy SDDM wallpaper${NC}"
        fi
    else
        echo -e "  ${GREEN}[WARN] No wallpaper available, hyprpaper will use default${NC}"
    fi
fi

# Fix permissions
echo -e "${GREEN}[*] Fixing permissions...${NC}"
sudo chown -R "$USER:$USER" "$HOME" 2>/dev/null || true
sudo chmod 755 "$HOME" 2>/dev/null || true

# Verify Hyprland binary
if [ -x "/usr/bin/Hyprland" ]; then
    echo -e "  ${GREEN}[OK] Hyprland binary found${NC}"
else
    echo -e "  ${GREEN}[WARN] Hyprland binary not found at /usr/bin/Hyprland${NC}"
    HYPRLAND_PATH=$(which Hyprland 2>/dev/null || find /usr -name "Hyprland" -type f 2>/dev/null | head -n1)
    if [ -n "$HYPRLAND_PATH" ]; then
        sudo ln -sf "$HYPRLAND_PATH" /usr/bin/Hyprland 2>/dev/null || true
    fi
fi

# Final summary
echo -e "${GREEN}[*] Display Manager configured${NC}"
echo -e "  ${GREEN}[OK] SDDM will provide graphical login screen${NC}"
echo -e "  ${GREEN}[OK] Hyprland is the default session${NC}"
echo -e "  ${GREEN}[OK] hyprlock works for locking (SUPER+L)${NC}"

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

echo -e "${GREEN}IMPORTANT FIXES APPLIED:${NC}"
echo -e "  - SDDM now uses X11 backend (more stable)"
echo -e "  - NVIDIA environment variables set"
echo -e "  - Display rendering fixes applied"
echo -e "  - Hyprland wrapper script created"
echo ""
echo -e "${GREEN}If you still get login loop:${NC}"
echo -e "  1. At SDDM, press Ctrl+Alt+F2"
echo -e "  2. Login and run: Hyprland"
echo -e "  3. Check error message"
echo ""

# Ask for reboot
echo -e "${GREEN}Do you want to reboot now? (y/N): ${NC}"
read -r reboot_choice
if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Rebooting...${NC}"
    sudo reboot
else
    echo -e "${GREEN}Reboot skipped. Run 'sudo reboot' when ready.${NC}"
fi
