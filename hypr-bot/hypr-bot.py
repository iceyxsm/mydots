#!/usr/bin/env python3
"""
System-Wide Error Monitor Bot with Telegram Control
Monitors all system errors, not just Hyprland
Author: iceyxsm
"""

import os
import sys
import time
import json
import hashlib
import subprocess
import asyncio
import logging
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict, deque

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
logger = logging.getLogger('system-bot')

class SystemMonitorBot:
    def __init__(self):
        self.config_file = Path('/etc/hypr-bot/.env')
        self.data_dir = Path('/var/lib/hypr-bot')
        self.data_dir.mkdir(exist_ok=True)
        
        # Storage files
        self.ignored_file = self.data_dir / 'ignored_errors.json'
        self.state_file = self.data_dir / 'bot_state.json'
        
        self.bot_token = None
        self.chat_id = None
        self.hostname = self.get_hostname()
        self.load_config()
        
        # State
        self.ignored_errors = self.load_ignored()
        self.mode = 'normal'  # 'normal' or 'package'
        self.selected_packages = []  # List of package IDs in package mode
        self.packages = {}  # Map ID -> package name
        self.recent_errors = deque(maxlen=1000)  # Recent errors for deduplication
        
        # Error patterns
        self.error_patterns = [
            'error', 'Error', 'ERROR',
            'crash', 'Crash', 'CRASH',
            'failed', 'Failed', 'FAILED',
            'fatal', 'Fatal', 'FATAL',
            'segmentation fault', 'segfault', 'SIGSEGV',
            'core dumped', 'aborted',
            'exception', 'Exception',
            'panic', 'Panic',
            'killed', 'Killed',
            'terminated', 'Terminated',
            'permission denied', 'Permission denied',
            'no such file', 'No such file',
            'connection refused', 'Connection refused',
            'timeout', 'Timeout',
            'unable to', 'Unable to',
            'cannot', 'Cannot',
            'not found', 'Not found'
        ]
        
        self.startup_time = datetime.now()
        self.last_journal_check = time.time()
        
    def get_hostname(self):
        try:
            return subprocess.run(['hostname'], capture_output=True, text=True).stdout.strip()
        except:
            return 'unknown-host'
    
    def load_config(self):
        if self.config_file.exists():
            try:
                with open(self.config_file) as f:
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
                    logger.info("Config loaded")
            except Exception as e:
                logger.error(f"Config error: {e}")
    
    def load_ignored(self):
        """Load ignored error IDs from JSON"""
        if self.ignored_file.exists():
            try:
                with open(self.ignored_file) as f:
                    return set(json.load(f))
            except:
                pass
        return set()
    
    def save_ignored(self):
        """Save ignored error IDs to JSON"""
        try:
            with open(self.ignored_file, 'w') as f:
                json.dump(list(self.ignored_errors), f)
        except Exception as e:
            logger.error(f"Failed to save ignored: {e}")
    
    def generate_error_id(self, error_text):
        """Generate unique ID for error"""
        # Hash first 100 chars of error for ID
        return hashlib.md5(error_text[:100].encode()).hexdigest()[:8].upper()
    
    def is_duplicate(self, error_id):
        """Check if error was recently sent"""
        if error_id in self.recent_errors:
            return True
        self.recent_errors.append(error_id)
        return False
    
    async def send_telegram_message(self, message, parse_mode='HTML'):
        """Send message to Telegram"""
        if not self.bot_token or not self.chat_id:
            logger.warning("Telegram not configured")
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

✅ Bot is monitoring all system errors

