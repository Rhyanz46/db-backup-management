use anyhow::{Result, Context};
use serde::{Deserialize, Serialize};
use std::path::Path;
use std::fs;
use std::io::Write;
use chrono::{Local, DateTime, Utc};
use super::CronJob;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CronJobManager {
    jobs: Vec<CronJob>,
    config_dir: String,
}

impl CronJobManager {
    pub fn new(config_dir: &str) -> Self {
        Self {
            jobs: Vec::new(),
            config_dir: config_dir.to_string(),
        }
    }

    pub fn get_config_file_path(&self) -> String {
        format!("{}/cronjobs.json", self.config_dir)
    }

    pub fn load(&mut self) -> Result<()> {
        let config_path = self.get_config_file_path();

        if Path::new(&config_path).exists() {
            // Try to load the main configuration
            match self.load_config_file(&config_path) {
                Ok(jobs) => {
                    self.jobs = jobs;
                    println!("Loaded {} cronjob(s)", self.jobs.len());
                    log::info!("Successfully loaded {} cronjobs from {}", self.jobs.len(), config_path);
                }
                Err(e) => {
                    log::warn!("Failed to load main config file {}: {}", config_path, e);
                    println!("⚠️ Configuration file corrupted, attempting recovery...");

                    // Try to recover from backup
                    match self.recover_from_backup() {
                        Ok(jobs) => {
                            self.jobs = jobs;
                            println!("✅ Successfully recovered {} cronjob(s) from backup", self.jobs.len());
                            log::info!("Successfully recovered {} cronjobs from backup", self.jobs.len());
                        }
                        Err(recovery_error) => {
                            log::error!("Failed to recover from backup: {}", recovery_error);
                            println!("❌ Recovery failed. Starting with empty configuration.");

                            // Move corrupted file to prevent repeated attempts
                            let corrupted_path = format!("{}.corrupted.{}", config_path, Utc::now().timestamp());
                            if let Err(move_error) = fs::rename(&config_path, &corrupted_path) {
                                log::error!("Failed to move corrupted config file: {}", move_error);
                            } else {
                                println!("📁 Corrupted config moved to: {}", corrupted_path);
                                log::info!("Corrupted config moved to: {}", corrupted_path);
                            }

                            self.jobs = Vec::new();
                        }
                    }
                }
            }
        } else {
            println!("No existing cronjobs configuration found, starting with empty list");
            self.jobs = Vec::new();
            log::info!("No existing configuration found, starting with empty cronjob list");
        }

        Ok(())
    }

    /// Load and validate a configuration file
  fn load_config_file(&self, config_path: &str) -> Result<Vec<CronJob>> {
        let content = fs::read_to_string(config_path)
            .context("Failed to read configuration file")?;

        // Validate content structure
        self.validate_jobs_content(&content)?;

        // Parse JSON
        let jobs: Vec<CronJob> = serde_json::from_str(&content)
            .context("Failed to parse cronjobs configuration")?;

        // Additional validation of loaded data
        for job in &jobs {
            self.validate_single_job(job)?;
        }

        Ok(jobs)
    }

    /// Recover cronjobs from the most recent backup file
    fn recover_from_backup(&self) -> Result<Vec<CronJob>> {
        let config_path = self.get_config_file_path();
        let backup_pattern = format!("{}.backup.*", config_path);

        // Find all backup files
        let backup_files = self.find_backup_files(&backup_pattern)?;

        if backup_files.is_empty() {
            return Err(anyhow::anyhow!("No backup files found for recovery"));
        }

        // Sort by timestamp (newest first) and try each backup
        for backup_file in backup_files {
            log::info!("Attempting recovery from backup: {}", backup_file);
            println!("🔄 Trying backup: {}", Path::new(&backup_file).file_name().unwrap().to_str().unwrap());

            match self.load_config_file(&backup_file) {
                Ok(jobs) => {
                    // Recovery successful - restore from this backup
                    if let Err(e) = self.restore_from_backup(&backup_file) {
                        log::warn!("Failed to restore from backup {}: {}", backup_file, e);
                    }
                    return Ok(jobs);
                }
                Err(e) => {
                    log::warn!("Backup file {} is also corrupted: {}", backup_file, e);
                    println!("❌ Backup corrupted, trying next...");
                    continue;
                }
            }
        }

        Err(anyhow::anyhow!("All backup files are corrupted or unreadable"))
    }

