#!/bin/bash

# PostgreSQL Backup Management System - Dependencies Installer
# Supports: Ubuntu/Debian, RHEL/CentOS, Fedora, Arch Linux, openSUSE

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_VERSION=$VERSION_ID
        print_status "Detected distribution: $DISTRO $DISTRO_VERSION"
    else
        print_error "Cannot detect Linux distribution"
        exit 1
    fi
}

# Install dependencies based on distribution
install_dependencies() {
    case $DISTRO in
        ubuntu|debian)
            print_status "Installing dependencies for Ubuntu/Debian..."
            sudo apt-get update
            sudo apt-get install -y \
                pkg-config \
                libssl-dev \
                postgresql-client \
                build-essential \
                curl \
                wget \
                unzip
            ;;

        rhel|centos)
            print_status "Installing dependencies for RHEL/CentOS..."
            sudo yum groupinstall -y "Development Tools"
            sudo yum install -y \
                pkgconfig \
                openssl-devel \
                postgresql \
                curl \
                wget \
                unzip
            ;;

        fedora)
            print_status "Installing dependencies for Fedora..."
            sudo dnf groupinstall -y "Development Tools"
            sudo dnf install -y \
                pkgconfig \
                openssl-devel \
                postgresql \
                curl \
                wget \
                unzip
            ;;

        arch)
            print_status "Installing dependencies for Arch Linux..."
            sudo pacman -S --needed \
                pkgconf \
                openssl \
                postgresql \
                base-devel \
                curl \
                wget \
                unzip
            ;;

        opensuse-leap)
            print_status "Installing dependencies for openSUSE Leap..."
            sudo zypper install -y \
                pkg-config \
                libopenssl-devel \
                postgresql \
                pattern:devel_basis \
                curl \
                wget \
                unzip
            ;;

        *)
            print_error "Unsupported distribution: $DISTRO"
            print_status "Please manually install:"
            print_status "  - pkg-config"
            print_status "  - OpenSSL development headers (libssl-dev or openssl-devel)"
            print_status "  - PostgreSQL client tools"
            print_status "  - Build tools (gcc, make)"
            exit 1
            ;;
    esac
}

# Check if Rust is installed
install_rust() {
    if ! command -v cargo &> /dev/null; then
        print_warning "Rust not found. Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
        print_success "Rust installed successfully"
    else
        print_success "Rust is already installed"
        rustup update
    fi
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."

    # Check pkg-config
    if pkg-config --exists openssl; then
        print_success "OpenSSL development headers found"
    else
        print_error "OpenSSL development headers not found"
        exit 1
    fi

    # Check Rust
    if cargo --version &> /dev/null; then
        print_success "Cargo (Rust) is working"
    else
        print_error "Cargo (Rust) not working"
        exit 1
    fi

    # Check PostgreSQL client
    if psql --version &> /dev/null || pg_dump --version &> /dev/null; then
        print_success "PostgreSQL client tools found"
    else
        print_warning "PostgreSQL client tools not found in PATH"
        print_status "You may need to add PostgreSQL to your PATH"
    fi
}

# Main installation function
main() {
    print_status "PostgreSQL Backup Management System - Dependencies Installer"
    print_status "=========================================================="

    detect_distro
    install_dependencies
    install_rust
    verify_installation

    print_success "All dependencies installed successfully!"
    print_status "You can now build the project with: cargo build --release"
}

# Run main function
main "$@"