#!/bin/bash

# PostgreSQL Backup Management System - Build Script for Linux

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
PROJECT_NAME="backup-service"
INSTALL_DIR="/opt/backup-service"
SERVICE_NAME="backup-service"
SERVICE_USER="backup-service"
SERVICE_PORT=8080

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_status "PostgreSQL Backup Management System - Linux Build Script"
print_status "========================================================"

# Check if running from project root
if [ ! -f "$PROJECT_ROOT/Cargo.toml" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check dependencies
print_status "Checking dependencies..."

if ! command -v cargo &> /dev/null; then
    print_error "Rust/Cargo not found. Please install Rust first."
    exit 1
fi

if ! pkg-config --exists openssl 2>/dev/null; then
    print_error "OpenSSL development headers not found."
    print_status "Run: ./scripts/install-deps.sh"
    exit 1
fi

print_success "Dependencies check passed"

# Clean previous build
if [ -d "$PROJECT_ROOT/target" ]; then
    print_status "Cleaning previous build..."
    cd "$PROJECT_ROOT"
    cargo clean
fi

# Build the project
print_status "Building PostgreSQL Backup Management System..."
cd "$PROJECT_ROOT"
cargo build --release

# Verify binary was created
if [ ! -f "target/release/$PROJECT_NAME" ]; then
    print_error "Build failed - binary not found"
    exit 1
fi

print_success "Build completed successfully!"
print_status "Binary location: $PROJECT_ROOT/target/release/$PROJECT_NAME"

# Test binary
print_status "Testing binary..."
./target/release/$PROJECT_NAME --version &> /dev/null
print_success "Binary test passed!"

# Get binary size
BINARY_SIZE=$(du -h "target/release/$PROJECT_NAME" | cut -f1)
print_status "Binary size: $BINARY_SIZE"

# Create installation directories
print_status "Creating installation directories..."
sudo mkdir -p "$INSTALL_DIR"/{bin,config,backup,logs}
print_success "Installation directories created"

# Copy binary to installation directory
print_status "Installing binary..."
sudo cp "target/release/$PROJECT_NAME" "$INSTALL_DIR/bin/"
sudo chmod +x "$INSTALL_DIR/bin/$PROJECT_NAME"
print_success "Binary installed to $INSTALL_DIR/bin/"

# Create config directories if they don't exist
if [ ! -d "$INSTALL_DIR/config" ]; then
    sudo mkdir -p "$INSTALL_DIR/config"
fi

if [ ! -d "$INSTALL_DIR/backup" ]; then
    sudo mkdir -p "$INSTALL_DIR/backup"
fi

print_success "Installation completed successfully!"
print_status ""
print_status "Binary location: $INSTALL_DIR/bin/$PROJECT_NAME"
print_status "Config directory: $INSTALL_DIR/config"
print_status "Backup directory: $INSTALL_DIR/backup"
print_status ""
print_status "Quick start commands:"
print_status "  sudo $INSTALL_DIR/bin/$PROJECT_NAME --help"
print_status "  sudo $INSTALL_DIR/bin/$PROJECT_NAME run"
print_status "  sudo $INSTALL_DIR/bin/$PROJECT_NAME server --port $SERVICE_PORT"