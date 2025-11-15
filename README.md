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
- Optional: Telegram Bot Token for notifications

### Building from Source

```bash
git clone <repository-url>
cd backup-service
cargo build --release
```

The compiled binary will be available at `target/release/backup-service`.

## Usage

### Interactive CLI Mode

```bash
# Start interactive menu
./backup-service run

# Start REST API server
./backup-service server

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
./backup-service server
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
- **`server`**: Start REST API server on port 8080
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
  F. Start REST API Server
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
