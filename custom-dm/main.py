#!/usr/bin/env python3
"""
Simple Custom Display Manager
Replaces SDDM with a minimal, fullscreen login
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
        
        # Fullscreen borderless
        self.showFullScreen()
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint
        )
        
        # Get screen size
        screen = QApplication.primaryScreen().geometry()
        self.screen_width = screen.width()
        self.screen_height = screen.height()
        
        self.setup_ui()
        self.load_sessions()
        self.load_wallpaper()
        
    def setup_ui(self):
        # Central widget with background
        self.central = QWidget()
        self.setCentralWidget(self.central)
        
        # Main layout - entire screen
        main_layout = QHBoxLayout(self.central)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        
        # Left side - Login form (400px wide)
        left_panel = QWidget()
        left_panel.setFixedWidth(400)
        left_panel.setStyleSheet("background-color: rgba(0, 0, 0, 180);")
        
        form_layout = QVBoxLayout(left_panel)
        form_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        form_layout.setSpacing(20)
        form_layout.setContentsMargins(40, 40, 40, 40)
        
        # Clock
        self.clock_label = QLabel()
        self.clock_label.setStyleSheet("color: white; font-size: 72px; font-weight: bold;")
        self.clock_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        form_layout.addWidget(self.clock_label)
        
        # Date
        self.date_label = QLabel()
        self.date_label.setStyleSheet("color: white; font-size: 20px;")
        self.date_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        form_layout.addWidget(self.date_label)
        
        # Spacer
        form_layout.addSpacing(50)
        
        # Username
        self.username_input = QLineEdit()
        self.username_input.setPlaceholderText("Username")
        self.username_input.setStyleSheet(self.input_style())
        self.username_input.setFont(QFont("Sans", 14))
        form_layout.addWidget(self.username_input)
        
        # Password
        self.password_input = QLineEdit()
        self.password_input.setPlaceholderText("Password")
        self.password_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.password_input.setStyleSheet(self.input_style())
        self.password_input.setFont(QFont("Sans", 14))
        form_layout.addWidget(self.password_input)
        
        # Session selector
        self.session_combo = QComboBox()
        self.session_combo.setStyleSheet(self.combo_style())
        self.session_combo.setFont(QFont("Sans", 12))
        form_layout.addWidget(self.session_combo)
        
        # Login button
        login_btn = QPushButton("Login")
        login_btn.setStyleSheet(self.button_style("#5e81ac"))
        login_btn.setFont(QFont("Sans", 14))
        login_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        login_btn.clicked.connect(self.do_login)
        form_layout.addWidget(login_btn)
        
        # Error label
        self.error_label = QLabel()
        self.error_label.setStyleSheet("color: #bf616a; font-size: 14px;")
        self.error_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        form_layout.addWidget(self.error_label)
        
        # Spacer
        form_layout.addStretch()
        
        # Power buttons
        power_layout = QHBoxLayout()
        
        shutdown_btn = QPushButton("Shutdown")
        shutdown_btn.setStyleSheet(self.button_style("#bf616a"))
        shutdown_btn.clicked.connect(self.shutdown)
        power_layout.addWidget(shutdown_btn)
        
        reboot_btn = QPushButton("Reboot")
        reboot_btn.setStyleSheet(self.button_style("#d08770"))
        reboot_btn.clicked.connect(self.reboot)
        power_layout.addWidget(reboot_btn)
        
        form_layout.addLayout(power_layout)
        
        # Add left panel to main layout
        main_layout.addWidget(left_panel)
        
        # Right side - empty (wallpaper shows through)
        right_spacer = QWidget()
        right_spacer.setStyleSheet("background: transparent;")
        main_layout.addWidget(right_spacer, stretch=1)
        
        # Start clock timer
        self.update_clock()
        timer = QTimer(self)
        timer.timeout.connect(self.update_clock)
        timer.start(1000)
        
        # Set focus to username
        self.username_input.setFocus()
        
    def input_style(self):
        return """
            QLineEdit {
                background-color: #333333;
                color: white;
                border: 2px solid transparent;
                border-radius: 5px;
                padding: 10px;
                font-size: 14px;
            }
            QLineEdit:focus {
                border: 2px solid #5e81ac;
            }
        """
    
    def combo_style(self):
        return """
            QComboBox {
                background-color: #333333;
                color: white;
                border-radius: 5px;
                padding: 10px;
                font-size: 12px;
            }
            QComboBox::drop-down {
                border: none;
            }
            QComboBox QAbstractItemView {
                background-color: #333333;
                color: white;
                selection-background-color: #5e81ac;
            }
        """
    
    def button_style(self, color):
        return f"""
            QPushButton {{
                background-color: {color};
                color: white;
                border: none;
                border-radius: 5px;
                padding: 12px;
                font-size: 14px;
                font-weight: bold;
            }}
            QPushButton:hover {{
                background-color: {color}aa;
            }}
            QPushButton:pressed {{
                background-color: {color}88;
            }}
        """
        
    def load_wallpaper(self):
        """Load wallpaper as window background"""
        wallpaper_paths = [
            "/usr/share/sddm/themes/sddm-astronaut-theme/background.jpg",
            os.path.expanduser("~/.config/hypr/wallpapers/dark-theme/dark-wall1.jpg"),
            "/usr/share/backgrounds/default.png",
        ]
        
        for path in wallpaper_paths:
            if os.path.exists(path):
                self.setStyleSheet(f"""
                    QMainWindow {{
                        background-image: url({path});
                        background-position: center;
                        background-repeat: no-repeat;
                        background-size: cover;
                    }}
                """)
                break
    
    def load_sessions(self):
        """Load available desktop sessions"""
        sessions = []
        session_dirs = [
            "/usr/share/xsessions",
            "/usr/share/wayland-sessions"
        ]
        
        for d in session_dirs:
            if os.path.isdir(d):
                for f in os.listdir(d):
                    if f.endswith(".desktop"):
                        name = f.replace(".desktop", "").title()
                        sessions.append((name, os.path.join(d, f)))
        
        if not sessions:
            sessions = [("Hyprland", "hyprland.desktop")]
            
        for name, path in sessions:
            self.session_combo.addItem(name, path)
            
    def update_clock(self):
        now = QDateTime.currentDateTime()
        self.clock_label.setText(now.toString("HH:mm"))
        self.date_label.setText(now.toString("dddd d MMMM"))
        
    def do_login(self):
        username = self.username_input.text()
        password = self.password_input.text()
        
        if not username or not password:
            self.error_label.setText("Please enter username and password")
            return
            
        # Authenticate using PAM
        p = pam.pam()
        if p.authenticate(username, password):
            self.error_label.setText("")
            self.start_session(username)
        else:
            self.error_label.setText("Invalid username or password")
            self.password_input.clear()
            self.password_input.setFocus()
            
    def start_session(self, username):
        """Start user session"""
        session = self.session_combo.currentData()
        
        # Get user info
        user_info = pwd.getpwnam(username)
        uid = user_info.pw_uid
        gid = user_info.pw_gid
        home = user_info.pw_dir
        
        # Set environment
        env = os.environ.copy()
        env["HOME"] = home
        env["USER"] = username
        env["LOGNAME"] = username
        env["SHELL"] = user_info.pw_shell
        env["XDG_SESSION_TYPE"] = "wayland"
        env["XDG_CURRENT_DESKTOP"] = "Hyprland"
        
        # Start session
        cmd = ["/usr/bin/Hyprland"]
        
        # Fork and start session
        pid = os.fork()
        if pid == 0:
            # Child process
            os.setgid(gid)
            os.setuid(uid)
            os.chdir(home)
            os.execve(cmd[0], cmd, env)
        else:
            # Parent - exit DM
            QApplication.quit()
            
    def shutdown(self):
        reply = QMessageBox.question(
            self, "Shutdown", 
            "Are you sure you want to shutdown?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if reply == QMessageBox.StandardButton.Yes:
            subprocess.run(["sudo", "systemctl", "poweroff"])
            
    def reboot(self):
        reply = QMessageBox.question(
            self, "Reboot",
            "Are you sure you want to reboot?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
        )
        if reply == QMessageBox.StandardButton.Yes:
            subprocess.run(["sudo", "systemctl", "reboot"])


def main():
    app = QApplication(sys.argv)
    
    # Set application font
    font = QFont("Noto Sans", 10)
    app.setFont(font)
    
    window = LoginWindow()
    window.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
