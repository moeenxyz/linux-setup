#!/bin/bash
# Cloudflared installation and configuration module

install_cloudflared_package() {
    if [[ ${INSTALL_CLOUDFLARED:-Y} =~ ^[Yy]$ ]]; then
        log "Installing Cloudflared for secure tunnel access..."

        # Check if Cloudflared is already installed
        if command -v cloudflared >/dev/null 2>&1; then
            warn "Cloudflared already installed. Checking version..."
            local current_version=$(cloudflared version 2>/dev/null | head -1 || echo "unknown")
            log "Current Cloudflared version: $current_version"
            return 0
        fi

        # Detect architecture
        local arch=$(uname -m)
        local cloudflared_arch=""

        case $arch in
            x86_64)
                cloudflared_arch="amd64"
                ;;
            aarch64|arm64)
                cloudflared_arch="arm64"
                ;;
            armv7l|armhf)
                cloudflared_arch="arm"
                ;;
            *)
                error "Unsupported architecture for Cloudflared: $arch"
                return 1
                ;;
        esac

        log "Detected architecture: $arch -> Cloudflared arch: $cloudflared_arch"

        # Download and install Cloudflared
        log "Downloading Cloudflared for $cloudflared_arch..."

        # Get the latest release version
        local latest_version=$(curl -s https://api.github.com/repos/cloudflare/cloudflared/releases/latest | grep '"tag_name"' | cut -d '"' -f 4 | sed 's/v//')

        if [[ -z "$latest_version" ]]; then
            error "Failed to get latest Cloudflared version"
            return 1
        fi

        log "Latest Cloudflared version: $latest_version"

        # Construct download URL
        local download_url="https://github.com/cloudflare/cloudflared/releases/download/${latest_version}/cloudflared-linux-${cloudflared_arch}"

        log "Download URL: $download_url"

        # Download and install
        if ! curl -L "$download_url" -o /tmp/cloudflared; then
            error "Failed to download Cloudflared from $download_url"
            return 1
        fi

        sudo chmod +x /tmp/cloudflared
        sudo mv /tmp/cloudflared /usr/local/bin/cloudflared

        # Verify installation
        if ! command -v cloudflared >/dev/null 2>&1; then
            error "Cloudflared installation failed"
            return 1
        fi

        local installed_version=$(cloudflared version 2>/dev/null | head -1 || echo "unknown")
        log "Cloudflared installed successfully: $installed_version"

        # Create cloudflared user and directories
        log "Setting up Cloudflared user and directories..."

        # Create cloudflared user if it doesn't exist
        if ! id -u cloudflared >/dev/null 2>&1; then
            sudo useradd -r -s /usr/sbin/nologin cloudflared
        fi

        # Create configuration directory
        sudo mkdir -p /etc/cloudflared
        sudo chown cloudflared:cloudflared /etc/cloudflared
        sudo chmod 755 /etc/cloudflared

        # Create log directory
        sudo mkdir -p /var/log/cloudflared
        sudo chown cloudflared:cloudflared /var/log/cloudflared
        sudo chmod 755 /var/log/cloudflared

        # Create credential directory
        sudo mkdir -p /etc/cloudflared/creds
        sudo chown cloudflared:cloudflared /etc/cloudflared/creds
        sudo chmod 700 /etc/cloudflared/creds

        # Configure Cloudflared service
        configure_cloudflared_service

        # Create tunnel configuration
        create_tunnel_config

        # Set up firewall rules for Cloudflared
        setup_cloudflared_firewall

        log "Cloudflared installation and configuration completed"
    fi
}

configure_cloudflared_service() {
    log "Configuring Cloudflared systemd service..."

    # Create systemd service file
    sudo tee /etc/systemd/system/cloudflared.service > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target

[Service]
Type=simple
User=cloudflared
Group=cloudflared
ExecStart=/usr/local/bin/cloudflared tunnel run --config /etc/cloudflared/config.yml
Restart=always
RestartSec=5
Environment=TUNNEL_ORIGIN_CERT=/etc/cloudflared/cert.pem

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable cloudflared

    log "Cloudflared systemd service configured"
}

