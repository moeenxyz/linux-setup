#!/bin/bash
# ZFS installation and configuration module

install_zfs_package() {
    if [[ ${INSTALL_ZFS:-Y} =~ ^[Yy]$ ]]; then
        log "Installing ZFS with complete server portability setup and validation..."

        # Check if ZFS is already available
        if command -v zfs >/dev/null 2>&1; then
            warn "ZFS already installed. Skipping installation."
            return 0
        fi

        # Install ZFS utilities with kernel headers
        log "Installing ZFS kernel modules and utilities..."
        sudo apt install -y linux-headers-$(uname -r) zfsutils-linux zfs-initramfs

        # Load ZFS module with error checking
        log "Loading ZFS kernel module..."
        if ! sudo modprobe zfs; then
            error "Failed to load ZFS kernel module"
            return 1
        fi

        # Add to modules to load at boot
        echo "zfs" | sudo tee -a /etc/modules

        # Check if we're on a live system or existing installation
        if [[ -f /etc/fstab.orig ]]; then
            warn "ZFS root setup detected as already configured"
        else
            log "Setting up ZFS datasets for complete server portability..."

            # Create ZFS pool if it doesn't exist (for existing systems)
            if ! zpool list rpool &>/dev/null 2>&1; then
                warn "No ZFS root pool found. Setting up data pool for migration preparation..."

                # Create a ZFS data pool for complete server state
                local create_pool="${CREATE_ZFS_POOL:-Y}"
                if [[ -z "$CREATE_ZFS_POOL" ]]; then
                    create_pool="Y"  # Default to yes for non-interactive mode
                    log "Using default: Create ZFS data pool for server migration"
                fi

                if [[ $create_pool =~ ^[Yy]$ ]]; then
                    # Ask user for pool type preference
                    local pool_option="${ZFS_POOL_TYPE:-1}"
                    if [[ -z "$ZFS_POOL_TYPE" ]]; then
                        log "Using default ZFS pool type: File-based pool (option 1)"
                    fi

                    case $pool_option in
                        1)
                            # File-based ZFS pool
                            log "Creating file-based ZFS pool..."

                            # Check available disk space for ZFS pool
                            local available_space=$(df /opt | awk 'NR==2 {print $4}')
                            if [[ $available_space -lt 10485760 ]]; then  # 10GB in KB
                                error "Insufficient space for ZFS pool. Need at least 10GB in /opt"
                                return 1
                            fi

                            sudo mkdir -p /opt/zfs

                            # Create a file-based ZFS pool (more compatible)
                            log "Creating 10GB file for ZFS pool..."
                            sudo truncate -s 10G /opt/zfs/server-data.img

                            # Create ZFS pool with error checking
                            log "Creating ZFS pool from file..."
                            if ! sudo zpool create -f server-data /opt/zfs/server-data.img; then
                                error "Failed to create ZFS pool"
                                return 1
                            fi
                            ;;
                        2)
                            # Disk-based ZFS pool
                            local zfs_disk="${ZFS_DISK:-}"
                            if [[ -z "$zfs_disk" ]]; then
                                log "No ZFS_DISK specified in .env file. Skipping disk-based pool creation."
                                return 0
                            fi

                            if [[ ! -b "$zfs_disk" ]]; then
                                error "Device $zfs_disk does not exist or is not a block device"
                                return 1
                            fi

                            warn "WARNING: This will destroy all data on $zfs_disk"
                            local confirm_disk="${ZFS_DISK_CONFIRM:-N}"
                            if [[ ! $confirm_disk =~ ^[Yy]$ ]]; then
                                log "ZFS disk pool creation cancelled (set ZFS_DISK_CONFIRM=Y in .env to confirm)"
                                return 0
                            fi

                            log "Creating ZFS pool on $zfs_disk..."
                            if ! sudo zpool create -f server-data "$zfs_disk"; then
                                error "Failed to create ZFS pool on $zfs_disk"
                                return 1
                            fi
                            ;;
                        *)
                            warn "Invalid ZFS_POOL_TYPE. Using default: File-based pool"
                            # Default to file-based pool
                            log "Creating file-based ZFS pool..."

                            # Check available disk space for ZFS pool
                            local available_space=$(df /opt | awk 'NR==2 {print $4}')
                            if [[ $available_space -lt 10485760 ]]; then  # 10GB in KB
                                error "Insufficient space for ZFS pool. Need at least 10GB in /opt"
                                return 1
                            fi

                            sudo mkdir -p /opt/zfs

                            # Create a file-based ZFS pool (more compatible)
                            log "Creating 10GB file for ZFS pool..."
                            sudo truncate -s 10G /opt/zfs/server-data.img

                            # Create ZFS pool with error checking
                            log "Creating ZFS pool from file..."
                            if ! sudo zpool create -f server-data /opt/zfs/server-data.img; then
                                error "Failed to create ZFS pool"
                                return 1
                            fi
                            ;;
                    esac

                    sudo zfs set compression=lz4 server-data
                    sudo zfs set atime=off server-data

                    # Create datasets for complete server state
                    local datasets=("configs" "docker" "scripts" "apps" "data" "logs" "home")
                    for dataset in "${datasets[@]}"; do
                        if ! sudo zfs create "server-data/$dataset"; then
                            error "Failed to create dataset: $dataset"
                            return 1
                        fi
                    done

                    # Set mount points for server components
                    sudo zfs set mountpoint=/server-data server-data
                    sudo zfs set mountpoint=/server-data/configs server-data/configs
                    sudo zfs set mountpoint=/server-data/docker server-data/docker
                    sudo zfs set mountpoint=/server-data/scripts server-data/scripts
                    sudo zfs set mountpoint=/server-data/apps server-data/apps
                    sudo zfs set mountpoint=/server-data/data server-data/data
                    sudo zfs set mountpoint=/server-data/logs server-data/logs
                    sudo zfs set mountpoint=/server-data/home server-data/home

                    log "ZFS server-data pool created with organized datasets for complete migration"
                fi
            else
                log "ZFS root pool detected. Creating datasets for complete server migration..."

                # Create datasets for complete server organization on existing ZFS root
                local root_datasets=("srv/configs" "srv/docker" "srv/scripts" "srv/apps" "srv/data" "srv/logs")
                for dataset in "${root_datasets[@]}"; do
                    sudo zfs create -o mountpoint="/$dataset" "rpool/$dataset" 2>/dev/null || true
                done

                # Create datasets for system directories
                local system_datasets=("home" "var" "var/log" "var/lib" "var/lib/docker" "opt" "tmp" "etc")
                for dataset in "${system_datasets[@]}"; do
                    sudo zfs create -o mountpoint="/$dataset" "rpool/$dataset" 2>/dev/null || true
                done

                # Set optimal properties for migration
                sudo zfs set compression=lz4 rpool
                sudo zfs set atime=off rpool
                sudo zfs set xattr=sa rpool
                sudo zfs set dnodesize=auto rpool

                log "ZFS datasets created and optimized for complete server migration"
            fi
        fi

        # Always create organized directory structure for server migration
        log "Creating organized directory structure for server migration..."

        # Create /srv structure (standard location)
        sudo mkdir -p /srv/{configs,docker,scripts,apps,data,logs}
        sudo mkdir -p /srv/configs/{nginx,apache,ssl,ssh,system,firewall}
        sudo mkdir -p /srv/docker/{containers,volumes,compose,images}
        sudo mkdir -p /srv/scripts/{setup,maintenance,deployment,monitoring}
        sudo mkdir -p /srv/apps/{web,api,services,static}
        sudo mkdir -p /srv/data/{databases,uploads,cache,sessions}
        sudo mkdir -p /srv/logs/{nginx,apache,app,system,security}

        # Set proper permissions
        sudo chown -R root:root /srv
        sudo chmod -R 755 /srv

        # Create /server-data structure if using file-based pool
        if [[ -d /server-data ]]; then
            sudo mkdir -p /server-data/{configs,docker,scripts,apps,data,logs}
            sudo mkdir -p /server-data/configs/{nginx,apache,ssl,ssh,system}
            sudo mkdir -p /server-data/docker/{containers,volumes,compose}
            sudo mkdir -p /server-data/scripts/{setup,maintenance,deployment}
            sudo mkdir -p /server-data/apps/{web,api,services}
            sudo mkdir -p /server-data/data/{databases,uploads,backups}
            sudo mkdir -p /server-data/logs/{nginx,apache,app,system}

            # Set proper permissions
            sudo chown -R root:root /server-data
            sudo chmod -R 755 /server-data
        fi

        # Configure services to use ZFS directories
        configure_services_for_zfs

        # Create service configuration templates
        create_service_templates

        # Create server migration tools
        create_migration_tools

        # Verify ZFS installation
        if ! zpool list >/dev/null 2>&1; then
            error "ZFS installation verification failed"
            return 1
        fi

        log "ZFS installed with complete server migration capabilities and validation"
    fi
}

