# PostgreSQL Backup Management System Makefile
# Enhanced for production deployment with custom port support

# Variables
BINARY_NAME=backup-service
BUILD_DIR=target/release
CONFIG_DIR=config
BACKUP_DIR=backup
SERVICE_NAME=backup-service
SERVICE_USER=backup-service
SERVICE_PORT=8080
INSTALL_PREFIX=/usr/local/bin
SERVICE_DIR=/etc/systemd/system
BACKUP_CONFIG_DIR=/etc/backup-service/config
BACKUP_DATA_DIR=/etc/backup-service/backup

# Allow PORT override for install target
ifdef PORT
    INSTALL_PORT=$(PORT)
else
    INSTALL_PORT=$(SERVICE_PORT)
endif

# Color codes for output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
NC=\033[0m # No Color

# Default target
.PHONY: all
all: build

# Build the project
.PHONY: build
build:
	@echo "$(BLUE)Building $(BINARY_NAME) in release mode...$(NC)"
	cargo build --release
	@echo "$(GREEN)✅ Build completed successfully!$(NC)"

# Clean build artifacts
.PHONY: clean
clean:
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	cargo clean
	@echo "$(GREEN)✅ Clean completed!$(NC)"

# Validate port number
define validate_port
	@if [ $(1) -lt 1024 ] || [ $(1) -gt 65535 ]; then \
		echo "$(RED)❌ Error: Port must be between 1024 and 65535$(NC)"; \
		exit 1; \
	fi
endef

# Check if port is available
define check_port_available
	@if netstat -tuln 2>/dev/null | grep -q ":$(1) "; then \
		echo "$(YELLOW)⚠️  Warning: Port $(1) appears to be in use$(NC)"; \
		echo "$(YELLOW)   Please check if this is intended$(NC)"; \
		read -p "Continue anyway? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1; \
	fi
endef

# Install with custom port support
.PHONY: install
install: build
	@echo "$(BLUE)Installing $(BINARY_NAME) with port $(INSTALL_PORT)...$(NC)"

	# Validate port
	$(call validate_port,$(INSTALL_PORT))

	# Check port availability
	$(call check_port_available,$(INSTALL_PORT))

	# Create user if not exists
	@if ! id $(SERVICE_USER) &>/dev/null; then \
		echo "$(BLUE)Creating user $(SERVICE_USER)...$(NC)"; \
		sudo useradd -r -s /bin/false -d /var/lib/$(SERVICE_NAME) $(SERVICE_USER); \
	fi

	# Install binary
	@echo "$(BLUE)Installing binary to $(INSTALL_PREFIX)...$(NC)"
	sudo install -D -m 755 $(BUILD_DIR)/$(BINARY_NAME) $(INSTALL_PREFIX)/$(BINARY_NAME)

	# Create default directories
	@echo "$(BLUE)Creating directories...$(NC)"
	sudo mkdir -p $(BACKUP_CONFIG_DIR) $(BACKUP_DATA_DIR)
	sudo chown -R $(SERVICE_USER):$(SERVICE_USER) /etc/backup-service

	# Install systemd service with custom port
	@echo "$(BLUE)Installing systemd service...$(NC)"
	@sed "s|{{EXEC_PATH}}|$(INSTALL_PREFIX)/$(BINARY_NAME)|g; \
	     s|{{CONFIG_DIR}}|$(BACKUP_CONFIG_DIR)|g; \
	     s|{{BACKUP_DIR}}|$(BACKUP_DATA_DIR)|g; \
	     s|{{SERVICE_USER}}|$(SERVICE_USER)|g; \
	     s|{{SERVICE_PORT}}|$(INSTALL_PORT)|g" \
	     backup-service.service.template > backup-service.service

	sudo cp backup-service.service $(SERVICE_DIR)/backup-service.service
	sudo systemctl daemon-reload
	sudo systemctl enable backup-service

	@echo ""
	@echo "$(GREEN)🎉 Installation completed successfully!$(NC)"
	@echo "$(BLUE)Installation details:$(NC)"
	@echo "  • Binary: $(INSTALL_PREFIX)/$(BINARY_NAME)"
	@echo "  • Config directory: $(BACKUP_CONFIG_DIR)"
	@echo "  • Backup directory: $(BACKUP_DATA_DIR)"
	@echo "  • Service port: $(INSTALL_PORT)"
	@echo "  • Service name: $(SERVICE_NAME)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  make service-start    # Start the service"
	@echo "  make service-status   # Check service status"
	@echo "  make firewall-setup PORT=$(INSTALL_PORT)  # Configure firewall"

# Enhanced service management targets
.PHONY: service-start
service-start:
	@echo "$(BLUE)Starting $(SERVICE_NAME) service...$(NC)"
	@if sudo systemctl start backup-service; then \
		echo "$(GREEN)✅ Service started successfully!$(NC)"; \
		sleep 2; \
		if sudo systemctl is-active --quiet backup-service; then \
			echo "$(GREEN)✅ Service is running properly$(NC)"; \
		else \
			echo "$(RED)❌ Service failed to start properly$(NC)"; \
			echo "$(YELLOW)Check logs with: make service-logs$(NC)"; \
		fi; \
	else \
		echo "$(RED)❌ Failed to start service$(NC)"; \
		exit 1; \
	fi

.PHONY: service-stop
service-stop:
	@echo "$(YELLOW)Stopping $(SERVICE_NAME) service...$(NC)"
	@if sudo systemctl is-active --quiet backup-service; then \
		if sudo systemctl stop backup-service; then \
			echo "$(GREEN)✅ Service stopped successfully!$(NC)"; \
		else \
			echo "$(RED)❌ Failed to stop service$(NC)"; \
			exit 1; \
		fi; \
	else \
		echo "$(YELLOW)⚠️  Service is already stopped$(NC)"; \
	fi

.PHONY: service-restart
service-restart:
	@echo "$(BLUE)Restarting $(SERVICE_NAME) service...$(NC)"
	@if sudo systemctl restart backup-service; then \
		echo "$(GREEN)✅ Service restarted successfully!$(NC)"; \
		sleep 2; \
		if sudo systemctl is-active --quiet backup-service; then \
			echo "$(GREEN)✅ Service is running properly$(NC)"; \
		else \
			echo "$(RED)❌ Service failed to restart properly$(NC)"; \
			echo "$(YELLOW)Check logs with: make service-logs$(NC)"; \
		fi; \
	else \
		echo "$(RED)❌ Failed to restart service$(NC)"; \
		exit 1; \
	fi

.PHONY: service-status
service-status:
	@echo "$(BLUE)$(SERVICE_NAME) Service Status:$(NC)"
	@echo "$(YELLOW)================================$(NC)"
	@if sudo systemctl is-active --quiet backup-service; then \
		echo "$(GREEN)Status: RUNNING$(NC)"; \
	else \
		echo "$(RED)Status: STOPPED$(NC)"; \
	fi
	@if sudo systemctl is-enabled --quiet backup-service; then \
		echo "$(GREEN)Enabled: YES$(NC)"; \
	else \
		echo "$(YELLOW)Enabled: NO$(NC)"; \
	fi
	@echo ""
	@sudo systemctl status backup-service --no-pager -l

.PHONY: service-logs
service-logs:
	@echo "$(BLUE)Showing $(SERVICE_NAME) service logs (Ctrl+C to exit):$(NC)"
	@echo "$(YELLOW)================================$(NC)"
	sudo journalctl -u backup-service -f

.PHONY: service-debug
service-debug:
	@echo "$(BLUE)Showing last 50 log entries for $(SERVICE_NAME):$(NC)"
	@echo "$(YELLOW)================================$(NC)"
	sudo journalctl -u backup-service -n 50 --no-pager

# Firewall configuration
.PHONY: firewall-setup
firewall-setup:
	@if [ -z "$(PORT)" ]; then \
		echo "$(RED)❌ Error: Please specify PORT (e.g., make firewall-setup PORT=3724)$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Setting up firewall for port $(PORT)...$(NC)"
	@if command -v ufw >/dev/null 2>&1; then \
		echo "$(BLUE)Using UFW firewall...$(NC)"; \
		sudo ufw allow $(PORT)/tcp && echo "$(GREEN)✅ UFW rule added for port $(PORT)$(NC)"; \
	elif command -v firewall-cmd >/dev/null 2>&1; then \
		echo "$(BLUE)Using firewalld...$(NC)"; \
		sudo firewall-cmd --permanent --add-port=$(PORT)/tcp && \
		sudo firewall-cmd --reload && \
		echo "$(GREEN)✅ firewalld rule added for port $(PORT)$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  No supported firewall found (ufw/firewalld)$(NC)"; \
		echo "$(YELLOW)Please manually open port $(PORT) in your firewall$(NC)"; \
	fi

# Update and deploy pipeline
.PHONY: update-and-deploy
update-and-deploy:
	@echo "$(BLUE)Starting update and deploy pipeline...$(NC)"
	@echo "$(YELLOW)===================================$(NC)"

	# Check if service exists
	@if ! systemctl list-unit-files | grep -q "backup-service.service"; then \
		echo "$(RED)❌ Service not found. Please run 'make install' first.$(NC)"; \
		exit 1; \
	fi

	# Get current port from running service
	@echo "$(BLUE)Checking current deployment...$(NC)"
	@if sudo systemctl is-active --quiet backup-service; then \
		echo "$(GREEN)✅ Service is currently running$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  Service is currently stopped$(NC)"; \
	fi

	# Git pull
	@echo "$(BLUE)Pulling latest changes...$(NC)"
	@if git pull; then \
		echo "$(GREEN)✅ Git pull successful$(NC)"; \
	else \
		echo "$(RED)❌ Git pull failed$(NC)"; \
		exit 1; \
	fi

	# Build
	@echo "$(BLUE)Building new version...$(NC)"
	@$(MAKE) build
	@if [ $$? -eq 0 ]; then \
		echo "$(GREEN)✅ Build successful$(NC)"; \
	else \
		echo "$(RED)❌ Build failed$(NC)"; \
		exit 1; \
	fi

	# Stop service
	@echo "$(BLUE)Stopping service for update...$(NC)"
	@$(MAKE) service-stop

	# Deploy binary
	@echo "$(BLUE)Deploying new binary...$(NC)"
	@sudo cp $(BUILD_DIR)/$(BINARY_NAME) $(INSTALL_PREFIX)/$(BINARY_NAME)
	@echo "$(GREEN)✅ Binary deployed successfully$(NC)"

	# Restart service
	@echo "$(BLUE)Starting updated service...$(NC)"
	@$(MAKE) service-start

	# Verify deployment
	@echo "$(BLUE)Verifying deployment...$(NC)"
	@sleep 3
	@if sudo systemctl is-active --quiet backup-service; then \
		echo "$(GREEN)🎉 Update and deploy completed successfully!$(NC)"; \
		echo "$(GREEN)✅ Service is running with new version$(NC)"; \
	else \
		echo "$(RED)❌ Service failed to start after update$(NC)"; \
		echo "$(YELLOW)Check logs with: make service-logs$(NC)"; \
		exit 1; \
	fi

# Enhanced uninstall with backup option
.PHONY: uninstall
uninstall:
	@echo "$(YELLOW)Uninstalling $(BINARY_NAME)...$(NC)"
	@echo "$(RED)⚠️  This will remove the service and binary$(NC)"
	@echo "$(RED)⚠️  Configuration and backup data will be preserved$(NC)"
	@read -p "Are you sure you want to continue? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1

	# Stop and disable service
	@echo "$(BLUE)Stopping and disabling service...$(NC)"
	@sudo systemctl stop backup-service 2>/dev/null || true
	@sudo systemctl disable backup-service 2>/dev/null || true

	# Remove binary
	@echo "$(BLUE)Removing binary...$(NC)"
	@sudo rm -f $(INSTALL_PREFIX)/$(BINARY_NAME)

	# Remove systemd service
	@echo "$(BLUE)Removing systemd service...$(NC)"
	@sudo rm -f $(SERVICE_DIR)/backup-service.service
	@sudo systemctl daemon-reload

	# Ask about data removal
	@read -p "Remove configuration and backup data? (y/N): " remove_data && \
	if [ "$$remove_data" = "y" ]; then \
		echo "$(YELLOW)Removing data directories...$(NC)"; \
		sudo rm -rf /etc/backup-service; \
		echo "$(RED)⚠️  All data has been removed$(NC)"; \
	else \
		echo "$(BLUE)Data preserved in /etc/backup-service$(NC)"; \
	fi

	# Ask about user removal
	@read -p "Remove service user $(SERVICE_USER)? (y/N): " remove_user && \
	if [ "$$remove_user" = "y" ]; then \
		echo "$(YELLOW)Removing service user...$(NC)"; \
		sudo userdel $(SERVICE_USER) 2>/dev/null || true; \
	fi

	@echo "$(GREEN)✅ Uninstallation completed!$(NC)"

# Deployment health check
.PHONY: check-deployment
check-deployment:
	@echo "$(BLUE)Checking deployment health...$(NC)"
	@echo "$(YELLOW)=============================$(NC)"

	# Check if binary exists
	@if [ -f $(INSTALL_PREFIX)/$(BINARY_NAME) ]; then \
		echo "$(GREEN)✅ Binary exists at $(INSTALL_PREFIX)/$(BINARY_NAME)$(NC)"; \
	else \
		echo "$(RED)❌ Binary not found$(NC)"; \
	fi

	# Check if service is enabled
	@if sudo systemctl is-enabled --quiet backup-service 2>/dev/null; then \
		echo "$(GREEN)✅ Service is enabled$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  Service is not enabled$(NC)"; \
	fi

	# Check if service is running
	@if sudo systemctl is-active --quiet backup-service 2>/dev/null; then \
		echo "$(GREEN)✅ Service is running$(NC)"; \
		# Get port from service file if possible
		@port=$$(sudo grep -o "port [0-9]*" /etc/systemd/system/backup-service.service | head -1 | cut -d' ' -f2); \
		if [ -n "$$port" ]; then \
			echo "$(GREEN)✅ Service running on port $$port$(NC)"; \
		fi; \
	else \
		echo "$(RED)❌ Service is not running$(NC)"; \
	fi

	# Check directories
	@if [ -d $(BACKUP_CONFIG_DIR) ]; then \
		echo "$(GREEN)✅ Config directory exists$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  Config directory not found$(NC)"; \
	fi

	@if [ -d $(BACKUP_DATA_DIR) ]; then \
		echo "$(GREEN)✅ Backup directory exists$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  Backup directory not found$(NC)"; \
	fi

	# Check configuration files
	@if [ -f $(BACKUP_CONFIG_DIR)/servers.json ]; then \
		echo "$(GREEN)✅ Server configuration exists$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  No server configuration found$(NC)"; \
	fi

# Quick install with common ports
.PHONY: install-dev
install-dev:
	@$(MAKE) install PORT=8080

.PHONY: install-prod
install-prod:
	@$(MAKE) install PORT=3724

# Install system dependencies (Linux)
.PHONY: install-deps
install-deps:
	@if command -v apt-get >/dev/null 2>&1; then \
		echo "$(BLUE)Installing dependencies for Debian/Ubuntu...$(NC)"; \
		sudo apt-get update && sudo apt-get install -y \
			pkg-config \
			libssl-dev \
			postgresql-client \
			build-essential \
			net-tools; \
	elif command -v yum >/dev/null 2>&1; then \
		echo "$(BLUE)Installing dependencies for RHEL/CentOS...$(NC)"; \
		sudo yum groupinstall -y "Development Tools" && \
		sudo yum install -y \
			pkgconfig \
			openssl-devel \
			postgresql \
			net-tools; \
	elif command -v dnf >/dev/null 2>&1; then \
		echo "$(BLUE)Installing dependencies for Fedora...$(NC)"; \
		sudo dnf groupinstall -y "Development Tools" && \
		sudo dnf install -y \
			pkgconfig \
			openssl-devel \
			postgresql \
			net-tools; \
	elif command -v pacman >/dev/null 2>&1; then \
		echo "$(BLUE)Installing dependencies for Arch Linux...$(NC)"; \
		sudo pacman -S --needed \
			pkgconf \
			openssl \
			postgresql \
			net-tools; \
	else \
		echo "$(RED)Unknown package manager. Please install manually:$(NC)"; \
		echo "  - pkg-config"; \
		echo "  - OpenSSL development headers (libssl-dev or openssl-devel)"; \
		echo "  - PostgreSQL client tools"; \
		echo "  - Build tools (gcc, make)"; \
		echo "  - net-tools (for port checking)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✅ Dependencies installed successfully!$(NC)"

# Legacy targets for backward compatibility
.PHONY: setup
setup: install-deps build

.PHONY: rebuild
rebuild: clean build

# Development targets
.PHONY: dev-cli
dev-cli:
	cargo run -- run

.PHONY: dev-server
dev-server:
	cargo run -- server --port $(SERVICE_PORT)

.PHONY: test
test:
	cargo test

.PHONY: check
check:
	cargo check
	cargo clippy

# Legacy service management (for backward compatibility)
.PHONY: start-service
start-service: service-start

.PHONY: stop-service
stop-service: service-stop

.PHONY: restart-service
restart-service: service-restart

.PHONY: status-service
status-service: service-status

.PHONY: logs-service
logs-service: service-logs

# Enhanced help
.PHONY: help
help:
	@echo "$(BLUE)PostgreSQL Backup Management System$(NC)"
	@echo "$(YELLOW)=====================================$(NC)"
	@echo ""
	@echo "$(GREEN)🚀 Quick Start:$(NC)"
	@echo "  make install PORT=3724     # Install with custom port"
	@echo "  make install-dev           # Quick dev install (port 8080)"
	@echo "  make install-prod          # Quick prod install (port 3724)"
	@echo ""
	@echo "$(GREEN)📦 Setup targets:$(NC)"
	@echo "  install-deps              # Install system dependencies (Linux)"
	@echo "  setup                     # Install deps and build"
	@echo "  rebuild                   # Clean and rebuild"
	@echo ""
	@echo "$(GREEN)🔨 Build targets:$(NC)"
	@echo "  build                     # Build the release binary"
	@echo "  clean                     # Clean build artifacts"
	@echo "  check                     # Run cargo check and clippy"
	@echo "  test                      # Run tests"
	@echo ""
	@echo "$(GREEN)🏃 Run targets:$(NC)"
	@echo "  run-cli                   # Run interactive CLI"
	@echo "  run-server                # Run REST server on default port"
	@echo "  run-server-port           # Run REST server with custom port"
	@echo "  dev-cli                   # Run CLI in development mode"
	@echo "  dev-server                # Run REST server in development mode"
	@echo ""
	@echo "$(GREEN)🔧 Service Management:$(NC)"
	@echo "  service-start             # Start systemd service"
	@echo "  service-stop              # Stop systemd service"
	@echo "  service-restart           # Restart systemd service"
	@echo "  service-status            # Check service status"
	@echo "  service-logs              # View real-time service logs"
	@echo "  service-debug             # Show recent service logs"
	@echo ""
	@echo "$(GREEN)🚀 Deployment:$(NC)"
	@echo "  update-and-deploy         # Git pull -> build -> deploy -> restart"
	@echo "  check-deployment          # Verify deployment health"
	@echo "  firewall-setup PORT=xxxx  # Configure firewall for port"
	@echo ""
	@echo "$(GREEN)🗑️  Maintenance:$(NC)"
	@echo "  uninstall                 # Remove service and binary"
	@echo ""
	@echo "$(GREEN)📚 Examples:$(NC)"
	@echo "  make install PORT=3724                    # Install on port 3724"
	@echo "  make firewall-setup PORT=3724            # Open port 3724 in firewall"
	@echo "  make update-and-deploy                    # Update to latest version"
	@echo "  make service-start && make service-status # Start and check service"
	@echo ""
	@echo "$(GREEN)⚙️  Variables:$(NC)"
	@echo "  PORT                     # Custom port for installation"
	@echo "  SERVICE_PORT             # Default REST server port ($(SERVICE_PORT))"
	@echo "  INSTALL_PREFIX           # Installation directory ($(INSTALL_PREFIX))"
	@echo "  SERVICE_USER             # Service user ($(SERVICE_USER))"