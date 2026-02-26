#!/bin/bash
# Install custom SDDM theme

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Installing Custom SDDM Theme ===${NC}"
echo ""

# Check if running as root for theme installation
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Note: Will use sudo for system directories${NC}"
fi

# Install theme
echo -e "${GREEN}[*] Installing custom theme to /usr/share/sddm/themes/${NC}"
sudo mkdir -p /usr/share/sddm/themes/custom-fullscreen
sudo cp sddm-theme-custom/* /usr/share/sddm/themes/custom-fullscreen/

# Copy current wallpaper
echo -e "${GREEN}[*] Copying wallpaper...${NC}"
if [ -f ~/.config/hypr/wallpapers/dark-theme/dark-wall1.jpg ]; then
    sudo cp ~/.config/hypr/wallpapers/dark-theme/dark-wall1.jpg /usr/share/sddm/themes/custom-fullscreen/background.jpg
elif [ -f ~/.config/hypr/wallpapers/background.jpg ]; then
    sudo cp ~/.config/hypr/wallpapers/background.jpg /usr/share/sddm/themes/custom-fullscreen/background.jpg
fi

# Update SDDM config
echo -e "${GREEN}[*] Updating SDDM config...${NC}"
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/99-custom-theme.conf > /dev/null << 'EOF'
[General]
DisplayServer=x11

[Theme]
Current=custom-fullscreen
EOF

echo -e "${GREEN}[OK] Custom theme installed!${NC}"
echo ""
echo -e "${YELLOW}To test without rebooting:${NC}"
echo "  sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/custom-fullscreen/"
echo ""
echo -e "${YELLOW}To apply (will logout):${NC}"
echo "  sudo systemctl restart sddm"
