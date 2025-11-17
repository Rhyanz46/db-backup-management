use anyhow::{Result, Context};
use tokio_cron_scheduler::{Job, JobScheduler};
use std::sync::Arc;
use tokio::sync::RwLock;
use log::{info, error, debug, warn};
use super::{CronJobManager, CronJob};
use crate::config::TelegramManager;
use crate::notifications::TelegramNotifier;
use std::time::SystemTime;
use std::fs;

pub struct CronScheduler {
    scheduler: Option<JobScheduler>,
    job_manager: Arc<RwLock<CronJobManager>>,
    config_dir: String,
    backup_dir: String,
    last_config_modified: Option<SystemTime>,
}

impl CronScheduler {
    pub fn new(config_dir: &str, backup_dir: &str) -> Self {
        Self {
            scheduler: None,
            job_manager: Arc::new(RwLock::new(CronJobManager::new(config_dir))),
            config_dir: config_dir.to_string(),
            backup_dir: backup_dir.to_string(),
            last_config_modified: None,
        }
    }

    pub async fn initialize(&mut self) -> Result<()> {
        // Load existing cronjobs
        {
            let mut manager = self.job_manager.write().await;
            manager.load()
                .context("Failed to load cronjob configurations")?;
        }

        // Create scheduler
        let scheduler = JobScheduler::new()
            .await
            .context("Failed to create job scheduler")?;

        self.scheduler = Some(scheduler);
        info!("Cronjob scheduler initialized");

        Ok(())
    }

    pub async fn start(&mut self) -> Result<()> {
        if let Some(scheduler) = &self.scheduler {
            // Add all enabled jobs to scheduler
            let jobs: Vec<CronJob> = {
                let manager = self.job_manager.read().await;
                manager.list_enabled_jobs().into_iter().map(|j| (*j).clone()).collect()
            };

            let jobs_count = jobs.len();

            for job in jobs {
                if let Err(e) = self.add_job_to_scheduler(scheduler, &job).await {
                    error!("Failed to add job '{}' to scheduler: {}", job.name, e);
                }
            }

            // Start the scheduler
            scheduler.start().await
                .context("Failed to start job scheduler")?;

            info!("Cronjob scheduler started with {} jobs", jobs_count);
        }

        Ok(())
    }

    async fn add_job_to_scheduler(&self, scheduler: &JobScheduler, cronjob: &CronJob) -> Result<()> {
        let job_id = cronjob.id.clone();
        let job_name = cronjob.name.clone();
        let config_dir = self.config_dir.clone();
        let backup_dir = self.backup_dir.clone();
        let job_manager = self.job_manager.clone();

        // Create scheduled job
        let scheduled_job = Job::new_async(cronjob.schedule.as_str(), move |_uuid, _l| {
            let job_id = job_id.clone();
            let job_name = job_name.clone();
            let config_dir = config_dir.clone();
            let backup_dir = backup_dir.clone();
            let job_manager = job_manager.clone();

            Box::pin(async move {
                info!("Executing cronjob: {} (ID: {})", job_name, job_id);

                let result = execute_cronjob(&job_id, &config_dir, &backup_dir).await;

                // Update job statistics based on execution result
                let mut manager = job_manager.write().await;
                if let Err(e) = manager.update_job_stats(&job_id, result.is_ok()) {
                    error!("Failed to update job stats: {}", e);
                }

                match result {
                    Ok(execution_result) => {
                        if execution_result.success {
                            info!("Cronjob '{}' completed successfully in {}s",
                                job_name, execution_result.duration_seconds);
                        } else {
                            error!("Cronjob '{}' failed after {}s",
                                  job_name, execution_result.duration_seconds);
                        }
                    }
                    Err(e) => {
                        error!("Cronjob '{}' execution failed: {}", job_name, e);
                    }
                }
            })
        });

        match scheduled_job {
            Ok(job) => {
                scheduler.add(job).await
                    .context("Failed to add job to scheduler")?;
                info!("Added cronjob '{}' to scheduler", cronjob.name);
                Ok(())
            }
            Err(e) => {
                error!("Failed to create scheduled job for '{}': {}", cronjob.name, e);
                anyhow::bail!("Failed to create scheduled job: {}", e);
            }
        }
    }

