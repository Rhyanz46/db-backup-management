# Production Deployment Guide

This guide covers the complete deployment of the PostgreSQL Backup Management System in a production Linux environment.

## Prerequisites

### System Requirements

- **OS**: Linux (Ubuntu 18.04+, CentOS 7+, RHEL 7+, Fedora 28+, Arch Linux)
- **RAM**: Minimum 512MB, Recommended 1GB+
- **Storage**: Depends on backup size and retention policy
- **Network**: Access to PostgreSQL servers

### Required Software

- PostgreSQL client tools (`postgresql-client` or equivalent)
- Rust toolchain (for building from source)
- System dependencies (installed via `make install-deps`)

## Installation

### 1. Clone and Build

```bash
# Clone the repository
git clone <repository-url>
cd backup-service

# Install system dependencies
make install-deps

# Build the application
make build
```

### 2. System Installation

#### Option A: Custom Port Installation (Recommended)
```bash
# Install with custom port (e.g., 3724 for production)
make install PORT=3724

# Quick installations
make install-prod  # Port 3724 (production)
make install-dev   # Port 8080 (development)
```

#### Option B: Default Port Installation
```bash
# Install with default port 8080
make install
```

**Installation Process:**
- ✅ Validates port (1024-65535) and checks availability
- ✅ Installs binary to `/usr/local/bin/backup-service`
- ✅ Creates directories `/etc/backup-service/{config,backup}`
- ✅ Creates `backup-service` system user
- ✅ Generates and installs systemd service with custom port
- ✅ Enables service for auto-start on boot
- ✅ Shows next steps and configuration tips

### 3. Verify Installation

```bash
# Enhanced deployment health check
make check-deployment

# Check service status
make service-status

# Check binary installation
which backup-service
backup-service --version

# Check directories
ls -la /etc/backup-service/
```

### 4. Configure Firewall

```bash
# Auto-configure firewall for your port (e.g., 3724)
make firewall-setup PORT=3724

# Manual firewall configuration (if needed)
sudo ufw allow 3724/tcp                    # Ubuntu/Debian
sudo firewall-cmd --permanent --add-port=3724/tcp  # RHEL/CentOS
sudo firewall-cmd --reload                 # RHEL/CentOS
```

### 5. Start Service

```bash
# Start the service with enhanced validation
make service-start

# Verify service is running
make service-status

# Check service logs if needed
make service-logs

## Configuration

### 1. Configure PostgreSQL Servers

```bash
# Interactive server configuration
sudo -u backup-service /usr/local/bin/backup-service serverconfig

# Or manually edit configuration file
sudo nano /etc/backup-service/config/servers.json
```

### 2. (Optional) Configure Telegram Notifications

```bash
# Interactive Telegram configuration
sudo -u backup-service /usr/local/bin/backup-service telegramconfig

# Or manually edit configuration file
sudo nano /etc/backup-service/config/telegram.json
```

### 3. Test Configuration

```bash
# Test connection to configured servers
sudo -u backup-service /usr/local/bin/backup-service test

# Test with specific server
sudo -u backup-service /usr/local/bin/backup-service test --server <server-name>
```

## Service Management

### Enhanced Service Management (Recommended)

```bash
# Start service with validation
make service-start

# Stop service with confirmation
make service-stop

# Restart service with health check
make service-restart

# Check detailed service status
make service-status

# View real-time logs
make service-logs

# Show recent logs for debugging
make service-debug

# Comprehensive deployment health check
make check-deployment
```

### Traditional Systemd Commands

```bash
# Start the REST API server
sudo systemctl start backup-service

# Enable to start on boot
sudo systemctl enable backup-service

# Check service status
sudo systemctl status backup-service

# View service logs
sudo journalctl -u backup-service -f

# Check service logs for errors
sudo journalctl -u backup-service --since "1 hour ago" | grep -i error

# Restart service
sudo systemctl restart backup-service

# Stop service
sudo systemctl stop backup-service

# Reload service configuration
sudo systemctl reload backup-service
```

## Network Configuration

### Firewall Settings

If using a firewall, allow access to the backup service port:

```bash
# For UFW (Ubuntu)
sudo ufw allow 8080/tcp
sudo ufw reload

