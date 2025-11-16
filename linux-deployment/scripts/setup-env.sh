#!/bin/bash

# PostgreSQL Backup Management System - Environment Setup Script
# Sets up environment files and directories for different deployment types

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/linux-deployment/configs"

# Detect environment type
detect_environment() {
    case "$1" in
        production)
            ENV_FILE="production"
            INSTALL_DIR="/opt/backup-service"
            SERVICE_USER="backup-service"
            SERVICE_GROUP="backup-service"
            REST_PORT="8080"
            LOG_LEVEL="info"
            ;;
        development)
            ENV_FILE="development"
            INSTALL_DIR="/home/$USER/backup-service"
            SERVICE_USER="$USER"
            SERVICE_GROUP="$(id -gn)"
            REST_PORT="8081"
            LOG_LEVEL="debug"
            ;;
        staging|test)
            ENV_FILE="development"  # Use dev config for staging/test
            INSTALL_DIR="/opt/backup-service-staging"
            SERVICE_USER="backup-service"
            SERVICE_GROUP="backup-service"
            REST_PORT="8082"
            LOG_LEVEL="debug"
            ;;
        *)
            print_error "Invalid environment. Use: production, development, staging, or test"
            exit 1
            ;;
    esac
}

# Create environment file
create_env_file() {
    print_status "Creating environment file for $ENV_TYPE environment..."

    local ENV_FILE_PATH="$PROJECT_ROOT/.env"

    # Copy template and customize
    cp "$CONFIG_DIR/.env.$ENV_FILE" "$ENV_FILE_PATH"

    # Customize environment-specific settings
    sed -i "s|INSTALL_DIR=.*|INSTALL_DIR=$INSTALL_DIR|g" "$ENV_FILE_PATH"
    sed -i "s|SERVICE_USER=.*|SERVICE_USER=$SERVICE_USER|g" "$ENV_FILE_PATH"
    sed -i "s|SERVICE_GROUP=.*|SERVICE_GROUP=$SERVICE_GROUP|g" "$ENV_FILE_PATH"
    sed -i "s|REST_PORT=.*|REST_PORT=$REST_PORT|g" "$ENV_FILE_PATH"
    sed -i "s|RUST_LOG=.*|RUST_LOG=$LOG_LEVEL|g" "$ENV_FILE_PATH"
    sed -i "s|APP_WORKDIR=.*|APP_WORKDIR=$INSTALL_DIR|g" "$ENV_FILE_PATH"
    sed -i "s|CONFIG_DIR=.*|CONFIG_DIR=$INSTALL_DIR/config|g" "$ENV_FILE_PATH"
    sed -i "s|BACKUP_DIR=.*|BACK_DIR=$INSTALL_DIR/backup|g" "$ENV_FILE_PATH"
    sed -i "s|LOG_DIR=.*|LOG_DIR=/var/log/backup-service|g" "$ENV_FILE_PATH"

    # Add system detection info
    sed -i "s|DETECTED_OS=.*|DETECTED_OS=$(uname -s)|g" "$ENV_FILE_PATH"
    sed -i "s|DETECTED_ARCH=.*|DETECTED_ARCH=$(uname -m)|g" "$ENV_FILE_PATH"

    # Try to detect Linux distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        sed -i "s|DETECTED_DISTRO=.*|DETECTED_DISTRO=$ID|g" "$ENV_FILE_PATH"
    fi

    # Add build timestamp
    sed -i "s|BUILD_TIMESTAMP=.*|BUILD_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)|g" "$ENV_FILE_PATH"

    # Add git commit if in git repo
    if git rev-parse --git-dir > /dev/null 2>&1; then
        sed -i "s|BUILD_COMMIT=.*|BUILD_COMMIT=$(git rev-parse HEAD)|g" "$ENV_FILE_PATH"
    fi

    print_success "Environment file created: $ENV_FILE_PATH"
}

