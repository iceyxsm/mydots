# Custom Display Manager Ultimate Edition

A Python/Qt6-based display manager designed specifically for Hyprland with video wallpaper support, GPU optimization, and smooth animations.

## Why Custom DM?

| Feature | SDDM | Custom DM |
|---------|------|-----------|
| Fullscreen wallpaper | Black bars (aspect ratio) | True fullscreen stretch |
| Video wallpapers | Limited | MPV-powered (efficient) |
| GPU optimization | Generic | NVIDIA/AMD/Intel specific |
| Animations | Basic | Smooth fade effects |
| VM support | Sometimes broken | Optimized for VMware/VBox |
| Test mode | No | Yes (--test) |

## Features

- ✅ **True fullscreen wallpaper** (no black bars)
- ✅ **Video wallpaper support** via mpv (MP4, WebM)
- ✅ **GPU-optimized**: NVIDIA, AMD, Intel specific settings
- ✅ **Smooth animations**: Fade in effects
- ✅ **Rose Pine cyberpunk theme** (purple/pink/cyan)
- ✅ **PAM authentication** with session management
- ✅ **Multi-session support** (Hyprland, KDE, GNOME, Sway)
- ✅ **Test mode**: Preview without installing
- ✅ **VM support**: VMware, VirtualBox, QEMU

## Installation

### Standard Install
```bash
sudo ./install-custom-dm.sh
```

### Test Mode (Preview without installing)
```bash
sudo ./install-custom-dm.sh --test
```

### Lock Mode (Screen lock replacement)
```bash
sudo ./install-custom-dm.sh --lock
```

## Usage

Start the DM:
```bash
sudo systemctl start custom-dm
```

Check logs:
```bash
sudo journalctl -u custom-dm -f
```

Test without installing:
```bash
sudo ./install-custom-dm.sh --test
```

## Configuration

### Video Wallpapers (Auto-Detected)

Videos are **automatically detected** from the Google Drive downloaded wallpapers folder:

**Primary location (scanned automatically):**
- `~/.config/hypr/wallpapers/live-wallpapers/*.mp4`
- `~/.config/hypr/wallpapers/live-wallpapers/*.webm`

**Any video file** in the downloaded folder will be used as the login background!

**Fallback locations:**
- `~/.config/hypr/wallpapers/background.mp4`
- `/usr/share/sddm/themes/sddm-astronaut-theme/background.mp4`

**Supported formats:** MP4, WebM, MKV, MOV, AVI  
**Audio:** Automatically muted  
**Loop:** Infinite loop enabled  
**Decoder:** Hardware-accelerated (NVIDIA/AMD/Intel)

### Static Wallpapers (Fallback)
If no video is found, falls back to static images **from Google Drive downloads**:
- `~/.config/hypr/wallpapers/live-wallpapers/*.jpg` (auto-detected)
- `~/.config/hypr/wallpapers/live-wallpapers/*.png` (auto-detected)
- `/usr/share/sddm/themes/sddm-astronaut-theme/background.jpg`
- `~/.config/hypr/wallpapers/dark-theme/dark-wall1.jpg`

### Sessions
The DM reads available sessions from:
- `/usr/share/wayland-sessions`
- `/usr/share/xsessions`

Hyprland is automatically selected by default if available.

## Hardware Support

### NVIDIA GPUs
- Hardware video decoding via VDPAU
- Optimal mpv settings for NVIDIA

### AMD GPUs
- VA-API hardware acceleration
- RadeonSI driver optimization

### Intel GPUs
- VA-API with i965 driver
- Integrated graphics optimized

### Virtual Machines
- VMware SVGA support
- VirtualBox VMSVGA support
- QEMU virtio support
- Software rendering fallback

## Troubleshooting

### DM won't start
Check logs:
```bash
sudo journalctl -u custom-dm -n 100
```

### Video wallpaper not playing
1. Check mpv is installed: `which mpv`
2. Check video format: MP4 or WebM
3. Check logs for errors: `sudo journalctl -u custom-dm -f`

### Authentication fails
Ensure PAM is configured:
```bash
sudo pamac check
```

### Session doesn't start
1. Verify Hyprland binary exists: `which Hyprland`
2. Check session file: `cat /usr/share/wayland-sessions/hyprland.desktop`

### Back to SDDM
```bash
sudo systemctl stop custom-dm
sudo systemctl disable custom-dm
sudo systemctl enable sddm
sudo systemctl start sddm
```

## Technical Details

### Video Playback
Uses **mpv** for video wallpapers instead of Qt Multimedia:
- More efficient CPU/GPU usage
- Better format support
- Hardware decoding support
- Loop seamlessly

### GPU Detection
Automatically detects GPU type and sets optimal environment variables:
- NVIDIA: `VDPAU_DRIVER=nvidia`
- AMD: `LIBVA_DRIVER_NAME=radeonsi`
- Intel: `LIBVA_DRIVER_NAME=i965`

### Animations
Smooth fade-in animation for login panel using QPropertyAnimation.

### PAM Integration
- Uses `service="login"` for authentication
- Calls `pam.open_session()` on successful login
- Calls `pam.close_session()` on session exit

### Process Model
1. DM runs as root (systemd service)
2. User authenticates via PAM
3. Fork child process, drop privileges with `setgid/initgroups/setuid`
4. Child calls `setsid()` to create new session
5. Exec Hyprland with proper environment
6. Parent monitors PID, restarts DM when session exits

### Environment Variables Set
- `XDG_SESSION_TYPE=wayland`
- `XDG_CURRENT_DESKTOP=Hyprland`
- `XDG_SESSION_DESKTOP=Hyprland`
- `XDG_SEAT=seat0`
- `XDG_VTNR=1`
- `XDG_RUNTIME_DIR=/run/user/<uid>`
- `WAYLAND_DISPLAY=wayland-1`
- `MOZ_ENABLE_WAYLAND=1`
- `QT_QPA_PLATFORM=wayland`
- `LIBVA_DRIVER_NAME` (GPU-specific)
- `VDPAU_DRIVER` (GPU-specific)

## License

Same as the main mydots project.
