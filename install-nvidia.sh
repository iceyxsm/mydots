#!/bin/bash
# NVIDIA Driver Auto-Installer for Arch Linux
# Detects GPU and installs appropriate driver

set -e

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
if ! lspci | grep -i nvidia &> /dev/null; then
    echo -e "${YELLOW}[WARN]${NC} No NVIDIA GPU detected!"
    read -p "Continue anyway? (y/N): " choice
    if [[ ! $choice =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get GPU info
GPU_INFO=$(lspci -nnk -d 10de: 2>/dev/null | grep -A2 "VGA\|3D\|Display" | head -n1)
echo -e "${GREEN}[OK]${NC} Found: $GPU_INFO"

# Determine driver based on GPU family
echo -e "${CYAN}[*] Determining appropriate driver...${NC}"

# Check if nouveau is loaded
if lsmod | grep -q nouveau; then
    echo -e "${CYAN}[*] Blacklisting nouveau...${NC}"
    echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
    echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf
    sudo mkinitcpio -P
fi

# Install base dependencies
echo -e "${CYAN}[*] Installing base dependencies...${NC}"
sudo pacman -S --needed --noconfirm dkms linux-headers

# Detect GPU generation and install appropriate driver
# Using nvidia-inst logic simplified

# Try to detect by PCI ID or use nvidia-open for new GPUs, nvidia-dkms for older
# RTX 2000+ (Turing+) can use nvidia-open or nvidia
# GTX 1000 and older need nvidia-dkms

# Simplified approach: Try nvidia-dkms first (works for most), fallback to nvidia-open
# For very old cards, user needs to manually install legacy drivers

echo -e "${CYAN}[*] Installing NVIDIA drivers...${NC}"

# Check if we should use open or proprietary
# Default to proprietary nvidia-dkms for maximum compatibility
NVIDIA_PACKAGES=(
    "nvidia-dkms"
    "nvidia-utils"
    "lib32-nvidia-utils"
)

for pkg in "${NVIDIA_PACKAGES[@]}"; do
    echo -e "  ${CYAN}Installing $pkg...${NC}"
    sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null || echo -e "  ${YELLOW}[WARN]${NC} $pkg may have failed"
done

# For RTX 4000+ series, offer nvidia-open
read -p "Do you have RTX 4000 series or newer? (y/N): " rtx4000
if [[ $rtx4000 =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}[*] Installing nvidia-open-dkms (for RTX 4000+)...${NC}"
    sudo pacman -S --needed --noconfirm nvidia-open-dkms 2>/dev/null || {
        echo -e "${YELLOW}[WARN]${NC} nvidia-open-dkms not available, keeping nvidia-dkms"
    }
fi

# Configure mkinitcpio for early loading
echo -e "${CYAN}[*] Configuring early module loading...${NC}"
if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
    sudo sed -i 's/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    sudo mkinitcpio -P
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
echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. Reboot: ${YELLOW}sudo reboot${NC}"
echo -e "  2. Verify: ${YELLOW}nvidia-smi${NC}"
echo -e "  3. Test: ${YELLOW}glxinfo | grep renderer${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} If you have issues, try:"
echo -e "  - For legacy GPUs (GTX 600/700): yay -S nvidia-470xx-dkms"
echo -e "  - For very old GPUs: Use nouveau driver instead"
