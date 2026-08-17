#!/bin/bash
# Health check for PostgreSQL Backup Service

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

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

# Configuration
SERVICE_NAME="backup-service"
BINARY_PATH="/usr/local/bin/${SERVICE_NAME}"
CONFIG_DIR="/etc/backup-service/config"
BACKUP_DIR="/etc/backup-service/backup"
LOG_DIR="/var/log/backup-service"

print_header() {
    echo ""
    echo "🔍 PostgreSQL Backup Service Health Check"
    echo "========================================"
    echo ""
}

check_binary() {
    log "Checking binary installation..."
    if [ -f "$BINARY_PATH" ]; then
        local version=$("$BINARY_PATH" --version 2>/dev/null || echo "unknown")
        success "✅ Binary found: $BINARY_PATH (version: $version)"
        return 0
    else
        error "❌ Binary not found: $BINARY_PATH"
        return 1
    fi
}

check_directories() {
    log "Checking directories..."

    # Config directory
    if [ -d "$CONFIG_DIR" ]; then
        local config_files=$(find "$CONFIG_DIR" -type f -name "*.json" | wc -l)
        success "✅ Config directory exists: $CONFIG_DIR ($config_files files)"
    else
        error "❌ Config directory missing: $CONFIG_DIR"
        return 1
    fi

    # Backup directory
    if [ -d "$BACKUP_DIR" ]; then
        local backup_count=$(find "$BACKUP_DIR" -name "*.sql" | wc -l)
        local backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
        success "✅ Backup directory exists: $BACKUP_DIR ($backup_count backups, $backup_size)"
    else
        warning "⚠️  Backup directory missing: $BACKUP_DIR"
        return 1
    fi

    # Log directory
    if [ -d "$LOG_DIR" ]; then
        local log_size=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1)
        success "✅ Log directory exists: $LOG_DIR ($log_size)"
    else
        warning "⚠️  Log directory missing: $LOG_DIR"
    fi
}

check_systemd_services() {
    log "Checking systemd services..."

    # Check for different service types
    local services=()

    # Combined service
    if systemctl list-unit-files | grep -q "${SERVICE_NAME}.service"; then
        services+=("combined")
    fi

    # REST service
    if systemctl list-unit-files | grep -q "${SERVICE_NAME}-rest.service"; then
        services+=("rest")
    fi

    # Cronjob services
    local cronjob_services=$(systemctl list-unit-files | grep "${SERVICE_NAME}-cronjob@" | awk '{print $1}')
    if [ -n "$cronjob_services" ]; then
        services+=("cronjob")
    fi

    if [ ${#services[@]} -eq 0 ]; then
        error "❌ No systemd services found"
        return 1
    fi

    for service_type in "${services[@]}"; do
        case "$service_type" in
            "combined")
                check_service_status "${SERVICE_NAME}" "Combined"
                ;;
            "rest")
                check_service_status "${SERVICE_NAME}-rest" "REST API"
                ;;
            "cronjob")
                echo "  🔍 Checking cronjob services:"
                for cronjob_service in $cronjob_services; do
                    local service_name=$(basename "$cronjob_service" .service)
                    local user=$(echo "$cronjob_service" | sed 's/.*@//' | sed 's/\.service//')
                    check_service_status "$cronjob_service" "Cronjob ($user)"
                done
                ;;
        esac
    done
}

check_service_status() {
    local service=$1
    local description=$2

    # Check if enabled
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        local enabled_status="Enabled"
    else
        local enabled_status="Disabled"
    fi

    # Check if running
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        success "✅ $description: Running ($enabled_status)"
        # Show additional info
        local memory=$(systemctl show "$service" --property=MemoryCurrent | cut -d'=' -f2)
        local cpu=$(systemctl show "$service" --property=CPUUsageNS | cut -d'=' -f2)
        echo "    📊 Memory: ${memory:-N/A} | CPU: ${cpu:-N/A}"
    else
        error "❌ $description: Not running ($enabled_status)"
        # Show recent errors
        local recent_logs=$(journalctl -u "$service" --since "5 minutes ago" --no-pager -p err --no-full | wc -l)
        if [ "$recent_logs" -gt 0 ]; then
            warning "  ⚠️  $recent_logs error(s) in last 5 minutes"
        fi
    fi
}

