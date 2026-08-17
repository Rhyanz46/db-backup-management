#!/bin/bash
# Install PostgreSQL Backup Management Service as systemd service

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default Configuration
BINARY_NAME="backup-service"
SERVICE_NAME="backup-service"
DEFAULT_SERVICE_USER="backup-service"
DEFAULT_PORT="8080"
DEFAULT_CONFIG_DIR="/etc/backup-service/config"
DEFAULT_BACKUP_DIR="/etc/backup-service/backup"

# Parse Command Line Arguments
SERVICE_TYPE="${1:-combined}"  # combined, rest, cronjob
SERVICE_USER="${2:-$DEFAULT_SERVICE_USER}"
PORT="${3:-$DEFAULT_PORT}"
CONFIG_DIR="${4:-$DEFAULT_CONFIG_DIR}"
BACKUP_DIR="${5:-$DEFAULT_BACKUP_DIR}"

# Path Variables
BINARY_PATH="/usr/local/bin/${BINARY_NAME}"
BINARY_BUILD_PATH="target/release/${BINARY_NAME}"
LOG_DIR="/var/log/backup-service"
SYSTEMD_DIR="/etc/systemd/system"

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Usage information
usage() {
    echo "Usage: $0 [SERVICE_TYPE] [USER] [PORT] [CONFIG_DIR] [BACKUP_DIR]"
    echo ""
    echo "SERVICE_TYPE options:"
    echo "  combined   - Combined service with both REST API and cronjob (default)"
    echo "  rest       - REST API service only"
    echo "  cronjob    - Cronjob scheduler service only"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 combined $DEFAULT_SERVICE_USER 8237"
    echo "  $0 rest backup-service 8237"
    echo "  $0 cronjob dev 8237 /etc/backup-service/config /home/dev/backups"
    echo ""
    echo "Default paths:"
    echo "  Config Directory: $DEFAULT_CONFIG_DIR"
    echo "  Backup Directory: $DEFAULT_BACKUP_DIR"
    echo "  Log Directory: $LOG_DIR"
    exit 1
}

# Validate arguments
case "$SERVICE_TYPE" in
    combined|rest|cronjob) ;;
    *) error "Invalid service type: $SERVICE_TYPE"; usage ;;
esac

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Check if binary exists
if [ ! -f "$BINARY_BUILD_PATH" ]; then
    error "Binary not found at $BINARY_BUILD_PATH"
    error "Please run: cargo build --release"
    exit 1
fi

log "Installing PostgreSQL Backup Service..."
echo ""

# Display installation details
info "Installation Configuration:"
info "  Service Type: $SERVICE_TYPE"
info "  Service User: $SERVICE_USER"
info "  Port: $PORT"
info "  Config Directory: $CONFIG_DIR"
info "  Backup Directory: $BACKUP_DIR"
echo ""

# 1. Create user if doesn't exist
log "Creating service user..."
if id "$SERVICE_USER" &>/dev/null; then
    success "User '$SERVICE_USER' already exists"
else
    useradd -r -s /bin/false -d "/var/lib/${SERVICE_NAME}" -c "PostgreSQL Backup Service" "$SERVICE_USER"
    success "User '$SERVICE_USER' created"
fi

# 2. Create directories
log "Creating directories..."
mkdir -p "$CONFIG_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "/var/lib/${SERVICE_NAME}"

# 3. Install binary
log "Installing binary..."
cp "$BINARY_BUILD_PATH" "$BINARY_PATH"
chmod +x "$BINARY_PATH"
success "Binary installed to $BINARY_PATH"

# 4. Set ownership
log "Setting permissions..."
chown -R "$SERVICE_USER:$SERVICE_USER" "$BACKUP_DIR"
chown -R "$SERVICE_USER:$SERVICE_USER" "$LOG_DIR"
chown "$SERVICE_USER:$SERVICE_USER" "/var/lib/${SERVICE_NAME}"
chown root:root "$CONFIG_DIR"
chmod 755 "$CONFIG_DIR"
success "Permissions set"

# 5. Generate systemd service file based on type
log "Installing systemd service..."
case "$SERVICE_TYPE" in
    "combined")
        cat > "$SYSTEMD_DIR/${SERVICE_NAME}.service" << EOF
[Unit]
Description=PostgreSQL Backup Management Service
Documentation=https://github.com/your-repo/backup-service
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=/etc/backup-service
Environment="RUST_LOG=info"
Environment="RUST_BACKTRACE=1"

# Create log directory before starting
ExecStartPre=/bin/mkdir -p /var/log/backup-service
ExecStartPre=/bin/chown $SERVICE_USER:$SERVICE_USER /var/log/backup-service

# Main command with combined mode (default behavior)
ExecStart=$BINARY_PATH server \\
  --config-dir $CONFIG_DIR \\
  --backup-dir $BACKUP_DIR \\
  --port $PORT

# Restart configuration
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$CONFIG_DIR $BACKUP_DIR /var/log/backup-service

# Resource limits
LimitNOFILE=65536

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=backup-service

[Install]
WantedBy=multi-user.target
EOF
        SERVICE_FILE="${SERVICE_NAME}.service"
        ;;

    "rest")
        cat > "$SYSTEMD_DIR/${SERVICE_NAME}-rest.service" << EOF