# For firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload

# For iptables
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT
```

### SSL/TLS Configuration

The service supports PostgreSQL SSL connections. Configure SSL mode in server configuration:

```json
{
  "name": "production-db",
  "host": "db.example.com",
  "port": 5432,
  "database": "mydb",
  "username": "backup_user",
  "password": "secure_password",
  "ssl_mode": "require"
}
```

SSL mode options:
- `disable` - No SSL
- `allow` - Try SSL, fall back to non-SSL
- `prefer` - Try SSL, use non-SSL if not available
- `require` - Require SSL connection

## Backup Operations

### Manual Backups

```bash
# Create backup using active server
sudo -u backup-service /usr/local/bin/backup-service backup

# List all backups
sudo -u backup-service /usr/local/bin/backup-service list

# Show backup details
sudo -u backup-service /usr/local/bin/backup-service details backup_2024_01_15_10_30_00.sql
```

### Automated Backups

#### Using Cron

```bash
# Edit crontab for backup-service user
sudo crontab -u backup-service -e

# Add daily backup at 2 AM
0 2 * * * /usr/local/bin/backup-service backup

# Add weekly backup on Sunday at 3 AM
0 3 * * 0 /usr/local/bin/backup-service backup
```

#### Using systemd Timer

```bash
# Create backup timer
sudo tee /etc/systemd/system/backup-service.timer > /dev/null <<EOF
[Unit]
Description=Run PostgreSQL backup daily
Requires=backup-service.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Create backup service
sudo tee /etc/systemd/system/backup-backup.service > /dev/null <<EOF
[Unit]
Description=PostgreSQL backup job
After=network.target

[Service]
Type=oneshot
User=backup-service
ExecStart=/usr/local/bin/backup-service backup
StandardOutput=journal
StandardError=journal
EOF

# Enable and start timer
sudo systemctl enable backup-service.timer
sudo systemctl start backup-service.timer

# Check timer status
sudo systemctl list-timers backup-service.timer
```

## Deployment Pipeline

### Automated Updates

```bash
# Complete update and deployment pipeline
make update-and-deploy
```

**The pipeline performs:**
1. ✅ Validates current service installation
2. ✅ Pulls latest changes from git repository
3. ✅ Builds the application in release mode
4. ✅ Stops the service gracefully
5. ✅ Deploys the new binary
6. ✅ Restarts and validates the service
7. ✅ Verifies successful deployment

### Manual Update Steps

If you prefer manual updates:

```bash
# Pull latest changes
git pull

# Build new version
make build

# Stop service
make service-stop

# Deploy binary
sudo cp target/release/backup-service /usr/local/bin/backup-service

# Restart service
make service-start

# Verify deployment
make check-deployment
```

### Version Management

```bash
# Check current version
backup-service --version

# Check git status
git status

# View recent commits
git log --oneline -n 5

# View deployment history
make service-debug
```

## Monitoring and Logging

### Log Management

```bash
# View real-time logs
sudo journalctl -u backup-service -f

# Search logs for specific patterns
sudo journalctl -u backup-service | grep "backup created"

# View logs for specific time range
sudo journalctl -u backup-service --since "2024-01-01" --until "2024-01-02"
```

### Log Rotation

Install logrotate configuration:

```bash
# Copy logrotate configuration
sudo cp backup-service.logrotate /etc/logrotate.d/backup-service

# Test logrotate configuration
sudo logrotate -d /etc/logrotate.d/backup-service
```

### Monitoring Service Health

Create a simple health check script:

```bash
#!/bin/bash
# /usr/local/bin/backup-service-health-check

# Check if service is running
if ! systemctl is-active --quiet backup-service; then
    echo "ERROR: backup-service is not running"
    exit 1
fi

# Check if service responds to HTTP requests
if ! curl -f -s http://localhost:8080/health > /dev/null; then
    echo "ERROR: backup-service is not responding"
    exit 1
fi

echo "OK: backup-service is healthy"
exit 0
```

## Security Considerations

### File Permissions

```bash
# Verify correct permissions
ls -la /etc/backup-service/
# Should show backup-service:backup-service ownership

