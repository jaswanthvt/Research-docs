#!/bin/bash

# Package Download Script for Foreman 3.15 Offline Installation
# Run this on an internet-connected machine to download all required packages

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}Downloading packages for Foreman 3.15 offline installation...${NC}"

# Create directories
mkdir -p "$PACKAGE_DIR/RPMs/foreman"
mkdir -p "$PACKAGE_DIR/RPMs/puppet"
mkdir -p "$PACKAGE_DIR/RPMs/epel"
mkdir -p "$PACKAGE_DIR/RPMs/almalinux-base"

# Enable repositories
echo -e "${YELLOW}Enabling required repositories...${NC}"

# Enable Puppet 8.x repository
dnf -y install https://yum.puppet.com/puppet8-release-el-9.noarch.rpm

# Enable Foreman repositories
dnf -y install https://yum.theforeman.org/releases/3.15/el9/x86_64/foreman-release.rpm

# Enable EPEL
dnf -y install epel-release

# Download Foreman packages
echo -e "${YELLOW}Downloading Foreman packages...${NC}"
dnf download --resolve --alldeps --destdir="$PACKAGE_DIR/RPMs/foreman" \
    foreman-installer foreman foreman-proxy foreman-proxy-dns \
    foreman-proxy-dhcp foreman-proxy-tftp

# Download Puppet packages
echo -e "${YELLOW}Downloading Puppet packages...${NC}"
dnf download --resolve --alldeps --destdir="$PACKAGE_DIR/RPMs/puppet" \
    puppet-server puppet-agent puppet

# Download EPEL packages
echo -e "${YELLOW}Downloading EPEL packages...${NC}"
dnf download --resolve --alldeps --destdir="$PACKAGE_DIR/RPMs/epel" \
    createrepo_c yum-utils

# Download AlmaLinux base packages
echo -e "${YELLOW}Downloading AlmaLinux base packages...${NC}"
dnf download --resolve --alldeps --destdir="$PACKAGE_DIR/RPMs/almalinux-base" \
    ruby rubygems rubygem-bundler mariadb mariadb-server \
    postgresql postgresql-server httpd mod_ssl

echo -e "${GREEN}Package download completed!${NC}"
echo -e "${GREEN}Packages are available in: $PACKAGE_DIR/RPMs/${NC}"
echo -e "${YELLOW}You can now create the offline package tar file.${NC}"
