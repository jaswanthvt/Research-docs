# Foreman 3.15 Offline Deployment Package for AlmaLinux 10

This package contains everything needed to deploy Foreman 3.15 on an air-gapped AlmaLinux 10 machine without internet access.

## Package Contents

- **RPMs/**: All required RPM packages and dependencies
- **repos/**: Local repository configurations
- **scripts/**: Installation and setup scripts
- **configs/**: Configuration templates
- **docs/**: Documentation and reference materials

## Prerequisites

- AlmaLinux 10 (x86_64) with at least 4GB RAM
- Root or sudo access
- Sufficient disk space (recommended: 20GB+)
- All packages in this offline bundle

## Quick Start

1. **Extract the package**:
   ```bash
   tar -xzf foreman-3.15-offline-almalinux10.tar.gz
   cd foreman-3.15-offline-almalinux10
   ```

2. **Create local repositories**:
   ```bash
   sudo ./scripts/setup-local-repos.sh
   ```

3. **Install Foreman**:
   ```bash
   sudo ./scripts/install-foreman.sh
   ```

4. **Access Foreman**:
   - Web UI: https://your-server-hostname
   - Default credentials: admin / [generated-password]

## Detailed Installation

See `docs/INSTALLATION.md` for step-by-step instructions.

## Troubleshooting

Check `docs/TROUBLESHOOTING.md` for common issues and solutions.

## Support

- Foreman Documentation: https://theforeman.org/manuals/3.15/
- Community Support: https://community.theforeman.org/

## Package Version

- Foreman: 3.15.0
- Target OS: AlmaLinux 10
- Architecture: x86_64
- Created: $(date)
