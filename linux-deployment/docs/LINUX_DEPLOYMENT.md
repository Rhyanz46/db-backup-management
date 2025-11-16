# PostgreSQL Backup Management System - Linux Deployment Guide

This guide provides comprehensive instructions for deploying the PostgreSQL Backup Management System on Linux environments.

## 🚀 Quick Start (Recommended)

For the fastest deployment, use the one-click deployment script:

```bash
# Clone the repository
git clone <repository-url>
cd backup-service

# Run one-click deployment
sudo ./linux-deployment/deploy.sh
```

This will automatically:
1. Install all system dependencies
2. Build the project
3. Set up systemd service
4. Start the service
5. Verify installation

## 📋 Prerequisites

### System Requirements
- Linux distribution (Ubuntu/Debian, RHEL/CentOS, Fedora, Arch Linux, openSUSE)
- sudo/root privileges for installation
- PostgreSQL server (any version with libpq support)
- Internet connection for dependency installation

### Manual Prerequisites Installation

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y pkg-config libssl-dev postgresql-client build-essential
```

**RHEL/CentOS:**
```bash
sudo yum groupinstall -y "Development Tools"
sudo yum install -y pkgconfig openssl-devel postgresql
```

**Fedora:**
```bash
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y pkgconfig openssl-devel postgresql
```

**Arch Linux:**
```bash
sudo pacman -S --needed pkgconf openssl postgresql base-devel
```

**openSUSE:**
```bash
sudo zypper install -y pkg-config libopenssl-devel postgresql pattern:devel_basis
```

## 🔧 Installation Options

### Option 1: One-Click Deployment (Recommended)

```bash
sudo ./linux-deployment/deploy.sh
```

### Option 2: Step-by-Step Manual Installation

#### Step 1: Install Dependencies
```bash
./linux-deployment/scripts/install-deps.sh
```

#### Step 2: Build Project
```bash
./linux-deployment/scripts/build.sh
```

#### Step 3: Setup Systemd Service
```bash
sudo ./linux-deployment/systemd/setup-service.sh
```

#### Step 4: Start Service
```bash
sudo systemctl start backup-service
sudo systemctl status backup-service
```

### Option 3: Install Rust and Build Manually

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"

# Build project
cargo build --release

# Install binary manually
sudo mkdir -p /opt/backup-service/bin
sudo cp target/release/backup-service /opt/backup-service/bin/
sudo chmod +x /opt/backup-service/bin/backup-service
```

## 📁 Directory Structure

After installation, the system creates the following directory structure:

```
/opt/backup-service/
├── bin/
│   └── backup-service          # Main executable
├── config/
│   ├── servers.json             # Server configurations
│   └── telegram.json            # Telegram settings
├── backup/                      # Backup files
└── logs/                        # Log files
```

## ⚙️ Configuration

### Server Configuration

Edit the server configuration file:
```bash
sudo nano /opt/backup-service/config/servers.json
```

Example configuration:
```json
{
  "my_production_db": {
    "name": "my_production_db",
    "host": "localhost",
    "port": 5432,
    "database": "myapp_prod",
    "username": "backup_user",
    "password": "secure_password",
    "version": null,
    "total_schemas": null,
    "is_active": true
  }
}
```

### Telegram Notifications (Optional)

Configure Telegram notifications:
```bash
sudo nano /opt/backup-service/config/telegram.json
```

```json
{
  "bot_token": "1234567890:ABCdefGHIjklMNOpqrsTUVwxyz",
  "chat_id": "123456789",
  "enabled": true
}
```

## 🚀 Service Management

### Start/Stop/Restart Service
```bash
sudo systemctl start backup-service
sudo systemctl stop backup-service
sudo systemctl restart backup-service
sudo systemctl status backup-service
```

### Enable/Disable Auto-start
```bash
sudo systemctl enable backup-service
sudo systemctl disable backup-service
```

### View Logs
```bash
sudo journalctl -u backup-service -f
sudo journalctl -u backup-service --since "1 hour ago"
```

## 🔌 REST API Usage

### Endpoints
- **GET** `http://localhost:8080/health` - Health check
- **POST** `http://localhost:8080/backup` - Trigger backup
- **GET** `http://localhost:8080/backup` - List backups

### Examples
```bash
# Health check
curl http://localhost:8080/health

# Trigger backup (for cron jobs)
curl -X POST http://localhost:8080/backup

# List backups
curl http://localhost:8080/backup
```

## 🖥️ CLI Usage

