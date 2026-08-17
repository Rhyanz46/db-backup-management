#!/bin/bash
# Manage PostgreSQL Backup Service

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SERVICE_NAME="backup-service"

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
    echo "Usage: $0 [COMMAND] [SERVICE_TYPE] [USER]"
    echo ""
    echo "COMMANDS:"
    echo "  start       Start service(s)"
    echo "  stop        Stop service(s)"
    echo "  restart     Restart service(s)"
    echo "  status      Show service status"
    echo "  logs        Show service logs"
    echo "  enable      Enable service(s)"
    echo "  disable     Disable service(s)"
    echo ""
    echo "SERVICE_TYPE:"
    echo "  combined    Combined service (default)"
    echo "  rest        REST API service only"
    echo "  cronjob     Cronjob scheduler service only"
    echo "  all         All services"
    echo ""
    echo "USER:"
    echo "  User name for cronjob services (required for cronjob)"
    echo "  Default: backup-service"
    echo ""
    echo "Examples:"
    echo "  $0 start combined                    # Start combined service"
    echo "  $0 start rest                        # Start REST API only"
    echo "  $0 start cronjob dev                # Start cronjob as user dev"
    echo "  $0 restart all                       # Restart all services"
    echo "  $0 status all dev admin             # Status of all services and specific users"
    echo ""
    exit 1
}

# Service name generation
get_service_name() {
    local service_type=$1
    local user=$2

    case "$service_type" in
        "combined")
            echo "${SERVICE_NAME}"
            ;;
        "rest")
            echo "${SERVICE_NAME}-rest"
            ;;
        "cronjob")
            echo "${SERVICE_NAME}-cronjob@${user}"
            ;;
        *)
            error "Unknown service type: $service_type"
            exit 1
            ;;
    esac
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Parse arguments
COMMAND="${1:-status}"
SERVICE_TYPE="${2:-combined}"
USER="${3:-backup-service}"

# Validate command
case "$COMMAND" in
    start|stop|restart|status|logs|enable|disable) ;;
    *) error "Unknown command: $COMMAND"; usage ;;
esac

# Handle 'all' service type
if [ "$SERVICE_TYPE" = "all" ]; then
    services=("combined" "rest")
else
    services=("$SERVICE_TYPE")
fi

# Function to check if user is needed
needs_user() {
    local service_type=$1
    [ "$service_type" = "cronjob" ]
}

# Function to perform action on a service
perform_action() {
    local command=$1
    local service_type=$2
    local user=$3

    if needs_user "$service_type" && [ -z "$user" ]; then
        error "User parameter required for cronjob service"
        return 1
    fi

    local service_name=$(get_service_name "$service_type" "$user")

    case "$command" in
        "start")
            info "Starting $service_name..."
            systemctl start "$service_name"
            ;;
        "stop")
            info "Stopping $service_name..."
            systemctl stop "$service_name"
            ;;
        "restart")
            info "Restarting $service_name..."
            systemctl restart "$service_name"
            ;;
        "status")
            info "Status of $service_name:"
            systemctl status "$service_name" --no-pager
            echo ""
            ;;
        "logs")
            info "Showing logs for $service_name (Ctrl+C to exit):"
            echo "==================================="
            journalctl -u "$service_name" -f
            ;;
        "enable")
            info "Enabling $service_name..."
            systemctl enable "$service_name"
            ;;
        "disable")
            info "Disabling $service_name..."
            systemctl disable "$service_name"
            ;;
    esac
}

# Execute commands
case "$COMMAND" in
    "logs")
        # For logs, handle one service at a time
        perform_action "$COMMAND" "$SERVICE_TYPE" "$USER"
        ;;
    *)
        # For other commands, process all services
        for service in "${services[@]}"; do
            if needs_user "$service" && [ "$SERVICE_TYPE" = "all" ]; then
                # Handle cronjob services for multiple users
                info "Checking for cronjob users..."
                # Get list of users with cronjob services
                for cronjob_service in $(systemctl list-units --type=service | grep "${SERVICE_NAME}-cronjob@" | awk '{print $1}'); do
                    echo ""
                    perform_action "$COMMAND" "cronjob" "$(echo $cronjob_service | sed 's/.*@//')"
                done
            else
                perform_action "$COMMAND" "$service" "$USER"
            fi
        done
        ;;
esac

# Summary for non-log commands
if [ "$COMMAND" != "logs" ]; then
    echo ""
    success "Command completed!"
fi