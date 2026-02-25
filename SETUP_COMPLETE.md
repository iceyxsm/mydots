# Cyberpunk Hyprland Rice - Setup Complete

## What's Been Configured

### 1. Waybar (Status Bar)
**Location:** `.config/waybar/`
- **Purple/Pink cyberpunk theme** with gradient effects
- **System monitoring modules:** CPU, Memory, Disk, Network
- **Hover effects** with glowing shadows
- **Custom icons** for workspaces and system stats
- **Colors:** Rose Pine inspired (#c4a7e7, #eb6f92, #9ccfd8, #f6c177)

### 2. Kitty Terminal
**Location:** `.config/kitty/kitty.conf`
- **Cyberpunk color scheme** (Rose Pine based)
- **85% transparency** with blur effect
- **Purple/pink accents** throughout
- **Custom tab bar** with powerline style
- **Beam cursor** with blink animation

### 3. btop (System Monitor)
**Location:** `.config/btop/`
- **Custom cyberpunk theme** (`.config/btop/themes/cyberpunk.theme`)
- **Purple/pink gradient** for all graphs
- **Transparent background** for terminal integration
- **Braille graphs** for smooth visualization
- **Shows:** CPU, Memory, Network, Processes

### 4. Neofetch (System Info)
**Location:** `.config/neofetch/config.conf`
- **Purple/pink ASCII colors** (colors 5 and 7)
- **Kitty image backend** support
- **Displays:** OS, Kernel, CPU, GPU, Memory, Packages, etc.
- **Custom formatting** for cyberpunk aesthetic

### 5. Hyprland (Window Manager)
**Location:** `.config/hypr/hyprland.conf`
- **Purple/pink gradient borders** (#ff00ff → #bd93f9)
- **Smooth animations** with custom bezier curves
- **Blur effects** and rounded corners
- **Gap spacing** for clean layout
- **Auto-starts:** waybar, hyprpaper

### 6. Wallpapers
**Location:** `.config/hypr/wallpapers/`
- **live-wallpapers/** - Animated cyberpunk cityscapes (from Google Drive)
- **dark-theme/** - Static dark wallpapers
- **light-theme/** - Static light wallpapers
- **hyprpaper configured** to use live wallpapers

## 🚀 Installation

Run the install script:
```bash
chmod +x install.sh
./install.sh
```

### What the script does:
1. ✅ Backs up existing configs (timestamped)
2. ✅ Creates directory structure
3. ✅ Installs packages (btop, neofetch, kitty, waybar, etc.)
4. ✅ Downloads live wallpapers from Google Drive
5. ✅ Copies all config files
6. ✅ Sets up btop custom theme
7. ✅ Configures neofetch
8. ✅ **Fully dynamic** - uses `$HOME` and `$(whoami)`

## 🎨 Color Palette

```
Primary Purple:  #c4a7e7
Accent Pink:     #eb6f92
Cyan:            #9ccfd8
Yellow:          #f6c177
Peach:           #ebbcba
Background:      #191724
Foreground:      #e0def4
Muted:           #6e6a86
```

## 📦 Dependencies

All installed automatically by the script:
- hyprland
- hyprpaper
- waybar
- kitty
- btop
- neofetch
- wofi
- thunar
- python-pip (for gdown)

## 🎯 Features Matching Your Screenshots

### Screenshot 1: btop with purple/pink graphs ✅
- Custom cyberpunk theme with gradient colors
- Transparent background
- Braille graphs for smooth visualization

### Screenshot 2: Neofetch with custom colors ✅
- Purple/pink ASCII art
- System info display
- Kitty image backend support

### Screenshot 3: File manager with wallpapers ✅
- Wallpapers organized in folders
- Live wallpapers from Google Drive
- Static dark/light themes included

### Screenshot 4: Animated cyberpunk wallpaper ✅
- hyprpaper configured for live wallpapers
- Cyberpunk cityscape aesthetic
- Auto-downloaded from Google Drive

### Screenshot 5: Waybar with system stats ✅
- CPU, Memory, Disk monitoring
- Purple/pink theme
- Hover effects with glow

## 🔧 Post-Installation

After running the install script:

```bash
# Reload Hyprland
hyprctl reload

# Test btop
btop

# Test neofetch
neofetch

# Change wallpaper (edit this file)
nano ~/.config/hypr/hyprpaper.conf
```

## 📁 File Structure

```
.config/
├── hypr/
│   ├── hyprland.conf          # Main Hyprland config
│   ├── hyprpaper.conf         # Wallpaper config
│   └── wallpapers/
│       ├── live-wallpapers/   # Animated wallpapers
│       ├── dark-theme/        # Dark static wallpapers
│       └── light-theme/       # Light static wallpapers
├── waybar/
│   ├── config                 # Waybar modules
│   └── style.css              # Cyberpunk theme
├── kitty/
│   └── kitty.conf             # Terminal config
├── btop/
│   ├── btop.conf              # btop settings
│   └── themes/
│       └── cyberpunk.theme    # Custom theme
└── neofetch/
    └── config.conf            # Neofetch config
```

## ✨ Everything is Dynamic

- ✅ Username detection: `$(whoami)`
- ✅ Home directory: `$HOME`
- ✅ Timestamped backups
- ✅ Automatic package detection
- ✅ Error handling with fallbacks
- ✅ Works on any Arch-based system

## 🎉 You're All Set!

Your cyberpunk Hyprland rice is ready to go. Just run `./install.sh` and enjoy your purple/pink aesthetic setup!
