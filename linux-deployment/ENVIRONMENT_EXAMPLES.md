# Environment Usage Examples

This document provides practical examples of using environment variables for different deployment scenarios.

## 🚀 Quick Setup Examples

### 1. Basic Development Environment
```bash
# Navigate to project directory
cd /path/to/backup-service

# Set up development environment
./linux-deployment/scripts/setup-env.sh development

# Review and customize
nano .env

# Run application
cargo run -- run
```

### 2. Production Environment Setup
```bash
# Set up production environment
sudo ./linux-deployment/scripts/setup-env.sh production

# Review production settings
cat /opt/backup-service/.env

# Start service
sudo systemctl start backup-service
```

## 📝 Configuration Examples

### Example 1: Development with Local PostgreSQL
```bash
# .env file
DEFAULT_DB_HOST=localhost
DEFAULT_DB_PORT=5432
DEFAULT_DB_NAME=dev_app
DEFAULT_DB_USER=postgres

# Application settings
RUST_LOG=debug
DEBUG_MODE=true
DEVELOPMENT_MODE=true
REST_PORT=8081

# Directory paths
INSTALL_DIR=/home/user/backup-service
CONFIG_DIR=/home/user/backup-service/config
BACKUP_DIR=/home/user/backup-service/backup

# Usage
./target/release/backup-service run
```

### Example 2: Production with Remote Database
```bash
# .env file
DEFAULT_DB_HOST=prod-db.company.com
DEFAULT_DB_PORT=5432
DEFAULT_DB_NAME=production
DEFAULT_DB_USER=backup_service

# Security
DEBUG_MODE=false
RUST_LOG=info
TELEGRAM_ENABLED=true

# Performance
MAX_CONCURRENT_BACKUPS=2
BACKUP_MEMORY_LIMIT=2048
BACKUP_TIMEOUT=7200

# Notification
TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_ID=-1234567890123

# Usage
sudo -E /opt/backup-service/bin/backup-service server
```

### Example 3. Multi-Environment Development
```bash
# Development environment
DEV_DB_HOST=localhost
DEV_DB_PORT=5433
DEV_DB_NAME=dev_app
RUST_LOG=debug

# Testing environment
TEST_DB_HOST=test-db.company.com
TEST_DB_PORT=5432
TEST_DB_NAME=test_app
RUST_LOG=debug
TELEGRAM_ENABLED=false

# Production environment
PROD_DB_HOST=prod-db.company.com
PROD_DB_PORT=5432
PROD_DB_NAME=production
RUST_LOG=info
TELEGRAM_ENABLED=true

# Usage scripts
# dev.sh
export DEFAULT_DB_HOST=$DEV_DB_HOST
export DEFAULT_DB_PORT=$DEV_DB_PORT
export DEFAULT_DB_NAME=$DEV_DB_NAME
export RUST_LOG=$RUST_LOG
./target/release/backup-service run

# prod.sh
export DEFAULT_DB_HOST=$PROD_DB_HOST
export DEFAULT_DB_PORT=$PROD_DB_PORT
export DEFAULT_DB_NAME=$PROD_DB_NAME
export RUST_LOG=$RUST_LOG
sudo -E ./target/release/backup-service server
```

## 🔧 Environment-Specific Examples

### Development Environment
```bash
# .env.development
# PostgreSQL Configuration
DEFAULT_DB_HOST=localhost
DEFAULT_DB_PORT=5432
DEFAULT_DB_NAME=myapp_dev
DEFAULT_DB_USER=$(whoami)

# Development Settings
DEBUG_MODE=true
DEVELOPMENT_MODE=true
RUST_LOG=debug
RUST_BACKTRACE=1

# Performance (development-optimized)
MAX_CONCURRENT_BACKUPS=1
BACKUP_MEMORY_LIMIT=512
BACKUP_TIMEOUT=300

# Directories (home directory)
INSTALL_DIR=/home/$(whoami)/backup-service
CONFIG_DIR=/home/$(whoami)/backup-service/config
BACKUP_DIR=/home/$(whoami)/backup-service/backup

# Development Features
ENABLE_PROFILING=true
TEST_CONNECTION_ON_STARTUP=true

# Logging
LOG_MAX_SIZE=10MB
LOG_ROTATION=hourly
STRUCTURED_LOGGING=true

# Usage
cd /home/$(whoami)/projects/backup-service
./linux-deployment/scripts/setup-env.sh development
source .env
cargo run -- run
```

