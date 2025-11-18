pub mod config;
pub mod job;
pub mod scheduler;
pub mod cli;

pub use config::*;
pub use job::*;
pub use scheduler::*;
pub use cli::*;

use anyhow::{Result, Context};
use log::info;
use std::time::SystemTime;

/// Start cronjob scheduler as standalone service (without REST API)
pub async fn start_cronjob_scheduler(config_dir: &str, backup_dir: &str) -> Result<()> {
    info!("🕐 Starting standalone cronjob scheduler...");

    let mut scheduler = CronScheduler::new(config_dir, backup_dir);

    // Initialize scheduler
    scheduler.initialize().await
        .context("Failed to initialize cronjob scheduler")?;

    // Start and run forever
    scheduler.run_forever().await
        .context("Failed to run cronjob scheduler")?;

    // This should never reach
    Ok(())
}