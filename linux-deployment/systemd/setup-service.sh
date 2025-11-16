#!/bin/bash

# PostgreSQL Backup Management System - Systemd Service Setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SERVICE_NAME="backup-service"
SERVICE_USER="backup-service"
INSTALL_DIR="/opt/backup-service"
SYSTEMD_DIR="/etc/systemd/system"

print_status "PostgreSQL Backup Management System - Systemd Service Setup"
print_status "========================================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check if binary exists
if [ ! -f "$INSTALL_DIR/bin/backup-service" ]; then
    print_error "Binary not found at $INSTALL_DIR/bin/backup-service"
    print_status "Please run the build script first"
    exit 1
fi

# Create service user
print_status "Creating service user..."
if ! id "$SERVICE_USER" &>/dev/null; then
    useradd -r -s /bin/false -d "$INSTALL_DIR" "$SERVICE_USER"
    print_success "Service user '$SERVICE_USER' created"
else
    print_status "Service user '$SERVICE_USER' already exists"
fi

# Set up directories and permissions
print_status "Setting up directories and permissions..."
mkdir -p "$INSTALL_DIR"/{config,backup,logs}
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
chmod 755 "$INSTALL_DIR"
chmod 700 "$INSTALL_DIR"/{config,backup,logs}
print_success "Directories configured with proper permissions"

# Install systemd service
print_status "Installing systemd service..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/backup-service.service" "$SYSTEMD_DIR/"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
print_success "Systemd service installed and enabled"

# Create default config directories
if [ ! -f "$INSTALL_DIR/config/servers.json" ]; then
    print_status "Creating default configuration files..."
    cat > "$INSTALL_DIR/config/servers.json" << 'EOF'
{
  "example_server": {
    "name": "example_server",
    "host": "localhost",
    "port": 5432,
    "database": "mydatabase",
    "username": "postgres",
    "password": "your_password_here",
    "version": null,
    "total_schemas": null,
    "is_active": false
  }
}
EOF
    chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/config/servers.json"
    chmod 600 "$INSTALL_DIR/config/servers.json"
    print_success "Default server configuration created"
fi

if [ ! -f "$INSTALL_DIR/config/telegram.json" ]; then
    cat > "$INSTALL_DIR/config/telegram.json" << 'EOF'
{
  "bot_token": "",
  "chat_id": "",
  "enabled": false
}
EOF
    chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/config/telegram.json"
    chmod 600 "$INSTALL_DIR/config/telegram.json"
    print_success "Default Telegram configuration created"
fi

# Show service status
print_status "Service installation completed!"
print_success "Systemd service '$SERVICE_NAME' is ready to use"
print_status ""
print_status "Service management commands:"
print_status "  systemctl start $SERVICE_NAME     - Start the service"
print_status "  systemctl stop $SERVICE_NAME      - Stop the service"
print_status "  systemctl restart $SERVICE_NAME   - Restart the service"
print_status "  systemctl status $SERVICE_NAME    - Check service status"
print_status "  journalctl -u $SERVICE_NAME -f    - View service logs"
print_status ""
print_status "Configuration files:"
print_status "  $INSTALL_DIR/config/servers.json    - Server configurations"
print_status "  $INSTALL_DIR/config/telegram.json   - Telegram notification settings"
print_status "  $INSTALL_DIR/backup/                 - Backup files location"
print_status ""
print_status "CLI commands:"
print_status "  $INSTALL_DIR/bin/backup-service run              - Start interactive CLI"
print_status "  $INSTALL_DIR/bin/backup-service server           - Start REST server"
print_status "  $INSTALL_DIR/bin/backup-service backup           - Create backup"