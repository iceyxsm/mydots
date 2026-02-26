#!/bin/bash
# Install Custom Display Manager

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Installing Custom Display Manager ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root: sudo ./install.sh${NC}"
    exit 1
fi

# Install dependencies
echo -e "${GREEN}[*] Installing dependencies...${NC}"
pacman -S --needed --noconfirm python python-pip python-pam qt6-base pyqt6 noto-fonts

# Install python-pam if not available
pip3 install python-pam 2>/dev/null || echo -e "${YELLOW}python-pam may already be installed${NC}"

# Copy files
echo -e "${GREEN}[*] Installing custom DM...${NC}"
cp main.py /usr/local/bin/custom-dm
chmod +x /usr/local/bin/custom-dm

# Install systemd service
cp custom-dm.service /etc/systemd/system/

# Disable SDDM if running
systemctl stop sddm 2>/dev/null || true
systemctl disable sddm 2>/dev/null || true

# Enable custom DM
systemctl daemon-reload
systemctl enable custom-dm

echo -e "${GREEN}[OK] Custom Display Manager installed!${NC}"
echo ""
echo -e "${YELLOW}To start now:${NC} systemctl start custom-dm"
echo -e "${YELLOW}To check logs:${NC} journalctl -u custom-dm -f"
echo ""
echo -e "${RED}WARNING: This is experimental!${NC}"
echo "If it fails, switch to TTY (Ctrl+Alt+F2) and run:"
echo "  systemctl stop custom-dm"
echo "  systemctl enable sddm"
echo "  systemctl start sddm"
