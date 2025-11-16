# Quick Environment Setup Guide

## 🚀 Super Quick Setup (3 Commands)

### For Development Environment
```bash
# 1. Navigate to project
cd backup-service

# 2. Setup development environment
./linux-deployment/scripts/setup-env.sh development

# 3. Run application
cargo run -- run
```

### For Production Environment
```bash
# 1. Navigate to project
cd backup-service

# 2. Setup production environment
sudo ./linux-deployment/scripts/setup-env.sh production

# 3. Start service
sudo systemctl start backup-service
```

## 📋 Environment Templates

### Development Environment Variables
```bash
# Basic development setup
DEFAULT_DB_HOST=localhost
DEFAULT_DB_PORT=5432
DEFAULT_DB_NAME=dev_app
DEFAULT_DB_USER=postgres

# Development settings
DEBUG_MODE=true
RUST_LOG=debug
DEVELOPMENT_MODE=true
REST_PORT=8081
```

### Production Environment Variables
```bash
# Basic production setup
DEFAULT_DB_HOST=your-db-server.com
DEFAULT_DB_PORT=5432
DEFAULT_DB_NAME=production
DEFAULT_DB_USER=backup_service

# Production settings
DEBUG_MODE=false
RUST_LOG=info
TELEGRAM_ENABLED=true
REST_PORT=8080
```

## 🔧 Manual Environment Setup

### Step 1: Create Environment File
```bash
# Create .env file
cat > .env << EOF
DEFAULT_DB_HOST=localhost
DEFAULT_DB_PORT=5432
DEFAULT_DB_NAME=myapp
DEFAULT_DB_USER=postgres
RUST_LOG=debug
EOF
```

### Step 2: Verify Environment
```bash
# Check environment file
cat .env

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# Verify loaded variables
echo "Database Host: $DEFAULT_DB_HOST"
echo "Database Port: $DEFAULT_DB_PORT"
echo "Log Level: $RUST_LOG"
```

### Step 3: Run Application
```bash
# With environment file (automatic loading)
./target/release/backup-service --help

# With manual environment variables
DEFAULT_DB_HOST=localhost \
DEFAULT_DB_PORT=5432 \
./target/release/backup-service run
```

## 🐳 Docker Environment

### Dockerfile with Environment
```dockerfile
FROM rust:1.70

# Environment variables
ENV RUST_LOG=info
ENV DEFAULT_DB_HOST=database
ENV DEFAULT_DB_PORT=5432
ENV DEFAULT_DB_NAME=postgres
ENV DEFAULT_DB_USER=postgres

# Build and run
COPY . /app
WORKDIR /app
RUN cargo build --release
CMD ["./target/release/backup-service", "server"]
```

### Docker Compose with Environment
```yaml
version: '3.8'

services:
  backup-service:
    build: .
    environment:
      - DEFAULT_DB_HOST=database
      - DEFAULT_DB_PORT=5432
      - DEFAULT_DB_NAME=myapp
      - DEFAULT_DB_USER=postgres
      - RUST_LOG=info
    ports:
      - "8080:8080"
```

## 🔧 Environment Variables Reference

### Essential Variables
| Variable | Description | Example |
|----------|-------------|--------|
| `DEFAULT_DB_HOST` | PostgreSQL host | `localhost` |
| `DEFAULT_DB_PORT` | PostgreSQL port | `5432` |
| `DEFAULT_DB_NAME` | Database name | `myapp` |
| `DEFAULT_DB_USER` | Database user | `postgres` |
| `RUST_LOG` | Log level | `debug` |
| `REST_PORT` | REST server port | `8080` |

### Optional Variables
| Variable | Description | Example |
|----------|-------------|--------|
| `TELEGRAM_ENABLED` | Enable notifications | `true` |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | `123456:ABC...` |
| `TELEGRAM_CHAT_ID` | Telegram chat ID | `-123456789` |
| `DEBUG_MODE` | Debug mode | `false` |
| `BACKUP_DIR` | Backup directory | `/opt/backups` |
| `CONFIG_DIR` | Config directory | `/opt/config` |

## 📝 Environment File Examples

### Production Example (.env.production)
```bash
# Database
DEFAULT_DB_HOST=prod-db.company.com
DEFAULT_DB_PORT=5432
DEFAULT_DB_NAME=production
DEFAULT_DB_USER=backup_service

# Security
DEBUG_MODE=false
RUST_LOG=info

# Notifications
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_ID=-1234567890123

# Performance
MAX_CONCURRENT_BACKUPS=2
BACKUP_MEMORY_LIMIT=2048
```

### Development Example (.env.development)
```bash
# Database
DEFAULT_DB_HOST=localhost
DEFAULT_DB_PORT=5433
DEFAULT_DB_NAME=dev_app
DEFAULT_DB_USER=postgres

# Development
DEBUG_MODE=true
RUST_LOG=debug
DEVELOPMENT_MODE=true
REST_PORT=8081
```

## 🔒 Security Best Practices

### 1. Protect Sensitive Information
```bash
# Set restrictive permissions
chmod 600 .env

# Never commit .env to version control
echo ".env" >> .gitignore
```

### 2. Use Environment Variables in Production
```bash
# Production startup script
#!/bin/bash

# Load secure environment
source /opt/backup-service/.secure_env

# Run application
sudo -E /opt/backup-service/bin/backup-service server
```

### 3. Different Environments
```bash
# Development
dev.sh:
  DEFAULT_DB_HOST=localhost
  ./target/release/backup-service run

# Production
prod.sh:
  DEFAULT_DB_HOST=prod-db.company.com
  sudo ./target/release/backup-service server
```

## 🎯 Quick Configuration Checklist

- [ ] Set up database host and credentials
- [ ] Configure log level (`debug` for dev, `info` for prod)
- [ ] Set backup directory permissions
- [ ] Configure notifications (optional)
- [ ] Test connection with test command
- [ ] Verify REST API is accessible

## 🚀 Ready to Go!

After setting up your environment:

1. **Test configuration**: `cargo run -- test`
2. **Interactive setup**: `cargo run -- run`
3. **Start server**: `cargo run -- server --port 8080`
4. **Check API**: `curl http://localhost:8080/health`

Your PostgreSQL backup system is ready! 🎉