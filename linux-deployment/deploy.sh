#!/bin/bash

# PostgreSQL Backup Management System - One-Click Linux Deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE}  PostgreSQL Backup Management System   ${NC}"
    echo -e "${BOLD}${BLUE}  One-Click Linux Deployment         ${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Configuration
PROJECT_NAME="backup-service"
INSTALL_DIR="/opt/backup-service"
SERVICE_NAME="backup-service"
SERVICE_USER="backup-service"
SERVICE_PORT=8080

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if running as root for installation steps
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Installation requires root privileges"
        print_info "Please run: sudo $0"
        exit 1
    fi
}

# Step 1: Install dependencies
install_dependencies() {
    print_step "Installing system dependencies..."

    if [ -f "$SCRIPT_DIR/scripts/install-deps.sh" ]; then
        bash "$SCRIPT_DIR/scripts/install-deps.sh"
    else
        print_error "Dependency installer not found"
        exit 1
    fi

    print_success "Dependencies installed successfully"
}

# Step 2: Build the project
build_project() {
    print_step "Building PostgreSQL Backup Management System..."

    if [ -f "$SCRIPT_DIR/scripts/build.sh" ]; then
        bash "$SCRIPT_DIR/scripts/build.sh"
    else
        print_error "Build script not found"
        exit 1
    fi

    print_success "Project built successfully"
}

# Step 3: Set up systemd service
setup_service() {
    print_step "Setting up systemd service..."

    if [ -f "$SCRIPT_DIR/systemd/setup-service.sh" ]; then
        bash "$SCRIPT_DIR/systemd/setup-service.sh"
    else
        print_error "Service setup script not found"
        exit 1
    fi

    print_success "Systemd service configured"
}

# Step 4: Start the service
start_service() {
    print_step "Starting the backup service..."

    systemctl start "$SERVICE_NAME"
    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service started successfully"
    else
        print_error "Failed to start service"
        systemctl status "$SERVICE_NAME"
        exit 1
    fi
}

# Step 5: Verify installation
verify_installation() {
    print_step "Verifying installation..."

    # Check service status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Service is running"
    else
        print_error "Service is not running"
        return 1
    fi

    # Check API endpoint
    sleep 2
    if curl -s "http://localhost:$SERVICE_PORT/health" > /dev/null; then
        print_success "REST API is responding"
    else
        print_warning "REST API not responding (this is normal if PostgreSQL is not configured)"
    fi

    # Test binary
    if [ -x "$INSTALL_DIR/bin/$PROJECT_NAME" ]; then
        print_success "Binary is executable"
    else
        print_error "Binary is not executable"
        return 1
    fi
}

# Show final instructions
show_instructions() {
    print_success "🎉 Installation completed successfully!"
    echo
    print_info "${BOLD}Service Management:${NC}"
    echo "  systemctl start $SERVICE_NAME      - Start service"
    echo "  systemctl stop $SERVICE_NAME       - Stop service"
    echo "  systemctl restart $SERVICE_NAME    - Restart service"
    echo "  systemctl status $SERVICE_NAME     - Check status"
    echo "  journalctl -u $SERVICE_NAME -f     - View logs"
    echo
    print_info "${BOLD}CLI Usage:${NC}"
    echo "  sudo $INSTALL_DIR/bin/$PROJECT_NAME run              - Interactive CLI"
    echo "  sudo $INSTALL_DIR/bin/$PROJECT_NAME list             - List backups"
    echo "  sudo $INSTALL_DIR/bin/$PROJECT_NAME backup           - Create backup"
    echo
    print_info "${BOLD}REST API:${NC}"
    echo "  http://localhost:$SERVICE_PORT/health              - Health check"
    echo "  POST http://localhost:$SERVICE_PORT/backup         - Trigger backup"
    echo "  GET  http://localhost:$SERVICE_PORT/backup          - List backups"
    echo
    print_info "${BOLD}Configuration:${NC}"
    echo "  $INSTALL_DIR/config/servers.json     - Server configurations"
    echo "  $INSTALL_DIR/config/telegram.json    - Telegram settings"
    echo "  $INSTALL_DIR/backup/                 - Backup files"
    echo
    print_info "${BOLD}Next Steps:${NC}"
    echo "  1. Configure your PostgreSQL servers: sudo nano $INSTALL_DIR/config/servers.json"
    echo "  2. Set up active server using CLI: sudo $INSTALL_DIR/bin/$PROJECT_NAME run"
    echo "  3. Configure notifications (optional): sudo nano $INSTALL_DIR/config/telegram.json"
    echo
    print_info "${BOLD}Documentation:${NC}"
    echo "  README.md - Complete user guide"
    echo "  $PROJECT_NAME --help - CLI help"
}

# Main deployment function
main() {
    print_header

    # Check arguments
    SKIP_DEPS=false
    SKIP_BUILD=false
    SKIP_SERVICE=false
    SKIP_START=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --skip-service)
                SKIP_SERVICE=true
                shift
                ;;
            --skip-start)
                SKIP_START=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --skip-deps     Skip dependency installation"
                echo "  --skip-build    Skip project build"
                echo "  --skip-service  Skip systemd service setup"
                echo "  --skip-start    Skip service start"
                echo "  --help, -h      Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Ask for confirmation if not running as root and will need root later
    if [ "$EUID" -ne 0 ] && [ "$SKIP_SERVICE" = false ]; then
        print_info "This script will require root privileges for service setup"
        print_info "You will be prompted for sudo password when needed"
        echo
    fi

    # Run deployment steps
    [ "$SKIP_DEPS" = false ] && install_dependencies
    [ "$SKIP_BUILD" = false ] && build_project

    # Service setup requires root
    if [ "$SKIP_SERVICE" = false ]; then
        check_root
        setup_service
    fi

    [ "$SKIP_START" = false ] && start_service
    verify_installation
    show_instructions
}

# Run main function with all arguments
main "$@"