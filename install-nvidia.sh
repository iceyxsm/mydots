#!/bin/bash
# NVIDIA Driver Auto-Installer for Arch Linux
# Auto-detects GPU series and installs appropriate driver

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}   NVIDIA Driver Auto-Installer${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}[!] Please do not run this script as root${NC}"
    exit 1
fi

# Detect NVIDIA GPU
echo -e "${CYAN}[*] Detecting NVIDIA GPU...${NC}"
GPU_INFO=$(lspci -nn | grep -i 'vga\|3d\|display' | grep -i nvidia | head -n1)

if [ -z "$GPU_INFO" ]; then
    echo -e "${RED}[!] No NVIDIA GPU detected!${NC}"
    echo -e "${YELLOW}GPUs found:${NC}"
    lspci -nn | grep -i 'vga\|3d\|display'
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Found: $GPU_INFO"

# Extract PCI ID
PCI_ID=$(echo "$GPU_INFO" | grep -oP '\[10de:\K[0-9a-f]+' | head -n1 | tr '[:lower:]' '[:upper:]')

if [ -z "$PCI_ID" ]; then
    echo -e "${YELLOW}[WARN]${NC} Could not detect PCI ID, defaulting to nvidia-dkms"
    PCI_ID="UNKNOWN"
fi

echo -e "${CYAN}[*] PCI Device ID: ${PCI_ID}${NC}"

# Determine driver based on PCI ID ranges
# Reference: https://wiki.archlinux.org/title/NVIDIA#Installation
# https://download.nvidia.com/XFree86/Linux-x86_64/535.154.05/README/supportedchips.html

echo -e "${CYAN}[*] Determining appropriate driver...${NC}"

# Convert hex to decimal for comparison
PCI_DEC=$((0x${PCI_ID}))

# Define driver based on GPU generation
# Blackwell (RTX 5000): GB20x - Use nvidia-open
# Ada (RTX 4000): AD10x - Use nvidia-open or nvidia
# Ampere (RTX 3000): GA10x - Use nvidia
# Turing (RTX 2000/1600): TU10x/TU11x/TU117 - Use nvidia
# Pascal (GTX 1000): GP10x - Use nvidia
# Maxwell (GTX 900/750): GM20x/GM10x - Use nvidia (or legacy)
# Kepler (GTX 600/700): GKxxx - Need nvidia-470xx (legacy)

