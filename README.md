# PostgreSQL Backup Management System

A comprehensive CLI-based PostgreSQL backup management system written in Rust with interactive menus, REST API endpoints, and Telegram notification support.

## Features

### 🗄️ Backup Management
- **Create Backups**: Select schemas from active server and create timestamped SQL backups
- **List Backups**: View all available backups with size and creation time
- **Backup Details**: View detailed information including schemas and file size
- **Delete Backups**: Safely remove unwanted backups with confirmation
- **Restore Backups**: Restore backups to any configured server

### 🖥️ Server Management
- **Add/Edit Servers**: Configure PostgreSQL server connections
- **Test Connections**: Verify server connectivity before operations
- **Set Active Server**: Mark one server as the default for operations
- **Server Information**: Display server version and schema count

### 🌐 REST API
- **Automated Backups**: POST `/backup` endpoint for cron job integration
- **Health Checks**: GET `/health` endpoint to monitor service status
- **Backup Listing**: GET `/backup` endpoint to retrieve backup information

### 📱 Notifications (Optional)
- **Telegram Integration**: Receive notifications for backup/restore operations
- **Detailed Messages**: Server info, schemas, file sizes, and timestamps
- **Error Notifications**: Get alerts for failed operations

## Installation

### Prerequisites
- Rust 1.70+ (for building from source)
- PostgreSQL client tools (`pg_dump`, `psql`) in PATH
- System dependencies for compilation (Linux only)
- Optional: Telegram Bot Token for notifications

### Quick Start (Linux)

For the easiest setup on Linux, run:

```bash
git clone <repository-url>
cd backup-service
make setup
```

This command will:
1. Install all system dependencies automatically
2. Build the project with default configuration
3. Create the binary in `target/release/backup-service`

### Manual Installation

#### 1. Install System Dependencies

**For Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y pkg-config libssl-dev postgresql-client build-essential
```

**For RHEL/CentOS:**
```bash
sudo yum groupinstall -y "Development Tools"
sudo yum install -y pkgconfig openssl-devel postgresql
```

**For Fedora:**
```bash
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y pkgconfig openssl-devel postgresql
```

**For Arch Linux:**
```bash
sudo pacman -S --needed pkgconf openssl postgresql
```

#### 2. Build the Project

**Option A: Standard build (requires system dependencies):**
```bash
make build
```

**Option B: Using Cargo directly:**
```bash
cargo build --release
```

**If you encounter OpenSSL errors, run:**
```bash
# For Ubuntu/Debian:
sudo apt-get update
sudo apt-get install -y pkg-config libssl-dev postgresql-client build-essential

# For RHEL/CentOS:
sudo yum groupinstall -y "Development Tools"
sudo yum install -y pkgconfig openssl-devel postgresql

# For Fedora:
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y pkgconfig openssl-devel postgresql

# After installing dependencies:
make rebuild
```

The compiled binary will be available at `target/release/backup-service`.

## Usage

### Basic Commands

```bash
# Start interactive CLI
./backup-service run

# Start REST API server
./backup-service server --port 8080

# Start REST API only (no cronjob)
./backup-service server --start-rest --port 8080

# Start cronjob only (no REST API)
./backup-service server --start-cronjob

# Quick backup
./backup-service backup

# List backups
./backup-service list
```

## Makefile Commands

### 🚀 Quick Start

```bash
# Install system dependencies and build
make setup

# Build in release mode
make build

# View all available commands
make help
```

### 📦 Installation & Deployment

#### Standard Installation (Combined Service)
```bash
# Install with default port (8080)
make install

# Install with custom port
make install PORT=8237

# Quick install for development (port 8080)
make install-dev

# Quick install for production (port 3724)
make install-prod
```

#### Separated Services Installation
```bash
# Install REST API service only
make install-rest BACKUP_DIR=/home/dev/backups

# Install cronjob service with custom user
make install-cronjob USER=dev BACKUP_DIR=/home/dev/db-backup-list

# Install cronjob for different users
make install-cronjob USER=admin BACKUP_DIR=/var/lib/backups
make install-cronjob USER=root BACKUP_DIR=/opt/backups
```

### 🔧 Service Management

#### Combined Service Management
```bash
# Start/stop service
make service-start
make service-stop
make service-restart

# Check status and logs
make service-status
make service-logs
make service-debug
```

#### Separated Service Management
```bash
# REST API service management
make service-start-rest
make service-stop-rest
make service-status-rest
make service-logs-rest