<b>Commands:</b>
/packages - List running packages
/pm &lt;id&gt; - Monitor specific package
/pm 1,2,3 - Monitor multiple packages
/nm - Normal mode (all logs)
/ignore #ID - Ignore error
/unignore #ID - Unignore error
/ignoring - List ignored errors"""

        await self.send_telegram_message(message)
        logger.info("Startup notification sent")
    
    def get_running_packages(self):
        """Get list of running packages with IDs"""
        packages = {}
        try:
            # Get unique process names
            result = subprocess.run(
                ['ps', '-eo', 'comm=', '--sort=comm'],
                capture_output=True, text=True
            )
            
            seen = set()
            idx = 1
            for line in result.stdout.strip().split('\n'):
                name = line.strip()
                if name and name not in seen:
                    seen.add(name)
                    packages[idx] = name
                    idx += 1
                    
        except Exception as e:
            logger.error(f"Failed to get packages: {e}")
            
        return packages
    
    async def handle_telegram_commands(self):
        """Poll Telegram for commands"""
        if not self.bot_token:
            return
            
        try:
            import aiohttp
            offset = 0
            
            while True:
                try:
                    url = f"https://api.telegram.org/bot{self.bot_token}/getUpdates"
                    params = {'offset': offset, 'limit': 10}
                    
                    async with aiohttp.ClientSession() as session:
                        async with session.get(url, params=params) as response:
                            if response.status == 200:
                                data = await response.json()
                                
                                for update in data.get('result', []):
                                    offset = max(offset, update['update_id'] + 1)
                                    await self.process_command(update)
                                    
                except Exception as e:
                    logger.error(f"Command poll error: {e}")
                    
                await asyncio.sleep(2)
                
        except ImportError:
            logger.warning("aiohttp not available, command handling disabled")
    
    async def process_command(self, update):
        """Process Telegram command"""
        if 'message' not in update or 'text' not in update['message']:
            return
            
        text = update['message']['text'].strip()
        chat_id = str(update['message']['chat']['id'])
        
        # Only respond to configured chat
        if chat_id != self.chat_id:
            return
        
        logger.info(f"Received command: {text}")
        
        if text == '/packages':
            await self.cmd_packages()
        elif text.startswith('/pm '):
            await self.cmd_pm(text[4:])
        elif text == '/nm':
            await self.cmd_nm()
        elif text.startswith('/ignore '):
            await self.cmd_ignore(text[8:])
        elif text.startswith('/unignore '):
            await self.cmd_unignore(text[10:])
        elif text == '/ignoring':
            await self.cmd_ignoring()
        elif text == '/start' or text == '/help':
            await self.cmd_help()
    
    async def cmd_packages(self):
        """List running packages"""
        self.packages = self.get_running_packages()
        
        lines = ["📦 <b>Running Packages</b>\n"]
        for idx, name in list(self.packages.items())[:50]:  # Show first 50
            lines.append(f"<code>{idx:3}</code> | {name}")
        
        if len(self.packages) > 50:
            lines.append(f"\n... and {len(self.packages) - 50} more")
        
        await self.send_telegram_message('\n'.join(lines))
    
    async def cmd_pm(self, args):
        """Package mode - monitor specific packages"""
        try:
            # Parse IDs (comma-separated)
            ids = [int(x.strip()) for x in args.split(',')]
            
            if not self.packages:
                self.packages = self.get_running_packages()
            
            selected = []
            names = []
            for pid in ids:
                if pid in self.packages:
                    selected.append(pid)
                    names.append(self.packages[pid])
            
            if not selected:
                await self.send_telegram_message("❌ Invalid package ID(s)")
                return
            
            self.selected_packages = selected
            self.mode = 'package'
            
            await self.send_telegram_message(
                f"📦 <b>Package Mode</b>\n\nMonitoring:\n" + 
                '\n'.join(f"• {n}" for n in names) +
                f"\n\nUse /nm to return to normal mode"
            )
            
        except ValueError:
            await self.send_telegram_message("❌ Invalid format. Use: /pm 1 or /pm 1,2,3")
    
    async def cmd_nm(self):
        """Normal mode"""
        self.mode = 'normal'
        self.selected_packages = []
        await self.send_telegram_message("🌐 <b>Normal Mode</b>\n\nMonitoring all system errors")
    
    async def cmd_ignore(self, error_id):
        """Ignore an error ID"""
        error_id = error_id.strip().upper()
        if not error_id.startswith('#'):
            error_id = '#' + error_id
        
        self.ignored_errors.add(error_id)
        self.save_ignored()
        
        await self.send_telegram_message(f"🚫 Now ignoring error <code>{error_id}</code>")
    
    async def cmd_unignore(self, error_id):
        """Unignore an error ID"""
        error_id = error_id.strip().upper()
        if not error_id.startswith('#'):
            error_id = '#' + error_id
        
        if error_id in self.ignored_errors:
            self.ignored_errors.remove(error_id)
            self.save_ignored()
            await self.send_telegram_message(f"✅ Error <code>{error_id}</code> removed from ignore list")
        else:
            await self.send_telegram_message(f"❌ Error <code>{error_id}</code> not in ignore list")
    
    async def cmd_ignoring(self):
        """List ignored errors"""
        if not self.ignored_errors:
            await self.send_telegram_message("📭 No errors being ignored")
            return
        
        lines = ["🚫 <b>Ignored Errors:</b>\n"]
        for err_id in sorted(self.ignored_errors):
            lines.append(f"• <code>{err_id}</code>")
        
        await self.send_telegram_message('\n'.join(lines))
    
    async def cmd_help(self):
        """Show help"""
        help_text = """🤖 <b>System Monitor Bot Commands</b>

