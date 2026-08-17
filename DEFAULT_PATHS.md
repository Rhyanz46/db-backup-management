# Default Directory Structure Configuration

This document explains the default directory structure for the PostgreSQL Backup Management System in production environments.

## Default Paths

The system uses the following default paths in production:

- **Config Directory**: `/etc/backup-service/config`
- **Backup Directory**: `/etc/backup-service/backup`

## Directory Structure

```
/etc/backup-service/
├── config/
│   ├── servers.json      # Server configurations
│   └── telegram.json     # Telegram notification settings
└── backup/
    ├── backup_2024_01_15_10_30_00.sql
    ├── backup_2024_01_16_10_30_00.sql
    └── ...
```

## Usage Examples

### Using Default Paths

The application will automatically use the default paths unless overridden:

```bash
# These commands use the default paths (/etc/backup-service/config and /etc/backup-service/backup)
./backup-service run
./backup-service server
./backup-service backup
./backup-service list
```

### Overriding Default Paths

You can override the default paths using command-line arguments:

```bash
# Use custom paths
./backup-service run --config-dir /custom/config --backup-dir /custom/backup

# Override only config directory
./backup-service run --config-dir /custom/config

# Override only backup directory
./backup-service run --backup-dir /custom/backup
```

### Development vs Production

During development, you might want to use local directories:

```bash
# Development with local paths
./backup-service run --config-dir ./config --backup-dir ./backup

# Development server with local paths
./backup-service server --config-dir ./config --backup-dir ./backup --port 8080
```

## Installation and Setup

When using `make install`, the system will:

1. Create the default directories: `/etc/backup-service/config` and `/etc/backup-service/backup`
2. Set proper ownership to the `backup-service` user
3. Configure systemd service to use these paths
4. Set appropriate permissions

```bash
# Install with default paths
make install

# This creates:
# - /etc/backup-service/config
# - /etc/backup-service/backup
```

## File Permissions

The directories are created with the following permissions:

- **Owner**: `backup-service:backup-service`
- **Permissions**: `755` (drwxr-xr-x)
- **Config files**: `644` (rw-r--r--)

## Systemd Service

The systemd service is configured to run with the default paths:

```ini
[Service]
ExecStart=/usr/local/bin/backup-service server \
  --config-dir /etc/backup-service/config \
  --backup-dir /etc/backup-service/backup \
  --port 8080
WorkingDirectory=/etc/backup-service
```

## Migration from Old Paths

If you were using the old paths (`./config` and `./backup`), you can migrate your data:

```bash
# Create new directories
sudo mkdir -p /etc/backup-service/{config,backup}

# Copy existing data (adjust paths as needed)
sudo cp -r ./config/* /etc/backup-service/config/
sudo cp -r ./backup/* /etc/backup-service/backup/

# Set proper ownership
sudo chown -R backup-service:backup-service /etc/backup-service

# Verify permissions
sudo ls -la /etc/backup-service/
```

## Backup Strategy

The default backup directory structure is designed for:

- **System-level backups**: Easy to include in system-wide backup strategies
- **Access control**: Centralized under `/etc/` for better security
- **Monitoring**: Simple to monitor with standard system monitoring tools
- **Maintenance**: Consistent with Linux system administration practices

## Troubleshooting

### Permission Issues

If you encounter permission errors:

```bash
# Check ownership
ls -la /etc/backup-service/

# Fix ownership if needed
sudo chown -R backup-service:backup-service /etc/backup-service

# Check permissions
ls -la /etc/backup-service/config/
ls -la /etc/backup-service/backup/
```

### Directory Not Found

If directories don't exist:

```bash
# Create directories manually
sudo mkdir -p /etc/backup-service/{config,backup}
sudo chown -R backup-service:backup-service /etc/backup-service
```

### Service Not Starting

Check systemd service logs:

```bash
# Check service status
sudo systemctl status backup-service

# View service logs
sudo journalctl -u backup-service -f

# Check for permission issues in logs
sudo journalctl -u backup-service | grep -i permission
```

## Environment Variables

You can also use environment variables to override paths (useful for containerization):

```bash
export CONFIG_DIR="/etc/backup-service/config"
export BACKUP_DIR="/etc/backup-service/backup"

# The application will pick up these environment variables
./backup-service run
```

## Container Considerations

For Docker/Kubernetes deployments, you might want to:

1. Mount volumes at the default paths:
```yaml
volumes:
  - ./config:/etc/backup-service/config
  - ./backup:/etc/backup-service/backup
```

2. Or override paths via environment variables:
```yaml
environment:
  - CONFIG_DIR=/app/config
  - BACKUP_DIR=/app/backup
```