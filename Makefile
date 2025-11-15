# PostgreSQL Backup Management System Makefile

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

# Default target
.PHONY: all
all: build

# Build the project
.PHONY: build
build:
	cargo build --release

# Clean build artifacts
.PHONY: clean
clean:
	cargo clean

# Run interactive CLI
.PHONY: run-cli
run-cli: build
	$(BUILD_DIR)/$(BINARY_NAME) run --config-dir $(CONFIG_DIR) --backup-dir $(BACKUP_DIR)

# Run REST server with default port
.PHONY: run-server
run-server: build
	$(BUILD_DIR)/$(BINARY_NAME) server --config-dir $(CONFIG_DIR) --backup-dir $(BACKUP_DIR) --port $(SERVICE_PORT)

# Run REST server with custom port
.PHONY: run-server-port
run-server-port: build
	@read -p "Enter port number: " port; \
	$(BUILD_DIR)/$(BINARY_NAME) server --config-dir $(CONFIG_DIR) --backup-dir $(BACKUP_DIR) --port $$port

# Install binary and create systemd service
.PHONY: install
install: build
	# Create user if not exists
	@if ! id $(SERVICE_USER) &>/dev/null; then \
		echo "Creating user $(SERVICE_USER)..."; \
		sudo useradd -r -s /bin/false -d /var/lib/$(SERVICE_NAME) $(SERVICE_USER); \
	fi

	# Install binary
	sudo install -D -m 755 $(BUILD_DIR)/$(BINARY_NAME) $(INSTALL_PREFIX)/$(BINARY_NAME)

	# Create directories
	sudo mkdir -p /var/lib/$(SERVICE_NAME)/{config,backup}
	sudo chown -R $(SERVICE_USER):$(SERVICE_USER) /var/lib/$(SERVICE_NAME)

	# Install systemd service
	@sed "s|{{EXEC_PATH}}|$(INSTALL_PREFIX)/$(BINARY_NAME)|g; \
	     s|{{CONFIG_DIR}}|/var/lib/$(SERVICE_NAME)/config|g; \
	     s|{{BACKUP_DIR}}|/var/lib/$(SERVICE_NAME)/backup|g; \
	     s|{{SERVICE_USER}}|$(SERVICE_USER)|g; \
	     s|{{SERVICE_PORT}}|$(SERVICE_PORT)|g" \
	     backup-service.service.template > backup-service.service

	sudo cp backup-service.service $(SERVICE_DIR)/backup-service.service
	sudo systemctl daemon-reload
	sudo systemctl enable backup-service

	@echo "Installation completed!"
	@echo "Binary installed at: $(INSTALL_PREFIX)/$(BINARY_NAME)"
	@echo "Config directory: /var/lib/$(SERVICE_NAME)/config"
	@echo "Backup directory: /var/lib/$(SERVICE_NAME)/backup"
	@echo "Systemd service: backup-service"
	@echo "To start service: sudo systemctl start backup-service"
	@echo "To check status: sudo systemctl status backup-service"

# Uninstall
.PHONY: uninstall
uninstall:
	# Stop and disable service
	sudo systemctl stop backup-service || true
	sudo systemctl disable backup-service || true

	# Remove binary
	sudo rm -f $(INSTALL_PREFIX)/$(BINARY_NAME)

	# Remove systemd service
	sudo rm -f $(SERVICE_DIR)/backup-service.service
	sudo systemctl daemon-reload

	# Remove user (optional - comment out if you want to keep user)
	# sudo userdel $(SERVICE_USER) || true

	# Remove directories (optional - comment out if you want to keep data)
	# sudo rm -rf /var/lib/$(SERVICE_NAME)

	@echo "Uninstallation completed!"

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

# Service management
.PHONY: start-service
start-service:
	sudo systemctl start backup-service

.PHONY: stop-service
stop-service:
	sudo systemctl stop backup-service

.PHONY: restart-service
restart-service:
	sudo systemctl restart backup-service

.PHONY: status-service
status-service:
	sudo systemctl status backup-service

.PHONY: logs-service
logs-service:
	sudo journalctl -u backup-service -f

# Help
.PHONY: help
help:
	@echo "PostgreSQL Backup Management System"
	@echo "====================================="
	@echo ""
	@echo "Build targets:"
	@echo "  build          - Build the release binary"
	@echo "  clean          - Clean build artifacts"
	@echo "  check          - Run cargo check and clippy"
	@echo "  test           - Run tests"
	@echo ""
	@echo "Run targets:"
	@echo "  run-cli        - Run interactive CLI with config in ./config"
	@echo "  run-server     - Run REST server on default port ($(SERVICE_PORT))"
	@echo "  run-server-port- Run REST server with custom port"
	@echo "  dev-cli        - Run CLI in development mode"
	@echo "  dev-server     - Run REST server in development mode"
	@echo ""
	@echo "Installation:"
	@echo "  install        - Install binary and systemd service"
	@echo "  uninstall      - Remove binary and systemd service"
	@echo ""
	@echo "Service management:"
	@echo "  start-service  - Start systemd service"
	@echo "  stop-service   - Stop systemd service"
	@echo "  restart-service - Restart systemd service"
	@echo "  status-service - Check service status"
	@echo "  logs-service   - View service logs"
	@echo ""
	@echo "Variables:"
	@echo "  SERVICE_PORT   - Default REST server port ($(SERVICE_PORT))"
	@echo "  INSTALL_PREFIX - Installation directory ($(INSTALL_PREFIX))"
	@echo "  SERVICE_USER   - Service user ($(SERVICE_USER))"