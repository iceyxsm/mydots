#!/usr/bin/env python3
"""
Custom Display Manager Ultimate Edition
- Fullscreen login for Hyprland
- Video wallpaper support via mpv
- GPU-optimized for NVIDIA/AMD/Intel
- Smooth animations
- Test mode support
"""

import sys
import os
import subprocess
import pwd
import fcntl
import termios
import signal
import json
import pam
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, 
    QHBoxLayout, QLineEdit, QPushButton, QLabel,
    QComboBox, QMessageBox, QGraphicsOpacityEffect
)
from PyQt6.QtCore import Qt, QTimer, QDateTime, QPropertyAnimation, QEasingCurve, QThread
from PyQt6.QtGui import QPixmap, QPalette, QColor, QFont, QPainter

# Python <3.13 compatibility for initgroups
if not hasattr(os, 'initgroups'):
    import ctypes
    import ctypes.util
    def initgroups(username, gid):
        libc = ctypes.CDLL(ctypes.util.find_library('c'), use_errno=True)
        libc.initgroups(username.encode('utf-8'), gid)
    os.initgroups = initgroups

# GPU Detection
GPU_TYPE = os.environ.get('CUSTOM_DM_GPU', 'unknown')
IS_VM = os.environ.get('CUSTOM_DM_VM', 'false').lower() == 'true'
TEST_MODE = os.environ.get('CUSTOM_DM_TEST', 'false').lower() == 'true'
LOCK_MODE = os.environ.get('CUSTOM_DM_LOCK', 'false').lower() == 'true'


