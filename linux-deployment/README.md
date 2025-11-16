# PostgreSQL Backup Management System - Linux Deployment Package

## 📦 Package Contents

This directory contains everything needed to deploy the PostgreSQL Backup Management System on Linux:

```
linux-deployment/
├── scripts/
│   ├── install-deps.sh        # Automatic dependency installer
│   └── build.sh                # Build script for the project
├── systemd/
│   ├── backup-service.service   # Systemd service template
│   └── setup-service.sh        # Service setup and configuration
├── configs/
│   ├── servers.json.example    # Example server configuration
│   └── telegram.json.example   # Example Telegram configuration
├── docs/
│   ├── LINUX_DEPLOYMENT.md    # Complete deployment guide
│   └── QUICK_START.md          # Quick start guide
├── deploy.sh                   # One-click deployment script
└── README.md                   # This file
```

## 🚀 Quick Deployment

For the fastest deployment, run:

```bash
sudo ./deploy.sh
```

This will:
1. ✅ Install all system dependencies automatically
2. ✅ Build the PostgreSQL backup system
3. ✅ Set up systemd service
4. ✅ Configure directories and permissions
5. ✅ Start the service
6. ✅ Verify installation

## 📋 Manual Deployment Options

### Option 1: One-Click Deployment
```bash
sudo ./deploy.sh
```

### Option 2: Step-by-Step
```bash
# 1. Install dependencies
./scripts/install-deps.sh

# 2. Build project
./scripts/build.sh

# 3. Set up service
sudo ./systemd/setup-service.sh

# 4. Start service
sudo systemctl start backup-service
```

### Option 3: Custom Installation
```bash
# Install dependencies manually
./scripts/install-deps.sh

# Build with custom options
cargo build --release

# Install manually
sudo mkdir -p /opt/backup-service/bin
sudo cp target/release/backup-service /opt/backup-service/bin/
sudo chmod +x /opt/backup-service/bin/backup-service
```

## 🔧 Configuration

### Server Configuration Example
```bash
sudo mkdir -p /opt/backup-service/config
sudo cp configs/servers.json.example /opt/backup-service/config/servers.json
sudo nano /opt/backup-service/config/servers.json
```

### Telegram Configuration Example
```bash
sudo cp configs/telegram.json.example /opt/backup-service/config/telegram.json
sudo nano /opt/backup-service/config/telegram.json
```

## 🌐 REST API

After deployment, the REST API will be available at:
- **Health Check**: http://localhost:8080/health
- **Trigger Backup**: POST http://localhost:8080/backup
- **List Backups**: GET http://localhost:8080/backup

## 🖥️ CLI Usage

```bash
# Interactive configuration
sudo /opt/backup-service/bin/backup-service run

# Quick commands
sudo /opt/backup-service/bin/backup-service list
sudo /opt/backup-service/bin/backup-service backup
sudo /opt/backup-service/bin/backup-service test
```

## 🔧 Service Management

```bash
sudo systemctl start backup-service
sudo systemctl stop backup-service
sudo systemctl restart backup-service
sudo systemctl status backup-service
sudo journalctl -u backup-service -f
```

## 📁 Installation Structure

After deployment:
```
/opt/backup-service/
├── bin/backup-service          # Main executable
├── config/                     # Configuration files
│   ├── servers.json             # Database servers
│   └── telegram.json            # Telegram notifications
├── backup/                     # Backup files storage
└── logs/                       # Log files
```

## 📚 Documentation

- **Complete Guide**: `docs/LINUX_DEPLOYMENT.md`
- **Quick Start**: `docs/QUICK_START.md`
- **Main README**: `../README.md`

## 🔄 Updates

To update the system:
```bash
sudo systemctl stop backup-service
# Build new version
./scripts/build.sh
# Replace binary
sudo cp target/release/backup-service /opt/backup-service/bin/
sudo systemctl start backup-service
```

## 🐧 Supported Linux Distributions

- Ubuntu 18.04+
- Debian 10+
- RHEL 8+
- CentOS 7+
- Fedora 30+
- Arch Linux
- openSUSE Leap 15+

## 🔒 Security

- Service runs as dedicated user `backup-service`
- Configuration files are secured with proper permissions
- Logs are handled by systemd journal
- Binary is installed in protected system directory

## 📞 Support

For troubleshooting:
1. Check service status: `sudo systemctl status backup-service`
2. View logs: `sudo journalctl -u backup-service -f`
3. Test binary: `sudo /opt/backup-service/bin/backup-service --help`
4. Review documentation in `docs/`

---

**🎉 Ready to deploy your PostgreSQL backup management system!**