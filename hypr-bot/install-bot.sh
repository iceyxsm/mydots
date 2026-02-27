#!/bin/bash
# Install Hyprland Error Monitor Bot as system service
# Author: iceyxsm

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Hyprland Error Monitor Bot Installer${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR] Please run as root (sudo ./install-bot.sh)${NC}"
    exit 1
fi

BOT_DIR="/opt/hypr-bot"
VENV_DIR="$BOT_DIR/venv"
CONFIG_DIR="/etc/hypr-bot"
LOG_DIR="/var/log/hypr-bot"

echo -e "${GREEN}[*] Installing bot to $BOT_DIR...${NC}"

# Create directories
mkdir -p "$BOT_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"

# Install Python packages if needed
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}[!] Installing Python...${NC}"
    pacman -S --needed --noconfirm python python-pip python-virtualenv
fi

# Copy bot files
echo -e "${GREEN}[*] Copying bot files...${NC}"
cp hypr-bot.py "$BOT_DIR/"
chmod +x "$BOT_DIR/hypr-bot.py"

# Create virtual environment
echo -e "${GREEN}[*] Creating Python virtual environment...${NC}"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m virtualenv "$VENV_DIR"
fi

# Install dependencies
echo -e "${GREEN}[*] Installing Python packages...${NC}"
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install aiohttp

echo -e "${GREEN}[OK] Virtual environment ready${NC}"

# Create config
echo -e "${GREEN}[*] Setting up configuration...${NC}"
if [ ! -f "$CONFIG_DIR/.env" ]; then
    cat > "$CONFIG_DIR/.env" << 'EOF'
# Telegram Bot Configuration
# Get bot token from @BotFather on Telegram
TELEGRAM_BOT_TOKEN=your_bot_token_here

# Get chat ID from @userinfobot on Telegram  
TELEGRAM_CHAT_ID=your_chat_id_here
EOF
    chmod 600 "$CONFIG_DIR/.env"
    echo -e "${GREEN}[OK] Config created at $CONFIG_DIR/.env${NC}"
    echo -e "${YELLOW}[!] IMPORTANT: Edit $CONFIG_DIR/.env with your bot token and chat ID${NC}"
else
    echo -e "${GREEN}[OK] Config already exists${NC}"
fi

# Install systemd service
echo -e "${GREEN}[*] Installing systemd service...${NC}"
cp hypr-bot.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable hypr-bot.service

echo -e "${GREEN}[OK] Service installed and enabled${NC}"

# Create user config symlink
mkdir -p /home/*/".config/hypr-bot" 2>/dev/null || true

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Edit config: ${GREEN}sudo nano $CONFIG_DIR/.env${NC}"
echo -e "2. Add your Telegram bot token and chat ID"
echo -e "3. Start bot: ${GREEN}sudo systemctl start hypr-bot${NC}"
echo -e "4. Check status: ${GREEN}sudo systemctl status hypr-bot${NC}"
echo -e "5. View logs: ${GREEN}sudo journalctl -u hypr-bot -f${NC}"
echo ""
echo -e "${GREEN}The bot will start automatically on system boot!${NC}"
