#!/bin/bash
# Services configuration module

configure_firewall() {
    if [[ ${CONFIGURE_FIREWALL:-Y} =~ ^[Yy]$ ]]; then
        log "Firewall configuration skipped as requested"
        return 0
    fi
}

harden_ssh_config() {
    if [[ ${HARDEN_SSH:-Y} =~ ^[Yy]$ ]]; then
        log "SSH hardening skipped as requested"
        return 0
    fi
}

install_fail2ban() {
    if [[ ${INSTALL_FAIL2BAN:-Y} =~ ^[Yy]$ ]]; then
        log "Installing and configuring Fail2Ban..."

        # Install Fail2Ban
        sudo apt install -y fail2ban

        # Create local configuration
        sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
# Ban hosts for one hour:
bantime = 3600

# Override /etc/fail2ban/jail.d/00-firewalld.conf:
banaction = iptables-multiport

# A host is banned if it has generated "maxretry" during the last "findtime" seconds.
findtime = 600
maxretry = 3

# "ignoreip" can be a list of IP addresses, CIDR masks or DNS hosts. Fail2ban
# will not ban a host which matches an address in this list. Several addresses
# can be defined using space (and/or comma) separator.
ignoreip = 127.0.0.1/8 ::1

# Enable logging to the systemd journal
logtarget = /var/log/fail2ban.log

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[sshd-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 6
bantime = 3600

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6
bantime = 3600

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 3600

[nginx-noproxy]
enabled = true
port = http,https
filter = nginx-noproxy
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 3600
EOF

        # Create custom filters for additional protection
        sudo tee /etc/fail2ban/filter.d/nginx-ddos.conf > /dev/null <<EOF
# Fail2Ban filter for nginx DDoS attacks

[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*" (200|404|301|302|403|500) .*".*".*"$
ignoreregex =

[Init]
# Author: Your Server Setup
# Description: Filter for nginx DDoS protection
EOF

        # Enable and start Fail2Ban
        sudo systemctl enable fail2ban
        sudo systemctl start fail2ban

        # Show status
        log "Fail2Ban status:"
        sudo fail2ban-client status

        log "Fail2Ban installed and configured"
    fi
}

configure_logrotate() {
    if [[ ${CONFIGURE_LOGROTATE:-Y} =~ ^[Yy]$ ]]; then
        log "Configuring logrotate for better log management..."

        # Create custom logrotate configuration
        sudo tee /etc/logrotate.d/server-logs > /dev/null <<EOF
/var/log/auth.log
/var/log/syslog
/var/log/kern.log
/var/log/mail.log
/var/log/mysql/mysql.log
/var/log/nginx/*.log
/var/log/apache2/*.log
/var/log/fail2ban.log
{
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
EOF

        # Configure Docker log rotation if Docker is installed
        if [[ ${INSTALL_DOCKER:-Y} =~ ^[Yy]$ ]]; then
            sudo tee /etc/logrotate.d/docker > /dev/null <<EOF
/var/lib/docker/containers/*/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    copytruncate
    notifempty
    create 644 root root
}
EOF
        fi

        # Test logrotate configuration
        sudo logrotate -d /etc/logrotate.conf

        log "Logrotate configured for comprehensive log management"
    fi
}

configure_system_limits() {
    if [[ ${CONFIGURE_SYSTEM_LIMITS:-Y} =~ ^[Yy]$ ]]; then
        log "Configuring system limits and security settings..."

        # Configure system limits
        sudo tee /etc/security/limits.d/server-limits.conf > /dev/null <<EOF
# System limits for server security and performance

# File descriptors
* soft nofile 65536
* hard nofile 65536

# Processes
* soft nproc 4096
* hard nproc 4096

# Memory locks
* soft memlock unlimited
* hard memlock unlimited

# Core dumps (disable for security)
* soft core 0
* hard core 0
EOF

        # Configure sysctl security settings
        sudo tee /etc/sysctl.d/99-server-security.conf > /dev/null <<EOF
# Security and performance optimizations

# Disable IP forwarding (unless needed for routing)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Enable TCP SYN cookies
net.ipv4.tcp_syncookies = 1

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable IPv6 if not needed
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1

# Increase maximum connections
net.core.somaxconn = 1024

# Optimize network buffers
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Enable TCP timestamps
net.ipv4.tcp_timestamps = 1

# Reduce SYN flood attacks
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Enable execshield
kernel.exec-shield = 1
kernel.randomize_va_space = 2

# Hide kernel pointers
kernel.kptr_restrict = 1

# Disable kexec (optional security measure)
# kernel.kexec_load_disabled = 1

# Magic SysRq key (disable for security)
kernel.sysrq = 0
EOF

        # Apply sysctl settings
        sudo sysctl -p /etc/sysctl.d/99-server-security.conf

        log "System limits and security settings configured"
    fi
}

configure_cron_jobs() {
    if [[ ${CONFIGURE_CRON:-Y} =~ ^[Yy]$ ]]; then
        log "Configuring automated maintenance cron jobs..."

        # Create cron jobs for system maintenance
        sudo tee /etc/cron.daily/server-maintenance > /dev/null <<EOF
#!/bin/bash
# Daily server maintenance tasks

# Update package lists
apt update >/dev/null 2>&1

# Clean up old packages
apt autoremove -y >/dev/null 2>&1
apt autoclean -y >/dev/null 2>&1

# Clean up old log files
find /var/log -type f -name "*.gz" -mtime +30 -delete 2>/dev/null || true
find /var/log -type f -name "*.old" -mtime +30 -delete 2>/dev/null || true

# Update locate database
updatedb >/dev/null 2>&1

# Check disk usage
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "WARNING: Disk usage is ${DISK_USAGE}% on $(hostname)" | mail -s "Disk Usage Alert" root
fi
EOF

        # Create weekly maintenance script
        sudo tee /etc/cron.weekly/server-weekly > /dev/null <<EOF
#!/bin/bash
# Weekly server maintenance tasks

# Update all packages (unattended upgrades if configured)
apt update >/dev/null 2>&1
apt upgrade -y >/dev/null 2>&1

# Clean up Docker if installed
if command -v docker >/dev/null 2>&1; then
    docker system prune -f >/dev/null 2>&1
    docker volume prune -f >/dev/null 2>&1
fi

# Rotate logs
logrotate -f /etc/logrotate.conf >/dev/null 2>&1

# Check for security updates
apt list --upgradable 2>/dev/null | grep -i security | mail -s "Security Updates Available" root || true
EOF

        # Set proper permissions
        sudo chmod +x /etc/cron.daily/server-maintenance
        sudo chmod +x /etc/cron.weekly/server-weekly

        log "Automated maintenance cron jobs configured"
    fi
}

configure_monitoring() {
    if [[ ${CONFIGURE_MONITORING:-Y} =~ ^[Yy]$ ]]; then
        log "Setting up basic system monitoring..."

        # Install monitoring tools
        sudo apt install -y htop iotop ncdu tree curl wget

        # Create monitoring script
        sudo tee /usr/local/bin/server-monitor.sh > /dev/null <<'EOF'
#!/bin/bash
# Server monitoring script

echo "=== Server Monitoring Report ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo ""

echo "=== System Information ==="
echo "Uptime: $(uptime -p)"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo "Users: $(who | wc -l)"
echo ""

echo "=== CPU Usage ==="
top -bn1 | head -10
echo ""

echo "=== Memory Usage ==="
free -h
echo ""

echo "=== Disk Usage ==="
df -h
echo ""

echo "=== Network Connections ==="
ss -tuln | head -20
echo ""

echo "=== Active Services ==="
systemctl list-units --type=service --state=active | head -20
echo ""

echo "=== Docker Status ==="
if command -v docker >/dev/null 2>&1; then
    echo "Docker containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "Docker system usage:"
    docker system df
else
    echo "Docker not installed"
fi
echo ""

echo "=== Security Status ==="
echo "Fail2Ban status:"
fail2ban-client status 2>/dev/null | head -10 || echo "Fail2Ban not configured"
echo ""

echo "=== Recent System Logs ==="
journalctl -n 20 --no-pager -q
EOF

        sudo chmod +x /usr/local/bin/server-monitor.sh

        # Create monitoring cron job (every 15 minutes)
        sudo tee /etc/cron.d/server-monitoring > /dev/null <<EOF
# Monitor server every 15 minutes
*/15 * * * * root /usr/local/bin/server-monitor.sh > /var/log/server-monitoring.log 2>&1
EOF

        log "Basic system monitoring configured"
        log "Run 'server-monitor.sh' for current system status"
    fi
}

# Service management functions
start_services() {
    log "Starting configured services..."

    # Start Fail2Ban
    if [[ ${INSTALL_FAIL2BAN:-Y} =~ ^[Yy]$ ]]; then
        sudo systemctl start fail2ban
        log "Fail2Ban service started"
    fi

    # Start Docker
    if [[ ${INSTALL_DOCKER:-Y} =~ ^[Yy]$ ]]; then
        sudo systemctl start docker
        log "Docker service started"
    fi

    # Start Cloudflared
    if [[ ${INSTALL_CLOUDFLARED:-Y} =~ ^[Yy]$ ]]; then
        sudo systemctl start cloudflared
        log "Cloudflared service started"
    fi

    log "All services started"
}

enable_services() {
    log "Enabling services to start on boot..."

    # Enable Fail2Ban
    if [[ ${INSTALL_FAIL2BAN:-Y} =~ ^[Yy]$ ]]; then
        sudo systemctl enable fail2ban
        log "Fail2Ban service enabled"
    fi

    # Enable Docker
    if [[ ${INSTALL_DOCKER:-Y} =~ ^[Yy]$ ]]; then
        sudo systemctl enable docker
        log "Docker service enabled"
    fi

    # Enable Cloudflared
    if [[ ${INSTALL_CLOUDFLARED:-Y} =~ ^[Yy]$ ]]; then
        sudo systemctl enable cloudflared
        log "Cloudflared service enabled"
    fi

    log "All services enabled for auto-start"
}
