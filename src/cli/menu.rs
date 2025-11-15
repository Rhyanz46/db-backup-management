use crate::config::{ServerManager, ServerConfig, TelegramManager};
use crate::database::DatabaseConnection;
use crate::backup::{BackupManager, BackupInfo};
use crate::notifications::TelegramNotifier;
use anyhow::{Result, Context};
use inquire::{Select, Text, Confirm, MultiSelect, CustomType};
use std::path::Path;
use tokio::runtime::Runtime;

pub struct CliInterface {
    server_manager: ServerManager,
    backup_manager: BackupManager,
    telegram_manager: TelegramManager,
    runtime: Runtime,
}

impl CliInterface {
    pub fn new(config_dir: &str, backup_dir: &str) -> Result<Self> {
        Ok(Self {
            server_manager: ServerManager::new(config_dir),
            backup_manager: BackupManager::new(backup_dir),
            telegram_manager: TelegramManager::new(config_dir),
            runtime: Runtime::new().context("Failed to create tokio runtime")?,
        })
    }

    pub async fn run(&mut self) -> Result<()> {
        // Load configurations
        self.server_manager.load()?;
        self.telegram_manager.load()?;
        self.backup_manager.ensure_backup_dir()?;

        println!("🗄️  PostgreSQL Backup Management System");
        println!("=========================================\n");

        loop {
            let choices = vec![
                "A. Create Backup",
                "B. List Backups",
                "C. Backup Details",
                "D. Manage Servers",
                "E. Notification Settings",
                "Q. Quit",
            ];

            let choice = Select::new("Select an option:", choices)
                .prompt()
                .context("Failed to get menu selection")?;

            match choice {
                "A. Create Backup" => self.create_backup().await?,
                "B. List Backups" => self.list_backups()?,
                "C. Backup Details" => self.backup_details().await?,
                "D. Manage Servers" => self.manage_servers().await?,
                "E. Notification Settings" => self.notification_settings()?,
                "Q. Quit" => {
                    println!("Goodbye! 👋");
                    break;
                }
                _ => println!("Invalid option"),
            }

            println!("\nPress Enter to continue...");
            let mut input = String::new();
            std::io::stdin().read_line(&mut input).unwrap_or_default();
        }

        Ok(())
    }

    async fn create_backup(&mut self) -> Result<()> {
        let active_server = self.server_manager.get_active_server()
            .ok_or_else(|| anyhow::anyhow!("No active server configured. Please set an active server first."))?;

        println!("Active Server: {}", active_server.display_name());

        // Test connection and get schemas
        println!("Connecting to database to get available schemas...");
        let connection_info = self.runtime.block_on(DatabaseConnection::test_connection(active_server))?;
        println!("Connection successful: {}", connection_info);

        let connection = self.runtime.block_on(DatabaseConnection::connect(active_server))?;
        let schemas = self.runtime.block_on(connection.get_schemas())?;

        if schemas.is_empty() {
            println!("No schemas found to backup.");
            return Ok(());
        }

        println!("\nAvailable schemas:");
        for (i, schema) in schemas.iter().enumerate() {
            println!("  {}. {}", i + 1, schema);
        }

        let selected_schemas = MultiSelect::new("Select schemas to backup:", schemas.clone())
            .prompt()
            .context("Failed to get schema selection")?;

        if selected_schemas.is_empty() {
            println!("No schemas selected. Aborting backup.");
            return Ok(());
        }

        let confirm = Confirm::new(&format!("Backup {} schema(s)?", selected_schemas.len()))
            .with_default(true)
            .prompt()
            .context("Failed to get backup confirmation")?;

        if !confirm {
            println!("Backup cancelled.");
            return Ok(());
        }

        println!("Creating backup...");
        let timestamp = self.backup_manager.generate_timestamp_filename();
        let backup_file = self.backup_manager.get_backup_filepath(&timestamp);

        self.runtime.block_on(
            DatabaseConnection::backup_schemas(active_server, &selected_schemas, backup_file.to_str().unwrap())
        )?;

        println!("✅ Backup created successfully: {}", backup_file.display());

        // Send notification if configured
        if self.telegram_manager.is_enabled() {
            if let Ok(notifier) = TelegramNotifier::new(self.telegram_manager.get_config().unwrap()) {
                let _ = self.runtime.block_on(
                    notifier.send_backup_notification(
                        active_server,
                        &selected_schemas,
                        &timestamp,
                        &self.backup_manager.get_backup_info(&backup_file)?.size_display()
                    )
                );
            }
        }

        Ok(())
    }

