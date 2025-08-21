# Troubleshooting Guide for Foreman 3.15 Offline Installation

This guide covers common issues and solutions when installing Foreman 3.15 offline on AlmaLinux 10.

## Pre-Installation Issues

### 1. System Requirements Not Met

**Symptoms**: Installation fails with memory or disk space errors

**Solutions**:
```bash
# Check memory
free -h

# Check disk space
df -h

# Check CPU architecture
uname -m
```

**Requirements**:
- Minimum 4GB RAM (8GB+ recommended)
- Minimum 20GB disk space
- x86_64 architecture

### 2. Hostname Resolution Issues

**Symptoms**: Installation fails with hostname-related errors

**Solutions**:
```bash
# Check hostname resolution
ping $(hostname -f)

# Fix /etc/hosts if needed
echo "$(hostname -I | awk '{print $1}') $(hostname -f) $(hostname)" >> /etc/hosts

# Verify FQDN
hostname -f
```

## Repository Issues

### 3. Local Repository Not Found

**Symptoms**: `yum repolist` shows no repositories or errors

**Solutions**:
```bash
# Check repository configuration
ls -la /etc/yum.repos.d/

# Verify offline repository file
cat /etc/yum.repos.d/foreman-offline.repo

# Re-run repository setup
sudo ./scripts/setup-local-repos.sh

# Check repository status
yum repolist
```

### 4. Package Dependencies Missing

**Symptoms**: Installation fails with "No package available" errors

**Solutions**:
```bash
# Check available packages
yum list available | grep foreman

# Verify repository contents
ls -la /opt/foreman-offline-repos/

# Re-create repositories
sudo ./scripts/setup-local-repos.sh
```

## Installation Issues

### 5. Foreman Installer Fails

**Symptoms**: `foreman-installer` command fails or hangs

**Solutions**:
```bash
# Check installer logs
tail -f /var/log/foreman-installer/foreman-installer.log

# Verify system resources during installation
htop

# Check for conflicting services
systemctl status postgresql mariadb httpd

# Run installer with verbose output
foreman-installer -v
```

### 6. Database Connection Issues

**Symptoms**: Installation fails with database-related errors

**Solutions**:
```bash
# Check if database services are running
systemctl status postgresql mariadb

# Verify database configuration
cat /etc/foreman/database.yml

# Check database connectivity
sudo -u foreman foreman-rake db:migrate:status
```

## Service Issues

### 7. Foreman Service Won't Start

**Symptoms**: `systemctl start foreman` fails

**Solutions**:
```bash
# Check service status
systemctl status foreman

# Check service logs
journalctl -u foreman -f

# Verify configuration
foreman-rake config:check

# Check file permissions
ls -la /var/log/foreman/
ls -la /etc/foreman/
```

### 8. Smart Proxy Issues

**Symptoms**: Foreman can't communicate with Smart Proxy

**Solutions**:
```bash
# Check proxy status
systemctl status foreman-proxy

# Verify proxy configuration
cat /etc/foreman-proxy/settings.yml

# Check proxy logs
tail -f /var/log/foreman-proxy/proxy.log

# Test proxy connectivity
curl -k https://localhost:8443
```

## Network and Security Issues

### 9. Firewall Blocking Access

**Symptoms**: Can't access Foreman web interface

**Solutions**:
```bash
# Check firewall status
firewall-cmd --list-all

# Open required ports
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=8443/tcp
firewall-cmd --reload

# Check SELinux status
getenforce
```

### 10. SSL Certificate Issues

**Symptoms**: Browser shows SSL errors or can't connect

**Solutions**:
```bash
# Check SSL configuration
cat /etc/foreman/ssl_cert.pem

# Verify certificate validity
openssl x509 -in /etc/foreman/ssl_cert.pem -text -noout

# Regenerate certificates if needed
foreman-installer --foreman-proxy-ssl-ca /etc/pki/tls/certs/ca-bundle.crt
```

## Performance Issues

### 11. Slow Installation or Operation

**Symptoms**: Installation takes too long or system is sluggish

**Solutions**:
```bash
# Check system resources
htop
iostat -x 1

# Check disk I/O
iotop

# Verify sufficient memory
free -h

# Check for resource-intensive processes
ps aux --sort=-%mem | head -10
```

### 12. Database Performance Issues

**Symptoms**: Foreman web interface is slow

**Solutions**:
```bash
# Check database performance
sudo -u foreman foreman-rake db:analyze

# Verify database configuration
cat /etc/foreman/database.yml

# Check database logs
tail -f /var/log/postgresql/postgresql-*.log
```

## Log Analysis

### 13. Understanding Log Files

**Key log locations**:
```bash
# Foreman installer logs
/var/log/foreman-installer/

# Foreman application logs
/var/log/foreman/

# Smart Proxy logs
/var/log/foreman-proxy/

# Puppet logs
/var/log/puppet/

# System logs
journalctl -u foreman -f
journalctl -u foreman-proxy -f
```

### 14. Common Error Patterns

**Look for these patterns in logs**:
- `ERROR`: Critical issues that prevent operation
- `WARN`: Warning messages that may indicate problems
- `FATAL`: Fatal errors that cause service failure
- `Permission denied`: File permission issues
- `Connection refused`: Network connectivity problems

## Recovery Procedures

### 15. Complete Reinstallation

If all else fails:
```bash
# Stop all services
systemctl stop foreman foreman-proxy puppet

# Remove Foreman packages
dnf remove foreman* puppet* -y

# Clean up configuration
rm -rf /etc/foreman /etc/foreman-proxy /var/log/foreman*

# Re-run installation
sudo ./scripts/install-foreman.sh
```

### 16. Database Recovery

```bash
# Backup current database
sudo -u foreman foreman-rake db:dump

# Reset database if needed
sudo -u foreman foreman-rake db:drop
sudo -u foreman foreman-rake db:create
sudo -u foreman foreman-rake db:migrate
```

## Getting Help

### 17. Collecting Information

Before seeking help, collect:
```bash
# System information
uname -a
cat /etc/os-release

# Foreman version
foreman-rake about

# Service status
systemctl status foreman foreman-proxy puppet

# Recent logs
journalctl -u foreman --since "1 hour ago"
```

### 18. Community Resources

- **Foreman Community**: https://community.theforeman.org/
- **Documentation**: https://theforeman.org/manuals/3.15/
- **GitHub Issues**: https://github.com/theforeman/foreman/issues
- **IRC**: #theforeman on Freenode

## Prevention

### 19. Best Practices

- Always verify system requirements before installation
- Use dedicated machines for Foreman installation
- Keep detailed logs of any customizations
- Test installation procedures in a lab environment first
- Maintain regular backups of configuration and data
