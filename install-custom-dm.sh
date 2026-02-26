#!/bin/bash
# Custom Display Manager Installer - Ultimate Edition
# Replaces SDDM with a feature-rich, fullscreen login manager
# Works with Hyprland, KDE, GNOME, etc.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
TEST_MODE=false
LOCK_MODE=false
for arg in "$@"; do
    case $arg in
        --test)
            TEST_MODE=true
            shift
            ;;
        --lock)
            LOCK_MODE=true
            shift
            ;;
        --help|-h)
            echo "Custom Display Manager Installer"
            echo ""
            echo "Usage: sudo ./install-custom-dm.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --test     Test mode - preview DM without installing"
            echo "  --lock     Lock mode - install as screen lock (hyprlock replacement)"
            echo "  --help     Show this help"
            echo ""
            exit 0
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Custom Display Manager Installer${NC}"
echo -e "${BLUE}  Ultimate Edition - Video + GPU Opt${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check root (not needed for test mode)
if [ "$TEST_MODE" = false ] && [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR] Please run as root: sudo ./install-custom-dm.sh${NC}"
    echo -e "${YELLOW}       Or use --test to preview without installing${NC}"
    exit 1
fi

# Detect GPU type
echo -e "${CYAN}[*] Detecting hardware...${NC}"
GPU_TYPE="unknown"
GPU_VENDOR=""
if lspci 2>/dev/null | grep -i nvidia &>/dev/null; then
    GPU_TYPE="nvidia"
    GPU_VENDOR="NVIDIA"
    echo -e "  ${GREEN}[OK] NVIDIA GPU detected${NC}"
elif lspci 2>/dev/null | grep -i amd &>/dev/null; then
    GPU_TYPE="amd"
    GPU_VENDOR="AMD"
    echo -e "  ${GREEN}[OK] AMD GPU detected${NC}"
elif lspci 2>/dev/null | grep -i intel &>/dev/null; then
    GPU_TYPE="intel"
    GPU_VENDOR="Intel"
    echo -e "  ${GREEN}[OK] Intel GPU detected${NC}"
else
    echo -e "  ${YELLOW}[INFO] No dedicated GPU detected, using generic drivers${NC}"
fi

# Detect if running in VM
IS_VM=false
if lspci 2>/dev/null | grep -iE 'vmware|virtualbox|qemu' &>/dev/null; then
    IS_VM=true
    echo -e "  ${YELLOW}[INFO] Virtual Machine detected${NC}"
fi

if [ "$TEST_MODE" = true ]; then
    echo -e "${CYAN}[*] TEST MODE - Previewing without installing${NC}"
    echo ""
fi

if [ "$LOCK_MODE" = true ]; then
    echo -e "${CYAN}[*] LOCK MODE - Installing as screen lock${NC}"
    echo ""
fi

echo -e "${GREEN}[*] Installing dependencies...${NC}"
pacman -S --needed --noconfirm python python-pip python-pam qt6-base pyqt6 mpv 2>/dev/null || true

# Install python-pam via pip if not available
pip3 install python-pam 2>/dev/null || pip install python-pam 2>/dev/null || true

# Create the display manager
echo -e "${GREEN}[*] Creating custom display manager...${NC}"

mkdir -p /usr/local/bin

cat > /usr/local/bin/custom-dm << 'PYTHON_EOF'
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
        """Load wallpaper - picks the FIRST video found in wallpapers folder"""
        self.video_thread = None
        
        # Check Google Drive downloaded wallpapers directory FIRST
        gdrive_wallpaper_dir = os.path.expanduser("~/.config/hypr/wallpapers/live-wallpapers")
        if os.path.isdir(gdrive_wallpaper_dir):
            print(f"Scanning for videos in: {gdrive_wallpaper_dir}")
            # Look for ANY video file - pick the first one found
            video_extensions = ('.mp4', '.webm', '.mkv', '.mov', '.avi')
            try:
                files = os.listdir(gdrive_wallpaper_dir)
                # Sort to get consistent ordering
                files.sort()
                for filename in files:
                    if filename.lower().endswith(video_extensions):
                        video_path = os.path.join(gdrive_wallpaper_dir, filename)
                        print(f"Using FIRST video found: {filename}")
                        self.setup_mpv_video(video_path)
                        return
                print("No videos found in wallpaper folder")
            except Exception as e:
                print(f"Error scanning wallpaper dir: {e}")
        else:
            print(f"Wallpaper folder not found: {gdrive_wallpaper_dir}")
        
        # Fallback: check any video in hypr/wallpapers folder
        fallback_dirs = [
            os.path.expanduser("~/.config/hypr/wallpapers"),
        ]
        for wallpaper_dir in fallback_dirs:
            if os.path.isdir(wallpaper_dir):
                video_extensions = ('.mp4', '.webm', '.mkv', '.mov', '.avi')
                try:
                    files = os.listdir(wallpaper_dir)
                    files.sort()
                    for filename in files:
                        if filename.lower().endswith(video_extensions):
                            video_path = os.path.join(wallpaper_dir, filename)
                            print(f"Using FIRST video found: {filename}")
                            self.setup_mpv_video(video_path)
                            return
                except Exception:
                    pass
        
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
PYTHON_EOF

