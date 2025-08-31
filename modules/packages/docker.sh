#!/bin/bash
# Docker installation and configuration module

install_docker_package() {
    if [[ ${INSTALL_DOCKER:-Y} =~ ^[Yy]$ ]]; then
        log "Installing Docker CE..."

        # Check if Docker is already installed
        if command -v docker >/dev/null 2>&1; then
            warn "Docker already installed. Skipping installation."
            return 0
        fi

        # Install prerequisites
        log "Installing Docker prerequisites..."
        sudo apt install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release

        # Add Docker's official GPG key
        log "Adding Docker GPG key..."
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        # Set up Docker repository
        log "Setting up Docker repository..."
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Update package index
        sudo apt update

        # Install Docker CE
        log "Installing Docker CE..."
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

                # Start and enable Docker service
                log "Starting Docker service..."
                sudo systemctl start docker
                sudo systemctl enable docker

                # Ensure docker group exists and add target user
                TARGET_USER="${SUDO_USER:-$USER}"
                log "Ensuring docker group exists and adding user $TARGET_USER to it..."
                sudo groupadd -f docker
                sudo usermod -aG docker "$TARGET_USER"

                # Configure daemon and socket permissions
                configure_docker_daemon() {
                        log "Configuring Docker daemon (/etc/docker/daemon.json)..."
                        sudo mkdir -p /etc/docker
                        sudo tee /etc/docker/daemon.json > /dev/null <<'JSON'
{
    "data-root": "/server-data/docker",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "features": {
        "buildkit": true
    }
}
JSON
                        # Restart docker to pick up configuration
                        sudo systemctl restart docker || warn "Could not restart docker after daemon config"

                        # Ensure socket group and permissions are correct
                        sudo chown root:docker /var/run/docker.sock || true
                        sudo chmod 660 /var/run/docker.sock || true

                        log "Docker daemon configuration applied"
                }

                configure_docker_daemon

                # Verify installation
                local docker_version=$(sudo docker --version 2>/dev/null | head -1 || echo "unknown")
                log "Docker installed: $docker_version"

                # Test Docker installation (use sudo to avoid group timing issues)
                log "Testing Docker installation..."
                if timeout 30s sudo docker run --rm hello-world >/dev/null 2>&1; then
                        log "Docker test successful"
                else
                        warn "Docker test failed or timed out"
                fi

                log "Docker CE installed successfully"
                warn "Please log out and log back in for Docker group changes to take effect (or run 'newgrp docker')"
    fi
}

install_compose_package() {
    if [[ ${INSTALL_COMPOSE:-Y} =~ ^[Yy]$ ]]; then
        log "Installing Docker Compose..."

        # Check if Docker Compose is already available
        if docker compose version >/dev/null 2>&1; then
            log "Docker Compose v2 already available via Docker CLI"
            return 0
        fi

        # Docker Compose v2 is included with Docker CE installation
        # But we can also install it separately if needed
        log "Docker Compose v2 is included with Docker CE"
        log "Verifying Docker Compose installation..."

        local compose_version=$(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo "unknown")
        log "Docker Compose: $compose_version"

        log "Docker Compose setup completed"
    fi
}