    fn list_backups(&mut self) -> Result<()> {
        let backups = self.backup_manager.list_backups()?;

        if backups.is_empty() {
            println!("No backups found.");
            return Ok(());
        }

        println!("Available Backups:");
        println!("{:<25} {:<10} {:<20} {:<20}", "Filename", "Size", "Created", "Schemas");
        println!("{}", "-".repeat(75));

        for backup in backups {
            let schemas_display = if backup.schemas.len() > 3 {
                format!("{} +{}", backup.schemas[..3].join(", "), backup.schemas.len() - 3)
            } else {
                backup.schemas.join(", ")
            };

            println!(
                "{:<25} {:<10} {:<20} {:<20}",
                backup.filename,
                backup.size_display(),
                backup.created_at_display(),
                schemas_display
            );
        }

        Ok(())
    }

    async fn backup_details(&mut self) -> Result<()> {
        let backups = self.backup_manager.list_backups()?;

        if backups.is_empty() {
            println!("No backups found.");
            return Ok(());
        }

        let backup_choices: Vec<String> = backups.iter().map(|b| b.filename.clone()).collect();
        let selected = Select::new("Select backup to view details:", backup_choices)
            .prompt()
            .context("Failed to get backup selection")?;

        let backup = backups.iter()
            .find(|b| b.filename == selected)
            .ok_or_else(|| anyhow::anyhow!("Backup not found"))?;

        println!("\nBackup Details:");
        println!("  Filename: {}", backup.filename);
        println!("  Size: {}", backup.size_display());
        println!("  Created: {}", backup.created_at_display());
        println!("  Schemas ({}):", backup.schemas.len());

        for schema in &backup.schemas {
            println!("    - {}", schema);
        }

        // Action menu
        let actions = vec!["Delete Backup", "Restore Backup", "Back"];
        let action = Select::new("Choose action:", actions)
            .prompt()
            .context("Failed to get action selection")?;

        match action {
            "Delete Backup" => self.delete_backup(backup)?,
            "Restore Backup" => self.restore_backup(backup).await?,
            "Back" => {},
            _ => {}
        }

        Ok(())
    }

    fn delete_backup(&mut self, backup: &BackupInfo) -> Result<()> {
        let confirm = Confirm::new(&format!("Are you sure you want to delete '{}'?", backup.filename))
            .with_default(false)
            .prompt()
            .context("Failed to get deletion confirmation")?;

        if confirm {
            self.backup_manager.delete_backup(&backup.filepath)?;
            println!("✅ Backup deleted successfully.");
        } else {
            println!("Deletion cancelled.");
        }

        Ok(())
    }

    async fn restore_backup(&mut self, backup: &BackupInfo) -> Result<()> {
        let servers = self.server_manager.get_all_servers();

        if servers.is_empty() {
            println!("No servers configured. Please add a server first.");
            return Ok(());
        }

        let server_choices: Vec<String> = servers.iter().map(|s| s.display_name()).collect();
        let selected_server = Select::new("Select target server for restore:", server_choices)
            .prompt()
            .context("Failed to get server selection")?;

        let server = servers.iter()
            .find(|s| s.display_name() == selected_server)
            .ok_or_else(|| anyhow::anyhow!("Server not found"))?;

        let confirm = Confirm::new(&format!("Restore backup '{}' to server '{}'?", backup.filename, server.name))
            .with_default(false)
            .prompt()
            .context("Failed to get restore confirmation")?;

        if !confirm {
            println!("Restore cancelled.");
            return Ok(());
        }

        println!("Restoring backup...");
        self.runtime.block_on(
            DatabaseConnection::restore_backup(server, backup.filepath.to_str().unwrap())
        )?;

        println!("✅ Backup restored successfully.");

        // Send notification if configured
        if self.telegram_manager.is_enabled() {
            if let Ok(notifier) = TelegramNotifier::new(self.telegram_manager.get_config().unwrap()) {
                let _ = self.runtime.block_on(
                    notifier.send_restore_notification(
                        server,
                        &backup.schemas,
                        &backup.filename,
                        &backup.size_display()
                    )
                );
            }
        }

        Ok(())
    }

    pub async fn manage_servers(&mut self) -> Result<()> {
        loop {
            let choices = vec![
                "List Servers",
                "Add Server",
                "Edit Server",
                "Test Connection",
                "Set Active Server",
                "Back",
            ];

            let choice = Select::new("Server Management:", choices)
                .prompt()
                .context("Failed to get server management selection")?;

            match choice {
                "List Servers" => self.list_servers()?,
                "Add Server" => self.add_server().await?,
                "Edit Server" => self.edit_server().await?,
                "Test Connection" => self.test_connection().await?,
                "Set Active Server" => self.set_active_server()?,
                "Back" => break,
                _ => {}
            }
        }

        Ok(())
    }