create_tunnel_config() {
    log "Creating Cloudflared tunnel configuration..."

    # Get tunnel configuration from environment
    local tunnel_name="${CLOUDFLARED_TUNNEL_NAME:-$(hostname)-tunnel}"
    local tunnel_uuid="${CLOUDFLARED_TUNNEL_UUID:-}"
    local tunnel_secret="${CLOUDFLARED_TUNNEL_SECRET:-}"

    # Create basic configuration
    sudo tee /etc/cloudflared/config.yml > /dev/null <<EOF
tunnel: $tunnel_name
credentials-file: /etc/cloudflared/creds/credentials.json

ingress:
  - hostname: ${CLOUDFLARED_DOMAIN:-your-domain.com}
    service: http://localhost:80
  - hostname: api.${CLOUDFLARED_DOMAIN:-your-domain.com}
    service: http://localhost:3000
  - hostname: ssh.${CLOUDFLARED_DOMAIN:-your-domain.com}
    service: ssh://localhost:22
  - service: http_status:404
EOF

    # Set proper permissions
    sudo chown cloudflared:cloudflared /etc/cloudflared/config.yml
    sudo chmod 644 /etc/cloudflared/config.yml

    # Create credentials file if tunnel UUID and secret are provided
    if [[ -n "$tunnel_uuid" && -n "$tunnel_secret" ]]; then
        log "Creating tunnel credentials file..."

        sudo tee /etc/cloudflared/creds/credentials.json > /dev/null <<EOF
{
  "AccountTag": "$tunnel_uuid",
  "TunnelSecret": "$tunnel_secret"
}
EOF

        sudo chown cloudflared:cloudflared /etc/cloudflared/creds/credentials.json
        sudo chmod 600 /etc/cloudflared/creds/credentials.json

        log "Tunnel credentials configured"
    else
        warn "Tunnel UUID and secret not provided in .env file"
        warn "You'll need to authenticate manually:"
        warn "  sudo -u cloudflared cloudflared tunnel login"
        warn "  sudo -u cloudflared cloudflared tunnel create $tunnel_name"
        warn "  sudo -u cloudflared cloudflared tunnel route dns $tunnel_name ${CLOUDFLARED_DOMAIN:-your-domain.com}"
    fi

    log "Cloudflared tunnel configuration created"
}

setup_cloudflared_firewall() {
    log "Setting up firewall rules for Cloudflared..."

    # Allow Cloudflared outbound connections
    if command -v ufw >/dev/null 2>&1; then
        # Allow outbound to Cloudflare IPs (if using UFW)
        sudo ufw allow out to 162.159.128.0/18 comment "Cloudflare Tunnel"
        sudo ufw allow out to 162.159.192.0/18 comment "Cloudflare Tunnel"
        sudo ufw allow out to 162.159.0.0/16 comment "Cloudflare Tunnel"
        sudo ufw allow out to 104.16.0.0/13 comment "Cloudflare Tunnel"
        sudo ufw allow out to 104.24.0.0/14 comment "Cloudflare Tunnel"
        sudo ufw allow out to 172.64.0.0/13 comment "Cloudflare Tunnel"
        sudo ufw allow out to 131.0.72.0/22 comment "Cloudflare Tunnel"

        log "UFW rules added for Cloudflared outbound connections"
    fi

    # If using iptables directly
    if command -v iptables >/dev/null 2>&1 && ! command -v ufw >/dev/null 2>&1; then
        # Allow outbound to Cloudflare
        sudo iptables -A OUTPUT -d 162.159.128.0/18 -j ACCEPT -m comment --comment "Cloudflare Tunnel"
        sudo iptables -A OUTPUT -d 162.159.192.0/18 -j ACCEPT -m comment --comment "Cloudflare Tunnel"
        sudo iptables -A OUTPUT -d 162.159.0.0/16 -j ACCEPT -m comment --comment "Cloudflare Tunnel"
        sudo iptables -A OUTPUT -d 104.16.0.0/13 -j ACCEPT -m comment --comment "Cloudflare Tunnel"
        sudo iptables -A OUTPUT -d 104.24.0.0/14 -j ACCEPT -m comment --comment "Cloudflare Tunnel"
        sudo iptables -A OUTPUT -d 172.64.0.0/13 -j ACCEPT -m comment --comment "Cloudflare Tunnel"
        sudo iptables -A OUTPUT -d 131.0.72.0/22 -j ACCEPT -m comment --comment "Cloudflare Tunnel"

        log "iptables rules added for Cloudflared outbound connections"
    fi

    log "Firewall rules configured for Cloudflared"
}

