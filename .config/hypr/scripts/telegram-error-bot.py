#!/usr/bin/env python3
"""
Hyprland Error Monitor Bot
Sends critical errors and crashes to Telegram
Author: iceyxsm
"""

import os
import sys
import time
import json
import subprocess
import asyncio
import logging
from datetime import datetime
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(Path.home() / '.config/hypr/logs/bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('hypr-bot')

class HyprlandMonitorBot:
    def __init__(self):
        self.config_file = Path.home() / '.config/hypr/telegram-bot.conf'
        self.env_file = Path.home() / '.config/hypr/scripts/.env'
        self.bot_token = None
        self.chat_id = None
        self.load_config()
        
        # Error patterns to watch for
        self.error_patterns = [
            'error', 'Error', 'ERROR',
            'crash', 'Crash', 'CRASH',
            'failed', 'Failed', 'FAILED',
            'fatal', 'Fatal', 'FATAL',
            'segmentation fault', 'segfault',
            'config error', 'Config error',
            'invalid field',
            'command not found',
            'permission denied',
        ]
        
        # Log files to monitor
        self.log_paths = [
            Path.home() / '.hyprland/hyprland.log',
            Path('/tmp/hypr') if Path('/tmp/hypr').exists() else None,
            Path.home() / '.config/hypr/logs',
        ]
        
        self.last_positions = {}
        
    def load_config(self):
        """Load Telegram bot configuration from .env or JSON"""
        # Try .env file first (preferred)
        if self.env_file.exists():
            try:
                with open(self.env_file) as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith('#'):
                            continue
                        if '=' in line:
                            key, value = line.split('=', 1)
                            os.environ[key] = value
                
                self.bot_token = os.environ.get('TELEGRAM_BOT_TOKEN')
                self.chat_id = os.environ.get('TELEGRAM_CHAT_ID')
                
                if self.bot_token and self.chat_id:
                    logger.info("Config loaded from .env file")
                    return
            except Exception as e:
                logger.error(f"Error loading .env: {e}")
        
        # Fallback to JSON config
        if self.config_file.exists():
            try:
                with open(self.config_file) as f:
                    config = json.load(f)
                    self.bot_token = config.get('bot_token')
                    self.chat_id = config.get('chat_id')
                    logger.info("Config loaded from JSON file")
                    return
            except Exception as e:
                logger.error(f"Error loading JSON config: {e}")
        
        logger.warning("No config found!")
        logger.info(f"Create ~/.config/hypr/scripts/.env with TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID")
        logger.info(f"Or create ~/.config/hypr/telegram-bot.conf with JSON: {{\"bot_token\": \"...\", \"chat_id\": \"...\"}}")
    
    async def send_telegram_message(self, message):
        """Send message to Telegram"""
        if not self.bot_token or not self.chat_id:
            logger.warning("Telegram not configured, message not sent")
            return False
            
        try:
            import aiohttp
            url = f"https://api.telegram.org/bot{self.bot_token}/sendMessage"
            payload = {
                'chat_id': self.chat_id,
                'text': message,
                'parse_mode': 'HTML'
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(url, json=payload) as response:
                    if response.status == 200:
                        logger.info("Message sent to Telegram")
                        return True
                    else:
                        logger.error(f"Failed to send message: {response.status}")
                        return False
                        
        except ImportError:
            # Fallback to curl if aiohttp not available
            return await self._send_with_curl(message)
        except Exception as e:
            logger.error(f"Error sending Telegram message: {e}")
            return False
    
    async def _send_with_curl(self, message):
        """Send message using curl as fallback"""
        try:
            import urllib.parse
            encoded_msg = urllib.parse.quote(message)
            url = f"https://api.telegram.org/bot{self.bot_token}/sendMessage"
            
            cmd = [
                'curl', '-s', '-X', 'POST',
                url,
                '-d', f'chat_id={self.chat_id}',
                '-d', f'text={encoded_msg}',
                '-d', 'parse_mode=HTML'
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            
            if result.returncode == 0:
                logger.info("Message sent via curl")
                return True
            else:
                logger.error(f"Curl failed: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Error with curl: {e}")
            return False
    
    def get_hyprland_logs(self):
        """Get recent Hyprland logs"""
        logs = []
        
        # Try hyprctl
        try:
            result = subprocess.run(
                ['hyprctl', 'getoption', 'debug:enable_stdout_logs'],
                capture_output=True, text=True, timeout=2
            )
            if "not running" in result.stderr.lower():
                logs.append("⚠️ Hyprland is not running!")
                return logs
        except:
            pass
        
        # Read hyprland log file
        log_file = Path.home() / '.hyprland/hyprland.log'
        if log_file.exists():
            try:
                with open(log_file, 'r') as f:
                    lines = f.readlines()
                    # Get last 50 lines with errors
                    for line in lines[-50:]:
                        if any(pattern in line for pattern in self.error_patterns):
                            logs.append(line.strip())
            except Exception as e:
                logger.error(f"Error reading log: {e}")
        
        return logs[-10:]  # Return last 10 error lines
    
    def check_system_errors(self):
        """Check for recent system errors"""
        errors = []
        
        # Check if critical processes are running
        critical_apps = ['waybar', 'hyprpaper', 'mako', 'hypridle']
        for app in critical_apps:
            result = subprocess.run(
                ['pgrep', '-x', app],
                capture_output=True
            )
            if result.returncode != 0:
                errors.append(f"❌ {app} is NOT running!")
        
        # Check Hyprland
        result = subprocess.run(
            ['pgrep', '-x', 'Hyprland'],
            capture_output=True
        )
        if result.returncode != 0:
            errors.append("🚨 Hyprland process not found!")
        
        return errors
    
    async def send_status_report(self):
        """Send initial status report"""
        hostname = subprocess.run(['hostname'], capture_output=True, text=True).stdout.strip()
        
        message = f"""<b>🖥️ Hyprland Monitor Started</b>

<code>{hostname}</code>
Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

<b>Monitoring:</b>
• Hyprland logs
• System errors  
• Critical apps (waybar, mako, etc.)

You'll receive alerts for any errors!"""

        await self.send_telegram_message(message)
    
    async def send_error_alert(self, errors):
        """Send error alert to Telegram"""
        if not errors:
            return
            
        hostname = subprocess.run(['hostname'], capture_output=True, text=True).stdout.strip()
        
        error_text = '\n'.join(f"• <code>{err[:100]}</code>" for err in errors[:5])
        
        message = f"""<b>🚨 Hyprland Error Detected!</b>

<code>{hostname}</code>
Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

<b>Errors:</b>
{error_text}

<i>Check logs for details</i>"""

        await self.send_telegram_message(message)
    
    async def run(self):
        """Main monitoring loop"""
        logger.info("Starting Hyprland Monitor Bot...")
        
        # Send startup notification
        await self.send_status_report()
        
        last_errors = set()
        
        while True:
            try:
                # Check for errors
                hypr_errors = self.get_hyprland_logs()
                sys_errors = self.check_system_errors()
                
                all_errors = hypr_errors + sys_errors
                current_errors = set(all_errors)
                
                # Send alert for new errors
                new_errors = current_errors - last_errors
                if new_errors:
                    await self.send_error_alert(list(new_errors))
                
                last_errors = current_errors
                
                # Wait before next check
                await asyncio.sleep(30)  # Check every 30 seconds
                
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}")
                await asyncio.sleep(60)

if __name__ == '__main__':
    bot = HyprlandMonitorBot()
    
    try:
        asyncio.run(bot.run())
    except KeyboardInterrupt:
        logger.info("Bot stopped by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)
