# Environment Variables Reference

This document describes all environment variables used by the PostgreSQL Backup Management System.

## 📋 Quick Reference

### Database Configuration
```bash
DEFAULT_DB_HOST=localhost          # Default PostgreSQL host
DEFAULT_DB_PORT=5432             # Default PostgreSQL port
DEFAULT_DB_NAME=backup_db        # Default database name
DEFAULT_DB_USER=postgres         # Default database username
```

### Application Settings
```bash
APP_NAME=backup-service          # Application name
RUST_LOG=info                  # Log level (debug, info, warn, error)
REST_PORT=8080                 # REST API server port
APP_WORKDIR=/opt/backup-service # Working directory
```

### Directory Paths
```bash
CONFIG_DIR=/opt/backup-service/config   # Configuration directory
BACKUP_DIR=/opt/backup-service/backup   # Backup storage directory
LOG_DIR=/var/log/backup-service         # Log files directory
```

## 📚 Complete Environment Variables

### Database Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `DEFAULT_DB_HOST` | `localhost` | Default PostgreSQL server host |
| `DEFAULT_DB_PORT` | `5432` | Default PostgreSQL server port |
| `DEFAULT_DB_NAME` | `backup_db` | Default database name |
| `DEFAULT_DB_USER` | `postgres` | Default database username |

### Application Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `APP_NAME` | `backup-service` | Application name for logging |
| `APP_VERSION` | `0.1.0` | Application version |
| `APP_WORKDIR` | `/opt/backup-service` | Working directory |
| `RUST_LOG` | `info` | Log level (debug, info, warn, error) |
| `RUST_BACKTRACE` | `1` | Enable error backtraces |
| `REST_PORT` | `8080` | REST API server port |
| `REST_HOST` | `0.0.0.0` | REST API server host |

### Directory Paths
| Variable | Default | Description |
|----------|---------|-------------|
| `INSTALL_DIR` | `/opt/backup-service` | Installation directory |
| `CONFIG_DIR` | `/opt/backup-service/config` | Configuration files directory |
| `BACKUP_DIR` | `/opt/backup-service/backup` | Backup files directory |
| `LOG_DIR` | `/var/log/backup-service` | Log files directory |
| `TEMP_DIR` | `/tmp/backup-service` | Temporary processing directory |

### Security Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `SERVICE_USER` | `backup-service` | Service user |
| `SERVICE_GROUP` | `backup-service` | Service group |
| `DEBUG_MODE` | `false` | Enable debug mode |
| `RUST_BACKTRACE` | `1` | Error backtrace level |

### Backup Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `COMPRESS_BACKUPS` | `false` | Compress backup files |
| `MAX_BACKUPS_RETAINED` | `30` | Maximum backup count |
| `BACKUP_RETENTION_DAYS` | `30` | Backup retention period |
| `DEFAULT_SCHEMAS` | `public` | Default schemas to backup |

### Notification Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `TELEGRAM_ENABLED` | `false` | Enable Telegram notifications |
| `TELEGRAM_BOT_TOKEN` | `""` | Telegram bot token |
| `TELEGRAM_CHAT_ID` | `""` | Telegram chat ID |

### Performance Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `MAX_CONCURRENT_BACKUPS` | `1` | Concurrent backup limit |
| `DB_CONNECTION_TIMEOUT` | `30` | Connection timeout (seconds) |
| `BACKUP_TIMEOUT` | `3600` | Backup timeout (seconds) |
| `BACKUP_MEMORY_LIMIT` | `1024` | Memory limit (MB) |

### Logging Configuration
| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_MAX_SIZE` | `100MB` | Maximum log file size |
| `LOG_MAX_FILES` | `5` | Number of log files |
| `LOG_ROTATION` | `daily` | Log rotation frequency |
| `STRUCTURED_LOGGING` | `false` | Structured logging format |
| `LOG_TO_JOURNAL` | `true` | Log to systemd journal |

### Monitoring
| Variable | Default | Description |
|----------|---------|-------------|
| `ENABLE_METRICS` | `true` | Enable metrics collection |
| `METRICS_PORT` | `9090` | Metrics server port |
| `HEALTH_CHECK_INTERVAL` | `60` | Health check interval |

### Development Settings
| Variable | Default | Description |
|----------|---------|-------------|
| `DEVELOPMENT_MODE` | `false` | Development mode |
| `ENABLE_PROFILING` | `false` | Enable profiling |
| `TEST_CONNECTION_ON_STARTUP` | `true` | Test connection on startup |

## 🔧 Environment Templates

### Production Environment
```bash
# Database
DEFAULT_DB_HOST=192.168.1.100
DEFAULT_DB_PORT=5432
DEFAULT_DB_NAME=production_app
DEFAULT_DB_USER=backup_service