# Cronjob service management (requires USER parameter)
make service-start-cronjob USER=dev
make service-stop-cronjob USER=dev
make service-status-cronjob USER=dev
make service-logs-cronjob USER=dev

# Start services with custom backup directory
make service-start-cronjob USER=dev BACKUP_DIR=/home/dev/db-backup-list
make service-start-rest BACKUP_DIR=/var/lib/postgresql-backups
```

### 🔨 Development Commands

```bash
# Build commands
make build                    # Build in release mode
make clean                    # Clean build artifacts
make rebuild                  # Clean and rebuild
make check                    # Run cargo check and clippy
make test                     # Run tests

# Development server
make dev-server               # Run server in development mode
make dev-cli                  # Run CLI in development mode

# Debug connections
make debug PORT=5432
```

### 🛠️ System Management

```bash
# Install dependencies (Linux)
make install-deps

# Deployment management
make update-and-deploy        # Git pull → build → deploy → restart
make check-deployment         # Verify installation health

# Firewall configuration
make firewall-setup PORT=8237

# Uninstallation (keeps data)
make uninstall

# Complete uninstall (removes data)
make uninstall-data
```

### 📁 Custom Paths Configuration

```bash
# Install with custom backup directory
make install BACKUP_DIR=/custom/backup/path

# Start services with custom paths
make service-start BACKUP_DIR=/home/user/backups
make service-start-cronjob USER=dev BACKUP_DIR=/home/dev/postgresql-backups

# Build with custom prefix
make build INSTALL_PREFIX=/opt/local/bin
```

## Configuration

### Default Paths
- **Config Directory**: `/etc/backup-service/config`
- **Backup Directory**: `/etc/backup-service/backup` (default)
- **Log Directory**: `/var/log/backup-service`
- **Binary**: `/usr/local/bin/backup-service`

### Environment Variables
You can override default paths using environment variables:

```bash
# Custom configuration directory
export BACKUP_CONFIG_DIR=/custom/config

# Custom backup directory
export BACKUP_DIR=/custom/backups

# Custom log directory
export LOG_DIR=/custom/logs

# Start with custom paths
./backup-service server --config-dir $BACKUP_CONFIG_DIR --backup-dir $BACKUP_DIR
```

### Direct Binary Usage

```bash
# Start interactive menu
./backup-service run

# Start REST API server on default port (8080)
./backup-service server

# Start REST API server on custom port
./backup-service server --port 9000

# Quick backup of active server
./backup-service backup

# List all backups
./backup-service list

# Show backup details
./backup-service details backup_20241215_143022.sql

# Restore backup
./backup-service restore backup_20241215_143022.sql --server target_server

# Test server connection
./backup-service test --server my_server

# Configure Telegram notifications
./backup-service telegram-config
```

### REST API

Start the REST server:

```bash
# Using Makefile
make run-server

# Direct binary usage
./backup-service server --port 8080
```

#### Endpoints

- **GET `/`** or **GET `/health`** - Service health check
- **POST `/backup`** - Trigger backup of active server
- **GET `/backup`** - List all backups

Example usage:

```bash
# Health check
curl http://localhost:8080/health

# Trigger backup
curl -X POST http://localhost:8080/backup

# List backups
curl http://localhost:8080/backup
```

## Systemd Deployment

### Installation as System Service

```bash
# Install binary and create systemd service
make install

# Start the service
sudo systemctl start backup-service

# Check service status
sudo systemctl status backup-service

# View logs
sudo journalctl -u backup-service -f
```

### Service Configuration

The systemd service will be installed with the following defaults:
- **User**: `backup-service`
- **Config Directory**: `/var/lib/backup-service/config`
- **Backup Directory**: `/var/lib/backup-service/backup`
- **Port**: `8080`

### Custom Installation

You can customize installation variables:

```bash
# Install with custom port and user
make install SERVICE_PORT=9000 SERVICE_USER=myuser
```

### Service Management

```bash
# Start/stop service
sudo systemctl start backup-service
sudo systemctl stop backup-service
sudo systemctl restart backup-service

# Enable/disable auto-start
sudo systemctl enable backup-service
sudo systemctl disable backup-service

# View logs
sudo journalctl -u backup-service -f
```

## Configuration

The application creates local configuration files in the working directory:

```
./
├── config/
│   ├── servers.json      # Server configurations
│   └── telegram.json     # Telegram notification settings
└── backup/
    └── *.sql             # Backup files
