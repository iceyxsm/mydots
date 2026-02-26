#!/bin/bash
# Emergency disk cleanup script for Arch Linux

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}=== EMERGENCY DISK CLEANUP ===${NC}"
echo ""

# Show current disk usage
echo -e "${YELLOW}Current disk usage:${NC}"
df -h /
echo ""

# 1. Clean pacman cache (keeps only latest version)
echo -e "${YELLOW}Cleaning pacman cache...${NC}"
sudo paccache -rk1 2>/dev/null || sudo rm -rf /var/cache/pacman/pkg/*
echo -e "${GREEN}✓ Pacman cache cleaned${NC}"
echo ""

# 2. Remove orphaned packages
echo -e "${YELLOW}Removing orphaned packages...${NC}"
orphans=$(pacman -Qdtq 2>/dev/null)
if [ -n "$orphans" ]; then
    echo "$orphans" | sudo pacman -Rns --noconfirm - 2>/dev/null
    echo -e "${GREEN}✓ Orphans removed${NC}"
else
    echo -e "${GREEN}✓ No orphans found${NC}"
fi
echo ""

# 3. Clean yay cache
echo -e "${YELLOW}Cleaning yay cache...${NC}"
rm -rf ~/.cache/yay/* 2>/dev/null
rm -rf /tmp/yay-* 2>/dev/null
echo -e "${GREEN}✓ Yay cache cleaned${NC}"
echo ""

# 4. Clean /tmp
echo -e "${YELLOW}Cleaning /tmp...${NC}"
sudo rm -rf /tmp/* 2>/dev/null
sudo rm -rf /var/tmp/* 2>/dev/null
echo -e "${GREEN}✓ /tmp cleaned${NC}"
echo ""

# 5. Clean user caches
echo -e "${YELLOW}Cleaning user caches...${NC}"
rm -rf ~/.cache/* 2>/dev/null
rm -rf ~/.local/share/Trash/* 2>/dev/null
echo -e "${GREEN}✓ User caches cleaned${NC}"
echo ""

# 6. Clean old logs
echo -e "${YELLOW}Cleaning old logs...${NC}"
sudo journalctl --vacuum-time=7d 2>/dev/null
sudo find /var/log -name "*.log" -type f -mtime +7 -delete 2>/dev/null
echo -e "${GREEN}✓ Old logs cleaned${NC}"
echo ""

# 7. Show what's using space (top 20)
echo -e "${YELLOW}Largest directories (may take a moment)...${NC}"
sudo du -h / 2>/dev/null | sort -rh | head -20
echo ""

# Final disk usage
echo -e "${GREEN}=== CLEANUP COMPLETE ===${NC}"
echo -e "${YELLOW}Disk usage after cleanup:${NC}"
df -h /
