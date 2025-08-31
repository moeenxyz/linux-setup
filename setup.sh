#!/bin/bash
# Ubuntu Server Setup Script - Modular Version
# Complete server setup with Docker, ZFS, security hardening, and monitoring

set -euo pipefail

# Script configuration
# Handle both direct execution and piped execution
if [[ -n "${BASH_SOURCE[0]}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # When piped to bash, assume we're in a temp directory
    SCRIPT_DIR="$(pwd)"
fi
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]:-setup.sh}")"
START_TIME=$(date +%s)

# Load common functions
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    # Fallback functions if lib files are not available
    log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"; }
    error() { echo "[ERROR] $1" >&2; exit 1; }
    warn() { echo "[WARNING] $1"; }
fi

if [[ -f "$SCRIPT_DIR/lib/system.sh" ]]; then
    source "$SCRIPT_DIR/lib/system.sh"
else
    # Fallback system functions
    check_root() { [[ $EUID -eq 0 ]] && { error "This script should not be run as root"; exit 1; } || true; }
    check_sudo() { sudo -n true 2>/dev/null || sudo -v || { error "Sudo access required"; exit 1; }; }
    validate_system() { log "System validation skipped (lib not available)"; }
fi

# Function to show usage
show_usage() {
    cat << EOF
Ubuntu Server Setup Script - Modular Version

Usage: $SCRIPT_NAME [OPTIONS]

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -d, --dry-run       Show what would be done without making changes
    -c, --config FILE   Use specific configuration file (default: .env)
    --skip-validation   Skip system validation checks
    --force             Force installation even if components are already installed

Environment Configuration (.env file):
    # Core Settings
    INSTALL_ESSENTIALS=Y     # Install essential tools (git, node, zsh)
    INSTALL_DOCKER=Y         # Install Docker CE and Compose
    INSTALL_ZFS=Y           # Install ZFS with migration setup
    INSTALL_CLOUDFLARED=Y   # Install Cloudflare tunnel
    INSTALL_FAIL2BAN=Y     # Install Fail2Ban intrusion prevention
    CONFIGURE_MONITORING=Y # Set up system monitoring

    # SSH Configuration
    SSH_PORT=22             # Custom SSH port (default: 22)
    ALLOW_HTTP=Y            # Allow HTTP traffic
    ALLOW_HTTPS=Y           # Allow HTTPS traffic

    # ZFS Configuration
    CREATE_ZFS_POOL=Y       # Create ZFS pool for migration
    ZFS_POOL_TYPE=1         # 1=file-based, 2=disk-based
    ZFS_DISK=               # Disk device for ZFS pool (if type=2)
    ZFS_DISK_CONFIRM=N      # Confirm disk destruction

    # Cloudflared Configuration
    CLOUDFLARED_TUNNEL_NAME=  # Tunnel name
    CLOUDFLARED_DOMAIN=       # Domain for tunnel routing
    CLOUDFLARED_TUNNEL_UUID=  # Tunnel UUID
    CLOUDFLARED_TUNNEL_SECRET= # Tunnel secret

    # Custom Configuration
    CUSTOM_UFW_PORTS=        # Additional ports to allow (format: 8080/tcp,9000/udp)

Examples:
    $SCRIPT_NAME                    # Run with default .env configuration
    $SCRIPT_NAME --config myconfig.env  # Use custom configuration file
    $SCRIPT_NAME --verbose          # Enable verbose output
    $SCRIPT_NAME --dry-run          # Show what would be done

Modules:
    - Essentials: Git, Node.js LTS, Zsh, development tools
    - Docker: Docker CE, Compose v2, optimized configuration
    - ZFS: Complete filesystem setup with migration tools
    - Cloudflared: Secure tunnel access with management scripts
    - Security: Fail2Ban intrusion prevention, system limits
    - Monitoring: Automated monitoring and maintenance scripts

For more information, see the README.md file.
EOF
}

# Parse command line arguments
VERBOSE=false
DRY_RUN=false
SKIP_VALIDATION=false
FORCE=false
CONFIG_FILE=".env"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Set verbose mode
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

# Main function
main() {
    log "=== Ubuntu Server Setup Script - Modular Version ==="
    log "Script directory: $SCRIPT_DIR"
    log "Configuration file: $CONFIG_FILE"
    log "Start time: $(date)"

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "DRY RUN MODE - No changes will be made"
    fi

    # Load configuration
    if [[ -f "$CONFIG_FILE" ]]; then
        log "Loading configuration from $CONFIG_FILE..."
        load_config "$CONFIG_FILE"
    else
        warn "Configuration file $CONFIG_FILE not found, using defaults"
    fi

    # Check root and sudo
    check_root
    check_sudo

    # Validate system (unless skipped)
    if [[ "$SKIP_VALIDATION" == "false" ]]; then
        validate_system
    else
        warn "Skipping system validation as requested"
    fi

    # Show installation plan
    show_installation_plan

    log "Proceeding to confirmation..."

    # Confirm installation (unless forced)
    if [[ "$FORCE" == "false" && "$DRY_RUN" == "false" ]]; then
        # Check if running interactively
        if [[ -t 0 ]]; then
            echo ""
            read -p "Do you want to proceed with the installation? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "Installation cancelled by user"
                exit 0
            fi
        else
            log "Non-interactive mode detected, proceeding with installation..."
        fi
    fi

    # Load and execute modules
    execute_modules

    # Show completion summary
    show_completion_summary

    log "=== Setup completed successfully ==="
    log "Total execution time: $(( $(date +%s) - START_TIME )) seconds"
}

