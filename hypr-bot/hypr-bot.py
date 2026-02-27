#!/usr/bin/env python3
"""
Hyprland Error Monitor Bot - System Service
Sends system status and errors to Telegram
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
LOG_DIR = Path('/var/log/hypr-bot')
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_DIR / 'bot.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('hypr-bot')

class HyprlandMonitorBot:
    def __init__(self):
        self.config_file = Path('/etc/hypr-bot/.env')
        self.user_config = Path.home() / '.config/hypr-bot/.env'
        self.bot_token = None
        self.chat_id = None
        self.hostname = self.get_hostname()
        self.load_config()
        
        # Error patterns
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
            'not found',
            'core dumped'
        ]
        
        self.last_errors = set()
        self.startup_time = datetime.now()
        
    def get_hostname(self):
        """Get system hostname"""
        try:
            return subprocess.run(['hostname'], capture_output=True, text=True).stdout.strip()
        except:
            return 'unknown-host'
    
    def load_config(self):
        """Load config from /etc/hypr-bot/.env or ~/.config/hypr-bot/.env"""
        config_paths = [self.config_file, self.user_config]
        
        for config_path in config_paths:
            if config_path.exists():
                try:
                    with open(config_path) as f:
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
                        logger.info(f"Config loaded from {config_path}")
                        return
                except Exception as e:
                    logger.error(f"Error loading {config_path}: {e}")
        
        logger.warning("No valid config found!")
        logger.info("Create /etc/hypr-bot/.env with TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID")
    
    async def send_telegram_message(self, message, parse_mode='HTML'):
        """Send message to Telegram"""
        if not self.bot_token or not self.chat_id:
            logger.warning("Telegram not configured, message not sent")
            logger.info(f"Message would be: {message[:100]}...")
            return False
            
        try:
            import aiohttp
            url = f"https://api.telegram.org/bot{self.bot_token}/sendMessage"
            payload = {
                'chat_id': self.chat_id,
                'text': message,
                'parse_mode': parse_mode
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(url, json=payload) as response:
                    if response.status == 200:
                        logger.info("Message sent to Telegram")
                        return True
                    else:
                        logger.error(f"Failed to send: {response.status}")
                        return False
                        
        except ImportError:
            return await self._send_with_curl(message, parse_mode)
        except Exception as e:
            logger.error(f"Error: {e}")
            return False
    
    async def _send_with_curl(self, message, parse_mode):
        """Fallback to curl"""
        try:
            import urllib.parse
            encoded_msg = urllib.parse.quote(message)
            url = f"https://api.telegram.org/bot{self.bot_token}/sendMessage"
            
            cmd = [
                'curl', '-s', '-X', 'POST', url,
                '-d', f'chat_id={self.chat_id}',
                '-d', f'text={encoded_msg}',
                '-d', f'parse_mode={parse_mode}'
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            return result.returncode == 0
            
        except Exception as e:
            logger.error(f"Curl error: {e}")
            return False
    
    async def send_startup_notification(self):
        """Send system startup notification"""
        uptime = subprocess.run(['uptime', '-p'], capture_output=True, text=True).stdout.strip()
        boot_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        message = f"""🖥️ <b>System Started</b>

<b>Host:</b> <code>{self.hostname}</code>
<b>Boot Time:</b> {boot_time}
<b>Uptime:</b> {uptime}

✅ Bot is monitoring for errors..."""

        success = await self.send_telegram_message(message)
        if success:
            logger.info("Startup notification sent")
        return success
    
    def get_hyprland_logs(self):
        """Get recent Hyprland errors"""
        logs = []
        
        # Try hyprctl
        try:
            result = subprocess.run(
                ['hyprctl', 'version'],
                capture_output=True, text=True, timeout=2
            )
            if "not running" in result.stderr.lower():
                return ["⚠️ Hyprland is not running!"]
        except:
            pass
        
        # Read hyprland log
        log_paths = [
            Path.home() / '.hyprland/hyprland.log',
            Path('/tmp/hypr') / 'hyprland.log',
        ]
        
        for log_file in log_paths:
            if log_file.exists():
                try:
                    with open(log_file, 'r') as f:
                        lines = f.readlines()
                        for line in lines[-100:]:
                            if any(pattern in line for pattern in self.error_patterns):
                                logs.append(line.strip())
                except:
                    pass
        
        return logs[-10:] if logs else []
    
    def check_system_status(self):
        """Check system processes"""
        errors = []
        
        # Check critical processes
        critical_apps = ['Hyprland', 'waybar', 'hyprpaper', 'mako']
        for app in critical_apps:
            result = subprocess.run(['pgrep', '-x', app], capture_output=True)
            if result.returncode != 0:
                errors.append(f"❌ {app} is NOT running")
        
        return errors
    
    async def send_error_alert(self, errors):
        """Send error alert"""
        if not errors:
            return
            
        error_text = '\n'.join(f"• <code>{err[:80]}</code>" for err in errors[:5])
        
        message = f"""🚨 <b>Error Detected on {self.hostname}</b>

Time: {datetime.now().strftime('%H:%M:%S')}

<b>Issues:</b>
{error_text}

<i>Check /var/log/hypr-bot/bot.log</i>"""

        await self.send_telegram_message(message)
    
    async def run(self):
        """Main loop"""
        logger.info("="*50)
        logger.info("Hyprland Monitor Bot Starting...")
        logger.info("="*50)
        
        # Send startup notification
        await self.send_startup_notification()
        
        loop_count = 0
        while True:
            try:
                loop_count += 1
                
                # Check every 30 seconds
                hypr_errors = self.get_hyprland_logs()
                sys_errors = self.check_system_status()
                all_errors = hypr_errors + sys_errors
                
                current_errors = set(all_errors)
                new_errors = current_errors - self.last_errors
                
                if new_errors:
                    await self.send_error_alert(list(new_errors))
                
                self.last_errors = current_errors
                
                # Send heartbeat every 5 minutes
                if loop_count % 10 == 0:
                    logger.info("Bot heartbeat - still monitoring...")
                
                await asyncio.sleep(30)
                
            except Exception as e:
                logger.error(f"Loop error: {e}")
                await asyncio.sleep(60)

if __name__ == '__main__':
    bot = HyprlandMonitorBot()
    
    try:
        asyncio.run(bot.run())
    except KeyboardInterrupt:
        logger.info("Bot stopped")
    except Exception as e:
        logger.error(f"Fatal: {e}")
        sys.exit(1)