    pub async fn stop(&mut self) -> Result<()> {
        if let Some(mut scheduler) = self.scheduler.take() {
            scheduler.shutdown().await
                .context("Failed to shutdown scheduler")?;
            info!("Cronjob scheduler stopped");
        }
        Ok(())
    }

    /// Get the config file path
    fn get_config_file_path(&self) -> String {
        format!("{}/cronjobs.json", self.config_dir)
    }

    /// Get the modification time of the config file
    fn get_config_modified_time(&self) -> Option<SystemTime> {
        let config_path = self.get_config_file_path();
        fs::metadata(&config_path)
            .ok()
            .and_then(|metadata| metadata.modified().ok())
    }

    /// Check if the config file has been modified since last check
    async fn has_config_changed(&mut self) -> bool {
        let current_modified = self.get_config_modified_time();

        // If we don't have a last modified time, initialize it and return false
        if self.last_config_modified.is_none() {
            self.last_config_modified = current_modified;
            return false;
        }

        // Check if modification time has changed
        match (self.last_config_modified, current_modified) {
            (Some(last), Some(current)) => {
                if current > last {
                    info!("Config file change detected!");
                    self.last_config_modified = Some(current);
                    true
                } else {
                    false
                }
            }
            (Some(_), None) => {
                warn!("Config file was deleted!");
                false
            }
            (None, Some(current)) => {
                info!("Config file appeared!");
                self.last_config_modified = Some(current);
                true
            }
            (None, None) => false,
        }
    }

    /// Reload all jobs from config file and re-schedule them
    async fn reload_jobs(&mut self) -> Result<()> {
        info!("🔄 Reloading cronjob configuration...");

        // Check if scheduler is initialized
        if self.scheduler.is_none() {
            error!("Scheduler not initialized, cannot reload jobs");
            return Err(anyhow::anyhow!("Scheduler not initialized"));
        }

        // 1. Shutdown existing scheduler
        debug!("Shutting down existing scheduler...");
        if let Some(mut scheduler) = self.scheduler.take() {
            let _ = scheduler.shutdown().await;
        }

        // 2. Reload config from file
        {
            let mut manager = self.job_manager.write().await;
            manager.load()
                .context("Failed to reload cronjob configuration")?;
        }

        // 3. Reinitialize and start scheduler with new jobs
        self.initialize().await?;
        self.start().await?;

        let jobs_count = {
            let manager = self.job_manager.read().await;
            manager.list_enabled_jobs().len()
        };

        info!("✅ Configuration reloaded successfully! Active jobs: {}", jobs_count);

        Ok(())
    }

    pub async fn run_forever(&mut self) -> Result<()> {
        self.start().await?;

        // Initialize config modification tracking
        self.last_config_modified = self.get_config_modified_time();

        info!("Cronjob scheduler is running with hot-reload enabled (checking every 30s)");
        info!("Press Ctrl+C to stop.");

        // Keep the scheduler running indefinitely
        loop {
            tokio::time::sleep(tokio::time::Duration::from_secs(30)).await;

            // 1. Check for config file changes and reload if needed
            if self.has_config_changed().await {
                info!("📝 Config file modified, initiating hot-reload...");
                if let Err(e) = self.reload_jobs().await {
                    error!("Failed to reload jobs after config change: {}", e);
                    error!("Scheduler will continue with existing jobs");
                }
            }

            // 2. Health check - ensure scheduler is still running
            if self.scheduler.is_some() {
                debug!("Scheduler health check - running normally");
            } else {
                error!("Scheduler is None, attempting to restart...");
                if let Err(e) = self.initialize().await {
                    error!("Failed to reinitialize scheduler: {}", e);
                }
                if let Err(e) = self.start().await {
                    error!("Failed to restart scheduler: {}", e);
                }
            }
        }
    }

    pub async fn add_new_job(&mut self, cronjob: CronJob) -> Result<()> {
        // Save to configuration
        {
            let mut manager = self.job_manager.write().await;
            manager.add_job(cronjob.clone())?;
        }

        // Add to scheduler if enabled
        if cronjob.enabled {
            if let Some(scheduler) = &self.scheduler {
                self.add_job_to_scheduler(scheduler, &cronjob).await?;
            }
        }

        info!("Added new cronjob: {}", cronjob.name);
        Ok(())
    }

