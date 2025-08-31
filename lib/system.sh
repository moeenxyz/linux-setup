#!/bin/bash
# System validation functions for Ubuntu Server Setup

# Check if running as root or with sudo
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "Running as root - proceeding with installation"
    else
        log "Running as regular user - will use sudo when needed"
    fi
}

# Check sudo privileges
check_sudo() {
    if [[ $EUID -eq 0 ]]; then
        log "Running as root - sudo not needed"
    else
        if ! sudo -n true 2>/dev/null; then
            log "Testing sudo privileges..."
            if ! sudo -v; then
                error "This script requires sudo privileges."
                error "Please ensure your user has sudo access."
                exit 1
            fi
        fi
        log "Sudo privileges confirmed"
    fi
}

# Check if running on Ubuntu
check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine operating system"
        exit 1
    fi

    source /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        error "This script is designed for Ubuntu Linux only"
        error "Detected OS: $PRETTY_NAME"
        exit 1
    fi

    log "Running on: $PRETTY_NAME"
}

# Validate system requirements
validate_system() {
    log "Validating system requirements..."

    # Check architecture
    local arch=$(uname -m)
    case $arch in
        x86_64|aarch64|arm64)
            log "Architecture: $arch (supported)"
            ;;
        *)
            error "Unsupported architecture: $arch"
            error "This script supports x86_64, aarch64, and arm64 architectures"
            exit 1
            ;;
    esac

    # Check Ubuntu version
    source /etc/os-release
    local major_version=$(echo "$VERSION_ID" | cut -d. -f1)

    if [[ $major_version -lt 18 ]]; then
        error "Ubuntu version $VERSION_ID is not supported"
        error "Minimum required version: Ubuntu 18.04 LTS"
        exit 1
    fi

    log "System validation completed successfully"
}