```

### Server Configuration

Servers can be added through the interactive CLI or by editing `config/servers.json`:

```json
{
  "my_server": {
    "name": "my_server",
    "host": "localhost",
    "port": 5432,
    "database": "mydb",
    "username": "postgres",
    "password": "password",
    "version": "PostgreSQL 14.5",
    "total_schemas": 5,
    "is_active": true
  }
}
```

### Telegram Notifications

1. Create a bot with [@BotFather](https://t.me/botfather)
2. Get your bot token
3. Get your chat ID (send `/start` to your bot and check updates)
4. Configure via CLI: `./backup-service telegram-config`

## CLI Commands

### Main Commands

- **`run`**: Start interactive CLI mode with menu system
- **`server`**: Start REST API server (default port 8080)
- **`backup`**: Create backup of all schemas from active server
- **`list`**: Display all available backups
- **`details <filename>`**: Show detailed backup information
- **`restore <filename> [--server <name>]`**: Restore backup to server
- **`test [--server <name>]`**: Test database connection
- **`server-config`**: Manage server configurations
- **`telegram-config`**: Configure Telegram notifications

### Options

- **`--config-dir <path>`**: Configuration directory (default: `./config`)
- **`--backup-dir <path>`**: Backup directory (default: `./backup`)
- **`--port <number>`**: Port for REST API server (default: `8080`)
- **`--debug`**: Enable debug logging

## Interactive Menu

When running `./backup-service run`, you'll see a menu with the following options:

```
🗄️  PostgreSQL Backup Management System
=========================================

Select an option:
❯ A. Create Backup
  B. List Backups
  C. Backup Details
  D. Manage Servers
  E. Notification Settings
  Q. Quit
```

### Server Management Menu

```
Server Management:
❯ List Servers
  Add Server
  Edit Server
  Test Connection
  Set Active Server
  Back
```

## Backup Process

1. **Schema Discovery**: The system lists all available schemas from the active server
2. **Schema Selection**: Choose which schemas to backup (interactive mode)
3. **Backup Creation**: Uses `pg_dump` to create SQL files with timestamps
4. **Notification**: Sends Telegram notification if configured
5. **Storage**: Backups saved as `[timestamp].sql` in backup directory

## Restore Process

1. **Backup Selection**: Choose from available backups
2. **Target Server**: Select destination server
3. **Confirmation**: Requires confirmation before overwriting data
4. **Restore**: Uses `psql` to restore the backup
5. **Notification**: Sends completion notification

## Security Notes

- Server passwords are stored in plain text JSON files
- Use appropriate file permissions on configuration files
- Consider using read-only database users for backups
- Backup files contain your complete database data - secure them appropriately

## Troubleshooting

### Common Issues

1. **Connection Failures**: Ensure PostgreSQL is accessible and credentials are correct
2. **Missing `pg_dump`/`psql`**: Install PostgreSQL client tools
3. **Permission Errors**: Check file permissions on config and backup directories
4. **Port Conflicts**: REST server uses port 8080 by default

### Logging

Enable debug logging:

```bash
./backup-service --debug run
```

Logs will show detailed information about operations, errors, and system status.

## Advanced Usage

### 🕐 Cronjob Management

#### Interactive Cronjob Configuration
```bash
# Open cronjob management menu
./backup-service cronjob

# Or via makefile
make run-cronjob-menu
```

#### Cronjob Examples
```bash
# Create daily backup at 2 AM
Schedule Type: Daily
Hour: 2
Minute: 0

# Create hourly backup during business hours
Schedule Type: Hours
Interval: 1

# Create weekly backup on Sunday at 3 AM
Schedule Type: Weekly
Day of Week: 0 (Sunday)
Hour: 3
Minute: 0

# Create backup every 30 minutes
Schedule Type: Minutes
Interval: 30

# Custom cron expression (every 6 hours)
Schedule Type: Custom
Cron Expression: 0 */6 * * *
```

#### Cronjob Features
- ✅ **Hot-reload**: Config changes applied automatically without restart
- ✅ **Server Validation**: Skips execution if database server is unavailable
- ✅ **Failure Notifications**: Telegram alerts for configuration and connection issues
- ✅ **Execution Statistics**: Track success/failure rates
- ✅ **Skip Logic**: Graceful skipping instead of errors when server unavailable
- ✅ **Auto-recovery**: Automatic recovery from corrupted configuration files

### 📊 Hot-Reload Feature

The cronjob scheduler monitors configuration file changes every 30 seconds:

```bash
# Modify cronjob configuration
./backup-service cronjob
# → Edit/Add/Remove jobs