    fn list_servers(&mut self) -> Result<()> {
        let servers = self.server_manager.get_all_servers();

        if servers.is_empty() {
            println!("No servers configured.");
            return Ok(());
        }

        println!("Configured Servers:");
        for server in servers {
            let active_marker = if server.is_active { " (ACTIVE)" } else { "" };
            let total_schemas = server.total_schemas.map(|n| n.to_string()).unwrap_or_else(|| "?".to_string());
            println!("  {}{} - {}:{} - {} schemas - {}",
                server.name, active_marker, server.host, server.port, total_schemas,
                server.version.as_deref().unwrap_or("version unknown"));
        }

        Ok(())
    }

    async fn add_server(&mut self) -> Result<()> {
        println!("Add New Server");

        let name = Text::new("Server name:")
            .prompt()
            .context("Failed to get server name")?;

        if self.server_manager.server_exists(&name) {
            return Err(anyhow::anyhow!("Server '{}' already exists", name));
        }

        let host = Text::new("Host/IP address:")
            .with_default("localhost")
            .prompt()
            .context("Failed to get host")?;

        let port: u16 = CustomType::new("Port:")
            .with_default(5432)
            .prompt()
            .context("Failed to get port")?;

        let database = Text::new("Database name:")
            .prompt()
            .context("Failed to get database name")?;

        let username = Text::new("Username:")
            .prompt()
            .context("Failed to get username")?;

        let password = Text::new("Password:")
            .with_help_message("Enter password (will be stored in plain text)")
            .prompt()
            .context("Failed to get password")?;

        let server_config = ServerConfig::new(name.clone(), host, port, database, username, password);

        // Test connection
        println!("Testing connection...");
        match self.runtime.block_on(DatabaseConnection::test_connection(&server_config)) {
            Ok(connection_info) => {
                println!("✅ Connection successful: {}", connection_info);

                // Get server version and schema count
                let version = self.runtime.block_on(
                    DatabaseConnection::get_server_version(&server_config)
                )?;

                // Add server
                self.server_manager.add_server(server_config)?;

                // Update with version info (we need to get mutable reference)
                if let Some(server) = self.server_manager.get_server_mut(&name) {
                    server.version = Some(version);
                }

                println!("✅ Server '{}' added successfully.", name);

                // Ask if this should be the active server
                if self.server_manager.count_servers() == 1 {
                    let set_active = Confirm::new("Set this as the active server?")
                        .with_default(true)
                        .prompt()
                        .context("Failed to get active server confirmation")?;

                    if set_active {
                        self.server_manager.set_active_server(&name)?;
                        println!("✅ Server '{}' set as active.", name);
                    }
                }
            }
            Err(e) => {
                println!("❌ Connection failed: {}", e);
                let save_anyway = Confirm::new("Save server configuration anyway?")
                    .with_default(false)
                    .prompt()
                    .context("Failed to get save anyway confirmation")?;

                if save_anyway {
                    self.server_manager.add_server(server_config)?;
                    println!("⚠️  Server '{}' saved but connection failed.", name);
                } else {
                    println!("Server configuration cancelled.");
                }
            }
        }

        Ok(())
    }

    async fn edit_server(&mut self) -> Result<()> {
        let server_names: Vec<String> = self.server_manager.get_server_names();

        if server_names.is_empty() {
            println!("No servers configured.");
            return Ok(());
        }

        let server_choices: Vec<String> = server_names.iter().map(|s| s.clone()).collect();
        let selected = Select::new("Select server to edit:", server_choices)
            .prompt()
            .context("Failed to get server selection")?;

        let server = self.server_manager.get_server(&selected)
            .ok_or_else(|| anyhow::anyhow!("Server not found"))?;

        if server.is_active {
            return Err(anyhow::anyhow!("Cannot edit active server '{}'", server.name));
        }

        println!("Editing server: {}", server.name);

        let host = Text::new("Host/IP address:")
            .with_default(&server.host)
            .prompt()
            .context("Failed to get host")?;

        let port: u16 = CustomType::new("Port:")
            .with_default(server.port)
            .prompt()
            .context("Failed to get port")?;

        let database = Text::new("Database name:")
            .with_default(&server.database)
            .prompt()
            .context("Failed to get database name")?;

        let username = Text::new("Username:")
            .with_default(&server.username)
            .prompt()
            .context("Failed to get username")?;

        let password = Text::new("Password (leave empty to keep current):")
            .prompt()
            .context("Failed to get password")?;

        let new_password = if password.is_empty() {
            server.password.clone()
        } else {
            password
        };

        let new_server_config = ServerConfig::new(
            server.name.clone(),
            host,
            port,
            database,
            username,
            new_password,
        );

        // Remove old config and add new one
        let server_name = server.name.clone();
        self.server_manager.remove_server(&server_name)?;
        self.server_manager.add_server(new_server_config)?;

        println!("✅ Server '{}' updated successfully.", server_name);

        Ok(())
    }

