#!/bin/bash
# Ubuntu Server Setup Bootstrap Script
# Downloads and runs the complete linux-setup installation

set -euo pipefail

# Colors for output
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
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root. Please run as a regular user with sudo privileges."
fi

# Check if sudo is available
if ! sudo -n true 2>/dev/null; then
    log "Testing sudo privileges..."
    if ! sudo -v; then
        error "This script requires sudo privileges. Please ensure your user has sudo access."
    fi
fi

log "=== Ubuntu Server Setup Bootstrap ==="
log "Starting automated server setup installation..."

# Create temporary directory for setup
TEMP_DIR="/tmp/linux-setup-$(date +%s)"
log "Creating temporary directory: $TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Clone the repository
REPO_URL="https://github.com/moeenxyz/linux-setup.git"
log "Cloning linux-setup repository from GitHub..."
if ! git clone "$REPO_URL" .; then
    error "Failed to clone repository. Please check your internet connection and try again."
fi

# Make scripts executable
log "Setting up executable permissions..."
chmod +x setup.sh
chmod +x verify.sh
if [[ -d "modules" ]]; then
    find modules -name "*.sh" -type f -exec chmod +x {} \;
fi
if [[ -d "lib" ]]; then
    find lib -name "*.sh" -type f -exec chmod +x {} \;
fi

# Check if .env file exists, create from example if not
if [[ ! -f ".env" && -f ".env.example" ]]; then
    log "Creating .env file from .env.example..."
    cp .env.example .env
    warn "Please review and customize the .env file for your configuration."
fi

# Run the setup script
log "Starting main setup script..."
log "Note: You may be prompted to confirm the installation."
log "Use './setup.sh --force' to skip confirmation prompts."

# Execute the setup script
./setup.sh "$@"</content>
<parameter name="filePath">/Users/moeen/Desktop/Codes/linux-setup/bootstrap.sh