    /// Find all backup files matching the pattern, sorted by timestamp (newest first)
    fn find_backup_files(&self, pattern: &str) -> Result<Vec<String>> {
        let config_path = self.get_config_file_path();
        let config_dir = Path::new(&config_path).parent()
            .ok_or_else(|| anyhow::anyhow!("Invalid config path"))?;

        let mut backup_files = Vec::new();

        if let Ok(entries) = fs::read_dir(config_dir) {
            for entry in entries.flatten() {
                let path = entry.path();
                if let Some(filename) = path.file_name().and_then(|n| n.to_str()) {
                    if filename.starts_with("cronjobs.backup.") {
                        backup_files.push(path.to_string_lossy().to_string());
                    }
                }
            }
        }

        // Sort by timestamp in filename (newest first)
        backup_files.sort_by(|a, b| {
            let timestamp_a = self.extract_timestamp_from_backup(a);
            let timestamp_b = self.extract_timestamp_from_backup(b);
            timestamp_b.cmp(&timestamp_a)
        });

        Ok(backup_files)
    }

    /// Extract timestamp from backup filename
    fn extract_timestamp_from_backup(&self, backup_path: &str) -> u64 {
        Path::new(backup_path)
            .file_stem()
            .and_then(|stem| stem.to_str())
            .and_then(|stem| stem.split('.').last())
            .and_then(|timestamp_str| timestamp_str.parse().ok())
            .unwrap_or(0)
    }

    /// Restore configuration from backup file
    fn restore_from_backup(&self, backup_path: &str) -> Result<()> {
        let config_path = self.get_config_file_path();

        fs::copy(backup_path, config_path)
            .context("Failed to restore backup file")?;

        log::info!("Configuration restored from backup: {}", backup_path);
        Ok(())
    }

    pub fn save(&self) -> Result<()> {
        let config_path = self.get_config_file_path();

        // Ensure config directory exists
        if let Some(parent) = Path::new(&config_path).parent() {
            fs::create_dir_all(parent)
                .context("Failed to create config directory")?;
        }

        self.save_atomic()
    }

    /// Save configuration atomically with backup protection
    pub fn save_atomic(&self) -> Result<()> {
        let config_path = self.get_config_file_path();
        let temp_path = format!("{}.tmp.{}", config_path, Utc::now().timestamp());

        // 1. Write to temporary file
        let content = serde_json::to_string_pretty(&self.jobs)
            .context("Failed to serialize cronjobs configuration")?;

        // 2. Validate JSON structure before committing
        self.validate_jobs_content(&content)?;

        // 3. Write to temporary file
        let mut temp_file = fs::File::create(&temp_path)
            .context("Failed to create temporary config file")?;
        temp_file.write_all(content.as_bytes())
            .context("Failed to write to temporary config file")?;
        temp_file.sync_all() // Ensure data is written to disk
            .context("Failed to sync temporary config file")?;

        // 4. Atomic rename (atomic operation on most filesystems)
        fs::rename(&temp_path, &config_path)
            .context("Failed to atomically rename temporary config file")?;

        log::info!("Cronjob configuration saved successfully");
        Ok(())
    }

    /// Save with automatic backup (creates backup before modification)
    pub fn save_with_backup(&self) -> Result<()> {
        let config_path = self.get_config_file_path();

        // 1. Create backup if config file exists
        if Path::new(&config_path).exists() {
            let timestamp = Local::now().format("%Y%m%d_%H%M%S%S");
            let backup_path = format!("{}.backup.{}", config_path, timestamp);

            fs::copy(config_path, &backup_path)
                .context("Failed to create backup of config file")?;

            log::info!("Created backup: {}", backup_path);

            // Cleanup old backups (keep only 10 most recent)
            self.cleanup_old_backups(10)?;
        }

        // 2. Save with atomic operations
        self.save_atomic()?;

        Ok(())
    }