    pub async fn remove_job(&mut self, job_id: &str) -> Result<()> {
        // Remove from configuration
        {
            let mut manager = self.job_manager.write().await;
            manager.remove_job(job_id)?;
        }

        info!("Removed cronjob with ID: {}", job_id);
        Ok(())
    }

    pub async fn get_job_manager(&self) -> Arc<RwLock<CronJobManager>> {
        self.job_manager.clone()
    }

    pub async fn execute_job_now(&self, job_id: &str) -> Result<()> {
        let manager = self.job_manager.read().await;

        if let Some(job) = manager.get_job_by_id(job_id) {
            info!("Executing cronjob '{}' immediately", job.name);

            let result = execute_cronjob(job_id, &self.config_dir, &self.backup_dir).await;

            // Update statistics
            drop(manager);

            let mut manager = self.job_manager.write().await;
            manager.update_job_stats(job_id, result.is_ok())?;

            match result {
                Ok(_) => {
                    info!("Cronjob '{}' executed successfully", job_id);
                    println!("✅ Cronjob '{}' berhasil dieksekusi", job_id);
                }
                Err(e) => {
                    error!("Cronjob '{}' execution failed: {}", job_id, e);
                    println!("❌ Cronjob '{}' gagal: {}", job_id, e);
                }
            }

            Ok(())
        } else {
            anyhow::bail!("Cronjob dengan ID '{}' tidak ditemukan", job_id);
        }
    }
}

async fn execute_cronjob(job_id: &str, config_dir: &str, backup_dir: &str) -> Result<CronjobExecutionResult> {
    use std::process::Command;

    // Load job details and telegram config
    let job = {
        let manager = CronJobManager::new(config_dir);
        // Note: This could be optimized by passing job info instead of reloading
        let mut temp_manager = manager;
        temp_manager.load().ok();
        temp_manager.get_job_by_id(job_id).cloned()
    };

    let job = job.ok_or_else(|| anyhow::anyhow!("Cronjob not found: {}", job_id))?;

    let start_time = std::time::Instant::now();

    // Initialize telegram notifier
    let telegram_notifier = {
        let mut telegram_manager = TelegramManager::new(config_dir);
        if telegram_manager.load().is_ok() && telegram_manager.is_enabled() {
            if let Some(telegram_config) = telegram_manager.get_config() {
                TelegramNotifier::new(&telegram_config).ok()
            } else {
                None
            }
        } else {
            None
        }
    };

    // Send start notification (optional)
    if let Some(ref notifier) = telegram_notifier {
        let _ = notifier.send_cronjob_schedule_notification(
            &job.name,
            &job.schedule_type.get_description(),
            job.next_run.map(|dt| dt.with_timezone(&chrono::Local))
        ).await;
    }

    // Get job details to construct proper command
    let mut cmd = Command::new("backup-service");
    cmd.arg("backup")
        .arg("--config-dir").arg(config_dir)
        .arg("--backup-dir").arg(backup_dir);

    // Execute the command
    let output = tokio::task::spawn_blocking(move || {
        cmd.output()
    }).await
    .context("Failed to spawn backup command")?
    .context("Failed to execute backup command")?;

    let duration = start_time.elapsed();
    let duration_seconds = duration.as_secs();

    if output.status.success() {
        debug!("Backup command executed successfully for job: {}", job_id);

        // Parse output to get backup info
        let stdout_str = String::from_utf8_lossy(&output.stdout);
        let backup_info = parse_backup_output(&stdout_str);

        info!("Cronjob '{}' completed successfully in {}s", job.name, duration_seconds);

        // Send success notification
        if let Some(ref notifier) = telegram_notifier {
            let _ = notifier.send_cronjob_success_notification(
                &job.name,
                &job.schedule_type.get_description(),
                &backup_info.filename,
                &backup_info.size_display(),
                duration_seconds,
                &backup_info.schemas,
            ).await;
        }

        Ok(CronjobExecutionResult {
            success: true,
            backup_info,
            duration_seconds,
            error_message: None,
        })
    } else {
        let error_msg = String::from_utf8_lossy(&output.stderr);
        error!("Cronjob '{}' failed: {}", job.name, error_msg);

        // Send failure notification
        if let Some(ref notifier) = telegram_notifier {
            let _ = notifier.send_cronjob_failure_notification(
                &job.name,
                &job.schedule_type.get_description(),
                &error_msg,
                0, // retry count (could be implemented later)
                None, // next retry time (could be implemented later)
            ).await;
        }

        Ok(CronjobExecutionResult {
            success: false,
            backup_info: CronjobBackupInfo::default(),
            duration_seconds,
            error_message: Some(error_msg.to_string()),
        })
    }
}

