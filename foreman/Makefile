# Makefile for Foreman 3.15 Offline Package
# This Makefile provides common operations for managing the offline package

.PHONY: help clean download setup install package verify

# Default target
help:
	@echo "Foreman 3.15 Offline Package Management"
	@echo "======================================"
	@echo ""
	@echo "Available targets:"
	@echo "  download  - Download all required packages (requires internet)"
	@echo "  setup     - Set up local repositories on target machine"
	@echo "  install   - Install Foreman using offline packages"
	@echo "  package   - Create the final tar.gz package"
	@echo "  clean     - Clean up temporary files and packages"
	@echo "  verify    - Verify package integrity and structure"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "Usage examples:"
	@echo "  make download  # On internet-connected machine"
	@echo "  make package   # Create distribution package"
	@echo "  make setup     # On air-gapped machine"
	@echo "  make install   # Install Foreman"

# Download packages (run on internet-connected machine)
download:
	@echo "Downloading packages for offline Foreman installation..."
	@chmod +x scripts/download-packages.sh
	@./scripts/download-packages.sh

# Set up local repositories (run on target machine)
setup:
	@echo "Setting up local repositories..."
	@chmod +x scripts/setup-local-repos.sh
	@sudo ./scripts/setup-local-repos.sh

# Install Foreman (run on target machine)
install:
	@echo "Installing Foreman..."
	@chmod +x scripts/install-foreman.sh
	@sudo ./scripts/install-foreman.sh

# Create the final package
package:
	@echo "Creating offline package..."
	@chmod +x scripts/create-package.sh
	@./scripts/create-package.sh

# Clean up temporary files
clean:
	@echo "Cleaning up temporary files..."
	@rm -rf RPMs/
	@rm -f *.tar.gz
	@rm -f scripts/*.log
	@echo "Cleanup completed."

# Verify package structure
verify:
	@echo "Verifying package structure..."
	@echo "Checking required directories..."
	@test -d scripts || (echo "ERROR: scripts/ directory missing" && exit 1)
	@test -d docs || (echo "ERROR: docs/ directory missing" && exit 1)
	@test -d configs || (echo "ERROR: configs/ directory missing" && exit 1)
	@echo "Checking required scripts..."
	@test -f scripts/setup-local-repos.sh || (echo "ERROR: setup-local-repos.sh missing" && exit 1)
	@test -f scripts/install-foreman.sh || (echo "ERROR: install-foreman.sh missing" && exit 1)
	@test -f scripts/download-packages.sh || (echo "ERROR: download-packages.sh missing" && exit 1)
	@test -f scripts/create-package.sh || (echo "ERROR: create-package.sh missing" && exit 1)
	@echo "Checking documentation..."
	@test -f docs/INSTALLATION.md || (echo "ERROR: INSTALLATION.md missing" && exit 1)
	@test -f docs/TROUBLESHOOTING.md || (echo "ERROR: TROUBLESHOOTING.md missing" && exit 1)
	@test -f configs/foreman-installer-answers.yaml || (echo "ERROR: foreman-installer-answers.yaml missing" && exit 1)
	@echo "Package structure verification completed successfully."

# Full workflow for internet-connected machine
workflow-download: download package verify
	@echo "Download workflow completed. Package is ready for distribution."

# Full workflow for air-gapped machine
workflow-install: setup install
	@echo "Installation workflow completed. Foreman is ready."

# Show package information
info:
	@echo "Foreman 3.15 Offline Package Information"
	@echo "======================================="
	@echo "Version: 3.15.0"
	@echo "Target OS: AlmaLinux 10"
	@echo "Architecture: x86_64"
	@echo "Package Type: Offline RPM Bundle"
	@echo ""
	@echo "Contents:"
	@echo "  - Foreman 3.15.0"
	@echo "  - Puppet 8.x"
	@echo "  - Smart Proxy"
	@echo "  - All dependencies"
	@echo ""
	@echo "Estimated size: 500MB - 1GB (depending on dependencies)"
	@echo "Installation time: 10-30 minutes"
	@echo "Memory requirement: 4GB minimum (8GB+ recommended)"

# Check system requirements
check-system:
	@echo "Checking system requirements..."
	@echo "OS: $$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
	@echo "Architecture: $$(uname -m)"
	@echo "Memory: $$(free -h | grep Mem | awk '{print $$2}')"
	@echo "Disk space: $$(df -h / | tail -1 | awk '{print $$4}')"
	@echo "SELinux: $$(getenforce)"
	@echo "Firewall: $$(systemctl is-active firewalld)"

# Show available repositories
show-repos:
	@echo "Available repositories:"
	@yum repolist 2>/dev/null || echo "No repositories configured or yum not available"

# Show package status
show-status:
	@echo "Foreman package status:"
	@rpm -qa | grep -E "(foreman|puppet)" | sort || echo "No Foreman packages installed"
	@echo ""
	@echo "Service status:"
	@systemctl status foreman foreman-proxy puppet 2>/dev/null || echo "Services not found"

# Backup configuration
backup:
	@echo "Creating configuration backup..."
	@BACKUP_DIR="foreman-backup-$$(date +%Y%m%d-%H%M%S)" && \
	mkdir -p "$$BACKUP_DIR" && \
	cp -r /etc/foreman* "$$BACKUP_DIR/" 2>/dev/null || true && \
	cp -r /etc/puppet "$$BACKUP_DIR/" 2>/dev/null || true && \
	tar -czf "$$BACKUP_DIR.tar.gz" "$$BACKUP_DIR" && \
	rm -rf "$$BACKUP_DIR" && \
	echo "Backup created: $$BACKUP_DIR.tar.gz"

# Restore configuration
restore:
	@echo "Usage: make restore BACKUP_FILE=backup-file.tar.gz"
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "ERROR: Please specify BACKUP_FILE parameter"; \
		echo "Example: make restore BACKUP_FILE=foreman-backup-20231201-120000.tar.gz"; \
		exit 1; \
	fi
	@echo "Restoring configuration from $(BACKUP_FILE)..."
	@tar -xzf "$(BACKUP_FILE)" && \
	echo "Configuration restored. Please restart services manually."
