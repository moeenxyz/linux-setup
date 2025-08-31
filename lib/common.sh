#!/bin/bash
# Common functions and utilities for Ubuntu Server Setup
# This file contains shared functions used across all modules

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Input validation functions
validate_input() {
    local input="$1"
    local pattern="$2"
    local error_msg="$3"

    if [[ ! "$input" =~ $pattern ]]; then
        error "$error_msg"
        return 1
    fi
    return 0
}

validate_ssh_key() {
    local key="$1"

    # Basic SSH key format validation
    if [[ ! "$key" =~ ^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
        error "Invalid SSH key format. Must start with ssh-rsa, ssh-ed25519, etc."
        return 1
    fi

    # Check if key has at least 3 parts (type, key, comment)
    local parts
    IFS=' ' read -ra parts <<< "$key"
    if [[ ${#parts[@]} -lt 2 ]]; then
        error "Invalid SSH key format. Key must have at least type and key data."
        return 1
    fi

    return 0
}

# System utility functions
create_backup() {
    local file="$1"
    local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"

    if [[ -f "$file" ]]; then
        log "Creating backup of $file"
        sudo cp "$file" "$backup_file"
        log "Backup created: $backup_file"
    else
        warn "File $file does not exist, skipping backup"
    fi
}

check_service_status() {
    local service="$1"
    local timeout="${2:-30}"
    local count=0

    while [[ $count -lt $timeout ]]; do
        if sudo systemctl is-active --quiet "$service"; then
            log "Service $service is running"
            return 0
        fi
        sleep 1
        ((count++))
    done

    error "Service $service failed to start within $timeout seconds"
    return 1
}

# Configuration loading
load_config() {
    local config_file=".env"

    if [[ ! -f "$config_file" ]]; then
        error "Configuration file .env not found!"
        error "Please copy .env.example to .env and configure your settings."
        exit 1
    fi

    log "Loading configuration from $config_file"

    # Source the config file
    set -a
    source "$config_file"
    set +a

    log "Configuration loaded successfully"
}

# Get configuration value with fallback
get_config() {
    local var_name="$1"
    local default_value="${2:-}"

    # Try to get the variable value
    local value="${!var_name:-}"

    # If empty and default provided, use default
    if [[ -z "$value" && -n "$default_value" ]]; then
        value="$default_value"
    fi

    echo "$value"
}

# System resource checking
check_system_resources() {
    log "Checking system resources..."

    # Check available disk space
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local min_space=$((10*1024*1024)) # 10GB in KB

    if [[ $available_space -lt $min_space ]]; then
        error "Insufficient disk space. Need at least 10GB available."
        return 1
    fi

    # Check available memory
    local available_mem=$(free -m | awk 'NR==2 {print $7}')
    local min_mem=512 # 512MB

    if [[ $available_mem -lt $min_mem ]]; then
        warn "Low memory detected: ${available_mem}MB available"
        warn "Some installations may fail or perform slowly"
    fi

    log "System resources check completed"
    return 0
}

# Network connectivity check
check_network_connectivity() {
    log "Checking network connectivity..."

    # Test basic connectivity
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        error "No internet connectivity detected"
        return 1
    fi

    # Test DNS resolution
    if ! nslookup github.com >/dev/null 2>&1; then
        error "DNS resolution failed"
        return 1
    fi

    log "Network connectivity check passed"
    return 0
}

# Package management helpers
is_package_installed() {
    local package="$1"
    dpkg -l "$package" >/dev/null 2>&1
}

install_package() {
    local package="$1"

    if is_package_installed "$package"; then
        log "Package $package is already installed"
        return 0
    fi

    log "Installing package: $package"
    if ! sudo apt install -y "$package"; then
        error "Failed to install package: $package"
        return 1
    fi

    log "Package $package installed successfully"
    return 0
}

# User interaction helpers
prompt_user() {
    echo ""
    echo -e "${BLUE}=========================================="
    echo "    Ubuntu Server Setup Configuration"
    echo -e "==========================================${NC}"
    echo ""
    echo "The following components will be installed:"
    echo ""

    # Show installation plan
    [[ "${UPDATE_SYSTEM:-Y}" =~ ^[Yy]$ ]] && echo "  ✓ System updates"
    [[ "${INSTALL_GIT:-Y}" =~ ^[Yy]$ ]] && echo "  ✓ Git"
    [[ "${INSTALL_DOCKER:-Y}" =~ ^[Yy]$ ]] && echo "  ✓ Docker"
    [[ "${INSTALL_COMPOSE:-Y}" =~ ^[Yy]$ ]] && echo "  ✓ Docker Compose"
    [[ "${INSTALL_ZFS:-Y}" =~ ^[Yy]$ ]] && echo "  ✓ ZFS with server migration"
    [[ "${INSTALL_ESSENTIAL_TOOLS:-Y}" =~ ^[Yy]$ ]] && echo "  ✓ Essential tools"
    [[ "${INSTALL_ZSH:-Y}" =~ ^[Yy]$ ]] && echo "  ✓ Zsh with Oh My Zsh"
    [[ "${INSTALL_NODEJS:-Y}" =~ ^[Yy]$ ]] && echo "  ✓ Node.js LTS"
    [[ "${CONFIGURE_FIREWALL:-Y}" =~ ^[Yy]$ ]] && echo "  ✓ UFW firewall"
    [[ "${INSTALL_FAIL2BAN:-Y}" =~ ^[Yy]$ ]] && echo "  ✓ Fail2Ban"
    [[ "${INSTALL_CLOUDFLARED:-Y}" =~ ^[Yy]$ ]] && echo "  ✓ Cloudflared tunnel"
    [[ "${HARDEN_SSH:-Y}" =~ ^[Yy]$ ]] && echo "  ✓ SSH hardening"

    echo ""
    info "Configuration loaded from .env file"
    info "Press Enter to continue or Ctrl+C to cancel..."
    read -r || true
}