[Unit]
Description=PostgreSQL Backup Management Service - REST API
Documentation=https://github.com/your-repo/backup-service
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=/etc/backup-service
Environment="RUST_LOG=info"
Environment="RUST_BACKTRACE=1"

# Create log directory before starting
ExecStartPre=/bin/mkdir -p /var/log/backup-service
ExecStartPre=/bin/chown $SERVICE_USER:$SERVICE_USER /var/log/backup-service

# REST API server command (without cronjob)
ExecStart=$BINARY_PATH server \\
  --config-dir $CONFIG_DIR \\
  --backup-dir $BACKUP_DIR \\
  --port $PORT \\
  --start-rest

# Restart configuration
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$CONFIG_DIR $BACKUP_DIR /var/log/backup-service

# Resource limits
LimitNOFILE=65536

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=backup-service-rest

[Install]
WantedBy=multi-user.target
EOF
        SERVICE_FILE="${SERVICE_NAME}-rest.service"
        ;;

    "cronjob")
        cat > "$SYSTEMD_DIR/${SERVICE_NAME}-cronjob@.service" << EOF
[Unit]
Description=PostgreSQL Backup Management Service - Cronjob Scheduler (%I)
Documentation=https://github.com/your-repo/backup-service
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=%i
Group=%i
WorkingDirectory=/etc/backup-service
Environment="RUST_LOG=info"
Environment="RUST_BACKTRACE=1"

# Create log directory before starting
ExecStartPre=/bin/mkdir -p /var/log/backup-service
ExecStartPre=/bin/chown %i:%i /var/log/backup-service

# Cronjob scheduler command (without REST API)
ExecStart=$BINARY_PATH server \\
  --config-dir $CONFIG_DIR \\
  --backup-dir $BACKUP_DIR \\
  --start-cronjob

# Restart configuration
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$CONFIG_DIR $BACKUP_DIR /var/log/backup-service

# Resource limits
LimitNOFILE=65536

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=backup-service-cronjob-%i

[Install]
WantedBy=multi-user.target
EOF
        SERVICE_FILE="${SERVICE_NAME}-cronjob@.service"
        ;;
esac

# 6. Set permissions for service file
chmod 644 "$SYSTEMD_DIR/$SERVICE_FILE"

# 7. Reload systemd
log "Reloading systemd daemon..."
systemctl daemon-reload
success "Systemd reloaded"

# 8. Enable service
log "Enabling service..."
if [ "$SERVICE_TYPE" = "cronjob" ]; then
    systemctl enable "${SERVICE_NAME}-cronjob@${SERVICE_USER}"
    success "Service '${SERVICE_NAME}-cronjob@${SERVICE_USER}' enabled"
else
    systemctl enable "$SERVICE_FILE"
    success "Service '$SERVICE_FILE' enabled"
fi

# 9. Create environment file for configuration
log "Creating environment file..."
cat > "/etc/default/${SERVICE_NAME}" << EOF
# PostgreSQL Backup Service Environment Configuration
SERVICE_TYPE=$SERVICE_TYPE
SERVICE_USER=$SERVICE_USER
PORT=$PORT
CONFIG_DIR=$CONFIG_DIR
BACKUP_DIR=$BACKUP_DIR
EOF

# 10. Show next steps
echo ""
success "🎉 Installation completed successfully!"
echo ""
echo "Installation Details:"
echo "  Service Type: $SERVICE_TYPE"
echo "  Service User: $SERVICE_USER"
echo "  Binary: $BINARY_PATH"
echo "  Config Directory: $CONFIG_DIR"
echo "  Backup Directory: $BACKUP_DIR"
echo "  Log Directory: $LOG_DIR"
echo "  Port: $PORT"
echo ""

# Service-specific instructions
case "$SERVICE_TYPE" in
    "combined")
        echo "Next Steps:"
        echo "  sudo systemctl start ${SERVICE_NAME}"
        echo "  sudo systemctl status ${SERVICE_NAME}"
        echo "  sudo journalctl -u ${SERVICE_NAME} -f"
        ;;
    "rest")
        echo "Next Steps:"
        echo "  sudo systemctl start ${SERVICE_NAME}-rest"
        echo "  sudo systemctl status ${SERVICE_NAME}-rest"
        echo "  sudo journalctl -u ${SERVICE_NAME}-rest -f"
        ;;
    "cronjob")
        echo "Next Steps:"
        echo "  sudo systemctl start ${SERVICE_NAME}-cronjob@${SERVICE_USER}"
        echo "  sudo systemctl status ${SERVICE_NAME}-cronjob@${SERVICE_USER}"
        echo "  sudo journalctl -u ${SERVICE_NAME}-cronjob@${SERVICE_USER} -f"
        ;;
esac

echo ""
echo "Configuration Management:"
echo "  ${BINARY_PATH} cronjob  # Manage cronjobs"
echo "  ${BINARY_PATH} run       # Interactive menu"
echo "  sudo nano /etc/default/${SERVICE_NAME}  # Edit environment"
echo ""
echo "Service Management:"
echo "  sudo systemctl ${SERVICE_NAME}-start"
echo "  sudo systemctl ${SERVICE_NAME}-stop"
echo "  sudo systemctl ${SERVICE_NAME}-restart"
echo ""
echo "Uninstallation:"
echo "  ./scripts/uninstall-backup-service.sh $SERVICE_TYPE $SERVICE_USER"
echo ""

success "Ready to start using PostgreSQL Backup Service!"