### Production Environment
```bash
# .env.production
# PostgreSQL Configuration
DEFAULT_DB_HOST=db1.internal.company.com
DEFAULT_DB_PORT=5432
DEFAULT_DB_NAME=production
DEFAULT_DB_USER=backup_service

# Security Settings
DEBUG_MODE=false
DEVELOPMENT_MODE=false
RUST_LOG=info
RUST_BACKTRACE=0

# Performance (production-optimized)
MAX_CONCURRENT_BACKUPS=3
BACKUP_MEMORY_LIMIT=4096
BACKUP_TIMEOUT=7200

# Backup Settings
COMPRESS_BACKUPS=false
MAX_BACKUPS_RETAINED=60
BACKUP_RETENTION_DAYS=90
DEFAULT_SCHEMAS=public,data,analytics

# Notifications
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_CHAT_ID=-1234567890123

# Monitoring
ENABLE_METRICS=true
METRICS_PORT=9090
HEALTH_CHECK_INTERVAL=30

# Directories
INSTALL_DIR=/opt/backup-service
CONFIG_DIR=/opt/backup-service/config
BACKUP_DIR=/opt/backup-service/backup
LOG_DIR=/var/log/backup-service

# Usage
sudo ./linux-deployment/scripts/setup-env.sh production
sudo systemctl restart backup-service
```

### Staging Environment
```bash
# .env.staging
# PostgreSQL Configuration
DEFAULT_DB_HOST=staging-db.company.com
DEFAULT_DB_PORT=5432
DEFAULT_DB_NAME=staging_app
DEFAULT_DB_USER=backup_service

# Staging Settings
DEBUG_MODE=true  # Enable for debugging
DEVELOPMENT_MODE=false
RUST_LOG=debug

# Performance
MAX_CONCURRENT_BACKUPS=1
BACKUP_MEMORY_LIMIT=1024
BACKUP_TIMEOUT=3600

# Notifications (testing only)
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=staging_bot_token
TELEGRAM_CHAT_ID=staging_chat_id

# Directories
INSTALL_DIR=/opt/backup-service-staging
CONFIG_DIR=/opt/backup-service-staging/config
BACKUP_DIR=/opt/backup-service-staging/backup

# Usage
sudo ./linux-deployment/scripts/setup-env.sh development
# Then manually edit .env to change paths to staging
sudo cp .env .env.backup
sed -i 's|/opt/backup-service|/opt/backup-service-staging|g' .env
```

## 🐳 Docker Environment Examples

### Multi-Stage Docker Build
```dockerfile
# Dockerfile
FROM rust:1.70 as builder

# Build environment
ENV APP_NAME=backup-service
ENV RUST_LOG=info

WORKDIR /app
COPY . .

# Build application
RUN cargo build --release

# Production stage
FROM debian:bullseye-slim

# Install PostgreSQL client
RUN apt-get update && apt-get install -y \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create application user
RUN groupadd -r backup-service && \
    useradd -r -g backup-service -s /bin/false -d /app backup-service

# Production environment
ENV APP_NAME=backup-service
ENV APP_VERSION=0.1.0
ENV APP_WORKDIR=/app
ENV RUST_LOG=info
ENV RUST_BACKTRACE=0
ENV DEFAULT_DB_HOST=database
ENV DEFAULT_DB_PORT=5432
ENV DEFAULT_DB_NAME=postgres
ENV DEFAULT_DB_USER=postgres
ENV REST_PORT=8080

# Copy application
COPY --from=builder /app/target/release/backup-service /app/bin/

# Create directories
RUN mkdir -p /app/{config,backup,logs} && \
    chown -R backup-service:backup-service /app

# Switch to application user
USER backup-service
WORKDIR /app

# Health check
HEALTHCHECK --interval=30s --timeout=10s \
    CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080
CMD ["/app/bin/backup-service", "server"]
```

