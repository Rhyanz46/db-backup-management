#!/bin/bash
# Uninstall PostgreSQL Backup Management Service

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SERVICE_NAME="backup-service"
BINARY_PATH="/usr/local/bin/${SERVICE_NAME}"
SYSTEMD_DIR="/etc/systemd/system"

# Parse Command Line Arguments
SERVICE_TYPE="${1:-combined}"
SERVICE_USER="${2:-backup-service}"
REMOVE_DATA="${3:-no}"

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

# Usage information
usage() {
    echo "Usage: $0 [SERVICE_TYPE] [USER] [REMOVE_DATA]"
    echo ""
    echo "SERVICE_TYPE options:"
    echo "  combined   - Combined service (default)"
    echo "  rest       - REST API service only"
    echo "  cronjob    - Cronjob scheduler service only"
    echo ""
    echo "REMOVE_DATA options:"
    echo "  no         - Keep configuration and backup data (default)"
    echo "  yes        - Remove all data directories"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 combined"
    echo "  $0 rest backup-service"
    echo "  $0 cronjob dev"
    echo "  $0 cronjob dev yes"
    exit 1
}

# Validate arguments
case "$SERVICE_TYPE" in
    combined|rest|cronjob) ;;
    *) error "Invalid service type: $SERVICE_TYPE"; usage ;;
esac

case "$REMOVE_DATA" in
    yes|no) ;;
    *) error "Invalid REMOVE_DATA option: $REMOVE_DATA"; usage ;;
esac

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

log "Uninstalling PostgreSQL Backup Service..."
echo ""

# Display what will be uninstalled
warning "Service Type: $SERVICE_TYPE"
warning "Service User: $SERVICE_USER"
if [ "$REMOVE_DATA" = "yes" ]; then
    warning "⚠️  ALL DATA WILL BE REMOVED"
else
    info "Configuration and backup data will be preserved"
fi
echo ""

# Confirm uninstallation
read -p "Are you sure you want to continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    error "Uninstallation cancelled"
    exit 1
fi

# 1. Stop and disable service
log "Stopping and disabling service..."
case "$SERVICE_TYPE" in
    "combined")
        if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
            systemctl stop "${SERVICE_NAME}"
            success "Service '${SERVICE_NAME}' stopped"
        fi
        if systemctl is-enabled --quiet "${SERVICE_NAME}" 2>/dev/null; then
            systemctl disable "${SERVICE_NAME}"
            success "Service '${SERVICE_NAME}' disabled"
        fi
        ;;
    "rest")
        if systemctl is-active --quiet "${SERVICE_NAME}-rest" 2>/dev/null; then
            systemctl stop "${SERVICE_NAME}-rest"
            success "Service '${SERVICE_NAME}-rest' stopped"
        fi
        if systemctl is-enabled --quiet "${SERVICE_NAME}-rest" 2>/dev/null; then
            systemctl disable "${SERVICE_NAME}-rest"
            success "Service '${SERVICE_NAME}-rest' disabled"
        fi
        ;;
    "cronjob")
        if systemctl is-active --quiet "${SERVICE_NAME}-cronjob@${SERVICE_USER}" 2>/dev/null; then
            systemctl stop "${SERVICE_NAME}-cronjob@${SERVICE_USER}"
            success "Service '${SERVICE_NAME}-cronjob@${SERVICE_USER}' stopped"
        fi
        if systemctl is-enabled --quiet "${SERVICE_NAME}-cronjob@${SERVICE_USER}" 2>/dev/null; then
            systemctl disable "${SERVICE_NAME}-cronjob@${SERVICE_USER}"
            success "Service '${SERVICE_NAME}-cronjob@${SERVICE_USER}' disabled"
        fi
        ;;
esac

# 2. Remove systemd service file
log "Removing systemd service file..."
case "$SERVICE_TYPE" in
    "combined")
        if [ -f "$SYSTEMD_DIR/${SERVICE_NAME}.service" ]; then
            rm "$SYSTEMD_DIR/${SERVICE_NAME}.service"
            success "Removed service file: ${SERVICE_NAME}.service"
        fi
        ;;
    "rest")
        if [ -f "$SYSTEMD_DIR/${SERVICE_NAME}-rest.service" ]; then
            rm "$SYSTEMD_DIR/${SERVICE_NAME}-rest.service"
            success "Removed service file: ${SERVICE_NAME}-rest.service"
        fi
        ;;
    "cronjob")
        if [ -f "$SYSTEMD_DIR/${SERVICE_NAME}-cronjob@.service" ]; then
            rm "$SYSTEMD_DIR/${SERVICE_NAME}-cronjob@.service"
            success "Removed service template: ${SERVICE_NAME}-cronjob@.service"
        fi
        ;;
esac

# 3. Remove binary
log "Removing binary..."
if [ -f "$BINARY_PATH" ]; then
    rm "$BINARY_PATH"
    success "Removed binary: $BINARY_PATH"
fi

# 4. Reload systemd
log "Reloading systemd daemon..."
systemctl daemon-reload
success "Systemd reloaded"

# 5. Remove environment file
log "Removing environment file..."
if [ -f "/etc/default/${SERVICE_NAME}" ]; then
    rm "/etc/default/${SERVICE_NAME}"
    success "Removed environment file"
fi

# 6. Optionally remove data
if [ "$REMOVE_DATA" = "yes" ]; then
    warning "Removing all data directories..."

    # Remove directories
    if [ -d "/etc/backup-service" ]; then
        rm -rf "/etc/backup-service"
        success "Removed configuration directory: /etc/backup-service"
    fi

    if [ -d "/var/log/backup-service" ]; then
        rm -rf "/var/log/backup-service"
        success "Removed log directory: /var/log/backup-service"
    fi

    if [ -d "/var/lib/${SERVICE_NAME}" ]; then
        rm -rf "/var/lib/${SERVICE_NAME}"
        success "Removed data directory: /var/lib/${SERVICE_NAME}"
    fi
else
    info "Data directories preserved:"
    info "  Configuration: /etc/backup-service"
    info "  Logs: /var/log/backup-service"
    info "  Data: /var/lib/${SERVICE_NAME}"
fi

# 7. Ask about removing user
read -p "Remove service user '$SERVICE_USER'? (y/N): " remove_user
if [[ "$remove_user" =~ ^[Yy]$ ]]; then
    if id "$SERVICE_USER" &>/dev/null; then
        userdel "$SERVICE_USER" 2>/dev/null || true
        success "Removed user: $SERVICE_USER"
    else
        info "User '$SERVICE_USER' does not exist"
    fi
fi

# 8. Show completion message
echo ""
success "🗑️  Uninstallation completed successfully!"
echo ""

# Show what was preserved (if any)
if [ "$REMOVE_DATA" = "no" ]; then
    echo "Preserved items:"
    echo "  ✅ Data directories and files"
    echo "  ✅ Configuration files"
    echo "  ✅ Backup files"
    echo ""
    echo "To remove data manually, run:"
    echo "  sudo rm -rf /etc/backup-service"
    echo "  sudo rm -rf /var/log/backup-service"
    echo "  sudo rm -rf /var/lib/${SERVICE_NAME}"
    echo ""
fi

echo "To completely remove all remaining files:"
echo "  sudo find /etc/systemd/system -name '*${SERVICE_NAME}*' -delete"
echo "  sudo systemctl daemon-reload"
echo ""

success "Uninstallation completed!"