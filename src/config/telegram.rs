use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use anyhow::{Result, Context};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TelegramConfig {
    pub bot_token: String,
    pub chat_id: String,
    pub enabled: bool,
}

impl TelegramConfig {
    pub fn new(bot_token: String, chat_id: String) -> Self {
        Self {
            bot_token,
            chat_id,
            enabled: true,
        }
    }

    pub fn is_configured(&self) -> bool {
        !self.bot_token.is_empty() && !self.chat_id.is_empty() && self.enabled
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct TelegramManager {
    config: Option<TelegramConfig>,
    config_path: String,
}

impl TelegramManager {
    pub fn new(config_dir: &str) -> Self {
        let config_path = format!("{}/telegram.json", config_dir);
        Self {
            config: None,
            config_path,
        }
    }

    pub fn load(&mut self) -> Result<()> {
        if !Path::new(&self.config_path).exists() {
            // Create empty config file if it doesn't exist
            self.save()?;
            return Ok(());
        }

        let content = fs::read_to_string(&self.config_path)
            .context("Failed to read telegram configuration file")?;

        // Handle empty file or null value
        if content.trim().is_empty() || content.trim() == "null" {
            self.config = None;
            return Ok(());
        }

        self.config = serde_json::from_str(&content)
            .context("Failed to parse telegram configuration")?;

        Ok(())
    }

    pub fn save(&self) -> Result<()> {
        let content = serde_json::to_string_pretty(&self.config)
            .context("Failed to serialize telegram configuration")?;

        fs::write(&self.config_path, content)
            .context("Failed to write telegram configuration file")?;

        Ok(())
    }

    pub fn set_config(&mut self, config: TelegramConfig) -> Result<()> {
        self.config = Some(config);
        self.save()
    }

    pub fn get_config(&self) -> Option<&TelegramConfig> {
        self.config.as_ref()
    }

    pub fn remove_config(&mut self) -> Result<()> {
        self.config = None;
        self.save()
    }

    pub fn is_enabled(&self) -> bool {
        self.config.as_ref()
            .map(|c| c.is_configured())
            .unwrap_or(false)
    }

    pub fn disable(&mut self) -> Result<()> {
        if let Some(ref mut config) = self.config {
            config.enabled = false;
            self.save()?;
        }
        Ok(())
    }

    pub fn enable(&mut self) -> Result<()> {
        if let Some(ref mut config) = self.config {
            config.enabled = true;
            self.save()?;
        }
        Ok(())
    }
}