### Docker Compose
```yaml
# docker-compose.yml
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
      - TELEGRAM_ENABLED=false
    ports:
      - "8080:8080"
    volumes:
      - ./config:/app/config
      - ./backups:/app/backup
      - ./logs:/app/logs
    depends_on:
      - database
    restart: unless-stopped
    user: "backup-service"

  database:
    image: postgres:14
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    restart: unless-stopped

volumes:
  postgres_data:
```

## 🔒 Security Examples

### Secure Production Environment
```bash
# .env (never commit this file)
DEFAULT_DB_HOST=prod-db.internal
DEFAULT_DB_USER=backup_service

# Use environment variables instead of .env in production
export DEFAULT_DB_PASSWORD=$(cat /opt/backup-service/.db_password)
export TELEGRAM_BOT_TOKEN=$(cat /opt/backup-service/.telegram_token)
export TELEGRAM_CHAT_ID=$(cat /opt/backup-service/.telegram_chat_id)

# Secure file permissions
chmod 600 /opt/backup-service/.db_password
chmod 600 /opt/backup-service/.telegram_token
chmod 600 /opt/backup-service/.telegram_chat_id

# Run with environment variables
sudo -E /opt/backup-service/bin/backup-service server
```

### Multiple Server Environments
```bash
# .env.servers
# Production server
PROD_DB_HOST=prod1.internal.company.com
PROD_DB_PORT=5432
PROD_DB_NAME=production
PROD_DB_USER=backup_service

# Backup server
BACKUP_DB_HOST=backup-db.internal.company.com
BACKUP_DB_PORT=5432
BACKUP_DB_NAME=production_backup
BACKUP_DB_USER=backup_service

# Usage script
#!/bin/bash
# backup-to-backup.sh
export DEFAULT_DB_HOST=$BACKUP_DB_HOST
export DEFAULT_DB_PORT=$BACKUP_DB_PORT
export DEFAULT_DB_NAME=$BACKUP_DB_NAME
export DEFAULT_DB_USER=$BACKUP_DB_USER

./target/release/backup-service backup --server-name backup_server
```

## 📊 Monitoring Examples

### Environment with Metrics
```bash
# .env.metrics
# Enable metrics
ENABLE_METRICS=true
METRICS_PORT=9090
HEALTH_CHECK_INTERVAL=30

# Logging configuration
RUST_LOG=info
LOG_TO_JOURNAL=true

# Performance monitoring
MAX_CONCURRENT_BACKUPS=3
BACKUP_MEMORY_LIMIT=2048

# Usage with monitoring
curl http://localhost:9090/metrics
journalctl -u backup-service -f
```

### Environment-Specific Logging
```bash
# Development - Verbose logging
RUST_LOG=debug
STRUCTURED_LOGGING=true
LOG_TO_JOURNAL=false

# Production - Efficient logging
RUST_LOG=info
STRUCTURED_LOGGING=false
LOG_TO_JOURNAL=true
LOG_MAX_SIZE=100MB
LOG_MAX_FILES=10

# Testing - Detailed logging
RUST_LOG=debug
STRUCTURED_LOGGING=true
LOG_TO_JOURNAL=true
LOG_MAX_SIZE=10MB
LOG_ROTATION=hourly
```

## 🔍 Troubleshooting Examples

### Environment Variable Debugging
```bash
# Check loaded environment
env | grep DEFAULT_DB

# Test environment loading
DEFAULT_DB_HOST=test ./target/release/backup-service --help

# Display all application environment
./target/release/backup-service --help
```

### Permission Issues
```bash
# Check current user
whoami

# Check directory permissions
ls -la /opt/backup-service/

# Fix permissions
sudo chown -R backup-service:backup-service /opt/backup-service/
sudo chmod 700 /opt/backup-service/config
```

### Environment Migration
```bash
# Migrate from .env to system environment
cat .env | grep -v '^#' | xargs

# Export specific variables
export $(cat .env | grep '^DEFAULT_DB' | xargs)
export $(cat .env | grep '^TELEGRAM' | xargs)
```

---

**💡 Pro Tip:** Always use different environments for production, staging, and development to avoid configuration conflicts!