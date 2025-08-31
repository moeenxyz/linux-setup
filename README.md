# 🚀 Ubuntu Server Setup Script

A **fully automated, production-ready** Ubuntu server setup script that creates **complete server migration capability** with ZFS. Everything is configured to use ZFS directories automatically, ensuring **zero data loss** during migration.

## ⚡ Quick Install

**One command to install everything:**

```bash
curl -fsSL https://raw.githubusercontent.com/moeenxyz/linux-setup/main/bootstrap.sh | bash
```

Or download and run:

```bash
wget -qO- https://raw.githubusercontent.com/moeenxyz/linux-setup/main/bootstrap.sh | bash
```

## ✨ Key Features

### 🎯 **Complete Automation**
- � **.env Configuration**: Fully non-interactive setup using `.env` file
- � **Zero Prompts**: No terminal prompts during execution
- ⚡ **One-Command Setup**: `./setup.sh` with `.env` file
- ✅ **Automatic Verification**: Comprehensive post-setup verification

### �️ **Production Security**
- � **SSH Hardening**: Key-only authentication, custom ports, disabled root login
- 🛡️ **UFW Firewall**: Intelligent port management
- 🚫 **Fail2Ban**: Advanced intrusion prevention
- 🔒 **Service Security**: All services configured with security best practices

### � **ZFS-Powered Migration**
- � **Complete Server State**: All data, configs, and services in ZFS
- � **One-Click Migration**: Export/import entire server state
- � **Auto Service Reconfiguration**: Services automatically use new ZFS paths
- 📁 **Organized Structure**: Everything has its place in ZFS

### � **Docker Integration**
- 📍 **ZFS Data Root**: Docker uses ZFS directory automatically
- 🔄 **Migration-Ready**: All containers and volumes migrate perfectly
- 👥 **User Group Setup**: Seamless Docker group management
- 📊 **Optimized Config**: Production-ready Docker daemon settings

### 📊 **Comprehensive Monitoring**
- 📋 **System Logging**: All logs directed to ZFS with logrotate
- 🔍 **Service Verification**: Automated health checks
- 📈 **Resource Monitoring**: System resource validation
- � **Detailed Logs**: Complete audit trail

## 📋 Requirements

- � **Ubuntu 18.04+** (24.04 recommended)
- 👤 **Non-root user** with sudo privileges
- 🌐 **Internet connection** for package downloads
- � **10GB+ free space** for ZFS pool

## 🚀 Quick Start

### 1. Clone & Configure
```bash
git clone <your-repo-url>
cd linux-setup
cp .env.example .env
nano .env  # Configure your settings
```

### 2. Run Setup
```bash
./setup.sh
```

### 3. Verify
```bash
./verify.sh
```

**That's it!** Your server is fully set up and migration-ready.

## ⚙️ Configuration (.env File)

The script uses a comprehensive `.env` file for complete automation:

```bash
# System Configuration
UPDATE_SYSTEM=Y
INSTALL_GIT=Y
INSTALL_DOCKER=Y
INSTALL_COMPOSE=Y
INSTALL_ZFS=Y

# Security Settings
SSH_PORT=2222
SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc... your-key"
HARDEN_SSH=Y
CONFIGURE_FIREWALL=Y
INSTALL_FAIL2BAN=Y

# Cloudflare Tunnel
CLOUDFLARED_TOKEN="your-token-here"
SETUP_CLOUDFLARED_TUNNEL=Y

# ZFS Configuration
ZFS_POOL_TYPE=1  # 1=file-based, 2=disk-based
CREATE_ZFS_POOL=Y
```

## 🏗️ What Gets Installed & Configured

### Core Components
- ✅ **System Updates**: Complete system upgrade and cleanup
- ✅ **Git**: Version control with user configuration
- ✅ **Docker CE**: Latest stable with ZFS integration
- ✅ **Docker Compose**: Standalone v2.x
- ✅ **ZFS**: Complete filesystem with migration tools

### Development Tools
- ✅ **Node.js LTS**: Via NodeSource with ZFS npm config
- ✅ **Python 3**: With pip and development headers
- ✅ **Essential Tools**: curl, wget, vim, htop, tree, etc.
- ✅ **Zsh + Oh My Zsh**: Enhanced shell with plugins

### Security & Services
- ✅ **UFW Firewall**: Intelligent port management
- ✅ **Fail2Ban**: SSH protection with custom port support
- ✅ **Cloudflared**: Secure tunnel with token authentication
- ✅ **SSH Hardening**: Production-ready SSH configuration

## 💾 ZFS Directory Structure (Automatic)

All services are **automatically configured** to use these ZFS directories:

```
/server-data/ or /srv/
├── docker/          # 🐳 Docker data root (auto-configured)
├── apps/            # 📱 Application code
│   ├── web/         # 🌐 Web files (nginx/apache ready)
│   ├── api/         # 🔌 API applications
│   └── services/    # ⚙️ Background services
├── data/            # 💾 Persistent data
│   ├── databases/   # 🗄️ Database files
│   ├── uploads/     # 📤 User uploads
│   ├── cache/       # 🚀 Cache files
│   └── sessions/    # 💭 Session data
├── logs/            # 📋 All logs (rsyslog configured)
│   ├── system/      # 🖥️ System logs
│   ├── security/    # 🔒 Security logs
│   ├── app/         # 📱 Application logs
│   ├── nginx/       # 🌐 Web server logs
│   └── apache/      # 🏗️ Apache logs
├── configs/         # ⚙️ Configuration files
└── scripts/         # 🤖 Automation scripts
```

## 🔄 Server Migration (Zero Data Loss)

### Export Complete Server
```bash
# � Export everything (ZFS + configs + services)
sudo /usr/local/bin/server-migrate.sh export
```