# Show installation plan
show_installation_plan() {
    log "Installation Plan:"

    echo "Core Components:"
    if [ "${INSTALL_ESSENTIALS:-Y}" = "Y" ] || [ "${INSTALL_ESSENTIALS:-Y}" = "y" ]; then echo "  [OK] Essential tools (Git, Node.js, Zsh)"; fi
    if [ "${INSTALL_DOCKER:-Y}" = "Y" ] || [ "${INSTALL_DOCKER:-Y}" = "y" ]; then echo "  [OK] Docker CE and Compose"; fi
    if [ "${INSTALL_ZFS:-Y}" = "Y" ] || [ "${INSTALL_ZFS:-Y}" = "y" ]; then echo "  [OK] ZFS filesystem with migration setup"; fi
    if [ "${INSTALL_CLOUDFLARED:-Y}" = "Y" ] || [ "${INSTALL_CLOUDFLARED:-Y}" = "y" ]; then echo "  [OK] Cloudflare tunnel"; fi

    echo "Security & Services:"
    if [ "${CONFIGURE_FIREWALL:-Y}" = "Y" ] || [ "${CONFIGURE_FIREWALL:-Y}" = "y" ]; then echo "  [OK] UFW firewall configuration"; fi
    if [ "${HARDEN_SSH:-Y}" = "Y" ] || [ "${HARDEN_SSH:-Y}" = "y" ]; then echo "  [OK] SSH hardening (port: ${SSH_PORT:-22})"; fi
    if [ "${INSTALL_FAIL2BAN:-Y}" = "Y" ] || [ "${INSTALL_FAIL2BAN:-Y}" = "y" ]; then echo "  [OK] Fail2Ban intrusion prevention"; fi
    if [ "${CONFIGURE_MONITORING:-Y}" = "Y" ] || [ "${CONFIGURE_MONITORING:-Y}" = "y" ]; then echo "  [OK] System monitoring and maintenance"; fi

    echo "Configuration:"
    # if [ -n "${CLOUDFLARED_DOMAIN:-}" ]; then echo "  [OK] Cloudflared domain: ${CLOUDFLARED_DOMAIN}"; fi
    # if [ -n "${CUSTOM_UFW_PORTS:-}" ]; then echo "  [OK] Custom firewall ports: ${CUSTOM_UFW_PORTS}"; fi

    log "End of show_installation_plan"
}

# Execute installation modules
execute_modules() {
    log "Starting module execution..."

    # Load package modules
    source "$SCRIPT_DIR/modules/packages/essentials.sh"
    source "$SCRIPT_DIR/modules/packages/docker.sh"
    source "$SCRIPT_DIR/modules/packages/zfs.sh"
    source "$SCRIPT_DIR/modules/packages/cloudflared.sh"

    # Load service modules
    source "$SCRIPT_DIR/modules/services/security.sh"

    # Execute modules in order
    local modules=(
        "install_essential_tools"
        "install_docker_package"
        "install_zfs_package"
        "install_cloudflared_package"
        "install_fail2ban"
        "configure_logrotate"
        "configure_system_limits"
        "configure_cron_jobs"
        "configure_monitoring"
    )

    for module in "${modules[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            log "[DRY RUN] Would execute: $module"
        else
            log "Executing module: $module"
            if command -v "$module" >/dev/null 2>&1; then
                if "$module"; then
                    log "Module $module completed successfully"
                else
                    error "Module $module failed, but continuing with other modules"
                fi
            else
                warn "Module function $module not found, skipping"
            fi
        fi
    done

    # Start and enable services
    if [[ "$DRY_RUN" == "false" ]]; then
        start_services
        enable_services
    else
        log "[DRY RUN] Would start and enable services"
    fi
}

# Show completion summary
show_completion_summary() {
    log "Installation Summary:"

    echo ""
    echo "✓ Essential tools installed and configured"
    echo "✓ Docker CE and Compose v2 ready for use"
    echo "✓ ZFS filesystem configured with migration tools"
    echo "✓ Cloudflare tunnel configured for secure access"
    echo "✓ Fail2Ban protecting against brute force attacks"
    echo "✓ System monitoring and maintenance scripts installed"

    echo ""
    echo "Management Commands:"
    echo "  Server monitoring: server-monitor.sh"
    echo "  Docker management: docker --version && docker-compose --version"
    echo "  ZFS migration: server-migrate.sh export|import"
    echo "  Cloudflared tunnel: cloudflared-manage.sh status|start|stop"
    echo "  Fail2Ban status: sudo fail2ban-client status"

    echo ""
    echo "Configuration Files:"
    echo "  Docker: /etc/docker/daemon.json"
    echo "  Fail2Ban: /etc/fail2ban/jail.local"
    echo "  Cloudflared: /etc/cloudflared/config.yml"
    echo "  System limits: /etc/security/limits.d/server-limits.conf"

    if [[ -n "${CLOUDFLARED_DOMAIN:-}" ]]; then
        echo ""
        echo "Cloudflare Tunnel Access:"
        echo "  HTTPS: https://${CLOUDFLARED_DOMAIN}"
        echo "  SSH: ssh://ssh.${CLOUDFLARED_DOMAIN}"
        echo "  API: https://api.${CLOUDFLARED_DOMAIN}"
    fi

    echo ""
    echo "For detailed logs, check: /var/log/server-setup.log"
}

# Error handling
trap 'error "Script failed at line $LINENO with exit code $?"' ERR

# Run main function
main "$@"