# PCI ID ranges (simplified detection)
case "$PCI_ID" in
    # Blackwell RTX 5000 series (2025+)
    2B85|2B87|2C05|2C07|2D05|2D07)
        DRIVER="nvidia-open-dkms"
        DRIVER_DESC="NVIDIA Open (Blackwell RTX 5000)"
        ;;
    # Ada Lovelace RTX 4000 series
    2684|2685|2686|2687|2688|2689|26B0|26B1|26B2|26B3|26B5|26B6|2704|2705|2730|2750|2780|2781|2782|2783|2786|2787|27A0|27B0|27B1|27B2|27B3|27B6|27B7|27B8|27B9|27BA|27BB|27E0)
        DRIVER="nvidia-open-dkms"
        DRIVER_DESC="NVIDIA Open (Ada Lovelace RTX 4000)"
        ;;
    # Ampere RTX 3000 series
    2204|2206|2207|2208|220A|2216|222F|2230|2231|2232|2233|2235|2236|2237|2414|2420|2438|2482|2484|2486|2487|2488|2489|24B0|24B1|24B6|24B7|24B8|24B9|24BA|24C9|24DC|24DD|24E0|24FA|2503|2504|2507|2508|2520|2523|2531|2544|2560|2571|2582|2583|2584|25B0|25B2|25B6|25B8|25E0|25E2|25E5|25F0|25F8|25F9|25FA)
        DRIVER="nvidia-dkms"
        DRIVER_DESC="NVIDIA Proprietary (Ampere RTX 3000)"
        ;;
    # Turing RTX 2000/1600 series and GTX 1600
    1E02|1E04|1E07|1E09|1E30|1E36|1E78|1E81|1E82|1E84|1E87|1E90|1EB0|1EB1|1EB5|1EB6|1EC2|1EC7|1ED0|1ED1|1ED3|1EDF|1F02|1F03|1F06|1F07|1F08|1F10|1F11|1F12|1F14|1F15|1F36|1F42|1F47|1F54|1F76|1F82|1F83|1F91|1F95|1F96|1F97|1F98|1F99|1F9C|1F9D|1FA0|1FB0|1FB1|1FB2|1FB6|1FB7|1FB8|1FB9|1FBC|1FDD|1FF0|1FF2|1FF9|2182|2184|2187|2188|2189|21C4|21D1)
        DRIVER="nvidia-dkms"
        DRIVER_DESC="NVIDIA Proprietary (Turing RTX 2000/GTX 1600)"
        ;;
    # Pascal GTX 1000 series
    1582|15F0|15F7|15F8|15F9|1617|1618|1619|161A|179C|17C2|17C8|1B00|1B02|1B06|1B30|1B34|1B38|1B80|1B81|1B82|1B83|1B84|1B87|1BA0|1BA1|1BA2|1BB0|1BB1|1BB3|1BB4|1BB5|1BB6|1BB7|1BB8|1BB9|1BC7|1BE0|1BE1|1C02|1C03|1C07|1C09|1C20|1C21|1C22|1C30|1C31|1C60|1C61|1C62|1C81|1C82|1C83|1C8C|1C8D|1C8F|1CB1|1CB2|1CB3|1CB6|1D01|1D02|1D10|1D11|1D12|1D13|1D16|1D33|1D34|1D35|1D36|1D52|1D71|1D81|1DB1|1DB3|1DB4|1DB5|1DB6|1DB7|1DB8)
        DRIVER="nvidia-dkms"
        DRIVER_DESC="NVIDIA Proprietary (Pascal GTX 1000)"
        ;;
    # Maxwell GTX 900 series and GTX 750
    13C0|13C1|13C2|13C3|13D7|13D8|13D9|13DA|13F0|13F1|13F2|13F3|13F8|13F9|13FA|13FB|1401|1402|1406|1407|1427|1430|1431|1436|1613|1617|1618|1619|161A|1667|174D|174E|179C|17C2|17C8|1B00|1B02|1B06|1B30|1B34|1B38)
        DRIVER="nvidia-dkms"
        DRIVER_DESC="NVIDIA Proprietary (Maxwell GTX 900/750)"
        ;;
    # Kepler GTX 600/700 series - LEGACY
    0FC0|0FC1|0FC2|0FC6|0FC8|0FC9|0FCD|0FCE|0FD1|0FD2|0FD3|0FD4|0FD5|0FD8|0FD9|0FDF|0FE0|0FE1|0FE2|0FE3|0FE4|0FF2|0FF3|0FF6|0FF8|0FF9|0FFA|0FFB|0FFC|0FFD|0FFE|0FFF|1001|1004|1005|1007|1008|100A|100C|1021|1022|1023|1024|1026|1027|1028|1029|103A|103C|1180|1183|1184|1185|1187|1188|1189|118A|118E|118F|1193|1194|1195|1198|1199|119A|119D|119E|119F|11A0|11A1|11A2|11A3|11A7|11B4|11B6|11B7|11B8|11BA|11BC|11BD|11BE|11BF|11C0|11C2|11C3|11C4|11C5|11C6|11C8|11CB|11E0|11E1|11E2|11E3|11E7|11FA|11FC|1280|1281|1282|1284|1286|1287|1288|1289|128B|1290|1291|1292|1293|1295|1296|1298|1299|12B9|12BA)
        DRIVER="nvidia-470xx-dkms"
        DRIVER_DESC="NVIDIA Legacy 470xx (Kepler GTX 600/700)"
        AUR_NEEDED=1
        ;;
    # Fermi GTX 400/500 series - VERY LEGACY
    06C0|06C4|06CA|06CD|06D1|06D2|06D8|06D9|06DA|06DC|06DD|06DE|06DF|0DC0|0DC4|0DC5|0DC6|0DCD|0DCE|0DD1|0DD2|0DD6|0DE0|0DE1|0DE2|0DE3|0DE4|0DE5|0DE7|0DE8|0DE9|0DEA|0DEB|0DEC|0DED|0DEE|0DEF|0DF0|0DF1|0DF2|0DF3|0DF4|0DF5|0DF6|0DF7|0DF8|0DF9|0DFA|0DFC|0E22|0E23|0E24|0E30|0E31|0E3A|0E3B|0F00|0F01|0F02|0F03|0E3C|0E3D|0E3E|0FCD)
        DRIVER="nvidia-390xx-dkms"
        DRIVER_DESC="NVIDIA Legacy 390xx (Fermi GTX 400/500) - VERY OLD"
        AUR_NEEDED=1
        ;;
    # Tesla and older - TOO OLD
    *)
        DRIVER="nvidia-dkms"
        DRIVER_DESC="NVIDIA Proprietary (Unknown/Generic)"
        echo -e "${YELLOW}[WARN]${NC} Unknown GPU PCI ID, defaulting to nvidia-dkms"
        echo -e "${YELLOW}[WARN]${NC} If this fails, you may need a legacy driver from AUR"
        ;;
