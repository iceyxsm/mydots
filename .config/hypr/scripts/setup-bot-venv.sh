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
BOT_ENV="$HOME/.config/hypr/scripts/.env"
BOT_JSON="$HOME/.config/hypr/telegram-bot.conf"

if [ ! -f "$BOT_ENV" ] && [ ! -f "$BOT_JSON" ]; then
    echo -e "${YELLOW}[!] Telegram bot config not found${NC}"
    
    # Create sample .env file
    if [ -f ".config/hypr/scripts/.env.example" ]; then
        cp .config/hypr/scripts/.env.example "$BOT_ENV"
    else
        cat > "$BOT_ENV" << 'EOF'
# Telegram Bot Configuration
# Get bot token from @BotFather on Telegram
TELEGRAM_BOT_TOKEN=your_bot_token_here

# Get chat ID from @userinfobot on Telegram  
TELEGRAM_CHAT_ID=your_chat_id_here
EOF
    fi
    
    echo -e "${GREEN}[OK] Sample .env created at $BOT_ENV${NC}"
    echo -e "${YELLOW}[!] Please edit it with your actual Telegram bot token and chat ID${NC}"
    echo -e "${YELLOW}[!] Get token from @BotFather, chat ID from @userinfobot${NC}"
fi

echo -e "${GREEN}[OK] Bot setup complete!${NC}"
echo -e "${GREEN}[*] The bot will start automatically on next Hyprland login${NC}"
echo -e "${GREEN}[*] Check logs at: $LOGS_DIR/bot.log${NC}"