<b>Error Management:</b>
/ignore #ID - Ignore error with ID
/unignore #ID - Stop ignoring error
/ignoring - List all ignored errors

<b>Package Monitoring:</b>
/packages - List all running packages
/pm &lt;id&gt; - Monitor specific package
/pm 1,2,3 - Monitor multiple packages
/nm - Normal mode (all errors)

<b>Other:</b>
/help - Show this help

Errors are shown as:
<b>[#ID]</b> [package]: message"""
        
        await self.send_telegram_message(help_text)
    
    def get_journal_errors(self):
        """Get errors from systemd journal"""
        errors = []
        
        try:
            # Get logs since last check
            since = datetime.fromtimestamp(self.last_journal_check).strftime('%Y-%m-%d %H:%M:%S')
            self.last_journal_check = time.time()
            
            # Query journal for errors
            cmd = [
                'journalctl', '--since', since,
                '--priority=err', '--no-pager',
                '-o', 'short',
                '--output-fields=SYSLOG_IDENTIFIER,MESSAGE'
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            
            for line in result.stdout.split('\n'):
                if not line or line.startswith('--'):
                    continue
                
                # Parse log line
                # Format: Mon DD HH:MM:SS hostname process[pid]: message
                if ':' in line:
                    parts = line.split(':', 2)
                    if len(parts) >= 3:
                        timestamp_part = parts[0]
                        process_part = parts[1].strip()
                        message = parts[2].strip()
                        
                        # Check if it's an error
                        if any(pattern in message for pattern in self.error_patterns):
                            # Extract process name
                            process = process_part.split('[')[0].strip()
                            if not process:
                                process = 'system'
                            
                            errors.append({
                                'process': process,
                                'message': message,
                                'raw': line
                            })
                            
        except subprocess.TimeoutExpired:
            pass
        except Exception as e:
            logger.error(f"Journal error: {e}")
        
        return errors
    
    async def process_and_send_errors(self, errors):
        """Process errors and send to Telegram"""
        for error in errors:
            error_text = f"{error['process']}: {error['message']}"
            error_id = self.generate_error_id(error_text)
            error_id_str = f"#{error_id}"
            
            # Skip if ignored
            if error_id_str in self.ignored_errors:
                continue
            
            # Skip duplicates
            if self.is_duplicate(error_id):
                continue
            
            # Filter by mode
            if self.mode == 'package':
                # Get current packages
                current_packages = self.get_running_packages()
                selected_names = [
                    current_packages.get(pid, '') 
                    for pid in self.selected_packages
                ]
                
                # Check if error is from selected package
                if error['process'] not in selected_names:
                    continue
            
            # Format message
            if self.mode == 'package' and len(self.selected_packages) > 1:
                # Multi-package mode
                message = f"<b>{error_id_str}</b> [{error['process']}]: {error['message'][:200]}"
            else:
                message = f"🚨 <b>Error {error_id_str}</b>\n\n<b>Process:</b> <code>{error['process']}</code>\n<b>Message:</b> {error['message'][:300]}"
            
            await self.send_telegram_message(message)
    
    async def run(self):
        """Main loop"""
        logger.info("="*50)
        logger.info("System Monitor Bot Starting...")
        logger.info("="*50)
        
        # Send startup notification
        await self.send_startup_notification()
        
        # Start command handler in background
        asyncio.create_task(self.handle_telegram_commands())
        
        loop_count = 0
        while True:
            try:
                loop_count += 1
                
                # Check journal for errors
                errors = self.get_journal_errors()
                if errors:
                    await self.process_and_send_errors(errors)
                
                # Periodic refresh of packages
                if loop_count % 30 == 0:  # Every ~5 minutes
                    self.packages = self.get_running_packages()
                    logger.info(f"Refreshed packages: {len(self.packages)} found")
                
                # Heartbeat
                if loop_count % 60 == 0:
                    logger.info("Bot heartbeat - monitoring...")
                
                await asyncio.sleep(10)
                
            except Exception as e:
                logger.error(f"Loop error: {e}")
                await asyncio.sleep(30)

if __name__ == '__main__':
    bot = SystemMonitorBot()
    
    try:
        asyncio.run(bot.run())
    except KeyboardInterrupt:
        logger.info("Bot stopped")
    except Exception as e:
        logger.error(f"Fatal: {e}")
        sys.exit(1)
