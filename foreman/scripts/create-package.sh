#!/bin/bash

# Package Creation Script for Foreman 3.15 Offline Installation
# This script creates the final tar.gz package for distribution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"

# Package name
PACKAGE_NAME="foreman-3.15-offline-almalinux10"
PACKAGE_FILE="${PACKAGE_NAME}.tar.gz"

echo -e "${GREEN}Creating offline package: $PACKAGE_FILE${NC}"

# Check if RPMs directory exists
if [[ ! -d "$PACKAGE_DIR/RPMs" ]]; then
    echo -e "${RED}RPMs directory not found. Run download-packages.sh first.${NC}"
    exit 1
fi

# Create package
echo -e "${YELLOW}Creating tar.gz package...${NC}"
cd "$PACKAGE_DIR"
tar -czf "$PACKAGE_FILE" \
    --exclude="*.tar.gz" \
    --exclude=".git" \
    --exclude="*.log" \
    --exclude="*.tmp" \
    .

# Verify package
if [[ -f "$PACKAGE_FILE" ]]; then
    PACKAGE_SIZE=$(du -h "$PACKAGE_FILE" | cut -f1)
    echo -e "${GREEN}Package created successfully!${NC}"
    echo -e "${GREEN}Package file: $PACKAGE_FILE${NC}"
    echo -e "${GREEN}Package size: $PACKAGE_SIZE${NC}"
    echo -e "${GREEN}Package location: $PACKAGE_DIR/$PACKAGE_FILE${NC}"
    echo -e "${YELLOW}You can now transfer this package to your air-gapped machine.${NC}"
else
    echo -e "${RED}Failed to create package.${NC}"
    exit 1
fi