# Fix permissions if needed
sudo chown -R backup-service:backup-service /etc/backup-service
sudo chmod 755 /etc/backup-service
sudo chmod 755 /etc/backup-service/config
sudo chmod 755 /etc/backup-service/backup
sudo chmod 644 /etc/backup-service/config/*.json
```

### Database Security

- Use dedicated backup user with minimal privileges
- Store database passwords securely in the configuration files
- Use SSL connections for remote databases
- Regularly rotate database passwords

### Network Security

- Run service behind firewall
- Use reverse proxy (nginx/apache) for additional security
- Consider VPN for remote database access
- Monitor access logs

## Backup and Recovery

### Backing Up Configuration

```bash
# Backup configuration files
sudo tar -czf backup-service-config-$(date +%Y%m%d).tar.gz /etc/backup-service/config

# Include in system backup
# Add /etc/backup-service to your backup system
```

### Service Recovery

```bash
# In case of service failure:
# 1. Check logs for errors
sudo journalctl -u backup-service --since "1 hour ago"

# 2. Restart service
sudo systemctl restart backup-service

# 3. If persistent issues, check configuration
sudo -u backup-service /usr/local/bin/backup-service test

# 4. Restore configuration if needed
sudo tar -xzf backup-service-config-YYYYMMDD.tar.gz -C /
```

## Performance Tuning

### Resource Limits

Edit systemd service to adjust limits:

```ini
[Service]
# Increase file descriptor limit
LimitNOFILE=65536

# Adjust memory limits if needed
MemoryLimit=512M
MemoryMax=1G
```

### Database Connection Tuning

- Use connection pooling for multiple concurrent backups
- Configure PostgreSQL for backup workloads
- Monitor database performance during backups

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   ```bash
   # Fix ownership
   sudo chown -R backup-service:backup-service /etc/backup-service
   ```

2. **Service Won't Start**
   ```bash
   # Check logs
   sudo journalctl -u backup-service -n 50

   # Check configuration
   sudo -u backup-service /usr/local/bin/backup-service test
   ```

3. **Database Connection Issues**
   ```bash
   # Test connection manually
   sudo -u backup-service /usr/local/bin/backup-service debug --host <db-host> --username <user>
   ```

### Debug Mode

Enable debug logging:

```bash
# Temporarily enable debug
sudo systemctl edit backup-service
# Add:
# [Service]
# Environment="RUST_LOG=debug"

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart backup-service
```

## Maintenance

### Regular Tasks

- Review and clean up old backup files
- Monitor disk space usage
- Update application binary
- Test backup and restore procedures
- Review and rotate database credentials

### Updates

```bash
# Update binary
make build
sudo systemctl stop backup-service
sudo cp target/release/backup-service /usr/local/bin/backup-service
sudo systemctl start backup-service

# Or use Makefile
make rebuild
sudo systemctl restart backup-service
```

## Uninstallation

### Enhanced Uninstall (Recommended)

```bash
# Interactive uninstall with confirmation prompts
make uninstall
```

**The enhanced uninstall process:**
- ⚠️ Shows warning about what will be removed
- ✅ Prompts for confirmation before proceeding
- ✅ Stops and disables the service gracefully
- ✅ Removes the binary and systemd service
- 🤔 Asks about removing configuration and backup data
- 🤔 Asks about removing the service user
- ✅ Provides clear feedback at each step

### Manual Uninstall

```bash
# Stop and disable service
sudo systemctl stop backup-service
sudo systemctl disable backup-service

# Remove binary
sudo rm -f /usr/local/bin/backup-service

# Remove systemd service
sudo rm -f /etc/systemd/system/backup-service.service
sudo systemctl daemon-reload

# Optionally remove user and data (WARNING: This removes all data!)
sudo userdel backup-service 2>/dev/null || true
sudo rm -rf /etc/backup-service
```

### Backup Before Uninstall

If you want to preserve data before uninstalling:

```bash
# Backup configuration and data
sudo tar -czf backup-service-backup-$(date +%Y%m%d).tar.gz /etc/backup-service

# Then uninstall (choose to preserve data when prompted)
make uninstall
```