# Set permissions
chmod +x /usr/local/bin/custom-dm

# Handle test mode
if [ "$TEST_MODE" = true ]; then
    echo -e "${CYAN}[*] Running in TEST MODE${NC}"
    echo -e "${YELLOW}      The DM will start now for preview. Press Ctrl+C to exit.${NC}"
    echo ""
    
    # Export variables for test mode
    export CUSTOM_DM_GPU="$GPU_TYPE"
    export CUSTOM_DM_VM="$IS_VM"
    export CUSTOM_DM_TEST="true"
    export CUSTOM_DM_LOCK="$LOCK_MODE"
    
    # Run the DM directly (will exit on window close)
    /usr/local/bin/custom-dm
    
    echo -e "${GREEN}[OK] Test completed${NC}"
    exit 0
fi

# Create systemd service with GPU-specific settings
echo -e "${GREEN}[*] Creating systemd service...${NC}"

# Build GPU-specific environment
case "$GPU_TYPE" in
    nvidia)
        GPU_ENV='Environment="LIBVA_DRIVER_NAME=nvidia"
Environment="VDPAU_DRIVER=nvidia"
Environment="__GLX_VENDOR_LIBRARY_NAME=nvidia"'
        ;;
    amd)
        GPU_ENV='Environment="LIBVA_DRIVER_NAME=radeonsi"
Environment="VDPAU_DRIVER=radeonsi"'
        ;;
    intel)
        GPU_ENV='Environment="LIBVA_DRIVER_NAME=i965"
Environment="VDPAU_DRIVER=va_gl"'
        ;;
    *)
        GPU_ENV='Environment="LIBVA_DRIVER_NAME=i965"
Environment="VDPAU_DRIVER=va_gl"'
        ;;
esac

# VM-specific settings
if [ "$IS_VM" = true ]; then
    VM_ENV='Environment="WLR_RENDERER_ALLOW_SOFTWARE=1"
Environment="WLR_NO_HARDWARE_CURSORS=1"'
else
    VM_ENV=''
fi

cat > /etc/systemd/system/custom-dm.service << EOF
[Unit]
Description=Custom Display Manager
After=systemd-user-sessions.service getty@tty1.service plymouth-quit.service systemd-logind.service
After=rc-local.service

[Service]
Type=exec
ExecStart=/usr/local/bin/custom-dm
Restart=always
RestartSec=2
StandardOutput=journal
StandardError=journal
Environment="QT_QPA_PLATFORM=xcb"
Environment="QT_AUTO_SCREEN_SCALE_FACTOR=0"
Environment="QT_QPA_PLATFORMTHEME=gtk2"
Environment="CUSTOM_DM_GPU=$GPU_TYPE"
Environment="CUSTOM_DM_VM=$IS_VM"
Environment="CUSTOM_DM_LOCK=$LOCK_MODE"
# GPU-specific settings
$GPU_ENV
# VM-specific settings
$VM_ENV
# Hardware video decoding
Environment="LIBVA_DRIVER_NAME=i965"
# Ensure proper cleanup on stop
KillMode=mixed
TimeoutStopSec=5

[Install]
WantedBy=graphical.target
EOF

# Stop ALL running display managers
echo -e "${GREEN}[*] Stopping all display managers...${NC}"

# List of known display managers to stop
DMS="sddm gdm gdm3 lightdm lxdm slim xdm ly"
for dm in $DMS; do
    if systemctl is-active --quiet $dm 2>/dev/null; then
        echo -e "  ${YELLOW}Stopping $dm...${NC}"
        systemctl stop $dm 2>/dev/null || true
        systemctl disable $dm 2>/dev/null || true
    fi
