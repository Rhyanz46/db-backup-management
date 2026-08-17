# Makefile Quick Reference Guide

## 🚀 Quick Start

### Installation with Custom Port
```bash
# Install with specific port (e.g., 3724)
make install PORT=3724

# Quick installations
make install-dev    # Port 8080 (development)
make install-prod   # Port 3724 (production)
```

### Service Management
```bash
make service-start      # Start the service
make service-stop       # Stop the service
make service-restart    # Restart the service
make service-status     # Check service status
make service-logs       # View real-time logs
make service-debug      # Show recent logs
```

## 📋 Common Commands

### Deployment
```bash
# Install and configure everything
make install PORT=3724 && make firewall-setup PORT=3724 && make service-start

# Update to latest version
make update-and-deploy

# Check deployment health
make check-deployment
```

### Development
```bash
# Build and test
make build
make test
make check

# Run locally
make run-cli          # Interactive CLI
make run-server       # REST server with default port
make dev-server       # Development mode
```

### Firewall Management
```bash
# Open port in firewall (supports UFW and firewalld)
make firewall-setup PORT=3724

# Manual firewall commands (if needed)
sudo ufw allow 3724/tcp                    # Ubuntu/Debian
sudo firewall-cmd --permanent --add-port=3724/tcp  # RHEL/CentOS
sudo firewall-cmd --reload                 # RHEL/CentOS
```

### Maintenance
```bash
# Uninstall with data preservation
make uninstall

# Clean build artifacts
make clean

# Rebuild from scratch
make rebuild
```

## 🎯 Usage Examples

### Example 1: Fresh Production Installation
```bash
# Install system dependencies
make install-deps

# Install with production port
make install PORT=3724

# Configure firewall
make firewall-setup PORT=3724

# Start and verify service
make service-start
make service-status

# Check deployment health
make check-deployment
```

### Example 2: Update Existing Installation
```bash
# Update to latest version (includes git pull, build, deploy)
make update-and-deploy

# Check if everything is working
make check-deployment
```

### Example 3: Development Workflow
```bash
# Development setup
make setup

# Run interactive CLI to configure servers
make dev-cli

# Run server for testing
make run-server-port
```

### Example 4: Troubleshooting
```bash
# Check service status
make service-status

# View recent logs
make service-debug

# View live logs
make service-logs

# Verify deployment
make check-deployment
```

## 🔧 Advanced Usage

### Custom Installation Directory
```bash
# Install to custom location
make install INSTALL_PREFIX=/opt/backup-service PORT=3724
```

### Environment Variables
```bash
# Set environment variables for custom paths
export SERVICE_PORT=9000
export INSTALL_PREFIX=/usr/local/bin

# Then run make commands
make install
```

### Build Options
```bash
# Debug build
RUST_LOG=debug make build

# Release build with optimizations
make build
```

## 🚨 Error Handling

### Common Issues and Solutions

1. **Port Already in Use**
   ```bash
   # Check what's using the port
   sudo netstat -tuln | grep :3724

   # Choose a different port
   make install PORT=3725
   ```

2. **Service Won't Start**
   ```bash
   # Check logs
   make service-debug

   # Check configuration
   sudo -u backup-service /usr/local/bin/backup-service test
   ```

3. **Permission Errors**
   ```bash
   # Ensure proper ownership
   sudo chown -R backup-service:backup-service /etc/backup-service
   ```

4. **Build Failures**
   ```bash
   # Install dependencies
   make install-deps

   # Clean and rebuild
   make rebuild
   ```

## 📊 Service Status Indicators

### Status Colors and Meanings
- 🟢 **GREEN**: Success/Running
- 🔴 **RED**: Error/Stopped
- 🟡 **YELLOW**: Warning/Disabled
- 🔵 **BLUE**: Information/In Progress

### Health Check Commands
```bash
make check-deployment    # Comprehensive health check
make service-status      # Service status only
make service-debug       # Recent logs for debugging
```

## 🔄 Backup and Recovery

### Backup Configuration
```bash
# Backup configuration files
sudo tar -czf backup-config-$(date +%Y%m%d).tar.gz /etc/backup-service/config
```

### Service Recovery
```bash
# Restart service if issues occur
make service-restart

# Full redeployment if needed
make update-and-deploy
```

## 📝 Tips and Best Practices

1. **Always check port availability before installation**
2. **Use firewall-setup after installation**
3. **Run check-deployment after making changes**
4. **Keep service logs handy for troubleshooting**
5. **Test backup operations regularly**
6. **Monitor disk space for backup files**

## 🆘 Getting Help

```bash
# Show all available commands
make help

# Check this guide
cat MAKEFILE_QUICK_GUIDE.md

# Full deployment documentation
cat DEPLOYMENT.md
```