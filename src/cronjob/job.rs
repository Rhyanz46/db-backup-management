use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc, Datelike};
use uuid::Uuid;
use anyhow::Result;
use std::process::Command;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CronJob {
    pub id: String,
    pub name: String,
    pub schedule: String,
    pub schedule_type: ScheduleType,
    pub server_name: Option<String>,
    pub schemas: Option<Vec<String>>,
    pub enabled: bool,
    pub created_at: DateTime<Utc>,
    pub last_run: Option<DateTime<Utc>>,
    pub next_run: Option<DateTime<Utc>>,
    pub run_count: u64,
    pub success_count: u64,
    pub failure_count: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ScheduleType {
    Minutes { interval: u32 },
    Hours { interval: u32 },
    Daily { hour: u32, minute: u32 },
    Weekly { day_of_week: u32, hour: u32, minute: u32 },
    Monthly { day_of_month: u32, hour: u32, minute: u32 },
    Custom { cron_expression: String },
}

impl ScheduleType {
    pub fn to_cron_expression(&self) -> String {
        match self {
            ScheduleType::Minutes { interval } => {
                format!("*/{} * * * *", interval)
            }
            ScheduleType::Hours { interval } => {
                format!("0 */{} * * *", interval)
            }
            ScheduleType::Daily { hour, minute } => {
                format!("{} {} * * *", minute, hour)
            }
            ScheduleType::Weekly { day_of_week, hour, minute } => {
                format!("{} {} * * {}", minute, hour, day_of_week)
            }
            ScheduleType::Monthly { day_of_month, hour, minute } => {
                format!("{} {} {} * *", minute, hour, day_of_month)
            }
            ScheduleType::Custom { cron_expression } => {
                cron_expression.clone()
            }
        }
    }

    pub fn get_description(&self) -> String {
        match self {
            ScheduleType::Minutes { interval } => {
                format!("Setiap {} menit", interval)
            }
            ScheduleType::Hours { interval } => {
                format!("Setiap {} jam", interval)
            }
            ScheduleType::Daily { hour, minute } => {
                format!("Harian pukul {:02}:{:02}", hour, minute)
            }
            ScheduleType::Weekly { day_of_week, hour, minute } => {
                let days = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"];
                format!("Mingguan setiap {} pukul {:02}:{:02}",
                    days.get(*day_of_week as usize).unwrap_or(&"Unknown"), hour, minute)
            }
            ScheduleType::Monthly { day_of_month, hour, minute } => {
                format!("Bulanan setiap tanggal {} pukul {:02}:{:02}", day_of_month, hour, minute)
            }
            ScheduleType::Custom { cron_expression } => {
                format!("Custom: {}", cron_expression)
            }
        }
    }
}

impl CronJob {
    pub fn new(
        name: String,
        schedule_type: ScheduleType,
        server_name: Option<String>,
        schemas: Option<Vec<String>>,
    ) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4().to_string(),
            name,
            schedule: schedule_type.to_cron_expression(),
            schedule_type,
            server_name,
            schemas,
            enabled: true,
            created_at: now,
            last_run: None,
            next_run: None,
            run_count: 0,
            success_count: 0,
            failure_count: 0,
        }
    }

    pub fn execute(&self, config_dir: &str, backup_dir: &str) -> Result<()> {
        // Build the backup command
        let mut cmd = Command::new("backup-service");
        cmd.arg("backup")
            .arg("--config-dir").arg(config_dir)
            .arg("--backup-dir").arg(backup_dir);

        if let Some(server_name) = &self.server_name {
            cmd.args(["--server", server_name]);
        }

        // Execute the command
        let output = cmd.output()?;

        if output.status.success() {
            println!("✅ Backup job '{}' executed successfully", self.name);
            if !output.stdout.is_empty() {
                println!("Output: {}", String::from_utf8_lossy(&output.stdout));
            }
            Ok(())
        } else {
            eprintln!("❌ Backup job '{}' failed", self.name);
            if !output.stderr.is_empty() {
                eprintln!("Error: {}", String::from_utf8_lossy(&output.stderr));
            }
            anyhow::bail!("Backup job execution failed");
        }
    }

    pub fn update_execution_stats(&mut self, success: bool) {
        self.last_run = Some(Utc::now());
        self.run_count += 1;

        if success {
            self.success_count += 1;
        } else {
            self.failure_count += 1;
        }
    }

    pub fn get_success_rate(&self) -> f64 {
        if self.run_count == 0 {
            0.0
        } else {
            (self.success_count as f64 / self.run_count as f64) * 100.0
        }
    }

    pub fn is_due(&self) -> bool {
        if !self.enabled {
            return false;
        }

        if let Some(next_run) = self.next_run {
            Utc::now() >= next_run
        } else {
            true // First run
        }
    }

    pub fn calculate_next_run(&mut self) {
        // This is a simplified calculation
        // In a real implementation, you would use a cron parsing library
        use chrono::Duration;

        let now = Utc::now();
        self.next_run = match &self.schedule_type {
            ScheduleType::Minutes { interval } => {
                Some(now + Duration::minutes(*interval as i64))
            }
            ScheduleType::Hours { interval } => {
                Some(now + Duration::hours(*interval as i64))
            }
            ScheduleType::Daily { hour, minute } => {
                let mut next = now.date_naive().and_hms_opt(*hour as u32, *minute as u32, 0)
                    .unwrap().and_utc();
                if next <= now {
                    next = next + Duration::days(1);
                }
                Some(next)
            }
            ScheduleType::Weekly { day_of_week, hour, minute } => {
                let days_ahead = (*day_of_week as i32 - now.weekday().num_days_from_monday() as i32 + 7) % 7;
                let mut next = (now + Duration::days(days_ahead as i64)).date_naive()
                    .and_hms_opt(*hour as u32, *minute as u32, 0).unwrap().and_utc();
                if next <= now {
                    next = next + Duration::weeks(1);
                }
                Some(next)
            }
            ScheduleType::Monthly { day_of_month, hour, minute } => {
                let mut next_month = now.month() + 1;
                let mut next_year = now.year();
                if next_month > 12 {
                    next_month = 1;
                    next_year += 1;
                }

                if let Some(next) = chrono::NaiveDate::from_ymd_opt(next_year, next_month, *day_of_month as u32)
                    .and_then(|date| date.and_hms_opt(*hour as u32, *minute as u32, 0))
                    .map(|datetime| datetime.and_utc()) {
                    Some(next)
                } else {
                    // Fallback to next month if invalid date (e.g., February 30)
                    Some(now + Duration::days(30))
                }
            }
            ScheduleType::Custom { cron_expression } => {
                // For custom cron expressions, we would need a proper cron parser
                // For now, default to 1 hour from now
                Some(now + Duration::hours(1))
            }
        };
    }
}