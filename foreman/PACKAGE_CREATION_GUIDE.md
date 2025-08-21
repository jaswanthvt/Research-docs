# Foreman 3.15 Offline Package Creation and Usage Guide

This guide explains how to create and use the offline Foreman 3.15 package for AlmaLinux 10 air-gapped deployments.

## Overview

The offline package contains all necessary components to install Foreman 3.15 without internet access:
- **Foreman 3.15.0** - The main management interface
- **Puppet 8.x** - Configuration management server
- **Smart Proxy** - Network service management
- **All dependencies** - Complete RPM package tree
- **Installation scripts** - Automated setup and configuration
- **Documentation** - Comprehensive guides and troubleshooting

## Package Creation Workflow

### Phase 1: Internet-Connected Machine (Package Creation)

1. **Clone or download this package structure**
2. **Run the download script**:
   ```bash
   make download
   # or manually:
   ./scripts/download-packages.sh
   ```
3. **Create the distribution package**:
   ```bash
   make package
   # or manually:
   ./scripts/create-package.sh
   ```
4. **Verify the package**:
   ```bash
   make verify
   ```
5. **Transfer the package** to your air-gapped machine

### Phase 2: Air-Gapped Machine (Installation)

1. **Extract the package**:
   ```bash
   tar -xzf foreman-3.15-offline-almalinux10.tar.gz
   cd foreman-3.15-offline-almalinux10
   ```
2. **Set up local repositories**:
   ```bash
   make setup
   # or manually:
   sudo ./scripts/setup-local-repos.sh
   ```
3. **Install Foreman**:
   ```bash
   make install
   # or manually:
   sudo ./scripts/install-foreman.sh
   ```

## Package Structure

```
foreman-3.15-offline-almalinux10/
├── README.md                           # Main documentation
├── Makefile                           # Build and management commands
├── scripts/                           # Installation and setup scripts
│   ├── download-packages.sh          # Download packages (internet machine)
│   ├── setup-local-repos.sh          # Setup repositories (air-gapped machine)
│   ├── install-foreman.sh            # Install Foreman (air-gapped machine)
│   └── create-package.sh             # Create distribution package
├── docs/                             # Documentation
│   ├── INSTALLATION.md               # Detailed installation guide
│   └── TROUBLESHOOTING.md            # Troubleshooting guide
├── configs/                          # Configuration templates
│   └── foreman-installer-answers.yaml # Installer configuration template
└── RPMs/                             # RPM packages (created during download)
    ├── foreman/                      # Foreman packages
    ├── puppet/                       # Puppet packages
    ├── epel/                         # EPEL packages
    └── almalinux-base/               # Base system packages
```

## Key Features

### 1. Automated Package Download
- Downloads all required RPMs with dependencies
- Resolves package conflicts automatically
- Creates organized repository structure

### 2. Local Repository Management
- Sets up local RPM repositories
- Configures yum/dnf for offline use
- Handles repository priorities and conflicts

### 3. Automated Installation
- Non-interactive Foreman installation
- Configures all required services
- Sets up SSL certificates and security

### 4. Comprehensive Documentation
- Step-by-step installation guide
- Troubleshooting and recovery procedures
- Configuration templates and examples

## System Requirements

### Package Creation Machine (Internet-Connected)
- **OS**: Any Linux distribution with yum/dnf
- **Internet**: Required for package downloads
- **Storage**: 2-3GB for packages and dependencies
- **Tools**: yum-utils, createrepo_c

### Target Machine (Air-Gapped)
- **OS**: AlmaLinux 10 (x86_64)
- **Memory**: 4GB minimum (8GB+ recommended)
- **Storage**: 20GB+ available space
- **Network**: Proper hostname resolution
- **Access**: Root or sudo privileges

## Customization Options

### 1. Configuration Templates
Edit `configs/foreman-installer-answers.yaml` to customize:
- Database settings (PostgreSQL/MySQL/SQLite)
- Network configuration (interfaces, subnets)
- SSL certificate paths
- Service enablement (DHCP, DNS, TFTP)

### 2. Installation Scripts
Modify `scripts/install-foreman.sh` for:
- Custom admin passwords
- Specific service configurations
- Additional installation parameters

### 3. Package Selection
Edit `scripts/download-packages.sh` to:
- Add/remove specific packages
- Include additional repositories
- Customize dependency resolution

## Security Considerations

### 1. SSL Certificates
- Default installation generates self-signed certificates
- Replace with proper CA-signed certificates for production
- Configure certificate paths in configuration files

### 2. Authentication
- Change default admin password immediately
- Configure OAuth keys for Smart Proxy
- Set up proper user management

### 3. Network Security
- Configure firewall rules appropriately
- Use SELinux for additional security
- Restrict access to management interfaces

## Troubleshooting

### Common Issues

1. **Package Dependencies**: Use `yum deplist` to resolve conflicts
2. **Repository Issues**: Verify repository configuration and priorities
3. **Service Failures**: Check logs and system resources
4. **Network Problems**: Verify hostname resolution and firewall settings

### Recovery Procedures

1. **Service Recovery**: Use systemctl commands to restart services
2. **Configuration Reset**: Restore from backup or reinstall
3. **Database Issues**: Use Foreman rake tasks for database management

## Maintenance and Updates

### 1. Regular Maintenance
- Monitor service status and logs
- Backup configurations and databases
- Update system packages when possible

### 2. Foreman Updates
- Download new offline packages for updates
- Follow upgrade procedures from official documentation
- Test updates in lab environment first

### 3. Backup Strategy
- Regular configuration backups
- Database dumps for critical data
- Document all customizations

## Support and Resources

### 1. Official Documentation
- [Foreman Manual](https://theforeman.org/manuals/3.15/)
- [Installation Guide](https://theforeman.org/manuals/3.15/quickstart_guide.html)
- [Configuration Guide](https://theforeman.org/manuals/3.15/index.html)

### 2. Community Support
- [Foreman Community](https://community.theforeman.org/)
- [GitHub Issues](https://github.com/theforeman/foreman/issues)
- [IRC Channel](irc://irc.freenode.net/#theforeman)

### 3. Professional Services
- Red Hat Consulting for enterprise deployments
- Community training and workshops
- Third-party support providers

## Best Practices

### 1. Package Creation
- Test package creation in clean environment
- Verify all dependencies are included
- Document any custom modifications

### 2. Installation
- Use dedicated machines for Foreman
- Follow security hardening guidelines
- Test installation procedures thoroughly

### 3. Production Deployment
- Implement proper monitoring and alerting
- Use production-grade databases
- Configure backup and recovery procedures
- Document all customizations and procedures

## Conclusion

This offline package provides a complete solution for deploying Foreman 3.15 in air-gapped environments. The automated scripts and comprehensive documentation ensure successful installation and configuration while maintaining security and best practices.

For additional support or customization requirements, refer to the official Foreman documentation or community resources.
