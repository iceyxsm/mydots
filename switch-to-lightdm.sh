#!/bin/bash
# Switch from SDDM to LightDM for better wallpaper support

echo "=== Switching to LightDM ==="

# Install LightDM and webkit2 greeter (has better wallpaper support)
sudo pacman -S --noconfirm lightdm lightdm-webkit2-greeter

# Install glorious theme
yay -S --noconfirm lightdm-glorious-webkit2-theme 2>/dev/null || {
    echo "Installing glorious theme manually..."
    sudo git clone https://github.com/thecmdrunner/lightdm-glorious-webkit2.git /usr/share/lightdm-webkit/themes/glorious
}

# Configure LightDM
sudo tee /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
greeter-session=lightdm-webkit2-greeter
greeter-hide-users=false
user-session=hyprland
EOF

# Configure webkit2 greeter
sudo tee /etc/lightdm/lightdm-webkit2-greeter.conf << 'EOF'
[greeter]
webkit_theme=glorious
background_images=/usr/share/backgrounds
default_background=/usr/share/sddm/themes/sddm-astronaut-theme/background.jpg
EOF

# Disable SDDM, enable LightDM
sudo systemctl disable sddm
sudo systemctl enable lightdm

echo "=== Done! Reboot to use LightDM ==="
