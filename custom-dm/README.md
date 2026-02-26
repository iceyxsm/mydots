# Custom Display Manager

A simple, custom-built display manager (login screen) to replace SDDM.

## Why?

- SDDM themes are complex and have fullscreen issues
- This is simple Python + Qt code - easy to modify
- Guaranteed fullscreen wallpaper support
- Left-aligned login form (cyberpunk style)

## Features

- ✅ Fullscreen wallpaper (stretches to fill screen)
- ✅ Left-aligned login form with clock
- ✅ PAM authentication (secure)
- ✅ Session selector (Hyprland, etc.)
- ✅ Shutdown/Reboot buttons
- ✅ Clean, modern UI

## Installation

```bash
cd ~/mydots/custom-dm
sudo ./install.sh
```

## How it works

1. **Qt6 Application** - Creates a fullscreen borderless window
2. **PAM Authentication** - Uses system PAM for secure login
3. **X11/Wayland Launch** - Starts Hyprland after successful login
4. **Systemd Service** - Runs as system service before graphical.target

## Files

| File | Purpose |
|------|---------|
| `main.py` | The display manager application |
| `custom-dm.service` | Systemd service file |
| `install.sh` | Installation script |

## Customization

Edit `main.py` to change:
- Colors (search for styleSheet)
- Font sizes
- Layout (move login form to right/center)
- Background image path

## Troubleshooting

If login fails:
```bash
# Check logs
journalctl -u custom-dm -f

# Switch back to SDDM
systemctl stop custom-dm
systemctl disable custom-dm
systemctl enable sddm
systemctl start sddm
```

## Requirements

- Python 3
- PyQt6
- python-pam
- Qt6 Base

## ⚠️ Warning

This is experimental! SDDM is more mature and feature-complete. Only use this if SDDM doesn't work for your use case.
