# Experimental / WIP Features

This folder contains experimental or work-in-progress features that are not part of the main installation.

## Contents

### Custom Display Manager (custom-dm/)
A Python/Qt6-based display manager with video wallpaper support. 

**Status:** Experimental - Has issues with sudo/PAM configuration
**Location:** `custom-dm/`
**Files:**
- `install-custom-dm.sh` - Installation script
- `custom-dm/` - Source code and service files

**Known Issues:**
- Can cause sudo authentication issues if not configured properly
- Requires manual PAM/sudoers configuration
- Video wallpapers need mpv

**To use (advanced users only):**
```bash
cd experimental
sudo bash install-custom-dm.sh
```

**To revert to SDDM:**
```bash
sudo systemctl stop custom-dm
sudo systemctl disable custom-dm
sudo systemctl enable sddm
sudo systemctl start sddm
```

## Main Installation

For the stable installation using SDDM, use the main `install.sh` in the repository root.
