use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::Path;
use anyhow::{Result, Context};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    pub name: String,
    pub host: String,
    pub port: u16,
    pub database: String,
    pub username: String,
    pub password: String,
    #[serde(default = "default_ssl_mode")]
    pub ssl_mode: String,
    pub version: Option<String>,
    pub total_schemas: Option<usize>,
    pub is_active: bool,
}

fn default_ssl_mode() -> String {
    "prefer".to_string()
}

impl ServerConfig {
    pub fn new(name: String, host: String, port: u16, database: String, username: String, password: String) -> Self {
        Self {
            name,
            host,
            port,
            database,
            username,
            password,
            ssl_mode: "prefer".to_string(), // Default SSL mode
            version: None,
            total_schemas: None,
            is_active: false,
        }
    }

    pub fn new_with_ssl(name: String, host: String, port: u16, database: String, username: String, password: String, ssl_mode: String) -> Self {
        Self {
            name,
            host,
            port,
            database,
            username,
            password,
            ssl_mode,
            version: None,
            total_schemas: None,
            is_active: false,
        }
    }

    pub fn connection_string(&self) -> String {
        format!("postgresql://{}:{}@{}:{}/{}?sslmode={}",
                self.username, self.password, self.host, self.port, self.database, self.ssl_mode)
    }

    pub fn display_name(&self) -> String {
        format!("{} ({}:{}/{})", self.name, self.host, self.port, self.database)
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ServerManager {
    servers: HashMap<String, ServerConfig>,
    config_path: String,
}

impl ServerManager {
    pub fn new(config_dir: &str) -> Self {
        let config_path = format!("{}/servers.json", config_dir);
        Self {
            servers: HashMap::new(),
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
            .context("Failed to read servers configuration file")?;

        self.servers = serde_json::from_str(&content)
            .context("Failed to parse servers configuration")?;

        Ok(())
    }

    pub fn save(&self) -> Result<()> {
        let content = serde_json::to_string_pretty(&self.servers)
            .context("Failed to serialize servers configuration")?;

        fs::write(&self.config_path, content)
            .context("Failed to write servers configuration file")?;

        Ok(())
    }

    pub fn add_server(&mut self, server: ServerConfig) -> Result<()> {
        let name = server.name.clone();
        self.servers.insert(name, server);
        self.save()
    }

    pub fn remove_server(&mut self, name: &str) -> Result<bool> {
        if let Some(server) = self.servers.get(name) {
            if server.is_active {
                return Err(anyhow::anyhow!("Cannot remove active server '{}'", name));
            }
        }

        let removed = self.servers.remove(name).is_some();
        if removed {
            self.save()?;
        }
        Ok(removed)
    }

    pub fn get_server(&self, name: &str) -> Option<&ServerConfig> {
        self.servers.get(name)
    }

    pub fn get_server_mut(&mut self, name: &str) -> Option<&mut ServerConfig> {
        self.servers.get_mut(name)
    }

    pub fn get_all_servers(&self) -> Vec<&ServerConfig> {
        self.servers.values().collect()
    }

    pub fn get_server_names(&self) -> Vec<String> {
        self.servers.keys().cloned().collect()
    }

    pub fn get_active_server(&self) -> Option<&ServerConfig> {
        self.servers.values().find(|s| s.is_active)
    }

    pub fn set_active_server(&mut self, name: &str) -> Result<()> {
        // Clear active flag from all servers
        for server in self.servers.values_mut() {
            server.is_active = false;
        }

        // Set the requested server as active
        if let Some(server) = self.servers.get_mut(name) {
            server.is_active = true;
            self.save()?;
            Ok(())
        } else {
            Err(anyhow::anyhow!("Server '{}' not found", name))
        }
    }

    pub fn server_exists(&self, name: &str) -> bool {
        self.servers.contains_key(name)
    }

    pub fn count_servers(&self) -> usize {
        self.servers.len()
    }

    pub fn count_active_servers(&self) -> usize {
        self.servers.values().filter(|s| s.is_active).count()
    }
}