    /// Cleanup old backup files, keeping only the most recent N backups
    fn cleanup_old_backups(&self, keep_count: usize) -> Result<()> {
        let config_path = self.get_config_file_path();
        let backup_pattern = format!("{}.backup.*", config_path);

        let backup_files = self.find_backup_files(&backup_pattern)?;

        // Remove old backups if we have more than keep_count
        if backup_files.len() > keep_count {
            let files_to_remove = &backup_files[keep_count..];

            for backup_file in files_to_remove {
                if let Err(e) = fs::remove_file(backup_file) {
                    log::warn!("Failed to remove old backup file {}: {}", backup_file, e);
                } else {
                    log::info!("Removed old backup file: {}", backup_file);
                    println!("🗑️ Removed old backup: {}", Path::new(backup_file).file_name().unwrap().to_str().unwrap());
                }
            }
        }

        Ok(())
    }

    /// Validate jobs content before saving
    fn validate_jobs_content(&self, content: &str) -> Result<()> {
        // Try to parse JSON to ensure it's valid
        let parsed: Result<Vec<CronJob>, _> = serde_json::from_str(content);
        match parsed {
            Ok(jobs) => {
                // Validate each job
                for job in &jobs {
                    self.validate_single_job(job)?;
                }
                Ok(())
            }
            Err(e) => {
                Err(anyhow::anyhow!("Invalid JSON structure: {}", e))
            }
        }
    }

    /// Validate individual cronjob
    fn validate_single_job(&self, job: &CronJob) -> Result<()> {
        // 1. Validate name (required, unique, reasonable length)
        if job.name.trim().is_empty() {
            return Err(anyhow::anyhow!("Job name cannot be empty"));
        }
        if job.name.len() > 100 {
            return Err(anyhow::anyhow!("Job name too long (max 100 characters)"));
        }

        // 2. Validate ID (required, valid UUID format)
        if job.id.trim().is_empty() {
            return Err(anyhow::anyhow!("Job ID cannot be empty"));
        }

        // Validate UUID format (simplified check)
        if job.id.len() != 36 || !job.id.starts_with("temp_") && job.id.chars().all(|c| c.is_alphanumeric() || c == '-') {
            return Err(anyhow::anyhow!("Invalid job ID format"));
        }

        // 3. Validate schedule (required)
        if job.schedule.trim().is_empty() {
            return Err(anyhow::anyhow!("Job schedule cannot be empty"));
        }
        if !CronJobManager::is_valid_cron_expression(&job.schedule) {
            return Err(anyhow::anyhow!(
                "Invalid cron expression '{}': must be in format '* * * * *'",
                job.schedule
            ));
        }

        // 4. Validate schedule type consistency
        let expected_schedule = job.schedule_type.to_cron_expression();
        if expected_schedule != job.schedule {
            return Err(anyhow::anyhow!(
                "Schedule mismatch: computed '{}' but stored '{}'",
                expected_schedule, job.schedule
            ));
        }

        // 5. Validate run counts
        if job.failure_count > job.run_count {
            return Err(anyhow::anyhow!(
                "Failure count ({}) cannot be greater than total run count ({})",
                job.failure_count, job.run_count
            ));
        }
        if job.success_count > job.run_count {
            return Err(anyhow::anyhow!(
                "Success count ({}) cannot be greater than total run count ({})",
                job.success_count, job.run_count
            ));
        }
        if job.success_count + job.failure_count != job.run_count {
            return Err(anyhow::anyhow!(
                "Success count + failure count ({}) must equal total run count ({})",
                job.success_count + job.failure_count, job.run_count
            ));
        }

        // 6. Validate timestamps
        if let Some(last_run) = job.last_run {
            if let Some(created_at) = job.created_at {
                if last_run < created_at {
                    return Err(anyhow::anyhow!("Last run time cannot be before creation time"));
                }
            }
        }

        Ok(())
    }