# Cloudflared management functions
start_cloudflared_tunnel() {
    log "Starting Cloudflared tunnel..."

    if ! sudo systemctl is-active --quiet cloudflared; then
        sudo systemctl start cloudflared
        sleep 2

        if sudo systemctl is-active --quiet cloudflared; then
            log "Cloudflared tunnel started successfully"
        else
            error "Failed to start Cloudflared tunnel"
            return 1
        fi
    else
        log "Cloudflared tunnel is already running"
    fi
}

stop_cloudflared_tunnel() {
    log "Stopping Cloudflared tunnel..."

    if sudo systemctl is-active --quiet cloudflared; then
        sudo systemctl stop cloudflared
        log "Cloudflared tunnel stopped"
    else
        log "Cloudflared tunnel is not running"
    fi
}

restart_cloudflared_tunnel() {
    log "Restarting Cloudflared tunnel..."
    sudo systemctl restart cloudflared

    if sudo systemctl is-active --quiet cloudflared; then
        log "Cloudflared tunnel restarted successfully"
    else
        error "Failed to restart Cloudflared tunnel"
        return 1
    fi
}

check_cloudflared_status() {
    log "Checking Cloudflared tunnel status..."

    if sudo systemctl is-active --quiet cloudflared; then
        log "Cloudflared tunnel is running"

        # Check tunnel connections
        if command -v cloudflared >/dev/null 2>&1; then
            log "Tunnel information:"
            sudo -u cloudflared cloudflared tunnel list 2>/dev/null || log "Unable to list tunnels (may need authentication)"
        fi
    else
        warn "Cloudflared tunnel is not running"
        return 1
    fi
}

