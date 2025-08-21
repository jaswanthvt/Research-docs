# Foreman 3.15 Offline Installation Guide for AlmaLinux 10

This guide provides step-by-step instructions for installing Foreman 3.15 on an air-gapped AlmaLinux 10 machine using the offline package.

## Prerequisites

### System Requirements
- **OS**: AlmaLinux 10 (x86_64)
- **Memory**: Minimum 4GB RAM (8GB+ recommended)
- **Disk Space**: Minimum 20GB available space
- **Network**: Proper hostname resolution configured
- **Access**: Root or sudo privileges

### Package Requirements
- Complete offline package: `foreman-3.15-offline-almalinux10.tar.gz`
- All required RPM packages included in the bundle

## Installation Steps

### Step 1: Prepare the System

1. **Verify hostname resolution**:
   ```bash
   ping $(hostname -f)
   ```
   Ensure this returns the real IP address, not 127.0.1.1.

2. **Check system resources**:
   ```bash
   free -h
   df -h
   ```

3. **Update system packages** (if possible):
   ```bash
   dnf update -y
   ```

### Step 2: Extract the Offline Package

1. **Transfer the package** to your air-gapped machine
2. **Extract the package**:
   ```bash
   tar -xzf foreman-3.15-offline-almalinux10.tar.gz
   cd foreman-3.15-offline-almalinux10
   ```

### Step 3: Set Up Local Repositories

1. **Make scripts executable**:
   ```bash
   chmod +x scripts/*.sh
   ```

2. **Run the repository setup script**:
   ```bash
   sudo ./scripts/setup-local-repos.sh
   ```

3. **Verify repositories**:
   ```bash
   yum repolist
   ```

### Step 4: Install Foreman

1. **Run the Foreman installation script**:
   ```bash
   sudo ./scripts/install-foreman.sh
   ```

2. **Monitor the installation**:
   - The installer will run non-interactively
   - Installation typically takes 10-30 minutes
   - Check logs if issues occur

### Step 5: Post-Installation Configuration

1. **Access Foreman Web UI**:
   - URL: `https://your-server-hostname`
   - Default credentials: `admin` / [generated-password]

2. **Verify services**:
   ```bash
   systemctl status foreman
   systemctl status foreman-proxy
   systemctl status puppet
   ```

3. **Check logs**:
   ```bash
   tail -f /var/log/foreman-installer/foreman-installer.log
   ```

## Configuration Options

### Custom Installation Parameters

You can customize the installation by modifying `scripts/install-foreman.sh`:

- **Admin password**: Change the `--foreman-admin-password` parameter
- **Proxy services**: Modify DHCP, DNS, and TFTP settings
- **Database**: Default is SQLite, can be changed to PostgreSQL/MySQL

### Network Configuration

- **Firewall**: Ensure ports 80, 443, 8443 are open
- **SELinux**: Should be enabled and configured
- **Hostname**: Must resolve to the correct IP address

## Troubleshooting

### Common Issues

1. **Repository not found**:
   - Ensure `setup-local-repos.sh` was run successfully
   - Check `/etc/yum.repos.d/foreman-offline.repo`

2. **Installation fails**:
   - Check system resources (memory, disk space)
   - Verify hostname resolution
   - Review installer logs

3. **Services not starting**:
   - Check service status: `systemctl status [service-name]`
   - Review service logs: `journalctl -u [service-name]`

### Log Files

- **Installer logs**: `/var/log/foreman-installer/`
- **Foreman logs**: `/var/log/foreman/`
- **Puppet logs**: `/var/log/puppet/`
- **System logs**: `journalctl -f`

## Verification

### Service Status Check

```bash
# Check all Foreman-related services
systemctl status foreman foreman-proxy puppet puppetmaster

# Check web interface
curl -k https://localhost
```

### Database Verification

```bash
# Check Foreman database
foreman-rake db:migrate:status

# Check Puppet database
puppetdb-ssl-setup
```

## Next Steps

After successful installation:

1. **Configure Smart Proxies** for your network
2. **Set up Host Groups** for your infrastructure
3. **Configure Provisioning Templates** for your OS types
4. **Set up Content Management** (if using Katello)
5. **Configure Monitoring** and alerting

## Support

- **Documentation**: [Foreman Manual](https://theforeman.org/manuals/3.15/)
- **Community**: [Foreman Community](https://community.theforeman.org/)
- **Issues**: Check logs and community forums for solutions