### Import on New Server
```bash
# 🖥️ Setup new server
./setup.sh

# 📥 Import complete state (auto-reconfigures all services)
sudo /usr/local/bin/server-migrate.sh import migration-package.zfs.gz
```

### What Gets Migrated
- ✅ **Complete ZFS filesystem** with all data
- ✅ **All service configurations** (Docker, logging, npm, etc.)
- ✅ **Application code and data**
- ✅ **SSL certificates and keys**
- ✅ **User data and permissions**
- ✅ **System configurations**

## 🔧 Service Integration Details

### Docker Configuration
```json
{
  "data-root": "/server-data/docker",
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "storage-driver": "overlay2",
  "live-restore": true,
  "userland-proxy": false
}
```

### System Logging (rsyslog)
```
*.*;auth,authpriv.none          /server-data/logs/system/syslog
auth,authpriv.*                 /server-data/logs/security/auth.log
```

### Node.js/npm Configuration
```bash
npm config set prefix /server-data/apps/node_modules
npm config set cache /server-data/data/cache/npm
```

## 📊 Verification & Monitoring

### Automatic Verification
The `verify.sh` script checks:
- ✅ **System resources** and compatibility
- ✅ **SSH security** configuration
- ✅ **Docker functionality** and ZFS integration
- ✅ **ZFS pools** and service configurations
- ✅ **Firewall rules** and Fail2Ban status
- ✅ **All installed tools** and versions
- ✅ **Directory structure** and permissions
- ✅ **Service health** and configurations

### Manual Verification Commands
```bash
# System status
./verify.sh

# Service status
sudo systemctl status docker
sudo systemctl status ssh
sudo systemctl status cloudflared

# ZFS status
zfs list
zpool status

# Docker with ZFS
docker system info | grep "Docker Root Dir"
```

## 🛡️ Security Features

### SSH Hardening
- 🔑 **Key-only authentication** (passwords disabled)
- 🚪 **Custom SSH port** (configurable)
- 👤 **Root login disabled**
- ⏰ **Short login grace time**
- 📊 **Verbose logging**

### Firewall (UFW)
- 🚫 **Default deny** incoming
- ✅ **Allow configured ports** only
- 📋 **Detailed rules** with comments

### Fail2Ban
- 🔍 **SSH monitoring** with custom port support
- ⏱️ **Intelligent banning** (time-based)
- 📊 **Multiple jails** support

## 📈 Advanced Features

### Migration Tools
- � **server-migrate.sh**: Complete server export/import
- � **server-organize.sh**: Organize existing server for migration
- � **Auto-reconfiguration**: Services update paths automatically

### Configuration Templates
- 🌐 **Nginx config**: Ready-to-use with ZFS paths
- 🏗️ **Apache config**: Production-ready configuration
- ⚙️ **Service templates**: For common applications

### Backup & Recovery
- 💾 **System backups**: `/var/backups/server-setup/`
- � **Configuration backups**: Automatic before changes
- � **Rollback capability**: For failed configurations

## 🚨 Important Notes

### Post-Installation Steps
1. **Log out/in** for Docker group changes
2. **Test SSH** connection with new port
3. **Verify services** are using ZFS directories
4. **Check logs** in ZFS directories

### Migration Checklist
- ✅ Run `server-organize.sh` first
- ✅ Export from source server
- ✅ Setup target server with same `.env`
- ✅ Import migration package
- ✅ Verify all services working

### Troubleshooting
- 🔍 **Check logs**: `/var/log/server-setup.log`
- 🔧 **Run verification**: `./verify.sh`
- 📋 **Service status**: `sudo systemctl status <service>`
- 🔄 **Re-run setup**: Safe to re-run for fixes

## 📋 Environment Variables

### Core Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `UPDATE_SYSTEM` | `Y` | System package updates |
| `INSTALL_DOCKER` | `Y` | Docker CE installation |
| `INSTALL_ZFS` | `Y` | ZFS with migration setup |
| `HARDEN_SSH` | `Y` | SSH security hardening |
| `SSH_PORT` | `22` | Custom SSH port |

### ZFS Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `ZFS_POOL_TYPE` | `1` | 1=file-based, 2=disk-based |
| `ZFS_DISK` | `""` | Disk device for ZFS pool |
| `CREATE_ZFS_POOL` | `Y` | Create ZFS data pool |

### Security Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `SSH_PUBLIC_KEY` | `""` | SSH public key for access |
| `CLOUDFLARED_TOKEN` | `""` | Cloudflare tunnel token |
| `FIREWALL_EXTRA_PORTS` | `""` | Additional firewall ports |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly with `./verify.sh`
5. Submit a pull request

## 📄 License

**MIT License** - See [LICENSE](LICENSE) for details.

---

## 🎯 Why This Script?

### Before: Manual Setup
- ❌ Hours of manual configuration
- ❌ Inconsistent setups
- ❌ Migration nightmares
- ❌ Security oversights
- ❌ No verification

### After: Automated Excellence
- ✅ **5-minute setup** with `.env` file
- ✅ **Consistent, repeatable** deployments
- ✅ **Zero-downtime migration** capability
- ✅ **Production security** from day one
- ✅ **Complete verification** and monitoring

### Migration Comparison

**Traditional Migration:**
1. Manual backup of each service
2. Copy files individually
3. Reconfigure each service manually
4. Test everything works
5. Hope nothing was missed

**ZFS Migration:**
1. `sudo /usr/local/bin/server-migrate.sh export`
2. Copy single file to new server
3. `sudo /usr/local/bin/server-migrate.sh import`
4. All services auto-reconfigured
5. **Everything works perfectly**

**Result: From hours/days of migration work to minutes with zero risk!** 🚀