# Cloudflared tunnel management script
create_cloudflared_management_script() {
    log "Creating Cloudflared management script..."

    sudo tee /usr/local/bin/cloudflared-manage.sh > /dev/null <<'EOF'
#!/bin/bash
# Cloudflared Tunnel Management Script

set -euo pipefail

SCRIPT_NAME=$(basename "$0")
TUNNEL_NAME=${CLOUDFLARED_TUNNEL_NAME:-$(hostname)-tunnel}

show_help() {
    cat << HELP_EOF
Cloudflared Tunnel Management Script

Usage: $SCRIPT_NAME [COMMAND]

Commands:
    start       Start the Cloudflared tunnel
    stop        Stop the Cloudflared tunnel
    restart     Restart the Cloudflared tunnel
    status      Check tunnel status
    login       Authenticate with Cloudflare
    create      Create a new tunnel
    list        List tunnels
    route       Route DNS to tunnel
    logs        Show tunnel logs
    config      Show current configuration
    help        Show this help message

Environment Variables:
    CLOUDFLARED_TUNNEL_NAME    Name of the tunnel (default: hostname-tunnel)
    CLOUDFLARED_DOMAIN         Domain for tunnel routing

Examples:
    $SCRIPT_NAME start
    $SCRIPT_NAME status
    $SCRIPT_NAME login
    $SCRIPT_NAME create
    $SCRIPT_NAME route your-domain.com

HELP_EOF
}

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

check_cloudflared() {
    if ! command -v cloudflared >/dev/null 2>&1; then
        error "Cloudflared is not installed"
    fi
}

start_tunnel() {
    log "Starting Cloudflared tunnel..."
    sudo systemctl start cloudflared

    sleep 2
    if sudo systemctl is-active --quiet cloudflared; then
        log "✓ Cloudflared tunnel started successfully"
    else
        error "Failed to start Cloudflared tunnel"
    fi
}

stop_tunnel() {
    log "Stopping Cloudflared tunnel..."
    sudo systemctl stop cloudflared
    log "✓ Cloudflared tunnel stopped"
}

restart_tunnel() {
    log "Restarting Cloudflared tunnel..."
    sudo systemctl restart cloudflared

    sleep 2
    if sudo systemctl is-active --quiet cloudflared; then
        log "✓ Cloudflared tunnel restarted successfully"
    else
        error "Failed to restart Cloudflared tunnel"
    fi
}

check_status() {
    log "Checking Cloudflared tunnel status..."

    if sudo systemctl is-active --quiet cloudflared; then
        log "✓ Cloudflared tunnel is running"

        # Show tunnel information
        echo ""
        echo "Tunnel Information:"
        sudo -u cloudflared cloudflared tunnel list 2>/dev/null || echo "Unable to list tunnels (may need authentication)"

        # Show recent logs
        echo ""
        echo "Recent Logs:"
        sudo journalctl -u cloudflared -n 10 --no-pager 2>/dev/null || echo "Unable to show logs"
    else
        log "✗ Cloudflared tunnel is not running"
        echo ""
        echo "To start the tunnel:"
        echo "  $SCRIPT_NAME start"
    fi
}

login_cloudflare() {
    log "Authenticating with Cloudflare..."
    log "This will open a browser window for authentication"
    log "If running headless, use the provided URL manually"

    sudo -u cloudflared cloudflared tunnel login

    if [[ $? -eq 0 ]]; then
        log "✓ Successfully authenticated with Cloudflare"
    else
        error "Authentication failed"
    fi
}

create_tunnel() {
    log "Creating new tunnel: $TUNNEL_NAME"

    if sudo -u cloudflared cloudflared tunnel list | grep -q "$TUNNEL_NAME"; then
        log "✓ Tunnel '$TUNNEL_NAME' already exists"
        return 0
    fi

    sudo -u cloudflared cloudflared tunnel create "$TUNNEL_NAME"

    if [[ $? -eq 0 ]]; then
        log "✓ Tunnel '$TUNNEL_NAME' created successfully"
        log "Run '$SCRIPT_NAME route <domain>' to route DNS to this tunnel"
    else
        error "Failed to create tunnel"
    fi
}

list_tunnels() {
    log "Listing Cloudflared tunnels..."
    sudo -u cloudflared cloudflared tunnel list
}

route_dns() {
    local domain="$1"

    if [[ -z "$domain" ]]; then
        error "Domain name is required for DNS routing"
    fi

    log "Routing DNS for $domain to tunnel $TUNNEL_NAME..."

    sudo -u cloudflared cloudflared tunnel route dns "$TUNNEL_NAME" "$domain"

    if [[ $? -eq 0 ]]; then
        log "✓ DNS routing configured for $domain"
        log "The tunnel should now be accessible at https://$domain"
    else
        error "Failed to configure DNS routing"
    fi
}

show_logs() {
    log "Showing Cloudflared tunnel logs..."
    echo "Press Ctrl+C to stop viewing logs"
    echo ""
    sudo journalctl -u cloudflared -f
}

show_config() {
    log "Current Cloudflared configuration:"

    if [[ -f /etc/cloudflared/config.yml ]]; then
        echo ""
        echo "Configuration file (/etc/cloudflared/config.yml):"
        cat /etc/cloudflared/config.yml
    else
        echo "No configuration file found at /etc/cloudflared/config.yml"
    fi

    echo ""
    echo "Service status:"
    sudo systemctl status cloudflared --no-pager -l
}

# Main script logic
case "${1:-help}" in
    start)
        check_cloudflared
        start_tunnel
        ;;
    stop)
        check_cloudflared
        stop_tunnel
        ;;
    restart)
        check_cloudflared
        restart_tunnel
        ;;
    status)
        check_cloudflared
        check_status
        ;;
    login)
        check_cloudflared
        login_cloudflare
        ;;
    create)
        check_cloudflared
        create_tunnel
        ;;
    list)
        check_cloudflared
        list_tunnels
        ;;
    route)
        check_cloudflared
        route_dns "$2"
        ;;
    logs)
        check_cloudflared
        show_logs
        ;;
    config)
        show_config
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/cloudflared-manage.sh

    log "Cloudflared management script created at /usr/local/bin/cloudflared-manage.sh"
}