    /// Validate cron expression format (basic validation)
    fn is_valid_cron_expression(expr: &str) -> bool {
        // Basic validation: should have exactly 5 parts separated by whitespace
        let parts: Vec<&str> = expr.split_whitespace().collect();
        if parts.len() != 5 {
            return false;
        }

        // Validate each part
        for part in &parts {
            if part.is_empty() {
                return false;
            }

            // Allow common cron patterns:
            // * (any), */N (every N), specific numbers, ranges (1-5)
            let valid_patterns = ["*", "/", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                                   "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN",
                                   "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];

            if !valid_patterns.iter().any(|&pattern| part.starts_with(pattern)) &&
               !part.contains('-') && // Allow ranges like 1-5
               part.as_str() != "?" {  // Allow question marks
                return false;
            }
        }

        true
    }

    pub fn add_job(&mut self, job: CronJob) -> Result<()> {
        // Check if job name already exists
        if self.jobs.iter().any(|j| j.name == job.name) {
            anyhow::bail!("Cronjob dengan nama '{}' sudah ada", job.name);
        }

        self.jobs.push(job);
        self.save()?;
        Ok(())
    }

    pub fn remove_job(&mut self, job_id: &str) -> Result<()> {
        let initial_len = self.jobs.len();
        self.jobs.retain(|job| job.id != job_id);

        if self.jobs.len() == initial_len {
            anyhow::bail!("Cronjob dengan ID '{}' tidak ditemukan", job_id);
        }

        self.save()?;
        Ok(())
    }

    pub fn get_job_by_id(&self, job_id: &str) -> Option<&CronJob> {
        self.jobs.iter().find(|job| job.id == job_id)
    }

    pub fn get_job_by_id_mut(&mut self, job_id: &str) -> Option<&mut CronJob> {
        self.jobs.iter_mut().find(|job| job.id == job_id)
    }

    pub fn get_job_by_name(&self, name: &str) -> Option<&CronJob> {
        self.jobs.iter().find(|job| job.name == name)
    }

    pub fn list_jobs(&self) -> &[CronJob] {
        &self.jobs
    }

    pub fn list_enabled_jobs(&self) -> Vec<&CronJob> {
        self.jobs.iter().filter(|job| job.enabled).collect()
    }

    pub fn toggle_job(&mut self, job_id: &str) -> Result<()> {
        if let Some(job) = self.get_job_by_id_mut(job_id) {
            job.enabled = !job.enabled;
            self.save()?;
            Ok(())
        } else {
            anyhow::bail!("Cronjob dengan ID '{}' tidak ditemukan", job_id);
        }
    }

    pub fn update_job_stats(&mut self, job_id: &str, success: bool) -> Result<()> {
        if let Some(job) = self.get_job_by_id_mut(job_id) {
            job.update_execution_stats(success);
            job.calculate_next_run();
            self.save()?;
            Ok(())
        } else {
            anyhow::bail!("Cronjob dengan ID '{}' tidak ditemukan", job_id);
        }
    }

    pub fn get_jobs_summary(&self) -> CronJobsSummary {
        let total = self.jobs.len();
        let enabled = self.jobs.iter().filter(|job| job.enabled).count();
        let disabled = total - enabled;

        let total_runs: u64 = self.jobs.iter().map(|job| job.run_count).sum();
        let total_success: u64 = self.jobs.iter().map(|job| job.success_count).sum();
        let total_failures: u64 = self.jobs.iter().map(|job| job.failure_count).sum();

        CronJobsSummary {
            total,
            enabled,
            disabled,
            total_runs,
            total_success,
            total_failures,
            overall_success_rate: if total_runs > 0 {
                (total_success as f64 / total_runs as f64) * 100.0
            } else {
                0.0
            },
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CronJobsSummary {
    pub total: usize,
    pub enabled: usize,
    pub disabled: usize,
    pub total_runs: u64,
    pub total_success: u64,
    pub total_failures: u64,
    pub overall_success_rate: f64,
}

impl CronJobsSummary {
    pub fn display(&self) {
        println!("\n📊 Cronjobs Summary:");
        println!("┌─────────────────────────────┬─────────┐");
        println!("│ Total Jobs                 │ {:<7} │", self.total);
        println!("│ Enabled Jobs               │ {:<7} │", self.enabled);
        println!("│ Disabled Jobs              │ {:<7} │", self.disabled);
        println!("├─────────────────────────────┼─────────┤");
        println!("│ Total Runs                 │ {:<7} │", self.total_runs);
        println!("│ Successful Runs            │ {:<7} │", self.total_success);
        println!("│ Failed Runs                │ {:<7} │", self.total_failures);
        println!("│ Success Rate               │ {:<6.1}%│", self.overall_success_rate);
        println!("└─────────────────────────────┴─────────┘");
    }
}