class MpvVideoThread(QThread):
    """Thread to run mpv for video wallpapers"""
    def __init__(self, video_path, width, height):
        super().__init__()
        self.video_path = video_path
        self.width = width
        self.height = height
        self.process = None
        
    def run(self):
        # Build mpv command with optimal settings for DM background
        cmd = [
            'mpv',
            '--fs',  # Fullscreen
            '--loop-file=inf',  # Loop forever
            '--no-audio',  # No sound
            '--no-osc',  # No on-screen controls
            '--no-input-default-bindings',  # No key bindings
            '--hwdec=auto',  # Hardware decoding
            '--vo=gpu',  # GPU video output
            '--gpu-api=' + ('d3d11' if GPU_TYPE == 'nvidia' else 'opengl'),
            '--scale=ewa_lanczossharp',  # High quality scaling
            f'--geometry={self.width}x{self.height}',
            '--window-type=desktop',  # Treat as desktop window
            '--window-drag=no',
            '--cursor-autohide=no',
            '--force-window=immediate',
            '--x11-name=custom-dm-bg',  # Window name for finding it
            self.video_path
        ]
        
        # VM-specific optimizations
        if IS_VM:
            cmd.extend([
                '--hwdec=no',  # Software decoding for VMs
                '--vo=gpu',
                '--scale=bilinear',  # Faster scaling
            ])
        
        self.process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.process.wait()
    
    def stop(self):
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except:
                self.process.kill()


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
        
        self.session_pid = None
        self.pam_obj = None
        
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
        
        # Left side - Login panel with glass morphism effect
        self.left_panel = QWidget()
        self.left_panel.setFixedWidth(420)
        self.left_panel.setStyleSheet("""
            QWidget {
                background-color: rgba(25, 23, 36, 220);
                border-right: 1px solid rgba(196, 167, 231, 50);
            }
        """)
        
        # Add opacity effect for fade animation
        self.panel_opacity = QGraphicsOpacityEffect(self.left_panel)
        self.left_panel.setGraphicsEffect(self.panel_opacity)
        self.panel_opacity.setOpacity(0.0)  # Start invisible
        
        form_layout = QVBoxLayout(self.left_panel)
        form_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        form_layout.setSpacing(15)
        form_layout.setContentsMargins(30, 30, 30, 30)
        
        # Clock with cyberpunk glow
        self.clock_label = QLabel()
        self.clock_label.setStyleSheet("""
            QLabel {
                color: #e0def4;
                font-size: 80px;
                font-weight: bold;
                text-shadow: 0 0 20px rgba(196, 167, 231, 150);
            }
        """)
        self.clock_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        form_layout.addWidget(self.clock_label)
        
        # Date with accent color
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
        main_layout.addWidget(self.left_panel)
        
        # Fade in animation for panel
        self.fade_animation = QPropertyAnimation(self.panel_opacity, b"opacity")
        self.fade_animation.setDuration(800)
        self.fade_animation.setStartValue(0.0)
        self.fade_animation.setEndValue(1.0)
        self.fade_animation.setEasingCurve(QEasingCurve.Type.OutCubic)
        self.fade_animation.start()
        
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
        """Load wallpaper - searches downloaded Google Drive videos first"""
        self.video_thread = None
        
        # First, scan Google Drive downloaded wallpapers directory for videos
        gdrive_wallpaper_dir = os.path.expanduser("~/.config/hypr/wallpapers/live-wallpapers")
        if os.path.isdir(gdrive_wallpaper_dir):
            # Look for video files in the downloaded folder
            video_extensions = ('.mp4', '.webm', '.mkv', '.mov', '.avi')
            try:
                for filename in os.listdir(gdrive_wallpaper_dir):
                    if filename.lower().endswith(video_extensions):
                        video_path = os.path.join(gdrive_wallpaper_dir, filename)
                        print(f"Found Google Drive video wallpaper: {filename}")
                        self.setup_mpv_video(video_path)
                        return
            except Exception as e:
                print(f"Error scanning wallpaper dir: {e}")
        
        # Fallback to specific video paths
        video_paths = [
            os.path.expanduser("~/.config/hypr/wallpapers/live/login-video.mp4"),
            os.path.expanduser("~/.config/hypr/wallpapers/live/login-video.webm"),
            os.path.expanduser("~/.config/hypr/wallpapers/background.mp4"),
            os.path.expanduser("~/.config/hypr/wallpapers/background.webm"),
            "/usr/share/sddm/themes/sddm-astronaut-theme/background.mp4",
            "/usr/share/sddm/themes/sddm-astronaut-theme/background.webm",
            "/usr/share/backgrounds/login-video.mp4",
            "/usr/share/backgrounds/login-video.webm",
        ]
        
        # Static wallpaper paths (fallback) - also check Google Drive folder
        static_paths = []
        
        # First add any images from Google Drive folder
        if os.path.isdir(gdrive_wallpaper_dir):
            img_extensions = ('.jpg', '.jpeg', '.png', '.webp', '.gif')
            try:
                for filename in sorted(os.listdir(gdrive_wallpaper_dir)):
                    if filename.lower().endswith(img_extensions):
                        static_paths.append(os.path.join(gdrive_wallpaper_dir, filename))
            except Exception as e:
                print(f"Error scanning for images: {e}")
        
        # Add fallback paths
        static_paths.extend([
            "/usr/share/sddm/themes/sddm-astronaut-theme/background.jpg",
            "/usr/share/sddm/themes/sddm-astronaut-theme/background.png",
            os.path.expanduser("~/.config/hypr/wallpapers/dark-theme/dark-wall1.jpg"),
            os.path.expanduser("~/.config/hypr/wallpapers/dark-theme/dark-wall2.jpg"),
            os.path.expanduser("~/.config/hypr/wallpapers/light-theme/light-wall1.jpg"),
            os.path.expanduser("~/.config/hypr/wallpapers/background.jpg"),
            os.path.expanduser("~/.config/hypr/wallpapers/background.png"),
            "/usr/share/backgrounds/default.png",
            "/usr/share/backgrounds/default.jpg",
            "/usr/share/pixmaps/background.png",
        ])
        
        # Check for video first (using mpv)
        for path in video_paths:
            if os.path.exists(path):
                print(f"Found video wallpaper: {path}")
                self.setup_mpv_video(path)
                return
        
        # Fall back to static image
        wallpaper = None
        for path in static_paths:
            if os.path.exists(path):
                wallpaper = path
                print(f"Found static wallpaper: {path}")
                break
        
        if wallpaper:
            self.setup_static_wallpaper(wallpaper)
        else:
            # Fallback to gradient background
            self.setStyleSheet("""
                QMainWindow {
                    background: qlineargradient(
                        x1: 0, y1: 0, x2: 1, y2: 1,
                        stop: 0 #191724,
                        stop: 0.5 #1f1d2e,
                        stop: 1 #26233a
                    );
                }
            """)
    
    def setup_mpv_video(self, video_path):
        """Setup video wallpaper using mpv (most efficient)"""
        try:
            self.video_thread = MpvVideoThread(video_path, self.screen_width, self.screen_height)
            self.video_thread.start()
            print(f"Video wallpaper started with mpv: {video_path}")
        except Exception as e:
            print(f"Failed to start mpv video: {e}")
            self.load_static_fallback()
    
    def setup_static_wallpaper(self, wallpaper_path):
        """Setup static image wallpaper with smooth scaling"""
        # Set as palette for smooth scaling
        palette = self.palette()
        pixmap = QPixmap(wallpaper_path)
        scaled_pixmap = pixmap.scaled(
            self.screen_width, self.screen_height,
            Qt.AspectRatioMode.IgnoreAspectRatio,
            Qt.TransformationMode.SmoothTransformation
        )
        palette.setBrush(QPalette.ColorRole.Window, scaled_pixmap)
        self.setPalette(palette)
        self.setAutoFillBackground(True)
    
    def load_static_fallback(self):
        """Load static wallpaper as fallback"""
        static_paths = [
            "/usr/share/sddm/themes/sddm-astronaut-theme/background.jpg",
            os.path.expanduser("~/.config/hypr/wallpapers/dark-theme/dark-wall1.jpg"),
            os.path.expanduser("~/.config/hypr/wallpapers/background.jpg"),
        ]
        for path in static_paths:
            if os.path.exists(path):
                self.setup_static_wallpaper(path)
                return
        # Gradient fallback
        self.setStyleSheet("""
            QMainWindow {
                background: qlineargradient(
                    x1: 0, y1: 0, x2: 1, y2: 1,
                    stop: 0 #191724,
                    stop: 0.5 #1f1d2e,
                    stop: 1 #26233a
                );
            }
        """)
            
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
            
        # Authenticate with PAM
        p = pam.pam()
        if p.authenticate(username, password, service="login"):
            # Open PAM session (required for proper session setup)
            if p.open_session():
                self.error_label.setText("")
                self.error_label.setStyleSheet("color: #9ccfd8; font-size: 14px;")
                self.error_label.setText("Success! Starting session...")
                self.pam_obj = p
                self.start_session(username)
            else:
                self.error_label.setStyleSheet("color: #eb6f92; font-size: 14px;")
                self.error_label.setText("Failed to open session")
                self.password_input.clear()
                self.password_input.setFocus()
        else:
            self.error_label.setStyleSheet("color: #eb6f92; font-size: 14px;")
            self.error_label.setText("Invalid username or password")
            self.password_input.clear()
            self.password_input.setFocus()
            
    def start_session(self, username):
        """Start the user session with proper PAM integration"""
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
            desktop_name = "Hyprland"
        elif "plasma" in session_name or "kde" in session_name:
            cmd = "/usr/bin/startplasma-wayland"
            session_type = "wayland"
            desktop_name = "KDE"
        elif "gnome" in session_name:
            cmd = "/usr/bin/gnome-session"
            session_type = "wayland"
            desktop_name = "GNOME"
        elif "sway" in session_name:
            cmd = "/usr/bin/sway"
            session_type = "wayland"
            desktop_name = "sway"
        else:
            # Try to read from desktop file
            cmd = self.get_exec_from_desktop(session_path) or "/usr/bin/Hyprland"
            session_type = "wayland"
            desktop_name = session_name.title()
        
        # Create XDG_RUNTIME_DIR
        runtime_dir = f"/run/user/{uid}"
        os.makedirs(runtime_dir, exist_ok=True)
        os.chown(runtime_dir, uid, gid)
        os.chmod(runtime_dir, 0o700)
        
        # Build environment
        env = os.environ.copy()
        env["HOME"] = home
        env["USER"] = username
        env["LOGNAME"] = username
        env["SHELL"] = shell
        env["UID"] = str(uid)
        env["XDG_SESSION_TYPE"] = session_type
        env["XDG_CURRENT_DESKTOP"] = desktop_name
        env["XDG_SESSION_DESKTOP"] = desktop_name
        env["XDG_SEAT"] = "seat0"
        env["XDG_VTNR"] = "1"
        env["XDG_RUNTIME_DIR"] = runtime_dir
        env["WAYLAND_DISPLAY"] = "wayland-1"
        env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin"
        env["MOZ_ENABLE_WAYLAND"] = "1"
        env["QT_QPA_PLATFORM"] = "wayland"
        env["QT_WAYLAND_DISABLE_WINDOWDECORATION"] = "1"
        env["SDL_VIDEODRIVER"] = "wayland"
        env["_JAVA_AWT_WM_NONREPARENTING"] = "1"
        env["DISPLAY"] = ":0"
        
        print(f"Executing: {cmd}")
        print(f"Environment: XDG_SESSION_TYPE={session_type}, XDG_CURRENT_DESKTOP={desktop_name}")
        
        # Fork and start session
        pid = os.fork()
        if pid == 0:
            # Child process - create new session, drop privileges and exec
            try:
                # Create new session and process group
                os.setsid()
                
                # Set controlling terminal (for TTY1)
                try:
                    tty_fd = os.open("/dev/tty1", os.O_RDWR)
                    fcntl.ioctl(tty_fd, termios.TIOCSCTTY, 0)
                    os.close(tty_fd)
                except Exception as e:
                    print(f"Warning: Could not set controlling terminal: {e}")
                
                # Drop privileges
                os.setgid(gid)
                os.initgroups(username, gid)
                os.setuid(uid)
                os.chdir(home)
                
                # Clear environment and set new one
                os.environ.clear()
                for key, val in env.items():
                    if val is not None:
                        os.environ[key] = str(val)
                
                # Exec the session
                os.execv(cmd, [cmd])
            except Exception as e:
                print(f"Failed to start session: {e}")
                import traceback
                traceback.print_exc()
                sys.exit(1)
        else:
            # Parent - store PID and wait for session to take over
            self.session_pid = pid
            print(f"Session started with PID {pid}")
            
            # Hide the login window immediately
            self.hide()
            
            # Wait for session to exit
            QTimer.singleShot(100, lambda: self.monitor_session(pid))
    
    def monitor_session(self, pid):
        """Monitor session process and restart DM when it exits"""
        try:
            # Check if process is still running
            os.kill(pid, 0)  # Signal 0 just checks if process exists
            # Still running, check again in 500ms
            QTimer.singleShot(500, lambda: self.monitor_session(pid))
        except OSError:
            # Process has exited
            print(f"Session {pid} has exited")
            self.handle_session_exit()
    
    def handle_session_exit(self):
        """Handle session exit - restart DM after delay"""
        print("Session handler called - restarting DM in 2 seconds")
        
        # Close PAM session if open
        if self.pam_obj:
            try:
                self.pam_obj.close_session()
                print("PAM session closed")
            except Exception as e:
                print(f"Error closing PAM session: {e}")
            self.pam_obj = None
        
        QTimer.singleShot(2000, QApplication.quit)
            
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
    
    # Set app properties
    app.setApplicationName("custom-dm")
    app.setApplicationDisplayName("Custom Display Manager")
    
    window = LoginWindow()
    window.show()
    
    # Store app reference for session exit handling
    window.app = app
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
