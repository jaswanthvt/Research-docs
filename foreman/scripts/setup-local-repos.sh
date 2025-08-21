#!/bin/bash

# Foreman 3.15 Offline Repository Setup Script for AlmaLinux 10
# This script creates local repositories from the offline RPM packages

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

echo -e "${GREEN}Setting up local repositories for Foreman 3.15 offline installation...${NC}"

# Install required tools
echo -e "${YELLOW}Installing required tools...${NC}"
dnf -y install createrepo_c yum-utils

# Create repository directories
REPO_BASE="/opt/foreman-offline-repos"
mkdir -p "$REPO_BASE"

# Setup Foreman repository
echo -e "${YELLOW}Setting up Foreman repository...${NC}"
FOREMAN_REPO="$REPO_BASE/foreman"
mkdir -p "$FOREMAN_REPO"
cp -r "$PACKAGE_DIR/RPMs/foreman"/* "$FOREMAN_REPO/"
createrepo_c "$FOREMAN_REPO"

# Setup Puppet repository
echo -e "${YELLOW}Setting up Puppet repository...${NC}"
PUPPET_REPO="$REPO_BASE/puppet"
mkdir -p "$PUPPET_REPO"
cp -r "$PACKAGE_DIR/RPMs/puppet"/* "$PUPPET_REPO/"
createrepo_c "$PUPPET_REPO"

# Setup EPEL repository (if available)
if [[ -d "$PACKAGE_DIR/RPMs/epel" ]]; then
    echo -e "${YELLOW}Setting up EPEL repository...${NC}"
    EPEL_REPO="$REPO_BASE/epel"
    mkdir -p "$EPEL_REPO"
    cp -r "$PACKAGE_DIR/RPMs/epel"/* "$EPEL_REPO/"
    createrepo_c "$EPEL_REPO"
fi

# Setup AlmaLinux Base repository
echo -e "${YELLOW}Setting up AlmaLinux Base repository...${NC}"
BASE_REPO="$REPO_BASE/almalinux-base"
mkdir -p "$BASE_REPO"
cp -r "$PACKAGE_DIR/RPMs/almalinux-base"/* "$BASE_REPO/"
createrepo_c "$BASE_REPO"

# Create repository configuration files
echo -e "${YELLOW}Creating repository configuration files...${NC}"

cat > /etc/yum.repos.d/foreman-offline.repo << EOF
[foreman-offline]
name=Foreman 3.15 Offline Repository
baseurl=file://$FOREMAN_REPO
enabled=1
gpgcheck=0
priority=1

[puppet-offline]
name=Puppet 8.x Offline Repository
baseurl=file://$PUPPET_REPO
enabled=1
gpgcheck=0
priority=1

[almalinux-base-offline]
name=AlmaLinux Base Offline Repository
baseurl=file://$BASE_REPO
enabled=1
gpgcheck=0
priority=1
EOF

if [[ -d "$PACKAGE_DIR/RPMs/epel" ]]; then
    cat >> /etc/yum.repos.d/foreman-offline.repo << EOF

[epel-offline]
name=EPEL Offline Repository
baseurl=file://$EPEL_REPO
enabled=1
gpgcheck=0
priority=1
EOF
fi

# Disable online repositories temporarily
echo -e "${YELLOW}Disabling online repositories...${NC}"
yum-config-manager --disable "*" > /dev/null 2>&1 || true

# Enable offline repositories
echo -e "${YELLOW}Enabling offline repositories...${NC}"
yum-config-manager --enable foreman-offline puppet-offline almalinux-base-offline
if [[ -d "$PACKAGE_DIR/RPMs/epel" ]]; then
    yum-config-manager --enable epel-offline
fi

# Clean yum cache
echo -e "${YELLOW}Cleaning yum cache...${NC}"
yum clean all

echo -e "${GREEN}Local repositories setup completed successfully!${NC}"
echo -e "${GREEN}Repository location: $REPO_BASE${NC}"
echo -e "${GREEN}Configuration file: /etc/yum.repos.d/foreman-offline.repo${NC}"
echo -e "${YELLOW}You can now proceed with the Foreman installation.${NC}"
