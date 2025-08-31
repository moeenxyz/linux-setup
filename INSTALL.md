# Ubuntu Server Setup - One-Click Installation

## 🚀 Quick Install

Run this single command on your fresh Ubuntu server:

```bash
curl -fsSL https://raw.githubusercontent.com/moeenxyz/linux-setup/main/bootstrap.sh | bash
```

Or if you prefer wget:

```bash
wget -qO- https://raw.githubusercontent.com/moeenxyz/linux-setup/main/bootstrap.sh | bash
```

## 📋 What This Does

1. **Downloads** the complete linux-setup repository
2. **Sets up** all necessary permissions
3. **Creates** configuration files from templates
4. **Runs** the full server setup automatically

## ⚙️ Configuration

After installation, you can customize the setup by editing the `.env` file:

```bash
nano .env
```

## 🔧 Manual Installation

If you prefer to download and run manually:

```bash
# Clone the repository
git clone https://github.com/moeenxyz/linux-setup.git
cd linux-setup

# Make scripts executable
chmod +x setup.sh verify.sh
chmod +x modules/*/packages/*.sh
chmod +x lib/*.sh

# Copy configuration
cp .env.example .env
# Edit .env as needed

# Run setup
./setup.sh
```

## 📦 What's Included

- ✅ Essential development tools (Git, Node.js, Zsh)
- ✅ Docker CE and Compose
- ✅ ZFS filesystem with migration tools
- ✅ Cloudflared tunnel (ARM64 compatible)
- ✅ Fail2Ban intrusion prevention
- ✅ System monitoring and maintenance

## 🛡️ Safe Installation

- No firewall rules that could lock you out
- No SSH hardening that changes access
- Continues on errors instead of stopping
- Full logging for troubleshooting

## 🎯 Perfect For

- Fresh Ubuntu server setup
- Development environments
- Production server provisioning
- Automated deployments

---

**Repository**: [github.com/moeenxyz/linux-setup](https://github.com/moeenxyz/linux-setup)</content>
<parameter name="filePath">/Users/moeen/Desktop/Codes/linux-setup/INSTALL.md
