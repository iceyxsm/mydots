#!/bin/bash
# Custom Display Manager Installer - One script to rule them all
# Replaces SDDM with a simple, fullscreen login manager
# Works with Hyprland, KDE, GNOME, etc.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Custom Display Manager Installer${NC}"
echo -e "${BLUE}  Fullscreen login for Hyprland${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR] Please run as root: sudo ./install-custom-dm.sh${NC}"
    exit 1
fi

# Detect if running in VM
IS_VM=false
if lspci | grep -iE 'vmware|virtualbox|qemu' &>/dev/null; then
    IS_VM=true
    echo -e "${YELLOW}[INFO] Virtual Machine detected${NC}"
fi

echo -e "${GREEN}[*] Installing dependencies...${NC}"
pacman -S --needed --noconfirm python python-pip python-pam qt6-base pyqt6 base-devel 2>/dev/null || true

# Install python-pam via pip if not available
pip3 install python-pam 2>/dev/null || pip install python-pam 2>/dev/null || true

# Create the display manager
echo -e "${GREEN}[*] Creating custom display manager...${NC}"

mkdir -p /usr/local/bin

cat > /usr/local/bin/custom-dm << 'PYTHON_EOF'
#!/usr/bin/env python3
"""
Custom Display Manager - Simple fullscreen login for Hyprland
"""

import sys
import os
import subprocess
import pwd
import pam
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, 
    QHBoxLayout, QLineEdit, QPushButton, QLabel,
    QComboBox, QMessageBox
)
from PyQt6.QtCore import Qt, QTimer, QDateTime
from PyQt6.QtGui import QPixmap, QPalette, QColor, QFont


class LoginWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Login")
        
        # TRUE fullscreen - no borders, no decorations
        self.showFullScreen()
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.CustomizeWindowHint
        )
        
        # Get actual screen size
        screen = QApplication.primaryScreen().geometry()
        self.screen_width = screen.width()
        self.screen_height = screen.height()
        
        print(f"Screen: {self.screen_width}x{self.screen_height}")
        
        self.setup_ui()
        self.load_sessions()
        self.load_wallpaper()
        
    def setup_ui(self):
        # Central widget
        self.central = QWidget()
        self.setCentralWidget(self.central)
        
        # Main layout - full screen
        main_layout = QHBoxLayout(self.central)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        
        # Left side - Login panel
        left_panel = QWidget()
        left_panel.setFixedWidth(420)
        left_panel.setStyleSheet("background-color: rgba(0, 0, 0, 200);")
        
        form_layout = QVBoxLayout(left_panel)
        form_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        form_layout.setSpacing(15)
        form_layout.setContentsMargins(30, 30, 30, 30)
        
        # Clock
        self.clock_label = QLabel()
        self.clock_label.setStyleSheet("color: white; font-size: 80px; font-weight: bold;")
        self.clock_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        form_layout.addWidget(self.clock_label)
        
        # Date
        self.date_label = QLabel()
        self.date_label.setStyleSheet("color: #c4a7e7; font-size: 22px;")
        self.date_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        form_layout.addWidget(self.date_label)
        
        # Spacer
        form_layout.addSpacing(60)
        
        # Username
        self.username_input = QLineEdit()
        self.username_input.setPlaceholderText("Username")
        self.username_input.setStyleSheet(self.input_style())
        self.username_input.setFont(QFont("JetBrainsMono Nerd Font", 14))
        form_layout.addWidget(self.username_input)
        
        # Password
        self.password_input = QLineEdit()
        self.password_input.setPlaceholderText("Password")
        self.password_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.password_input.setStyleSheet(self.input_style())
        self.password_input.setFont(QFont("JetBrainsMono Nerd Font", 14))
        self.password_input.returnPressed.connect(self.do_login)
        form_layout.addWidget(self.password_input)
        
        # Session selector
        self.session_combo = QComboBox()
        self.session_combo.setStyleSheet(self.combo_style())
        self.session_combo.setFont(QFont("JetBrainsMono Nerd Font", 12))
        form_layout.addWidget(self.session_combo)
        
        # Login button
        login_btn = QPushButton("Login")
        login_btn.setStyleSheet(self.button_style("#5e81ac"))
        login_btn.setFont(QFont("JetBrainsMono Nerd Font", 14))
        login_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        login_btn.clicked.connect(self.do_login)
        form_layout.addWidget(login_btn)
        
        # Error label
        self.error_label = QLabel()
        self.error_label.setStyleSheet("color: #eb6f92; font-size: 14px; padding: 10px;")
        self.error_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        form_layout.addWidget(self.error_label)
        
        # Spacer
        form_layout.addStretch()
        
        # Power buttons
        power_layout = QHBoxLayout()
        
        shutdown_btn = QPushButton("Shutdown")
        shutdown_btn.setStyleSheet(self.button_style("#bf616a"))
        shutdown_btn.setFont(QFont("JetBrainsMono Nerd Font", 11))
        shutdown_btn.clicked.connect(self.shutdown)
        power_layout.addWidget(shutdown_btn)
        
        reboot_btn = QPushButton("Reboot")
        reboot_btn.setStyleSheet(self.button_style("#d08770"))
        reboot_btn.setFont(QFont("JetBrainsMono Nerd Font", 11))
        reboot_btn.clicked.connect(self.reboot)
        power_layout.addWidget(reboot_btn)
        
        form_layout.addLayout(power_layout)
        
        # Add left panel
        main_layout.addWidget(left_panel)
        
        # Right side - wallpaper shows here
        right_spacer = QWidget()
        right_spacer.setStyleSheet("background: transparent;")
        main_layout.addWidget(right_spacer, stretch=1)
        
        # Clock timer
        self.update_clock()
        timer = QTimer(self)
        timer.timeout.connect(self.update_clock)
        timer.start(1000)
        
        # Focus username
        self.username_input.setFocus()
        
    def input_style(self):
        return """
            QLineEdit {
                background-color: rgba(33, 33, 33, 220);
                color: #e0def4;
                border: 2px solid transparent;
                border-radius: 8px;
                padding: 12px;
                font-size: 14px;
            }
            QLineEdit:focus {
                border: 2px solid #c4a7e7;
            }
        """
    
    def combo_style(self):
        return """
            QComboBox {
                background-color: rgba(33, 33, 33, 220);
                color: #e0def4;
                border: 2px solid transparent;
                border-radius: 8px;
                padding: 10px;
                font-size: 12px;
            }
            QComboBox:focus {
                border: 2px solid #c4a7e7;
            }
            QComboBox::drop-down {
                border: none;
                width: 30px;
            }
            QComboBox QAbstractItemView {
                background-color: #212121;
                color: #e0def4;
                selection-background-color: #c4a7e7;
                border-radius: 8px;
            }
        """
    
    def button_style(self, color):
        return f"""
            QPushButton {{
                background-color: {color};
                color: #e0def4;
                border: none;
                border-radius: 8px;
                padding: 14px;
                font-size: 14px;
                font-weight: bold;
            }}
            QPushButton:hover {{
                background-color: {color}dd;
            }}
            QPushButton:pressed {{
                background-color: {color}aa;
            }}
        """
        
    def load_wallpaper(self):
        """Load wallpaper - searches multiple locations"""
        wallpaper_paths = [
            "/usr/share/sddm/themes/sddm-astronaut-theme/background.jpg",
            os.path.expanduser("~/.config/hypr/wallpapers/dark-theme/dark-wall1.jpg"),
            os.path.expanduser("~/.config/hypr/wallpapers/background.jpg"),
            "/usr/share/backgrounds/default.png",
            "/usr/share/pixmaps/background.png",
        ]
        
        wallpaper = None
        for path in wallpaper_paths:
            if os.path.exists(path):
                wallpaper = path
                print(f"Found wallpaper: {path}")
                break
        
        if wallpaper:
            # Use CSS to stretch wallpaper
            self.setStyleSheet(f"""
                QMainWindow {{
                    background-image: url({wallpaper.replace(' ', '%20')});
                    background-position: center;
                    background-repeat: no-repeat;
                    background-attachment: fixed;
                }}
            """)
            
            # Also set as palette for better coverage
            palette = self.palette()
            pixmap = QPixmap(wallpaper)
            scaled_pixmap = pixmap.scaled(
                self.screen_width, self.screen_height,
                Qt.AspectRatioMode.IgnoreAspectRatio,
                Qt.TransformationMode.SmoothTransformation
            )
            palette.setBrush(QPalette.ColorRole.Window, scaled_pixmap)
            self.setPalette(palette)
        else:
            # Fallback to solid color
            self.setStyleSheet("QMainWindow { background-color: #191724; }")
            
    def load_sessions(self):
        """Load available desktop sessions"""
        sessions = []
        session_dirs = [
            "/usr/share/wayland-sessions",
            "/usr/share/xsessions"
        ]
        
        for d in session_dirs:
            if os.path.isdir(d):
                for f in sorted(os.listdir(d)):
                    if f.endswith(".desktop"):
                        name = f.replace(".desktop", "").replace("-", " ").title()
                        # Prefer Hyprland
                        if "hyprland" in f.lower():
                            sessions.insert(0, (name, os.path.join(d, f)))
                        else:
                            sessions.append((name, os.path.join(d, f)))
        
        if not sessions:
            # Fallback
            sessions = [("Hyprland", "hyprland.desktop")]
            
        for name, path in sessions:
            self.session_combo.addItem(name, path)
            
        # Select Hyprland by default
        for i in range(self.session_combo.count()):
            if "hyprland" in self.session_combo.itemText(i).lower():
                self.session_combo.setCurrentIndex(i)
                break
            
    def update_clock(self):
        now = QDateTime.currentDateTime()
        self.clock_label.setText(now.toString("HH:mm"))
        self.date_label.setText(now.toString("dddd d MMMM yyyy"))
        
    def do_login(self):
        username = self.username_input.text().strip()
        password = self.password_input.text()
        
        if not username or not password:
            self.error_label.setText("Enter username and password")
            return
            
        # Authenticate
        p = pam.pam()
        if p.authenticate(username, password):
            self.error_label.setText("")
            self.error_label.setStyleSheet("color: #9ccfd8; font-size: 14px;")
            self.error_label.setText("Success! Starting session...")
            self.start_session(username)
        else:
            self.error_label.setStyleSheet("color: #eb6f92; font-size: 14px;")
            self.error_label.setText("Invalid username or password")
            self.password_input.clear()
            self.password_input.setFocus()
            
    def start_session(self, username):
        """Start the user session"""
        session_path = self.session_combo.currentData()
        session_name = self.session_combo.currentText().lower()
        
        print(f"Starting session: {session_name} for {username}")
        
        # Get user info
        try:
            user_info = pwd.getpwnam(username)
            uid = user_info.pw_uid
            gid = user_info.pw_gid
            home = user_info.pw_dir
            shell = user_info.pw_shell
        except KeyError:
            self.error_label.setText("User not found")
            return
        
        # Determine command based on session
        if "hyprland" in session_name:
            cmd = "/usr/bin/Hyprland"
            session_type = "wayland"
        elif "plasma" in session_name or "kde" in session_name:
            cmd = "/usr/bin/startplasma-wayland"
            session_type = "wayland"
        elif "gnome" in session_name:
            cmd = "/usr/bin/gnome-session"
            session_type = "wayland"
        elif "sway" in session_name:
            cmd = "/usr/bin/sway"
            session_type = "wayland"
        else:
            # Try to read from desktop file
            cmd = self.get_exec_from_desktop(session_path) or "/usr/bin/Hyprland"
            session_type = "wayland"
        
        # Environment variables
        env = os.environ.copy()
        env["HOME"] = home
        env["USER"] = username
        env["LOGNAME"] = username
        env["SHELL"] = shell
        env["XDG_SESSION_TYPE"] = session_type
        env["XDG_CURRENT_DESKTOP"] = session_name.title()
        env["XDG_SESSION_DESKTOP"] = session_name.title()
        env["WAYLAND_DISPLAY"] = "wayland-1"
        env["XDG_RUNTIME_DIR"] = f"/run/user/{uid}"
        env["PATH"] = "/usr/local/bin:/usr/bin:/bin"
        
        # Create runtime dir
        os.makedirs(f"/run/user/{uid}", exist_ok=True)
        os.chown(f"/run/user/{uid}", uid, gid)
        os.chmod(f"/run/user/{uid}", 0o700)
        
        print(f"Executing: {cmd}")
        print(f"Environment: XDG_SESSION_TYPE={session_type}")
        
        # Fork and start session
        pid = os.fork()
        if pid == 0:
            # Child process - drop privileges and exec
            try:
                os.setgid(gid)
                os.setuid(uid)
                os.chdir(home)
                
                # Set up environment in child
                for key, val in env.items():
                    os.environ[key] = val
                
                # Exec the session
                os.execv(cmd, [cmd])
            except Exception as e:
                print(f"Failed to start session: {e}")
                sys.exit(1)
        else:
            # Parent - wait a moment then exit
            import time
            time.sleep(2)
            QApplication.quit()
            
    def get_exec_from_desktop(self, path):
        """Extract Exec line from .desktop file"""
        try:
            with open(path, 'r') as f:
                for line in f:
                    if line.startswith('Exec='):
                        return line.split('=', 1)[1].strip().split()[0]
        except:
            pass
        return None
            
    def shutdown(self):
        reply = QMessageBox.question(
            self, "Shutdown", 
            "Shutdown the system?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if reply == QMessageBox.StandardButton.Yes:
            subprocess.run(["systemctl", "poweroff"])
            
    def reboot(self):
        reply = QMessageBox.question(
            self, "Reboot",
            "Reboot the system?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if reply == QMessageBox.StandardButton.Yes:
            subprocess.run(["systemctl", "reboot"])


def main():
    app = QApplication(sys.argv)
    
    # Set application-wide font
    font = QFont("JetBrainsMono Nerd Font", 10)
    if not QFont(font).exactMatch():
        font = QFont("Noto Sans", 10)
    app.setFont(font)
    
    window = LoginWindow()
    window.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
PYTHON_EOF

chmod +x /usr/local/bin/custom-dm

# Create systemd service
echo -e "${GREEN}[*] Creating systemd service...${NC}"

cat > /etc/systemd/system/custom-dm.service << 'SERVICE_EOF'
[Unit]
Description=Custom Display Manager
After=systemd-user-sessions.service getty@tty1.service plymouth-quit.service systemd-logind.service
After=rc-local.service

[Service]
Type=simple
ExecStart=/usr/local/bin/custom-dm
Restart=always
RestartSec=2
StandardOutput=journal
StandardError=journal
Environment="QT_QPA_PLATFORM=xcb"
Environment="QT_AUTO_SCREEN_SCALE_FACTOR=0"

[Install]
WantedBy=graphical.target
SERVICE_EOF

# Backup SDDM config
echo -e "${GREEN}[*] Backing up SDDM config...${NC}"
if [ -f /etc/sddm.conf ]; then
    cp /etc/sddm.conf /etc/sddm.conf.backup.$(date +%Y%m%d) 2>/dev/null || true
fi

# Stop and disable SDDM
echo -e "${GREEN}[*] Disabling SDDM...${NC}"
systemctl stop sddm 2>/dev/null || true
systemctl disable sddm 2>/dev/null || true

# Enable custom DM
systemctl daemon-reload
systemctl enable custom-dm

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}To start now:${NC}"
echo "  sudo systemctl start custom-dm"
echo ""
echo -e "${BLUE}To check logs:${NC}"
echo "  sudo journalctl -u custom-dm -f"
echo ""
echo -e "${YELLOW}If something goes wrong:${NC}"
echo "  1. Switch to TTY: Ctrl+Alt+F2"
echo "  2. Login and run:"
echo "     sudo systemctl stop custom-dm"
echo "     sudo systemctl disable custom-dm"
echo "     sudo systemctl enable sddm"
echo "     sudo systemctl start sddm"
echo ""
echo -e "${GREEN}Custom DM will start on next boot!${NC}"