    async fn test_connection(&mut self) -> Result<()> {
        let server_names: Vec<String> = self.server_manager.get_server_names();

        if server_names.is_empty() {
            println!("No servers configured.");
            return Ok(());
        }

        let server_choices: Vec<String> = server_names.iter().map(|name| {
            if let Some(server) = self.server_manager.get_server(name) {
                server.display_name()
            } else {
                name.clone()
            }
        }).collect();

        let selected = Select::new("Select server to test:", server_choices)
            .prompt()
            .context("Failed to get server selection")?;

        let servers = self.server_manager.get_all_servers();
        let server = servers.iter()
            .find(|s| s.display_name() == selected)
            .ok_or_else(|| anyhow::anyhow!("Server not found"))?;

        println!("Testing connection to {}...", server.name);
        let server_name = server.name.clone();

        match self.runtime.block_on(DatabaseConnection::test_connection(server)) {
            Ok(connection_info) => {
                println!("✅ Connection successful: {}", connection_info);

                // Update server info
                if let Some(server) = self.server_manager.get_server_mut(&server_name) {
                    let version = self.runtime.block_on(
                        DatabaseConnection::get_server_version(server)
                    )?;
                    server.version = Some(version);
                    self.server_manager.save()?;
                }
            }
            Err(e) => {
                println!("❌ Connection failed: {}", e);
            }
        }

        Ok(())
    }

    fn set_active_server(&mut self) -> Result<()> {
        let servers = self.server_manager.get_all_servers();

        if servers.is_empty() {
            println!("No servers configured.");
            return Ok(());
        }

        let server_choices: Vec<String> = servers.iter().map(|s| s.name.clone()).collect();
        let selected = Select::new("Select active server:", server_choices)
            .prompt()
            .context("Failed to get server selection")?;

        self.server_manager.set_active_server(&selected)?;
        println!("✅ Server '{}' set as active.", selected);

        Ok(())
    }

    fn notification_settings(&mut self) -> Result<()> {
        let telegram_config = self.telegram_manager.get_config();

        if telegram_config.is_some() && telegram_config.unwrap().is_configured() {
            let choices = vec!["View Current Settings", "Disable Notifications", "Edit Settings", "Back"];
            let choice = Select::new("Notification Settings:", choices)
                .prompt()
                .context("Failed to get notification settings selection")?;

            match choice {
                "View Current Settings" => self.view_notification_settings()?,
                "Disable Notifications" => self.disable_notifications()?,
                "Edit Settings" => self.edit_notification_settings()?,
                "Back" => {},
                _ => {}
            }
        } else {
            let choices = vec!["Configure Telegram", "Back"];
            let choice = Select::new("Notification Settings:", choices)
                .prompt()
                .context("Failed to get notification settings selection")?;

            match choice {
                "Configure Telegram" => self.configure_telegram()?,
                "Back" => {},
                _ => {}
            }
        }

        Ok(())
    }

    fn view_notification_settings(&mut self) -> Result<()> {
        if let Some(config) = self.telegram_manager.get_config() {
            println!("Telegram Notification Settings:");
            println!("  Status: {}", if config.enabled { "Enabled" } else { "Disabled" });
            println!("  Bot Token: {}...", config.bot_token.chars().take(10).collect::<String>());
            println!("  Chat ID: {}", config.chat_id);
        } else {
            println!("No notification settings configured.");
        }

        Ok(())
    }

    fn disable_notifications(&mut self) -> Result<()> {
        let confirm = Confirm::new("Disable Telegram notifications?")
            .with_default(false)
            .prompt()
            .context("Failed to get disable confirmation")?;

        if confirm {
            self.telegram_manager.disable()?;
            println!("✅ Telegram notifications disabled.");
        }

        Ok(())
    }

    fn edit_notification_settings(&mut self) -> Result<()> {
        self.configure_telegram()
    }

    fn configure_telegram(&mut self) -> Result<()> {
        println!("Configure Telegram Notifications");

        let bot_token = Text::new("Telegram Bot Token:")
            .prompt()
            .context("Failed to get bot token")?;

        let chat_id = Text::new("Telegram Chat ID:")
            .prompt()
            .context("Failed to get chat ID")?;

        let config = crate::config::TelegramConfig::new(bot_token, chat_id);
        self.telegram_manager.set_config(config)?;

        println!("✅ Telegram notifications configured successfully.");

        Ok(())
    }
}