check_configuration() {
    log "Checking configuration files..."

    # Server configuration
    if [ -f "$CONFIG_DIR/servers.json" ]; then
        local server_count=$(jq -r '.servers | length' "$CONFIG_DIR/servers.json" 2>/dev/null || echo "unknown")
        if [ "$server_count" != "unknown" ]; then
            success "✅ Server configuration: $server_count servers configured"

            # Check active server
            local active_server=$(jq -r '.active_server' "$CONFIG_DIR/servers.json" 2>/dev/null || echo "none")
            if [ "$active_server" != "null" ] && [ "$active_server" != "none" ]; then
                success "  🎯 Active server: $active_server"
            else
                warning "  ⚠️  No active server configured"
            fi
        else
            warning "  ⚠️  Server configuration file found but invalid JSON"
        fi
    else
        error "❌ Server configuration not found: $CONFIG_DIR/servers.json"
        return 1
    fi

    # Telegram configuration (optional)
    if [ -f "$CONFIG_DIR/telegram.json" ]; then
        if jq -e . "$CONFIG_DIR/telegram.json" >/dev/null 2>&1; then
            success "✅ Telegram configuration found and valid"
        else
            warning "⚠️  Telegram configuration found but invalid"
        fi
    else
        info "ℹ️  Telegram configuration not found (optional)"
    fi

    # Cronjob configuration
    if [ -f "$CONFIG_DIR/cronjobs.json" ]; then
        if jq -e . "$CONFIG_DIR/cronjobs.json" >/dev/null 2>&1; then
            local job_count=$(jq -r '. | length' "$CONFIG_DIR/cronjobs.json" 2>/dev/null || echo "0")
            local enabled_count=$(jq -r '[.[] | select(.enabled == true)] | length' "$CONFIG_DIR/cronjobs.json" 2>/dev/null || echo "0")
            success "✅ Cronjob configuration: $job_count jobs ($enabled_count enabled)"
        else
            warning "⚠️  Cronjob configuration found but invalid JSON"
        fi
    else
        info "ℹ️  No cronjob configuration found"
    fi
}

check_connectivity() {
    log "Testing database connectivity..."

    if [ -f "$CONFIG_DIR/servers.json" ] && jq -e . "$CONFIG_DIR/servers.json" >/dev/null 2>&1; then
        local active_server=$(jq -r '.active_server' "$CONFIG_DIR/servers.json" 2>/dev/null)
        if [ "$active_server" != "null" ] && [ "$active_server" != "none" ]; then
            local server_info=$(jq -r ".servers[] | select(.name == \"$active_server\")" "$CONFIG_DIR/servers.json")
            local host=$(echo "$server_info" | jq -r '.host')
            local port=$(echo "$server_info" | jq -r '.port')
            local database=$(echo "$server_info" | jq -r '.database')

            # Test using our binary
            log "  Testing connection to $host:$port/$database..."
            if "$BINARY_PATH" test --server "$active_server" >/dev/null 2>&1; then
                success "  ✅ Database connection successful"
            else
                error "  ❌ Database connection failed"
                echo "    💡 Try: $BINARY_PATH test --server $active_server"
            fi
        else
            warning "⚠️  No active server to test connectivity"
        fi
    else
        warning "⚠️  Cannot test connectivity - no valid server configuration"
    fi
}

check_recent_activity() {
    log "Checking recent activity..."

    # Recent backups
    if [ -d "$BACKUP_DIR" ]; then
        local recent_backups=$(find "$BACKUP_DIR" -name "*.sql" -mtime -7 | wc -l)
        if [ "$recent_backups" -gt 0 ]; then
            success "✅ Recent activity: $recent_backups backups in last 7 days"
            local latest_backup=$(find "$BACKUP_DIR" -name "*.sql" -printf '%T %p\n' | sort -n | tail -1 | cut -d' ' -f2)
            if [ -n "$latest_backup" ]; then
                local backup_date=$(stat -c %y "$latest_backup" 2>/dev/null || echo "unknown")
                local backup_size=$(du -h "$latest_backup" 2>/dev/null | cut -f1)
                success "  📦 Latest backup: $backup_date ($backup_size)"
            fi
        else
            warning "⚠️  No recent backups found"
        fi
    fi

    # Service logs
    local recent_errors=$(journalctl -u "${SERVICE_NAME}*" --since "1 day ago" -p err --no-pager --no-full | wc -l)
    if [ "$recent_errors" -gt 0 ]; then
        warning "⚠️  $recent_errors error(s) in last 24 hours"
    else
        success "✅ No errors in last 24 hours"
    fi
}

# Main execution
print_header

# Overall status
OVERALL_STATUS=0

echo "📋 System Information:"
echo "  OS: $(uname -s) $(uname -r)"
echo "  Architecture: $(uname -m)"
echo "  User: $(whoami)"
echo "  Date: $(date)"
echo ""

# Perform checks
check_binary || OVERALL_STATUS=1
echo ""
check_directories || OVERALL_STATUS=1
echo ""
check_systemd_services || OVERALL_STATUS=1
echo ""
check_configuration || OVERALL_STATUS=1
echo ""
check_connectivity || OVERALL_STATUS=1
echo ""
check_recent_activity

print_header

# Overall result
if [ $OVERALL_STATUS -eq 0 ]; then
    success "🎉 Overall Health: EXCELLENT"
    echo "All systems are operating normally!"
else
    error "❌ Overall Health: NEEDS ATTENTION"
    echo "Some issues were found that require resolution."
fi

echo ""
echo "📋 Quick Actions:"
echo "  View logs: ./scripts/manage-backup-service.sh logs [service]"
echo "  Test connection: $BINARY_PATH test"
echo "  Manage servers: $BINARY_PATH run"
echo "  View configuration: $BINARY_PATH cronjob"
echo ""

exit $OVERALL_STATUS