### Basic Commands
```bash
# Interactive CLI
sudo /opt/backup-service/bin/backup-service run

# List all backups
sudo /opt/backup-service/bin/backup-service list

# Create backup of active server
sudo /opt/backup-service/bin/backup-service backup

# Show backup details
sudo /opt/backup-service/bin/backup-service details backup_20241215_143022.sql

# Test connection
sudo /opt/backup-service/bin/backup-service test

# Configure servers
sudo /opt/backup-service/bin/backup-service server-config

# Configure Telegram
sudo /opt/backup-service/bin/backup-service telegram-config
```

### Restore Backup
```bash
sudo /opt/backup-service/bin/backup-service restore backup_20241215_143022.sql --server target_server
```

## 📅 Cron Job Integration

Add to your crontab for automated backups:

```bash
# Edit crontab
sudo crontab -e
```

Add line for daily backup at 2 AM:
```
0 2 * * * curl -X POST http://localhost:8080/backup
```

## 🔒 Security Considerations

### File Permissions
```bash
# Secure configuration files
sudo chmod 600 /opt/backup-service/config/*
sudo chown backup-service:backup-service /opt/backup-service/config/*

# Set proper directory permissions
sudo chmod 755 /opt/backup-service
sudo chmod 700 /opt/backup-service/{config,backup,logs}
```

### Database User
Create a dedicated backup user with minimal privileges:
```sql
CREATE USER backup_user WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE myapp_prod TO backup_user;
GRANT USAGE ON SCHEMA public TO backup_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup_user;
```

### Network Security
- Only allow access to the REST API from trusted networks
- Use HTTPS in production environments
- Configure firewall rules as needed

## 🔍 Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check service status
sudo systemctl status backup-service

# Check logs
sudo journalctl -u backup-service -n 50

# Check configuration
sudo /opt/backup-service/bin/backup-service --help
```

#### Connection Issues
```bash
# Test database connection
sudo /opt/backup-service/bin/backup-service test --server your_server_name

# Check PostgreSQL client tools
psql --version
pg_dump --version
```

#### Permission Issues
```bash
# Check file permissions
ls -la /opt/backup-service/
ls -la /opt/backup-service/config/

# Fix ownership
sudo chown -R backup-service:backup-service /opt/backup-service/
```

#### Build Issues
```bash
# Clean and rebuild
cd /path/to/backup-service
cargo clean
cargo build --release
```

### Logging Levels
Enable debug logging for troubleshooting:
```bash
# Edit systemd service
sudo systemctl edit backup-service

# Add to [Service] section:
Environment="RUST_LOG=debug"

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart backup-service
```

## 📊 Performance Considerations

### Resource Usage
- **Memory**: ~50-100MB RAM for normal operation
- **CPU**: Minimal impact during backup creation
- **Disk**: Depends on database size (backup files)
- **Network**: Minimal REST API overhead

### Optimization Tips
1. **Schedule backups** during off-peak hours
2. **Compress old backups** to save disk space
3. **Use SSD** storage for better I/O performance
4. **Monitor disk space** for backup directory
5. **Set up log rotation** for system logs

## 🔄 Updates and Maintenance

### Update Binary
```bash
# Stop service
sudo systemctl stop backup-service

# Backup current binary
sudo cp /opt/backup-service/bin/backup-service /opt/backup-service/bin/backup-service.backup

# Build and install new version
cd /path/to/backup-service
cargo build --release
sudo cp target/release/backup-service /opt/backup-service/bin/

# Start service
sudo systemctl start backup-service
```

### Backup Configuration
```bash
# Backup configuration files
sudo tar -czf backup-service-config-$(date +%Y%m%d).tar.gz /opt/backup-service/config/
```

### Clean Old Backups
```bash
# Add to cron for weekly cleanup
# Remove backups older than 30 days
find /opt/backup-service/backup -name "*.sql" -mtime +30 -delete
```

## 📞 Support

For issues and questions:
1. Check logs: `sudo journalctl -u backup-service -f`
2. Review this documentation
3. Test with CLI: `sudo /opt/backup-service/bin/backup-service --help`
4. Check system resources and PostgreSQL connectivity

## 📄 Version Information

- **Current Version**: 0.1.0
- **Rust Version**: 1.70+
- **Supported Databases**: PostgreSQL 9.6+
- **Linux Distributions**: Ubuntu, Debian, RHEL, CentOS, Fedora, Arch, openSUSE

---

**🎉 Congratulations! Your PostgreSQL Backup Management System is now deployed and ready for use!**