configure_services_for_zfs() {
    log "Configuring services to use ZFS directories..."

    # Configure Docker to use ZFS directories
    if [[ ${INSTALL_DOCKER:-Y} =~ ^[Yy]$ ]]; then
        log "Configuring Docker to use ZFS directories..."

        # Determine Docker data directory
        local docker_data_dir="/var/lib/docker"
        if [[ -d /server-data ]]; then
            docker_data_dir="/server-data/docker"
        elif [[ -d /srv ]]; then
            docker_data_dir="/srv/docker"
        fi

        # Create Docker data directory
        sudo mkdir -p "$docker_data_dir"
        sudo chown root:root "$docker_data_dir"
        sudo chmod 711 "$docker_data_dir"

        # Configure Docker daemon to use ZFS directory
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "data-root": "$docker_data_dir",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false,
  "default-ulimits": {
    "nofile": {
      "hard": 64000,
      "soft": 64000
    }
  }
}
EOF

        # If Docker is already running, we need to stop it and move data
        if sudo systemctl is-active --quiet docker; then
            log "Moving existing Docker data to ZFS directory..."
            sudo systemctl stop docker

            # Move existing Docker data if it exists
            if [[ -d /var/lib/docker && -d "$docker_data_dir" && "$docker_data_dir" != "/var/lib/docker" ]]; then
                sudo mv /var/lib/docker/* "$docker_data_dir/" 2>/dev/null || true
                sudo rmdir /var/lib/docker 2>/dev/null || true
            fi

            sudo systemctl start docker
        fi

        log "Docker configured to use ZFS directory: $docker_data_dir"
    fi

    # Configure system logging to use ZFS directories
    log "Configuring system logging to use ZFS directories..."

    # Determine logs directory
    local logs_dir="/var/log"
    if [[ -d /server-data ]]; then
        logs_dir="/server-data/logs"
    elif [[ -d /srv ]]; then
        logs_dir="/srv/logs"
    fi

    # Create additional log directories
    sudo mkdir -p "$logs_dir/app"
    sudo mkdir -p "$logs_dir/security"
    sudo mkdir -p "$logs_dir/nginx"
    sudo mkdir -p "$logs_dir/apache"

    # Configure rsyslog to log to ZFS directory
    if [[ "$logs_dir" != "/var/log" ]]; then
        log "Configuring rsyslog to use ZFS log directory..."

        # Create rsyslog configuration for ZFS logs
        sudo tee /etc/rsyslog.d/99-zfs-logs.conf > /dev/null <<EOF
# Log to ZFS directory
*.*;auth,authpriv.none          $logs_dir/system/syslog
auth,authpriv.*                 $logs_dir/security/auth.log
cron.*                          $logs_dir/system/cron.log
EOF

        # Create logrotate configuration for ZFS logs
        sudo tee /etc/logrotate.d/zfs-logs > /dev/null <<EOF
$logs_dir/system/*.log
$logs_dir/security/*.log
$logs_dir/app/*.log {
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

        sudo systemctl restart rsyslog
        log "System logging configured to use ZFS directory: $logs_dir"
    fi

    # Configure application directories
    log "Configuring application directories..."

    # Determine apps and data directories
    local apps_dir="/srv/apps"
    local data_dir="/srv/data"
    if [[ -d /server-data ]]; then
        apps_dir="/server-data/apps"
        data_dir="/server-data/data"
    fi

    # Create application-specific directories
    sudo mkdir -p "$apps_dir/web"
    sudo mkdir -p "$apps_dir/api"
    sudo mkdir -p "$apps_dir/services"
    sudo mkdir -p "$data_dir/databases"
    sudo mkdir -p "$data_dir/uploads"
    sudo mkdir -p "$data_dir/cache"
    sudo mkdir -p "$data_dir/sessions"

    # Set proper permissions for web applications
    sudo chown -R www-data:www-data "$apps_dir/web" 2>/dev/null || true
    sudo chown -R www-data:www-data "$data_dir/uploads" 2>/dev/null || true
    sudo chown -R www-data:www-data "$data_dir/cache" 2>/dev/null || true
    sudo chown -R www-data:www-data "$data_dir/sessions" 2>/dev/null || true

    # Configure Node.js to use ZFS directories
    if [[ ${INSTALL_NODEJS:-Y} =~ ^[Yy]$ ]]; then
        log "Configuring Node.js applications to use ZFS directories..."

        # Set npm global directory to ZFS
        if [[ -d "$apps_dir" ]]; then
            sudo mkdir -p "$apps_dir/node_modules"
            sudo chown -R $USER:$USER "$apps_dir/node_modules"

            # Configure npm to use ZFS directory
            npm config set prefix "$apps_dir/node_modules"
            npm config set cache "$data_dir/cache/npm"

            log "Node.js configured to use ZFS directories"
        fi
    fi

    log "All services configured to use ZFS directories for complete migration coverage"
}

create_service_templates() {
    log "Creating service configuration templates..."

    # Determine directories
    local apps_dir="/srv/apps"
    local data_dir="/srv/data"
    local logs_dir="/srv/logs"
    if [[ -d /server-data ]]; then
        apps_dir="/server-data/apps"
        data_dir="/server-data/data"
        logs_dir="/server-data/logs"
    fi

    # Nginx configuration template
    if [[ -d "$apps_dir/web" ]]; then
        sudo tee "$apps_dir/web/nginx-template.conf" > /dev/null <<EOF
# Nginx Configuration Template for ZFS
server {
    listen 80;
    server_name yourdomain.com;

    root $apps_dir/web;
    index index.html index.htm;

    # Logs to ZFS
    access_log $logs_dir/nginx/access.log;
    error_log $logs_dir/nginx/error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Static files
    location /static/ {
        alias $apps_dir/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Uploads
    location /uploads/ {
        alias $data_dir/uploads/;
        client_max_body_size 100M;
    }
}
EOF
        log "Nginx configuration template created"
    fi

    # Apache configuration template
    if [[ -d "$apps_dir/web" ]]; then
        sudo tee "$apps_dir/web/apache-template.conf" > /dev/null <<EOF
# Apache Configuration Template for ZFS
<VirtualHost *:80>
    ServerName yourdomain.com
    DocumentRoot $apps_dir/web

    # Logs to ZFS
    ErrorLog $logs_dir/apache/error.log
    CustomLog $logs_dir/apache/access.log combined

    <Directory $apps_dir/web>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Static files
    Alias /static/ $apps_dir/static/
    <Directory $apps_dir/static/>
        ExpiresActive On
        ExpiresDefault "access plus 1 year"
    </Directory>

    # Uploads
    Alias /uploads/ $data_dir/uploads/
    <Directory $data_dir/uploads/>
        Options -Indexes
        Require all granted
    </Directory>
</VirtualHost>
EOF
        log "Apache configuration template created"
    fi
}

create_migration_tools() {
    log "Creating server migration tools..."

    # Create server migration script
    sudo tee /usr/local/bin/server-migrate.sh > /dev/null <<'EOF'
#!/bin/bash
# Complete Server Migration Script using ZFS
# Usage: server-migrate.sh export|import [target-server]

set -euo pipefail

OPERATION=${1:-export}
TARGET=${2:-backup}
DATE=$(date +%Y%m%d-%H%M%S)

# Logging for migration
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Detect server data location
detect_server_base() {
    if [[ -d /server-data ]]; then
        echo "/server-data"
    elif [[ -d /srv ]]; then
        echo "/srv"
    else
        echo "/srv"
    fi
}

# Update service configurations for new server
update_service_configs() {
    local new_base="$1"
    log "Updating service configurations for new server base: $new_base"

    # Update Docker configuration
    if [[ -f /etc/docker/daemon.json ]]; then
        log "Updating Docker configuration..."
        local docker_dir="$new_base/docker"
        sudo mkdir -p "$docker_dir"
        sudo jq --arg docker_dir "$docker_dir" '.["data-root"] = $docker_dir' /etc/docker/daemon.json > /tmp/daemon.json
        sudo mv /tmp/daemon.json /etc/docker/daemon.json
        sudo systemctl restart docker 2>/dev/null || true
    fi

    # Update rsyslog configuration
    if [[ -f /etc/rsyslog.d/99-zfs-logs.conf ]]; then
        log "Updating rsyslog configuration..."
        local logs_dir="$new_base/logs"
        sudo mkdir -p "$logs_dir/system" "$logs_dir/security"
        sudo sed -i "s|/server-data/logs|$logs_dir|g" /etc/rsyslog.d/99-zfs-logs.conf
        sudo sed -i "s|/srv/logs|$logs_dir|g" /etc/rsyslog.d/99-zfs-logs.conf
        sudo systemctl restart rsyslog 2>/dev/null || true
    fi

    # Update logrotate configuration
    if [[ -f /etc/logrotate.d/zfs-logs ]]; then
        log "Updating logrotate configuration..."
        local logs_dir="$new_base/logs"
        sudo sed -i "s|/server-data/logs|$logs_dir|g" /etc/logrotate.d/zfs-logs
        sudo sed -i "s|/srv/logs|$logs_dir|g" /etc/logrotate.d/zfs-logs
    fi

    # Update npm configuration
    if command -v npm &> /dev/null; then
        log "Updating npm configuration..."
        local apps_dir="$new_base/apps"
        sudo mkdir -p "$apps_dir/node_modules"
        npm config set prefix "$apps_dir/node_modules" 2>/dev/null || true
        npm config set cache "$new_base/data/cache/npm" 2>/dev/null || true
    fi

    log "Service configurations updated for new server"
}

case $OPERATION in
    export)
        log "=== Exporting Complete Server State ==="

        # Validate ZFS pools exist
        if ! zpool list >/dev/null 2>&1; then
            error "No ZFS pools found. Cannot export."
        fi

        # Create migration snapshots
        log "Creating migration snapshots..."
        for dataset in $(zfs list -H -o name | grep -E "(rpool|server-data)" | head -5); do
            if zfs list "$dataset" >/dev/null 2>&1; then
                zfs snapshot "$dataset@migrate-$DATE" 2>/dev/null || true
                log "  ✓ Snapshot: $dataset@migrate-$DATE"
            fi
        done

        # Export server state
        mkdir -p "/tmp/server-migration-$DATE"

        log "Exporting ZFS datasets..."
        for dataset in $(zfs list -H -o name | grep -E "(rpool|server-data)" | head -1); do
            if zfs list "$dataset" >/dev/null 2>&1; then
                zfs send -R "$dataset@migrate-$DATE" | gzip > "/tmp/server-migration-$DATE/complete-server-$DATE.zfs.gz"
                log "  ✓ Exported: $dataset to complete-server-$DATE.zfs.gz"
            fi
        done

        # Export service configurations
        log "Exporting service configurations..."
        local server_base=$(detect_server_base)
        mkdir -p "/tmp/server-migration-$DATE/configs"

        # Export Docker configuration
        if [[ -f /etc/docker/daemon.json ]]; then
            cp /etc/docker/daemon.json "/tmp/server-migration-$DATE/configs/"
        fi

        # Export rsyslog configuration
        if [[ -f /etc/rsyslog.d/99-zfs-logs.conf ]]; then
            cp /etc/rsyslog.d/99-zfs-logs.conf "/tmp/server-migration-$DATE/configs/"
        fi

        # Export logrotate configuration
        if [[ -f /etc/logrotate.d/zfs-logs ]]; then
            cp /etc/logrotate.d/zfs-logs "/tmp/server-migration-$DATE/configs/"
        fi

        # Export npm configuration
        if command -v npm &> /dev/null; then
            npm config list > "/tmp/server-migration-$DATE/configs/npm-config"
        fi

        # Export environment information
        cat > "/tmp/server-migration-$DATE/migration-info.txt" <<EOL
=== Server Migration Package ===
Date: $(date)
Source Server: $(hostname)
Ubuntu Version: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
ZFS Version: $(zfs version | head -1)
Server Base Directory: $server_base

=== Included Data ===
- Complete ZFS filesystem with all datasets
- All configurations in $server_base/configs
- Docker containers and volumes
- Application code and deployments
- User data and home directories
- System configurations and service configs
- Scripts and automation tools
- SSL certificates and keys
- Database data
- Log files and configurations

=== Services Configured ===
- Docker: Data root configured for $server_base/docker
- System Logging: Logs directed to $server_base/logs
- Node.js: npm configured for $server_base/apps
- Web Applications: Configured for $server_base/apps/web

=== Migration Instructions ===
1. Set up target server with Ubuntu and ZFS
2. Copy this migration package to target server
3. Run: server-migrate.sh import complete-server-$DATE.zfs.gz
4. The script will automatically update all service configurations
5. Verify services and update network configurations
6. Update DNS records to point to new server
EOL

        log ""
        log "✓ Complete server migration package created:"
        log "  Location: /tmp/server-migration-$DATE/"
        log "  Package: complete-server-$DATE.zfs.gz"
        log "  Configs: configs/"
        log "  Info: migration-info.txt"
        log ""
        log "To migrate to new server:"
        log "  1. Copy entire folder to target server"
        log "  2. Run: server-migrate.sh import complete-server-$DATE.zfs.gz"
        ;;

    import)
        IMPORT_FILE=$TARGET
        log "=== Importing Complete Server State ==="
        log "Import file: $IMPORT_FILE"

        if [[ ! -f "$IMPORT_FILE" ]]; then
            error "Import file not found: $IMPORT_FILE"
        fi

        # Validate file integrity
        if ! gzip -t "$IMPORT_FILE" 2>/dev/null; then
            error "Import file is corrupted or not a valid gzip file"
        fi

        # Determine target server base directory
        local target_base=$(detect_server_base)
        log "Target server base directory: $target_base"

        log "Importing ZFS datasets..."
        if ! gunzip -c "$IMPORT_FILE" | zfs receive -F rpool/imported 2>/dev/null; then
            if ! gunzip -c "$IMPORT_FILE" | zfs receive -F server-data/imported; then
                error "ZFS import failed"
            fi
        fi

        # Update service configurations for new server
        update_service_configs "$target_base"

        log "✓ Complete server state imported successfully"
        log ""
        log "Next steps:"
        log "  1. Review imported datasets: zfs list"
        log "  2. Verify service configurations are updated"
        log "  3. Restart services: sudo systemctl restart docker"
        log "  4. Check logs: ls $target_base/logs/"
        log "  5. Update network configurations"
        log "  6. Verify all applications are running"
        ;;

    *)
        echo "Usage: $0 export|import [import-file]"
        echo "  export - Create complete server migration package"
        echo "  import - Import server state from migration package"
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/server-migrate.sh

    # Create server state organization script
    sudo tee /usr/local/bin/server-organize.sh > /dev/null <<'EOF'
#!/bin/bash
# Server State Organization Script
# Helps organize server components for easy migration

set -euo pipefail

echo "=== Server State Organization ==="

# Detect server data location
if [[ -d /server-data ]]; then
    SERVER_BASE="/server-data"
elif [[ -d /srv ]]; then
    SERVER_BASE="/srv"
else
    echo "Creating /srv for server organization..."
    sudo mkdir -p /srv
    SERVER_BASE="/srv"
fi

echo "Organizing server state in: $SERVER_BASE"

# Create organized structure if not exists
sudo mkdir -p $SERVER_BASE/{configs,docker,scripts,apps,data,logs}
sudo mkdir -p $SERVER_BASE/configs/{nginx,apache,ssl,ssh,system,firewall}
sudo mkdir -p $SERVER_BASE/docker/{containers,volumes,compose,images}
sudo mkdir -p $SERVER_BASE/scripts/{setup,maintenance,deployment,monitoring}
sudo mkdir -p $SERVER_BASE/apps/{web,api,services,static}
sudo mkdir -p $SERVER_BASE/data/{databases,uploads,cache,sessions}
sudo mkdir -p $SERVER_BASE/logs/{nginx,apache,app,system,security}

echo ""
echo "✓ Server organization structure created"
echo ""
echo "Move your server components to:"
echo "  Configs: $SERVER_BASE/configs/"
echo "  Docker: $SERVER_BASE/docker/"
echo "  Scripts: $SERVER_BASE/scripts/"
echo "  Apps: $SERVER_BASE/apps/"
echo "  Data: $SERVER_BASE/data/"
echo "  Logs: $SERVER_BASE/logs/"
echo ""

# Configure services to use organized directories
echo "=== Configuring Services ==="

# Configure Docker
if command -v docker &> /dev/null; then
    echo "Configuring Docker to use $SERVER_BASE/docker..."
    sudo mkdir -p $SERVER_BASE/docker
    sudo chown root:root $SERVER_BASE/docker
    sudo chmod 711 $SERVER_BASE/docker

    # Update Docker daemon configuration
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null <<DOCKER_EOF
{
  "data-root": "$SERVER_BASE/docker",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true,
  "userland-proxy": false
}
DOCKER_EOF

    echo "✓ Docker configured. Restart Docker service to apply changes."
    sudo systemctl restart docker 2>/dev/null || echo "Docker restart failed, but configuration applied"
fi

# Configure system logging
echo "Configuring system logging to use $SERVER_BASE/logs..."
sudo mkdir -p $SERVER_BASE/logs/{system,security,app}

# Configure rsyslog
sudo tee /etc/rsyslog.d/99-zfs-logs.conf > /dev/null <<RSYSLOG_EOF
# Log to organized directory
*.*;auth,authpriv.none          $SERVER_BASE/logs/system/syslog
auth,authpriv.*                 $SERVER_BASE/logs/security/auth.log
cron.*                          $SERVER_BASE/logs/system/cron.log
RSYSLOG_EOF

# Configure logrotate
sudo tee /etc/logrotate.d/zfs-logs > /dev/null <<LOGROTATE_EOF
$SERVER_BASE/logs/system/*.log
$SERVER_BASE/logs/security/*.log
$SERVER_BASE/logs/app/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate 2>/dev/null || true
    endscript
}
LOGROTATE_EOF

sudo systemctl restart rsyslog 2>/dev/null || echo "rsyslog restart failed, but configuration applied"

# Configure Node.js/npm
if command -v npm &> /dev/null; then
    echo "Configuring npm to use $SERVER_BASE/apps..."
    sudo mkdir -p $SERVER_BASE/apps/node_modules
    sudo chown -R $USER:$USER $SERVER_BASE/apps/node_modules 2>/dev/null || true
    npm config set prefix $SERVER_BASE/apps/node_modules 2>/dev/null || true
    npm config set cache $SERVER_BASE/data/cache/npm 2>/dev/null || true
fi

# Set proper permissions
echo "Setting proper permissions..."
sudo chown -R root:root $SERVER_BASE
sudo chmod -R 755 $SERVER_BASE

# Set permissions for web content
sudo chown -R www-data:www-data $SERVER_BASE/apps/web 2>/dev/null || true
sudo chown -R www-data:www-data $SERVER_BASE/data/uploads 2>/dev/null || true
sudo chown -R www-data:www-data $SERVER_BASE/data/cache 2>/dev/null || true
sudo chown -R www-data:www-data $SERVER_BASE/data/sessions 2>/dev/null || true

echo ""
echo "✓ All services configured to use organized directories"
echo ""
echo "This organization ensures complete server portability with ZFS migration."
echo ""
echo "Next steps:"
echo "  1. Move your existing data to the organized directories"
echo "  2. Update any application configurations to use new paths"
echo "  3. Restart services that were reconfigured"
echo "  4. Test your applications"
echo ""
echo "For migration:"
echo "  - Run: sudo /usr/local/bin/server-migrate.sh export"
echo "  - Copy the migration package to new server"
echo "  - Run: sudo /usr/local/bin/server-migrate.sh import <file>"
EOF

    sudo chmod +x /usr/local/bin/server-organize.sh

    log "Server migration tools created"
}
