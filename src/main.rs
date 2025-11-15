use anyhow::{Result, Context};
use clap::{Parser, Subcommand};
use std::env;
use std::path::Path;
use log::{info, warn};

mod config;
mod database;
mod backup;
mod cli;
mod api;
mod notifications;

use cli::CliInterface;
use config::{ServerManager, TelegramManager};
use database::DatabaseConnection;

#[derive(Parser)]
#[command(name = "backup-service")]
#[command(about = "PostgreSQL backup management system")]
#[command(version = "0.1.0")]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    /// Config directory path (default: ./config)
    #[arg(long, default_value = "./config")]
    config_dir: String,

    /// Backup directory path (default: ./backup)
    #[arg(long, default_value = "./backup")]
    backup_dir: String,

    /// Enable debug logging
    #[arg(short, long)]
    debug: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// Start interactive CLI mode
    Run,
    /// Start REST API server
    Server,
    /// Create backup of all schemas from active server
    Backup,
    /// List all backups
    List,
    /// Show backup details
    Details {
        /// Backup filename
        filename: String,
    },
    /// Restore backup
    Restore {
        /// Backup filename
        filename: String,
        /// Target server name
        #[arg(long)]
        server: Option<String>,
    },
    /// Manage server configurations
    ServerConfig,
    /// Configure Telegram notifications
    TelegramConfig,
    /// Test connection to server
    Test {
        /// Server name (optional, defaults to active server)
        server: Option<String>,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize logging
    let log_level = if cli.debug { "debug" } else { "info" };
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or(log_level))
        .init();

    // Validate directories
    validate_directories(&cli.config_dir, &cli.backup_dir)?;

    match cli.command {
        Commands::Run => {
            info!("Starting interactive CLI mode");
            let mut cli_interface = CliInterface::new(&cli.config_dir, &cli.backup_dir)?;
            cli_interface.run().await?;
        }
        Commands::Server => {
            info!("Starting REST API server");
            api::start_rest_server().await?;
        }
        Commands::Backup => {
            info!("Creating backup from active server");
            backup_active_server(&cli.config_dir, &cli.backup_dir).await?;
        }
        Commands::List => {
            info!("Listing backups");
            list_backups(&cli.backup_dir)?;
        }
        Commands::Details { filename } => {
            info!("Showing backup details for: {}", filename);
            show_backup_details(&cli.backup_dir, &filename)?;
        }
        Commands::Restore { filename, server } => {
            info!("Restoring backup: {}", filename);
            restore_backup(&cli.config_dir, &cli.backup_dir, &filename, server).await?;
        }
        Commands::ServerConfig => {
            info!("Managing server configurations");
            manage_servers(&cli.config_dir).await?;
        }
        Commands::TelegramConfig => {
            info!("Configuring Telegram notifications");
            configure_telegram(&cli.config_dir).await?;
        }
        Commands::Test { server } => {
            info!("Testing server connection");
            test_server_connection(&cli.config_dir, server).await?;
        }
    }

    Ok(())
}

fn validate_directories(config_dir: &str, backup_dir: &str) -> Result<()> {
    // Ensure config directory exists
    if !Path::new(config_dir).exists() {
        std::fs::create_dir_all(config_dir)
            .context("Failed to create config directory")?;
    }

    // Ensure backup directory exists
    if !Path::new(backup_dir).exists() {
        std::fs::create_dir_all(backup_dir)
            .context("Failed to create backup directory")?;
    }

    Ok(())
}

async fn backup_active_server(config_dir: &str, backup_dir: &str) -> Result<()> {
    let mut server_manager = ServerManager::new(config_dir);
    let backup_manager = backup::BackupManager::new(backup_dir);
    let mut telegram_manager = TelegramManager::new(config_dir);

    server_manager.load()?;
    telegram_manager.load()?;

    let active_server = server_manager.get_active_server()
        .ok_or_else(|| anyhow::anyhow!("No active server configured"))?;

    println!("Creating backup for active server: {}", active_server.display_name());

    // Get schemas
    let connection = DatabaseConnection::connect(active_server).await
        .context("Failed to connect to server")?;
    let schemas = connection.get_schemas().await
        .context("Failed to get schemas")?;

    if schemas.is_empty() {
        warn!("No schemas found to backup");
        return Ok(());
    }

    println!("Found {} schemas to backup", schemas.len());

    // Create backup
    let timestamp = backup_manager.generate_timestamp_filename();
    let backup_file = backup_manager.get_backup_filepath(&timestamp);

    DatabaseConnection::backup_schemas(active_server, &schemas, backup_file.to_str().unwrap()).await
        .context("Failed to create backup")?;

    println!("✅ Backup created successfully: {}", backup_file.display());

    // Get backup info for notification
    let backup_info = backup_manager.get_backup_info(&backup_file)?;

    // Send notification if configured
    if telegram_manager.is_enabled() {
        if let Ok(notifier) = notifications::TelegramNotifier::new(
            telegram_manager.get_config().unwrap()
        ) {
            if let Err(e) = notifier.send_backup_notification(
                active_server,
                &schemas,
                &timestamp,
                &backup_info.size_display()
            ).await {
                warn!("Failed to send Telegram notification: {}", e);
            }
        }
    }

    Ok(())
}

fn list_backups(backup_dir: &str) -> Result<()> {
    let backup_manager = backup::BackupManager::new(backup_dir);
    let backups = backup_manager.list_backups()?;

    if backups.is_empty() {
        println!("No backups found.");
        return Ok(());
    }

    println!("Available Backups:");
    println!("{:<25} {:<10} {:<20}", "Filename", "Size", "Created");
    println!("{}", "-".repeat(55));

    for backup in backups {
        println!(
            "{:<25} {:<10} {:<20}",
            backup.filename,
            backup.size_display(),
            backup.created_at_display()
        );
    }

    Ok(())
}

