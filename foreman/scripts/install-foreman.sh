#!/bin/bash

# Foreman 3.15 Offline Installation Script for AlmaLinux 10
# This script installs Foreman using the local repositories

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

echo -e "${GREEN}Starting Foreman 3.15 offline installation...${NC}"

# Verify local repositories are available
if ! yum repolist | grep -q "foreman-offline"; then
    echo -e "${RED}Foreman offline repository not found. Run setup-local-repos.sh first.${NC}"
    exit 1
fi

# Install Foreman installer
echo -e "${YELLOW}Installing Foreman installer...${NC}"
dnf -y install foreman-installer

# Run Foreman installer
echo -e "${YELLOW}Running Foreman installer...${NC}"
echo -e "${YELLOW}This may take several minutes...${NC}"

# Run installer with non-interactive mode
foreman-installer --foreman-admin-password="$(openssl rand -base64 12)" \
                  --foreman-proxy-dhcp=true \
                  --foreman-proxy-dns=true \
                  --foreman-proxy-tftp=true \
                  --foreman-proxy-foreman-url="https://$(hostname -f)" \
                  --foreman-proxy-oauth-consumer-key="$(openssl rand -base64 32)" \
                  --foreman-proxy-oauth-consumer-secret="$(openssl rand -base64 32)"

echo -e "${GREEN}Foreman installation completed successfully!${NC}"
echo -e "${GREEN}Foreman is now running at: https://$(hostname -f)${NC}"
echo -e "${GREEN}Check the installer log for credentials and additional information.${NC}"
