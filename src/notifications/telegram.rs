use crate::config::TelegramConfig;
use anyhow::{Result, Context};
use teloxide::prelude::*;
use teloxide::types::ParseMode;

pub struct TelegramNotifier {
    bot: Bot,
    chat_id: String,
}

impl TelegramNotifier {
    pub fn new(config: &TelegramConfig) -> Result<Self> {
        if !config.is_configured() {
            return Err(anyhow::anyhow!("Telegram is not properly configured"));
        }

        let bot = Bot::new(config.bot_token.clone());
        let chat_id = config.chat_id.clone();

        Ok(Self { bot, chat_id })
    }

    pub async fn send_backup_notification(
        &self,
        server: &crate::config::ServerConfig,
        schemas: &[String],
        backup_filename: &str,
        backup_size: &str,
    ) -> Result<()> {
        let message = format!(
            "🗄️ *Backup Completed Successfully*\n\n\
            *Server:* {}\n\
            *Database:* {}\n\
            *Host:* {}:{}\n\n\
            *Schemas Backed Up:* {}\n\
            {}\n\n\
            *Backup File:* `{}.sql`\n\
            *Size:* {}\n\n\
            *Timestamp:* {}",
            server.name,
            server.database,
            server.host,
            server.port,
            schemas.len(),
            schemas.iter().enumerate().map(|(i, s)|
                if i < 10 { format!("• {}", s) } else { String::new() }
            ).filter(|s| !s.is_empty()).collect::<Vec<_>>().join("\n"),
            backup_filename,
            backup_size,
            chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
        );

        self.send_message(&message).await
    }

    pub async fn send_restore_notification(
        &self,
        server: &crate::config::ServerConfig,
        schemas: &[String],
        backup_filename: &str,
        backup_size: &str,
    ) -> Result<()> {
        let message = format!(
            "♻️ *Restore Completed Successfully*\n\n\
            *Target Server:* {}\n\
            *Database:* {}\n\
            *Host:* {}:{}\n\n\
            *Schemas Restored:* {}\n\
            {}\n\n\
            *Source File:* `{}.sql`\n\
            *Size:* {}\n\n\
            *Timestamp:* {}",
            server.name,
            server.database,
            server.host,
            server.port,
            schemas.len(),
            schemas.iter().enumerate().map(|(i, s)|
                if i < 10 { format!("• {}", s) } else { String::new() }
            ).filter(|s| !s.is_empty()).collect::<Vec<_>>().join("\n"),
            backup_filename,
            backup_size,
            chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
        );

        self.send_message(&message).await
    }

    pub async fn send_error_notification(
        &self,
        operation: &str,
        server_name: &str,
        error_message: &str,
    ) -> Result<()> {
        let message = format!(
            "❌ *{} Failed*\n\n\
            *Server:* {}\n\n\
            *Error:* {}\n\n\
            *Timestamp:* {}",
            operation,
            server_name,
            error_message,
            chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
        );

        self.send_message(&message).await
    }

    pub async fn send_connection_test_notification(&self, server_name: &str, success: bool) -> Result<()> {
        let message = if success {
            format!(
                "✅ *Connection Test Successful*\n\n\
                *Server:* {}\n\n\
                *Timestamp:* {}",
                server_name,
                chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
            )
        } else {
            format!(
                "❌ *Connection Test Failed*\n\n\
                *Server:* {}\n\n\
                *Timestamp:* {}",
                server_name,
                chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
            )
        };

        self.send_message(&message).await
    }

    async fn send_message(&self, message: &str) -> Result<()> {
        let chat_id = ChatId(self.chat_id.parse()
            .context("Invalid chat ID format")?);

        self.bot.send_message(chat_id, message)
            .parse_mode(ParseMode::MarkdownV2)
            .disable_web_page_preview(true)
            .await
            .context("Failed to send Telegram message")?;

        log::info!("Telegram notification sent successfully");
        Ok(())
    }

    pub async fn test_connection(&self) -> Result<bool> {
        match self.bot.get_me().await {
            Ok(bot_info) => {
                log::info!("Telegram bot connection test successful. Bot: @{}", bot_info.user.username.as_deref().unwrap_or("unknown"));
                Ok(true)
            }
            Err(e) => {
                log::error!("Telegram bot connection test failed: {}", e);
                Ok(false)
            }
        }
    }
}

// Fallback notification implementation when teloxide is not available
#[cfg(not(feature = "telegram"))]
pub struct TelegramNotifier {
    _config: TelegramConfig,
}

#[cfg(not(feature = "telegram"))]
impl TelegramNotifier {
    pub fn new(config: &TelegramConfig) -> Result<Self> {
        log::warn!("Telegram notifications disabled - telegram feature not enabled");
        Ok(Self { _config: config.clone() })
    }

    pub async fn send_backup_notification(
        &self,
        _server: &crate::config::ServerConfig,
        _schemas: &[String],
        _backup_filename: &str,
        _backup_size: &str,
    ) -> Result<()> {
        log::info!("Telegram notification skipped - feature disabled");
        Ok(())
    }

    pub async fn send_restore_notification(
        &self,
        _server: &crate::config::ServerConfig,
        _schemas: &[String],
        _backup_filename: &str,
        _backup_size: &str,
    ) -> Result<()> {
        log::info!("Telegram notification skipped - feature disabled");
        Ok(())
    }

    pub async fn send_error_notification(
        &self,
        _operation: &str,
        _server_name: &str,
        _error_message: &str,
    ) -> Result<()> {
        log::info!("Telegram notification skipped - feature disabled");
        Ok(())
    }

    pub async fn send_connection_test_notification(&self, _server_name: &str, _success: bool) -> Result<()> {
        log::info!("Telegram notification skipped - feature disabled");
        Ok(())
    }

    pub async fn test_connection(&self) -> Result<bool> {
        log::info!("Telegram connection test skipped - feature disabled");
        Ok(false)
    }
}