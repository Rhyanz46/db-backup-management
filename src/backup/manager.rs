use std::fs;
use std::path::{Path, PathBuf};
use anyhow::{Result, Context};
use chrono::{DateTime, Local, NaiveDateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupInfo {
    pub filename: String,
    pub filepath: PathBuf,
    pub size_bytes: u64,
    pub created_at: DateTime<Utc>,
    pub schemas: Vec<String>,
    pub server_name: Option<String>,
}

impl BackupInfo {
    pub fn size_display(&self) -> String {
        const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
        let mut size = self.size_bytes as f64;
        let mut unit_index = 0;

        while size >= 1024.0 && unit_index < UNITS.len() - 1 {
            size /= 1024.0;
            unit_index += 1;
        }

        if unit_index == 0 {
            format!("{} {}", size as u64, UNITS[unit_index])
        } else {
            format!("{:.2} {}", size, UNITS[unit_index])
        }
    }

    pub fn created_at_display(&self) -> String {
        self.created_at.with_timezone(&Local).format("%Y-%m-%d %H:%M:%S").to_string()
    }
}

pub struct BackupManager {
    backup_dir: PathBuf,
}

impl BackupManager {
    pub fn new<P: AsRef<Path>>(backup_dir: P) -> Self {
        Self {
            backup_dir: backup_dir.as_ref().to_path_buf(),
        }
    }

    pub fn ensure_backup_dir(&self) -> Result<()> {
        if !self.backup_dir.exists() {
            fs::create_dir_all(&self.backup_dir)
                .context("Failed to create backup directory")?;
        }
        Ok(())
    }

    pub fn get_backup_filepath(&self, timestamp: &str) -> PathBuf {
        self.backup_dir.join(format!("{}.sql", timestamp))
    }

    pub fn list_backups(&self) -> Result<Vec<BackupInfo>> {
        self.ensure_backup_dir()?;

        let mut backups = Vec::new();

        if !self.backup_dir.exists() {
            return Ok(backups);
        }

        for entry in fs::read_dir(&self.backup_dir)
            .context("Failed to read backup directory")? {
            let entry = entry.context("Failed to read directory entry")?;
            let path = entry.path();

            if path.extension().and_then(|s| s.to_str()) == Some("sql") {
                if let Ok(backup_info) = self.get_backup_info(&path) {
                    backups.push(backup_info);
                }
            }
        }

        // Sort by creation time (newest first)
        backups.sort_by(|a, b| b.created_at.cmp(&a.created_at));

        Ok(backups)
    }

    pub fn get_backup_info<P: AsRef<Path>>(&self, backup_path: P) -> Result<BackupInfo> {
        let path = backup_path.as_ref();
        let filename = path.file_name()
            .and_then(|n| n.to_str())
            .ok_or_else(|| anyhow::anyhow!("Invalid backup filename"))?
            .to_string();

        let metadata = fs::metadata(path)
            .context("Failed to read backup file metadata")?;

        let size_bytes = metadata.len();
        let created_at = metadata.created()
            .ok()
            .and_then(|dt| {
                dt.duration_since(std::time::UNIX_EPOCH).ok()
                    .and_then(|duration| duration.as_secs().try_into().ok())
                    .and_then(|secs| DateTime::from_timestamp(secs, 0))
            })
            .unwrap_or_else(|| Utc::now());

        // Try to extract schema information from backup file
        let schemas = self.extract_schemas_from_file(path)?;

        Ok(BackupInfo {
            filename,
            filepath: path.to_path_buf(),
            size_bytes,
            created_at,
            schemas,
            server_name: None,
        })
    }

    fn extract_schemas_from_file(&self, backup_path: &Path) -> Result<Vec<String>> {
        let content = fs::read_to_string(backup_path)
            .context("Failed to read backup file")?;

        let mut schemas = Vec::new();

        for line in content.lines() {
            let line = line.trim();

            // Look for CREATE SCHEMA statements
            if line.to_uppercase().starts_with("CREATE SCHEMA") {
                if let Some(parts) = line.split_whitespace().collect::<Vec<_>>().get(2) {
                    let schema = parts.trim_end_matches(';');
                    if !schema.is_empty() && schema != "public" {
                        schemas.push(schema.to_string());
                    }
                }
            }

            // Alternative: Look for SET search_path statements
            else if line.to_uppercase().starts_with("SET search_path =") {
                if let Some(path_part) = line.split('=').nth(1) {
                    let path_part = path_part.trim_end_matches(';').trim();
                    let schemas_in_path: Vec<&str> = path_part.split(',').map(|s| s.trim()).collect();
                    for schema in schemas_in_path {
                        if !schema.is_empty() && schema != "public" && !schemas.contains(&schema.to_string()) {
                            schemas.push(schema.to_string());
                        }
                    }
                }
            }
        }

        Ok(schemas)
    }

    pub fn delete_backup<P: AsRef<Path>>(&self, backup_path: P) -> Result<()> {
        let path = backup_path.as_ref();
        if !path.exists() {
            return Err(anyhow::anyhow!("Backup file does not exist"));
        }

        fs::remove_file(path)
            .context("Failed to delete backup file")?;

        log::info!("Deleted backup file: {}", path.display());
        Ok(())
    }

    pub fn get_backup_by_filename(&self, filename: &str) -> Option<BackupInfo> {
        let path = self.backup_dir.join(filename);
        if path.exists() {
            self.get_backup_info(&path).ok()
        } else {
            None
        }
    }

    pub fn generate_timestamp_filename(&self) -> String {
        let now = Local::now();
        now.format("%Y%m%d_%H%M%S").to_string()
    }

    pub fn validate_backup_file<P: AsRef<Path>>(backup_path: P) -> Result<()> {
        let path = backup_path.as_ref();

        if !path.exists() {
            return Err(anyhow::anyhow!("Backup file does not exist"));
        }

        if !path.is_file() {
            return Err(anyhow::anyhow!("Backup path is not a file"));
        }

        if path.extension().and_then(|s| s.to_str()) != Some("sql") {
            return Err(anyhow::anyhow!("Backup file must have .sql extension"));
        }

        // Check if file is readable
        fs::read_to_string(path)
            .context("Backup file is not readable or empty")?;

        Ok(())
    }

    pub fn get_total_size(&self) -> Result<u64> {
        let mut total_size = 0u64;

        if !self.backup_dir.exists() {
            return Ok(0);
        }

        for entry in fs::read_dir(&self.backup_dir)
            .context("Failed to read backup directory")? {
            let entry = entry.context("Failed to read directory entry")?;
            let path = entry.path();

            if path.extension().and_then(|s| s.to_str()) == Some("sql") {
                if let Ok(metadata) = fs::metadata(&path) {
                    total_size += metadata.len();
                }
            }
        }

        Ok(total_size)
    }

    pub fn get_backup_count(&self) -> Result<usize> {
        if !self.backup_dir.exists() {
            return Ok(0);
        }

        let count = fs::read_dir(&self.backup_dir)
            .context("Failed to read backup directory")?
            .filter_map(|entry| entry.ok())
            .filter(|entry| {
                entry.path()
                    .extension()
                    .and_then(|s| s.to_str())
                    == Some("sql")
            })
            .count();

        Ok(count)
    }
}