esac

echo -e "${GREEN}[OK]${NC} Detected: ${DRIVER_DESC}"
echo -e "${CYAN}[*] Will install: ${DRIVER}${NC}"
echo ""

# Check if nouveau is loaded
if lsmod | grep -q nouveau; then
    echo -e "${CYAN}[*] Blacklisting nouveau...${NC}"
    echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
    echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf
fi

# Install base dependencies
echo -e "${CYAN}[*] Installing base dependencies...${NC}"
sudo pacman -S --needed --noconfirm dkms linux-headers

# Install driver
if [ "$AUR_NEEDED" = "1" ]; then
    echo -e "${YELLOW}[*] Legacy driver required - installing from AUR...${NC}"
    
    # Check if yay is installed
    if ! command -v yay &> /dev/null; then
        echo -e "${CYAN}[*] Installing yay first...${NC}"
        YAY_BUILD_DIR="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay.git "$YAY_BUILD_DIR"
        (cd "$YAY_BUILD_DIR" && makepkg -si --noconfirm)
        rm -rf "$YAY_BUILD_DIR"
    fi
    
    echo -e "${CYAN}[*] Installing ${DRIVER} from AUR...${NC}"
    yay -S --noconfirm "$DRIVER" || {
        echo -e "${RED}[!] Failed to install ${DRIVER}${NC}"
        echo -e "${YELLOW}Your GPU may be too old for modern NVIDIA drivers.${NC}"
        echo -e "${YELLOW}Consider using nouveau driver instead:${NC}"
        echo -e "  sudo pacman -S xf86-video-nouveau"
        exit 1
    }
else
    echo -e "${CYAN}[*] Installing ${DRIVER}...${NC}"
    sudo pacman -S --needed --noconfirm "$DRIVER" nvidia-utils lib32-nvidia-utils
fi

# Configure mkinitcpio for early loading
echo -e "${CYAN}[*] Configuring early module loading...${NC}"
if ! grep -q "nvidia" /etc/mkinitcpio.conf 2>/dev/null; then
    sudo sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    echo -e "  ${GREEN}[OK]${NC} Early module loading configured"
fi

# Enable DRM KMS
echo -e "${CYAN}[*] Enabling DRM KMS...${NC}"
if [ ! -f "/etc/modprobe.d/nvidia.conf" ]; then
    echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia.conf
    echo -e "  ${GREEN}[OK]${NC} DRM KMS enabled"
fi

# Regenerate initramfs
echo -e "${CYAN}[*] Regenerating initramfs...${NC}"
sudo mkinitcpio -P

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   NVIDIA Driver Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}Installed:${NC} ${DRIVER_DESC}"
echo -e "${CYAN}Package:${NC} ${DRIVER}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. Reboot: ${YELLOW}sudo reboot${NC}"
echo -e "  2. Verify: ${YELLOW}nvidia-smi${NC}"
echo -e "  3. Test: ${YELLOW}glxinfo | grep renderer${NC}"
echo ""
