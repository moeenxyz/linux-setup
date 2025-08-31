#!/bin/bash

# Server Verification Script
# This script verifies that all components from the setup script are working correctly

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root"
        exit 1
    fi
}

# System information
check_system() {
    log "=== System Information ==="
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p)"
    echo "Memory: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}')"
    echo "Disk Usage: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"
}

# SSH verification
check_ssh() {
    log "=== SSH Configuration ==="
    if systemctl is-active --quiet ssh; then
        echo "✅ SSH service is running"

        # Check SSH port
        local ssh_port=$(grep "^Port " /etc/ssh/sshd_config | awk '{print $2}')
        if [[ -n "$ssh_port" ]]; then
            echo "✅ SSH port: $ssh_port"
            # Use ss instead of netstat (more modern and always available)
            if ss -tlnp | grep -q ":$ssh_port "; then
                echo "✅ SSH port $ssh_port is listening"
            else
                warning "SSH port $ssh_port is not listening"
            fi
        else
            warning "SSH port not found in configuration"
        fi

        # Check SSH key authentication
        if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
            echo "✅ Password authentication disabled"
        else
            warning "Password authentication may still be enabled"
        fi

        # Check root login
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
            echo "✅ Root login disabled"
        else
            warning "Root login may still be enabled"
        fi
    else
        error "SSH service is not running"
    fi
}

# Docker verification
check_docker() {
    log "=== Docker Configuration ==="
    if command -v docker &> /dev/null; then
        echo "✅ Docker version: $(docker --version)"

        if systemctl is-active --quiet docker; then
            echo "✅ Docker service is running"
        else
            warning "Docker service is not running"
        fi

        # Check if user is in docker group
        if groups $USER | grep -q docker; then
            echo "✅ User is in docker group"
        else
            warning "User is not in docker group (log out and back in)"
        fi

        # Test Docker
        if docker run --rm hello-world &> /dev/null; then
            echo "✅ Docker hello-world test passed"
        else
            warning "Docker hello-world test failed"
        fi
    else
        warning "Docker is not installed"
    fi

    # Docker Compose
    if command -v docker-compose &> /dev/null; then
        echo "✅ Docker Compose version: $(docker-compose --version)"
    else
        warning "Docker Compose is not installed"
    fi
}

# ZFS verification
check_zfs() {
    log "=== ZFS Configuration ==="
    if command -v zfs &> /dev/null; then
        echo "✅ ZFS version: $(zfs version | head -1)"

        # Check ZFS pools
        local pools=$(zpool list -H -o name 2>/dev/null | wc -l)
        if [[ $pools -gt 0 ]]; then
            echo "✅ ZFS pools found: $pools"
            zpool list
        else
            warning "No ZFS pools found"
        fi

        # Check ZFS datasets
        local datasets=$(zfs list -H 2>/dev/null | wc -l)
        if [[ $datasets -gt 0 ]]; then
            echo "✅ ZFS datasets found: $datasets"
        else
            warning "No ZFS datasets found"
        fi
        
        # Check if services are using ZFS directories
        local server_base=""
        if [[ -d /server-data ]]; then
            server_base="/server-data"
        elif [[ -d /srv ]]; then
            server_base="/srv"
        fi
        
        if [[ -n "$server_base" ]]; then
            echo "✅ Server base directory: $server_base"
            
            # Check Docker configuration
            if [[ -f /etc/docker/daemon.json ]]; then
                local docker_root=$(jq -r '.["data-root"] // empty' /etc/docker/daemon.json 2>/dev/null)
                if [[ "$docker_root" == "$server_base/docker" ]]; then
                    echo "✅ Docker configured to use ZFS: $docker_root"
                else
                    warning "Docker not configured to use ZFS directory"
                fi
            fi
            
            # Check if ZFS directories exist
            local dirs=("docker" "apps" "data" "logs" "configs")
            for dir in "${dirs[@]}"; do
                if [[ -d "$server_base/$dir" ]]; then
                    echo "✅ ZFS directory exists: $server_base/$dir"
                else
                    warning "ZFS directory missing: $server_base/$dir"
                fi
            done
        fi
    else
        warning "ZFS is not installed"
    fi
}

# Firewall verification
check_firewall() {
    log "=== Firewall Configuration ==="
    if command -v ufw &> /dev/null; then
        echo "✅ UFW is installed"

        if sudo ufw status | grep -q "Status: active"; then
            echo "✅ UFW is active"
            echo "Firewall rules:"
            sudo ufw status numbered
        else
            warning "UFW is not active"
        fi
    else
        warning "UFW is not installed"
    fi
}

# Fail2Ban verification
check_fail2ban() {
    log "=== Fail2Ban Configuration ==="
    if command -v fail2ban-client &> /dev/null; then
        echo "✅ Fail2Ban is installed"

        if systemctl is-active --quiet fail2ban; then
            echo "✅ Fail2Ban service is running"
            echo "Jails status:"
            sudo fail2ban-client status 2>/dev/null || warning "Could not get Fail2Ban status"
        else
            warning "Fail2Ban service is not running"
        fi
    else
        warning "Fail2Ban is not installed"
    fi
}

