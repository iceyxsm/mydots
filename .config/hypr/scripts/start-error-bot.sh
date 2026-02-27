#!/bin/bash
# Start Hyprland Error Monitor Bot in background
# Author: iceyxsm

BOT_DIR="$HOME/.config/hypr/monitor-bot"
VENV_DIR="$BOT_DIR/venv"
BOT_SCRIPT="$HOME/.config/hypr/scripts/telegram-error-bot.py"
LOG_FILE="$HOME/.config/hypr/logs/bot.log"

# Ensure logs directory exists
mkdir -p "$HOME/.config/hypr/logs"

# Check if bot script exists
if [ ! -f "$BOT_SCRIPT" ]; then
    echo "Error: Bot script not found at $BOT_SCRIPT" >> "$LOG_FILE"
    exit 1
fi

# Check if venv exists, if not run setup
if [ ! -d "$VENV_DIR" ]; then
    echo "Setting up bot environment..." >> "$LOG_FILE"
    "$HOME/.config/hypr/scripts/setup-bot-venv.sh" >> "$LOG_FILE" 2>&1
fi

# Check if config exists
if [ ! -f "$HOME/.config/hypr/telegram-bot.conf" ]; then
    echo "Warning: Telegram bot config not found, bot will run in dry-run mode" >> "$LOG_FILE"
fi

# Activate venv and start bot
source "$VENV_DIR/bin/activate"

# Start bot in background with nohup
nohup python3 "$BOT_SCRIPT" >> "$LOG_FILE" 2>&1 &

# Store PID
echo $! > "$BOT_DIR/bot.pid"

echo "Bot started with PID $(cat "$BOT_DIR/bot.pid")"