# Within 30 seconds, scheduler will:
# 1. Detect file changes
# 2. Reload configuration
# 3. Update job schedules
# 4. Log reload event
# 5. Send Telegram notification (if configured)

# Monitor reload events
make service-logs-cronjob USER=dev
```

### 🔔 Telegram Notifications

#### Supported Notifications
- **Backup Success**: Server info, schemas, file size, duration
- **Backup Failure**: Error details and retry suggestions
- **Connection Test**: Server availability status
- **Cronjob Events**: Schedule, success, failure, removal, skip
- **Configuration Errors**: Invalid configs, connection failures
- **Service Health**: Start/stop events

#### Configure Telegram
```bash
# Interactive configuration
./backup-service telegram-config

# Or manually edit config
sudo nano /etc/backup-service/config/telegram.json
```

### 🏗️ Production Deployment

#### Multi-User Cronjob Setup
```bash
# Install cronjob for multiple users with different backup directories
make install-cronjob USER=dev BACKUP_DIR=/home/dev/postgres-backups
make install-cronjob USER=admin BACKUP_DIR=/opt/backups
make install-cronjob USER=backup BACKUP_DIR=/var/lib/backup-service

# Start all cronjob services
make service-start-cronjob USER=dev
make service-start-cronjob USER=admin
make service-start-cronjob USER=backup

# Monitor all services
make service-status-cronjob USER=dev
make service-status-cronjob USER=admin
make service-status-cronjob USER=backup
```

#### Separate Services Architecture
```bash
# Architecture:
# ├── REST API Service (port 8237)
# │   └── Handles API calls and manual backups
# └── Cronjob Services (multiple users)
#     ├── backup-service-cronjob@dev
#     ├── backup-service-cronjob@admin
#     └── backup-service-cronjob@backup

# Benefits:
# ✅ Independent scaling
# ✅ User isolation for security
# ✅ Separate backup directories per user
# ✅ Individual restart capability
# ✅ Custom backup retention per user
```

### 🔍 Debugging & Troubleshooting

#### Database Connection Debug
```bash
# Test connection to specific server
./backup-service test --server production

# Debug PostgreSQL connection with multiple hosts
./backup-service debug --host votin.id --test-all-hosts

# Debug with specific parameters
./backup-service debug \
  --host 172.18.0.2 \
  --port 5432 \
  --database suara_rakyat \
  --username suararakyat \
  --ssl-mode disable
```

#### Service Health Check
```bash
# Verify deployment health
make check-deployment

# Check specific service status
make service-status
make service-status-rest
make service-status-cronjob USER=dev

# View recent logs
make service-debug
make service-logs-rest
make service-logs-cronjob USER=dev
```

#### Configuration Issues
```bash
# Validate cronjob configuration
./backup-service cronjob
# → Choose "List Cronjobs" to see current jobs

# Check server configuration
./backup-service run
# → Choose "F. Server Management" → "A. List All Servers"

# Test all configured servers
./backup-service run
# → Choose "F. Server Management" → "E. Test Connections"
```

### 📈 Performance Tips

#### Large Database Optimization
```bash
# Backup specific schemas only
./backup-service cronjob
# → Edit job → Select specific schemas

# Use custom backup directory with fast storage
make install-cronjob USER=dev BACKUP_DIR=/mnt/ssd-backups

# Adjust cronjob schedule for off-peak hours
# Example: Daily at 3 AM when server load is minimal
```

#### Resource Management
```bash
# Monitor resource usage
systemctl status backup-service-cronjob@dev
systemctl status backup-service-rest

# Check log file sizes
sudo du -sh /var/log/backup-service/

# Backup rotation (manually delete old files)
sudo ls -la /home/dev/postgres-backups/
sudo rm old_backup_*.sql
```

## Development

### Building

```bash
# Debug build
cargo build

# Release build
cargo build --release

# Run tests
cargo test
```

### Features

- **`telegram`** (default): Enable Telegram notifications
- **No features**: Build without Telegram support for smaller binary

Example without Telegram:

```bash
cargo build --no-default-features
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Support

For issues, feature requests, or questions, please open an issue on the GitHub repository.# db-backup-management
