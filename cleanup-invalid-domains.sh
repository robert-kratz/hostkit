#!/bin/bash

# cleanup-invalid-domains.sh
# Cleanup script for invalid domain directories with ANSI codes
#
# Copyright (c) 2025 Robert Julian Kratz
# Licensed under the MIT License

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

WEB_ROOT="/opt/domains"

echo -e "${WHITE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${WHITE}║  HostKit - Cleanup Invalid Domain Directories            ║${NC}"
echo -e "${WHITE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ ! -d "$WEB_ROOT" ]; then
    echo -e "${RED}✗ Directory $WEB_ROOT not found${NC}"
    exit 1
fi

echo -e "${YELLOW}⚠ This will remove directories with invalid names (containing ANSI codes)${NC}"
echo ""

# Find directories with ANSI escape codes or invalid characters
invalid_dirs=()

cd "$WEB_ROOT" || exit 1

for dir in *; do
    if [ ! -d "$dir" ]; then
        continue
    fi
    
    # Check for ANSI escape sequences (ESC [ followed by codes)
    if [[ "$dir" =~ $'\033' ]] || [[ "$dir" =~ '\[' ]]; then
        invalid_dirs+=("$dir")
        echo -e "${RED}✗ Invalid: $dir${NC}"
    fi
done

if [ ${#invalid_dirs[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ No invalid directories found${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Found ${#invalid_dirs[@]} invalid director(ies)${NC}"
echo ""
read -p "Do you want to remove these directories? [y/N]: " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}Removing invalid directories...${NC}"

for dir in "${invalid_dirs[@]}"; do
    echo -e "${CYAN}Removing: $dir${NC}"
    
    # Use rm with -rf and quote the directory name
    if rm -rf "$WEB_ROOT/$dir" 2>/dev/null; then
        echo -e "${GREEN}  ✓ Removed${NC}"
    else
        # Try with sudo if first attempt fails
        if sudo rm -rf "$WEB_ROOT/$dir" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Removed (with sudo)${NC}"
        else
            echo -e "${RED}  ✗ Failed to remove${NC}"
            echo -e "${YELLOW}  Try manually: sudo rm -rf \"$WEB_ROOT/$dir\"${NC}"
        fi
    fi
done

echo ""
echo -e "${GREEN}✓ Cleanup completed${NC}"
echo ""
echo -e "${CYAN}Remaining domains:${NC}"
ls -la "$WEB_ROOT" | grep "^d" | grep -v "^\.$" | grep -v "^\.\.$" | awk '{print "  " $9}'
echo ""
