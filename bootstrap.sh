#!/bin/bash
# Ubuntu Server Setup Bootstrap Script
# Downloads and runs the complete linux-setup installation

set -e

echo "=== Ubuntu Server Setup Bootstrap ==="
echo "Starting automated server setup installation..."

# Create temporary directory for setup
TEMP_DIR="/tmp/linux-setup-$(date +%s)"
echo "Creating temporary directory: $TEMP_DIR"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Clone the repository
echo "Cloning linux-setup repository from GitHub..."
git clone https://github.com/moeenxyz/linux-setup.git .

# Make scripts executable
echo "Setting up executable permissions..."
chmod +x setup.sh
chmod +x verify.sh
find modules -name "*.sh" -exec chmod +x {} \;
find lib -name "*.sh" -exec chmod +x {} \;

# Create config if needed
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
fi

# Run the setup script
echo "Starting main setup script..."
echo "Note: You may be prompted to confirm the installation."
echo "Use './setup.sh --force' to skip confirmation prompts."

# Execute the setup script: first run a syntax-only check to avoid executing a broken file
if bash -n ./setup.sh >/dev/null 2>&1; then
    echo "setup.sh syntax check passed, executing..."
    ./setup.sh "$@"
else
    echo "Error: setup.sh contains a syntax error; aborting." >&2
    echo "Run 'bash -n setup.sh' in the cloned directory to see the parse error." >&2
    exit 1
fi