#[derive(Debug, Clone)]
pub struct CronjobExecutionResult {
    pub success: bool,
    pub backup_info: CronjobBackupInfo,
    pub duration_seconds: u64,
    pub error_message: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct CronjobBackupInfo {
    pub filename: String,
    pub size_bytes: u64,
    pub schemas: Vec<String>,
}

impl CronjobBackupInfo {
    pub fn size_display(&self) -> String {
        if self.size_bytes == 0 {
            "Unknown".to_string()
        } else if self.size_bytes < 1024 {
            format!("{} B", self.size_bytes)
        } else if self.size_bytes < 1024 * 1024 {
            format!("{:.1} KB", self.size_bytes as f64 / 1024.0)
        } else if self.size_bytes < 1024 * 1024 * 1024 {
            format!("{:.1} MB", self.size_bytes as f64 / (1024.0 * 1024.0))
        } else {
            format!("{:.1} GB", self.size_bytes as f64 / (1024.0 * 1024.0 * 1024.0))
        }
    }
}

fn parse_backup_output(output: &str) -> CronjobBackupInfo {
    let mut backup_info = CronjobBackupInfo::default();

    // Try to extract backup filename from output
    for line in output.lines() {
        if line.contains("Backup created successfully:") {
            if let Some(filename_part) = line.split(':').nth(1) {
                backup_info.filename = filename_part.trim().to_string();
            }
        } else if line.contains("Schemas:") {
            // Parse schemas (simplified)
            if let Some(schemas_part) = line.split(':').nth(1) {
                backup_info.schemas = schemas_part
                    .split(',')
                    .map(|s| s.trim().to_string())
                    .collect();
            }
        }
    }

    // Extract file size if backup_info.filename is set
    if !backup_info.filename.is_empty() {
        if let Ok(metadata) = std::fs::metadata(&backup_info.filename) {
            backup_info.size_bytes = metadata.len();
        }
    }

    backup_info
}

// CLI utility functions
pub async fn list_cronjobs(manager: &CronJobManager) {
    let jobs = manager.list_jobs();

    if jobs.is_empty() {
        println!("\n📅 Tidak ada cronjob yang dikonfigurasi.");
        return;
    }

    println!("\n📅 Daftar Cronjobs:");
    println!("┌─────┬──────────────────────────────────────────────┬────────────────────┬──────────┬─────────┐");
    println!("│ No  │ Nama Job                                    │ Jadwal            │ Status   │ Next Run│");
    println!("├─────┼──────────────────────────────────────────────┼────────────────────┼──────────┼─────────┤");

    for (index, job) in jobs.iter().enumerate() {
        let status = if job.enabled { "Aktif" } else { "Nonaktif" };
        let next_run = job.next_run
            .map(|dt| dt.format("%d %b %H:%M").to_string())
            .unwrap_or_else(|| "-".to_string());

        println!("│ {:<3} │ {:<44} │ {:<16} │ {:<8} │ {:<7} │",
            index + 1,
            truncate_string(&job.name, 44),
            truncate_string(&job.schedule_type.get_description(), 16),
            status,
            next_run
        );
    }

    println!("└─────┴──────────────────────────────────────────────┴────────────────────┴──────────┴─────────┘");

    // Show summary
    manager.get_jobs_summary().display();
}

fn truncate_string(s: &str, max_len: usize) -> String {
    if s.len() <= max_len {
        s.to_string()
    } else {
        format!("{}...", &s[..max_len.saturating_sub(3)])
    }
}