# Create directories
create_directories() {
    print_status "Creating directories..."

    # Create backup directory
    if [ ! -d "$INSTALL_DIR/backup" ]; then
        mkdir -p "$INSTALL_DIR/backup"
        print_success "Created backup directory: $INSTALL_DIR/backup"
    fi

    # Create config directory
    if [ ! -d "$INSTALL_DIR/config" ]; then
        mkdir -p "$INSTALL_DIR/config"
        print_success "Created config directory: $INSTALL_DIR/config"
    fi

    # Create log directory for development
    if [ "$ENV_TYPE" = "development" ]; then
        if [ ! -d "$PROJECT_ROOT/logs" ]; then
            mkdir -p "$PROJECT_ROOT/logs"
            print_success "Created log directory: $PROJECT_ROOT/logs"
        fi
    fi
}

# Setup permissions
setup_permissions() {
    print_status "Setting up permissions..."

    # Set ownership and permissions
    if [ "$EUID" -eq 0 ]; then
        # Running as root
        chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR"
        chmod 755 "$INSTALL_DIR"
        chmod 700 "$INSTALL_DIR"/{config,backup}
        print_success "Set permissions for $INSTALL_DIR"
    else
        # Running as regular user (development)
        chmod 755 "$INSTALL_DIR"
        chmod 700 "$INSTALL_DIR"/{config,backup}
        print_success "Set permissions for $INSTALL_DIR"
    fi
}

# Create startup script
create_startup_script() {
    print_status "Creating startup script..."

    local STARTUP_SCRIPT="$INSTALL_DIR/backup-service-env.sh"

    cat > "$STARTUP_SCRIPT" << 'EOF'
#!/bin/bash
# PostgreSQL Backup Management System - Environment Loader
# Load environment variables before running the service

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment file
if [ -f "$SCRIPT_DIR/../.env" ]; then
    export $(cat "$SCRIPT_DIR/../.env | grep -v '^#' | xargs)
else
    echo "Warning: Environment file not found"
fi

# Add current directory to PATH
export PATH="$SCRIPT_DIR/bin:$PATH"

# Set working directory
export APP_WORKDIR="${APP_WORKDIR:-$SCRIPT_DIR}"
cd "$APP_WORKDIR"

# Display environment info
echo "PostgreSQL Backup Management System Environment:"
echo "  App Name: $APP_NAME"
echo "  Version: $APP_VERSION"
echo "  Working Dir: $APP_WORKDIR"
echo "  Config Dir: $CONFIG_DIR"
echo "  Backup Dir: $BACKUP_DIR"
echo "  Log Level: $RUST_LOG"
echo "  Rest Port: $REST_PORT"
echo ""
EOF

    chmod +x "$STARTUP_SCRIPT"
    print_success "Created startup script: $STARTUP_SCRIPT"
}

# Generate environment summary
generate_summary() {
    print_status "Environment Setup Summary:"
    echo
    echo -e "${BOLD}Environment Type:${NC} $ENV_TYPE"
    echo -e "${BOLD}Installation Directory:${NC} $INSTALL_DIR"
    echo -e "${BOLD}Service User:${NC} $SERVICE_USER"
    echo -e "${BOLD}REST Port:${NC} $REST_PORT"
    echo -e "${BOLD}Log Level:${NC} $LOG_LEVEL"
    echo
    echo -e "${BOLD}Generated Files:${NC}"
    echo "  - $PROJECT_ROOT/.env"
    echo "  - $INSTALL_DIR/backup-service-env.sh"
    echo
    echo -e "${BOLD}Next Steps:${NC}"
    echo "  1. Review environment: nano $PROJECT_ROOT/.env"
    echo "  2. Run the service: cd $PROJECT_ROOT && ./target/release/backup-service --help"
    echo "  3. Test configuration: ./target/release/backup-service run"
    echo
}

# Main function
main() {
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE}  PostgreSQL Backup Management System  ${NC}"
    echo -e "${BOLD}${BLUE}  Environment Setup Tool              ${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo

    ENV_TYPE="$1"
    if [ -z "$ENV_TYPE" ]; then
        echo -e "${YELLOW}Usage: $0 <environment_type>${NC}"
        echo -e "${YELLOW}Environment types: production, development, staging, test${NC}"
        exit 1
    fi

    print_status "Setting up $ENV_TYPE environment..."
    detect_environment "$ENV_TYPE"
    create_env_file
    create_directories
    setup_permissions
    create_startup_script
    generate_summary

    print_success "Environment setup completed!"
}

# Run main function with arguments
main "$@"