# Security
DEBUG_MODE=false
RUST_LOG=info

# Performance
MAX_CONCURRENT_BACKUPS=2
BACKUP_MEMORY_LIMIT=2048

# Notifications
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_ID=-1234567890123
```

### Development Environment
```bash
# Database
DEFAULT_DB_HOST=localhost
DEFAULT_DB_PORT=5432
DEFAULT_DB_NAME=dev_app
DEFAULT_DB_USER=postgres

# Security
DEBUG_MODE=true
RUST_LOG=debug
RUST_BACKTRACE=1

# Performance
MAX_CONCURRENT_BACKUPS=1
BACKUP_MEMORY_LIMIT=512

# Development
DEVELOPMENT_MODE=true
ENABLE_PROFILING=true
```

### Staging Environment
```bash
# Use production template with staging-specific overrides
# Production settings with development logging
RUST_LOG=debug
BACKUP_RETENTION_DAYS=30
```

## 🚀 Usage Examples

### Setting Environment Variables

#### Method 1: Environment File (.env)
```bash
# Create .env file in project root
cat > .env << EOF
DEFAULT_DB_HOST=localhost
DEFAULT_DB_PORT=5432
DEFAULT_DB_NAME=myapp
RUST_LOG=debug
EOF
```

#### Method 2: Export Variables
```bash
export DEFAULT_DB_HOST=localhost
export DEFAULT_DB_PORT=5432
export DEFAULT_DB_NAME=myapp
export RUST_LOG=debug
```

#### Method 3: Command Line
```bash
DEFAULT_DB_HOST=localhost \
DEFAULT_DB_PORT=5432 \
DEFAULT_DB_NAME=myapp \
RUST_LOG=debug \
./target/release/backup-service run
```

### Environment Loading Priority

Variables are loaded in this order:
1. System environment variables
2. `.env` file in project root
3. Command-line arguments override both

### Environment Detection

The system automatically detects:
```bash
DETECTED_OS=linux
DETECTED_ARCH=x86_64
DETECTED_DISTRO=ubuntu  # if /etc/os-release exists
```

## 🔒 Security Best Practices

### Environment File Security
```bash
# Set restrictive permissions
chmod 600 .env

# Secure sensitive variables
chown backup-service:backup-service .env
```

### Production Recommendations
1. **Never commit `.env` files to version control**
2. **Use environment variables in production**
3. **Limit access to sensitive configuration**
4. **Regularly rotate secrets and passwords**
5. **Use different environments for prod/staging/dev**

### Production Environment Setup
```bash
# Use environment variables instead of .env
export DEFAULT_DB_HOST=prod-db.company.com
export DEFAULT_DB_USER=backup_service
export TELEGRAM_BOT_TOKEN=your_bot_token
export TELEGRAM_CHAT_ID=your_chat_id

# Run service
sudo -E /opt/backup-service/bin/backup-service server
```

## 🐳 Docker Environment Example

```dockerfile
# Dockerfile example
FROM rust:1.70 as builder

# Set build environment
ENV RUST_LOG=info
ENV APP_NAME=backup-service

# Runtime environment
ENV RUST_LOG=info
ENV DEFAULT_DB_HOST=database
ENV DEFAULT_DB_PORT=5432
ENV DEFAULT_DB_NAME=postgres

# Copy application
COPY . /app
WORKDIR /app

# Build and run
RUN cargo build --release
CMD ["./target/release/backup-service", "server"]
```

## 🔍 Troubleshooting Environment Issues

### Common Problems

#### Variable Not Loading
```bash
# Check if .env file exists
ls -la .env

# Check file permissions
ls -la .env  # Should be 600 for sensitive files

# Check syntax
cat .env | grep DEFAULT_DB
```

#### Service Won't Start
```bash
# Check environment variables
env | grep DEFAULT_DB

# Check environment file
cat .env

# Test with environment
DEFAULT_DB_HOST=localhost ./target/release/backup-service --help
```

#### Permission Issues
```bash
# Check file permissions
ls -la /opt/backup-service/

# Fix ownership
sudo chown -R backup-service:backup-service /opt/backup-service/
sudo chmod 700 /opt/backup-service/config
```

---

**💡 Tip:** Use the provided environment setup script for easy configuration:
```bash
./linux-deployment/scripts/setup-env.sh production
```