use crate::config::TelegramConfig;
use anyhow::{Result, Context};
use teloxide::prelude::*;
use teloxide::types::ParseMode;
use chrono;

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

    pub async fn send_cronjob_success_notification(
        &self,
        job_name: &str,
        job_schedule: &str,
        backup_filename: &str,
        backup_size: &str,
        duration_seconds: u64,
        schemas: &[String],
    ) -> Result<()> {
        let message = format!(
            "⏰ *Cronjob Executed Successfully*\n\n\
            *Job Name:* {}\n\
            *Schedule:* {}\n\
            *Duration:* {}m {}s\n\
            *Backup File:* `{}`\n\
            *Size:* {}\n\
            *Schemas:* {}\n\
            {}\n\n\
            *Status:* ✅ Completed\n\
            *Timestamp:* {}",
            job_name,
            job_schedule,
            duration_seconds / 60,
            duration_seconds % 60,
            backup_filename,
            backup_size,
            schemas.len(),
            if schemas.len() <= 10 {
                schemas.iter().enumerate().map(|(i, s)|
                    if i < 10 { format!("• {}", s) } else { String::new() }
                ).filter(|s| !s.is_empty()).collect::<Vec<_>>().join("\n")
            } else {
                format!("• {} schemas (first 10 shown)",
                                    schemas.iter().take(10).map(|s| s.as_str()).collect::<Vec<_>>().join(", "))
            },
            chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
        );

        self.send_message(&message).await
    }

    pub async fn send_cronjob_failure_notification(
        &self,
        job_name: &str,
        job_schedule: &str,
        error_message: &str,
        retry_count: u32,
        next_retry: Option<chrono::DateTime<chrono::Local>>,
    ) -> Result<()> {
        let retry_info = if retry_count > 0 {
            if let Some(next_time) = next_retry {
                format!("\n*Retry Count:* {}\n*Next Retry:* {}", retry_count, next_time.format("%Y-%m-%d %H:%M:%S"))
            } else {
                format!("\n*Retry Count:* {}\n*Next Retry:* Not scheduled", retry_count)
            }
        } else {
            String::new()
        };

        let message = format!(
            "🚨 *Cronjob Execution Failed*\n\n\
            *Job Name:* {}\n\
            *Schedule:* {}\n\
            *Error:* `{}`{}\n\
            *Status:* ❌ Failed\n\
            *Timestamp:* {}",
            job_name,
            job_schedule,
            error_message,
            retry_info,
            chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
        );

        self.send_message(&message).await
    }

    pub async fn send_cronjob_schedule_notification(
        &self,
        job_name: &str,
        job_schedule: &str,
        next_run: Option<chrono::DateTime<chrono::Local>>,
    ) -> Result<()> {
        let next_run_info = if let Some(next_time) = next_run {
            format!("*Next Run:* {}", next_time.format("%Y-%m-%d %H:%M:%S"))
        } else {
            String::from("*Next Run:* Not scheduled")
        };

        let message = format!(
            "📅 *Cronjob Scheduled*\n\n\
            *Job Name:* {}\n\
            *Schedule:* {}\n\
            {}\n\n\
            *Status:* ⏰ Active\n\
            *Created:* {}",
            job_name,
            job_schedule,
            next_run_info,
            chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
        );

        self.send_message(&message).await
    }

    pub async fn send_cronjob_removed_notification(
        &self,
        job_name: &str,
        job_schedule: &str,
    ) -> Result<()> {
        let message = format!(
            "🗑️ *Cronjob Removed*\n\n\
            *Job Name:* {}\n\
            *Schedule:* {}\n\n\
            *Status:* ⛔ Removed\n\
            *Timestamp:* {}",
            job_name,
            job_schedule,
            chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
        );

        self.send_message(&message).await
    }

    pub async fn send_cronjob_statistics_notification(
        &self,
        total_jobs: usize,
        enabled_jobs: usize,
        total_executions: u64,
        success_rate: f64,
        period: &str,
    ) -> Result<()> {
        let message = format!(
            "📊 *Cronjob Statistics Report*\n\n\
            *Period:* {}\n\
            *Total Jobs:* {}\n\
            *Enabled Jobs:* {}\n\
            *Disabled Jobs:* {}\n\n\
            *Total Executions:* {}\n\
            *Success Rate:* {:.1}%\n\n\
            *Report Generated:* {}",
            period,
            total_jobs,
            enabled_jobs,
            total_jobs - enabled_jobs,
            total_executions,
            success_rate,
            chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
        );

        self.send_message(&message).await
    }

    pub async fn send_cronjob_skip_notification(
        &self,
        job_name: &str,
        job_schedule: &str,
        skip_reason: &str,
    ) -> Result<()> {
        let message = format!(
            "⚠️ *Cronjob Execution Skipped*\n\n\
            *Job:* {}\n\
            *Schedule:* {}\n\
            *Skip Reason:* {}\n\
            *Time:* {}\n\n\
            _Note: This execution was skipped gracefully and will be retried according to schedule._",
            job_name,
            job_schedule,
            skip_reason,
            chrono::Local::now().format("%Y-%m-%d %H:%M:%S")
        );

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