fn show_backup_details(backup_dir: &str, filename: &str) -> Result<()> {
    let backup_manager = backup::BackupManager::new(backup_dir);
    let backup = backup_manager.get_backup_by_filename(filename)
        .ok_or_else(|| anyhow::anyhow!("Backup '{}' not found", filename))?;

    println!("Backup Details:");
    println!("  Filename: {}", backup.filename);
    println!("  Size: {}", backup.size_display());
    println!("  Created: {}", backup.created_at_display());
    println!("  Schemas ({}):", backup.schemas.len());

    for schema in &backup.schemas {
        println!("    - {}", schema);
    }

    Ok(())
}

async fn restore_backup(config_dir: &str, backup_dir: &str, filename: &str, target_server: Option<String>) -> Result<()> {
    let mut server_manager = ServerManager::new(config_dir);
    let backup_manager = backup::BackupManager::new(backup_dir);
    let mut telegram_manager = TelegramManager::new(config_dir);

    server_manager.load()?;
    telegram_manager.load()?;

    // Get backup info
    let backup = backup_manager.get_backup_by_filename(filename)
        .ok_or_else(|| anyhow::anyhow!("Backup '{}' not found", filename))?;

    // Validate backup file
    backup::BackupManager::validate_backup_file(&backup.filepath)?;

    // Get target server
    let server = if let Some(server_name) = target_server {
        server_manager.get_server(&server_name)
            .ok_or_else(|| anyhow::anyhow!("Server '{}' not found", server_name))?
    } else {
        server_manager.get_active_server()
            .ok_or_else(|| anyhow::anyhow!("No active server configured and no target server specified"))?
    };

    println!("Restoring backup '{}' to server: {}", filename, server.display_name());

    DatabaseConnection::restore_backup(server, backup.filepath.to_str().unwrap()).await
        .context("Failed to restore backup")?;

    println!("✅ Backup restored successfully.");

    // Send notification if configured
    if telegram_manager.is_enabled() {
        if let Ok(notifier) = notifications::TelegramNotifier::new(
            telegram_manager.get_config().unwrap()
        ) {
            if let Err(e) = notifier.send_restore_notification(
                server,
                &backup.schemas,
                &backup.filename,
                &backup.size_display()
            ).await {
                warn!("Failed to send Telegram notification: {}", e);
            }
        }
    }

    Ok(())
}

async fn manage_servers(config_dir: &str) -> Result<()> {
    let mut cli_interface = CliInterface::new(config_dir, &format!("{}/backup", std::env::current_dir()?.to_string_lossy()))?;
    cli_interface.manage_servers().await
}

async fn configure_telegram(config_dir: &str) -> Result<()> {
    let mut telegram_manager = TelegramManager::new(config_dir);
    telegram_manager.load()?;

    use inquire::Text;

    let bot_token = Text::new("Telegram Bot Token:")
        .prompt()
        .context("Failed to get bot token")?;

    let chat_id = Text::new("Telegram Chat ID:")
        .prompt()
        .context("Failed to get chat ID")?;

    let config = config::TelegramConfig::new(bot_token, chat_id);
    telegram_manager.set_config(config)?;

    println!("✅ Telegram notifications configured successfully.");

    // Test the connection
    if let Ok(notifier) = notifications::TelegramNotifier::new(
        telegram_manager.get_config().unwrap()
    ) {
        println!("Testing Telegram connection...");
        match notifier.test_connection().await {
            Ok(true) => println!("✅ Telegram connection test successful."),
            Ok(false) => println!("❌ Telegram connection test failed."),
            Err(e) => println!("⚠️  Telegram connection test error: {}", e),
        }
    }

    Ok(())
}

async fn test_server_connection(config_dir: &str, server_name: Option<String>) -> Result<()> {
    let mut server_manager = ServerManager::new(config_dir);
    let mut telegram_manager = TelegramManager::new(config_dir);

    server_manager.load()?;
    telegram_manager.load()?;

    let server_name_copy = if let Some(name) = &server_name {
        name.clone()
    } else {
        let server = server_manager.get_active_server()
            .ok_or_else(|| anyhow::anyhow!("No active server configured and no server specified"))?;
        server.name.clone()
    };

    let server = if let Some(name) = server_name {
        server_manager.get_server(&name)
            .ok_or_else(|| anyhow::anyhow!("Server '{}' not found", name))?
    } else {
        server_manager.get_active_server()
            .ok_or_else(|| anyhow::anyhow!("No active server configured and no server specified"))?
    };

    println!("Testing connection to {}...", server.display_name());

    match DatabaseConnection::test_connection(server).await {
        Ok(connection_info) => {
            println!("✅ Connection successful: {}", connection_info);

            // Update server info
            if let Ok(version) = DatabaseConnection::get_server_version(&server_manager.get_server(&server_name_copy).unwrap()).await {
                if let Some(server_mut) = server_manager.get_server_mut(&server_name_copy) {
                    server_mut.version = Some(version);
                    server_manager.save()?;
                }
            }

            // Send notification if configured
            if telegram_manager.is_enabled() {
                if let Ok(notifier) = notifications::TelegramNotifier::new(
                    telegram_manager.get_config().unwrap()
                ) {
                    let _ = notifier.send_connection_test_notification(&server_name_copy, true).await;
                }
            }
        }
        Err(e) => {
            println!("❌ Connection failed: {}", e);

            // Send notification if configured
            if telegram_manager.is_enabled() {
                if let Ok(notifier) = notifications::TelegramNotifier::new(
                    telegram_manager.get_config().unwrap()
                ) {
                    let _ = notifier.send_connection_test_notification(&server_name_copy, false).await;
                }
            }
        }
    }

    Ok(())
}