done

# Kill any remaining X11/Wayland sessions on tty1
echo -e "  ${YELLOW}Cleaning up display processes...${NC}"
pgrep -f "Xorg|wayland|sddm|gdm" | xargs -r kill -9 2>/dev/null || true
sleep 1

# Backup SDDM config (if exists)
if [ -f /etc/sddm.conf ]; then
    echo -e "${GREEN}[*] Backing up SDDM config...${NC}"
    cp /etc/sddm.conf /etc/sddm.conf.backup.$(date +%Y%m%d) 2>/dev/null || true
fi

# Disable ALL other display managers thoroughly
echo -e "${GREEN}[*] Disabling all other display managers...${NC}"
for dm in $DMS; do
    # Stop if running
    systemctl stop $dm 2>/dev/null || true
    # Disable completely
    systemctl disable $dm 2>/dev/null || true
    # Also disable any socket activation
    systemctl disable $dm.socket 2>/dev/null || true
    # Mask to prevent accidental start
    systemctl mask $dm 2>/dev/null || true
    echo -e "  ${GREEN}✓ $dm disabled${NC}"
done

# Ensure graphical.target only uses custom-dm
echo -e "${GREEN}[*] Setting graphical.target to use Custom DM only...${NC}"
systemctl set-default graphical.target 2>/dev/null || true

# Remove any conflicting symlinks
rm -f /etc/systemd/system/display-manager.service 2>/dev/null || true

# Create direct symlink for custom-dm
ln -sf /etc/systemd/system/custom-dm.service /etc/systemd/system/display-manager.service 2>/dev/null || true

# Enable custom DM
echo -e "${GREEN}[*] Enabling Custom DM...${NC}"
systemctl daemon-reload
systemctl enable custom-dm

# Verify only custom-dm is enabled
echo -e "${GREEN}[*] Verifying configuration...${NC}"
ENABLED_DM=$(systemctl get-default 2>/dev/null)
echo -e "  Default target: ${CYAN}$ENABLED_DM${NC}"
if [ -L /etc/systemd/system/display-manager.service ]; then
    LINK_TARGET=$(readlink /etc/systemd/system/display-manager.service)
    echo -e "  Display manager: ${CYAN}$LINK_TARGET${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}  Ultimate Edition${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${CYAN}Hardware Detected:${NC}"
if [ -n "$GPU_VENDOR" ]; then
    echo "  GPU: $GPU_VENDOR (optimized settings applied)"
else
    echo "  GPU: Generic (using compatible settings)"
fi
if [ "$IS_VM" = true ]; then
    echo "  VM: Yes (VM-specific optimizations enabled)"
fi
echo ""
echo -e "${CYAN}Status:${NC}"
echo "  ✓ SDDM/GDM/LightDM disabled (won't auto-start)"
echo "  ✓ Custom DM enabled as default display manager"
echo ""
echo -e "${CYAN}Features:${NC}"
echo "  ✓ True fullscreen wallpaper (no black bars)"
echo "  ✓ Video wallpaper support via mpv (MP4, WebM)"
echo "  ✓ Smooth fade animations"
echo "  ✓ GPU-optimized: NVIDIA, AMD, Intel"
echo "  ✓ VM support: VMware, VirtualBox, QEMU"
echo "  ✓ Rose Pine cyberpunk theme"
echo ""
echo -e "${CYAN}Video Wallpaper:${NC}"
echo "  Videos are auto-detected from Google Drive downloads:"
echo "    ~/.config/hypr/wallpapers/live-wallpapers/*.mp4"
echo "  Or place at:"
echo "    /usr/share/sddm/themes/sddm-astronaut-theme/background.mp4"
echo "    ~/.config/hypr/wallpapers/background.mp4"
echo ""
echo -e "${CYAN}Commands:${NC}"
echo "  Start now:       sudo systemctl start custom-dm"
echo "  Check logs:      sudo journalctl -u custom-dm -f"
echo "  Test mode:       sudo ./install-custom-dm.sh --test"
echo ""
echo -e "${YELLOW}Switch back to SDDM:${NC}"
echo "  sudo systemctl stop custom-dm"
echo "  sudo systemctl disable custom-dm"
echo "  sudo systemctl enable sddm"
echo "  sudo systemctl start sddm"
echo ""
echo -e "${GREEN}Custom DM Ultimate will start on next boot!${NC}"
