#!/bin/bash
# Setup Python virtual environment for Hyprland Error Monitor Bot
# Author: iceyxsm

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}[*] Setting up Hyprland Error Monitor Bot...${NC}"

BOT_DIR="$HOME/.config/hypr/monitor-bot"
VENV_DIR="$BOT_DIR/venv"
LOGS_DIR="$HOME/.config/hypr/logs"

# Create directories
mkdir -p "$BOT_DIR"
mkdir -p "$LOGS_DIR"

# Install Python if not present
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}[!] Python3 not found, installing...${NC}"
    sudo pacman -S --needed --noconfirm python python-pip python-virtualenv
fi

# Ensure python-virtualenv is installed
if ! python3 -m virtualenv --help &> /dev/null 2>&1; then
    echo -e "${YELLOW}[!] Installing python-virtualenv...${NC}"
    sudo pacman -S --needed --noconfirm python-virtualenv
fi

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${GREEN}[*] Creating Python virtual environment...${NC}"
    python3 -m virtualenv "$VENV_DIR"
fi

# Install required packages
echo -e "${GREEN}[*] Installing Python packages...${NC}"
source "$VENV_DIR/bin/activate"

pip install --upgrade pip
pip install aiohttp requests

echo -e "${GREEN}[OK] Virtual environment ready at $VENV_DIR${NC}"

# Check if bot config exists
BOT_CONFIG="$HOME/.config/hypr/telegram-bot.conf"
if [ ! -f "$BOT_CONFIG" ]; then
    echo -e "${YELLOW}[!] Telegram bot config not found${NC}"
    echo -e "${YELLOW}[!] Create it at: $BOT_CONFIG${NC}"
    echo -e "${YELLOW}[!] Format: {\"bot_token\": \"YOUR_BOT_TOKEN\", \"chat_id\": \"YOUR_CHAT_ID\"}${NC}"
    
    # Create sample config
    echo '{"bot_token": "YOUR_BOT_TOKEN_HERE", "chat_id": "YOUR_CHAT_ID_HERE"}' > "$BOT_CONFIG"
    echo -e "${GREEN}[OK] Sample config created at $BOT_CONFIG${NC}"
    echo -e "${YELLOW}[!] Please edit it with your actual Telegram bot token and chat ID${NC}"
fi

echo -e "${GREEN}[OK] Bot setup complete!${NC}"
echo -e "${GREEN}[*] The bot will start automatically on next Hyprland login${NC}"
echo -e "${GREEN}[*] Check logs at: $LOGS_DIR/bot.log${NC}"