# Development tools verification
check_dev_tools() {
    log "=== Development Tools ==="

    # Git
    if command -v git &> /dev/null; then
        echo "✅ Git version: $(git --version)"
    else
        warning "Git is not installed"
    fi

    # Node.js
    if command -v node &> /dev/null; then
        echo "✅ Node.js version: $(node --version)"
        if command -v npm &> /dev/null; then
            echo "✅ NPM version: $(npm --version)"
        fi
    else
        warning "Node.js is not installed"
    fi

    # Python
    if command -v python3 &> /dev/null; then
        echo "✅ Python version: $(python3 --version)"
        if command -v pip3 &> /dev/null; then
            echo "✅ Pip version: $(pip3 --version)"
        fi
    else
        warning "Python 3 is not installed"
    fi

    # Other tools
    local tools=("curl" "wget" "vim" "htop" "tree")
    for tool in "${tools[@]}"; do
        if command -v $tool &> /dev/null; then
            echo "✅ $tool is installed"
        else
            warning "$tool is not installed"
        fi
    done
}

# Zsh verification
check_zsh() {
    log "=== Zsh Configuration ==="
    if command -v zsh &> /dev/null; then
        echo "✅ Zsh version: $(zsh --version)"

        # Check if Zsh is default shell
        if [[ $SHELL == *"zsh"* ]]; then
            echo "✅ Zsh is the default shell"
        else
            info "Zsh is installed but not default shell (run 'chsh -s $(which zsh)')"
        fi

        # Check Oh My Zsh
        if [[ -d "$HOME/.oh-my-zsh" ]]; then
            echo "✅ Oh My Zsh is installed"
        else
            warning "Oh My Zsh is not installed"
        fi
    else
        warning "Zsh is not installed"
    fi
}

# Cloudflared verification
check_cloudflared() {
    log "=== Cloudflared Configuration ==="
    if command -v cloudflared &> /dev/null; then
        echo "✅ Cloudflared version: $(cloudflared version)"

        if systemctl is-active --quiet cloudflared 2>/dev/null; then
            echo "✅ Cloudflared service is running"
        else
            warning "Cloudflared service is not running"
        fi
    else
        warning "Cloudflared is not installed"
    fi
}

# Server organization verification
check_server_org() {
    log "=== Server Organization ==="
    local srv_dir="/srv"

    if [[ -d "$srv_dir" ]]; then
        echo "✅ /srv directory exists"

        local subdirs=("configs" "docker" "scripts" "apps" "data" "logs")
        for dir in "${subdirs[@]}"; do
            if [[ -d "$srv_dir/$dir" ]]; then
                echo "✅ $srv_dir/$dir exists"
            else
                warning "$srv_dir/$dir does not exist"
            fi
        done
    else
        warning "/srv directory does not exist"
    fi
}

# Migration tools verification
check_migration_tools() {
    log "=== Migration Tools ==="
    local tools=("/usr/local/bin/server-migrate.sh" "/usr/local/bin/server-organize.sh")

    for tool in "${tools[@]}"; do
        if [[ -x "$tool" ]]; then
            echo "✅ $tool exists and is executable"
        else
            warning "$tool does not exist or is not executable"
        fi
    done
}

# Logs verification
check_logs() {
    log "=== Log Files ==="
    local log_files=("/var/log/server-setup.log" "/var/log/auth.log" "/var/log/syslog")

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            echo "✅ $log_file exists"
            local size=$(stat -c%s "$log_file" 2>/dev/null || echo "unknown")
            echo "   Size: $size bytes"
        else
            warning "$log_file does not exist"
        fi
    done
}

# Main verification function
main() {
    log "Starting Server Verification"
    echo "========================================"
    
    # Create temporary log file for summary
    exec > >(tee /tmp/verification_output.log)
    
    check_root
    check_system
    echo

    check_ssh
    echo

    check_docker
    echo

    check_zfs
    echo

    check_firewall
    echo

    check_fail2ban
    echo

    check_dev_tools
    echo

    check_zsh
    echo

    check_cloudflared
    echo

    check_server_org
    echo

    check_migration_tools
    echo

    check_logs
    echo

    log "Verification complete!"
    info "Review any warnings above and address them as needed."
    info "For detailed setup logs, check: /var/log/server-setup.log"
    
    # Count warnings and errors for summary
    local warning_count=$(grep -c "WARNING" /tmp/verification_output.log 2>/dev/null || echo "0")
    local error_count=$(grep -c "ERROR" /tmp/verification_output.log 2>/dev/null || echo "0")
    
    if [[ -n "$warning_count" && "$warning_count" -gt 0 ]] || [[ -n "$error_count" && "$error_count" -gt 0 ]]; then
        echo ""
        echo "📊 Summary:"
        [[ -n "$error_count" && "$error_count" -gt 0 ]] && echo "❌ $error_count errors found"
        [[ -n "$warning_count" && "$warning_count" -gt 0 ]] && echo "⚠️  $warning_count warnings found"
        echo "✅ All other components verified successfully"
    else
        echo ""
        echo "🎉 All components verified successfully!"
    fi
    
    # Clean up temporary log file
    rm -f /tmp/verification_output.log
}

# Run main function
main "$@"
