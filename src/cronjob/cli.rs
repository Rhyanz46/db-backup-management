use anyhow::{Result, Context};
use inquire::{Text, Select, Confirm, CustomType};
use super::{CronJob, ScheduleType, CronJobManager, list_cronjobs};

pub struct CronJobCli {
    config_dir: String,
}

impl CronJobCli {
    pub fn new(config_dir: &str) -> Self {
        Self {
            config_dir: config_dir.to_string(),
        }
    }

    pub async fn run_interactive_menu(&self) -> Result<()> {
        loop {
            let choices = vec![
                "📋 List Cronjobs",
                "➕ Add New Cronjob",
                "✏️  Edit Cronjob",
                "🗑️  Remove Cronjob",
                "🔄 Toggle Cronjob Status",
                "⚡ Execute Job Now",
                "📊 View Statistics",
                "🔙 Back to Main Menu",
            ];

            let choice = Select::new("Pilih operasi cronjob:", choices)
                .with_page_size(10)
                .with_help_message("Gunakan ↑/↓ untuk navigasi, Enter untuk memilih")
                .prompt()?;

            match choice {
                "📋 List Cronjobs" => {
                    self.list_cronjobs().await?;
                }
                "➕ Add New Cronjob" => {
                    self.add_cronjob_interactive().await?;
                }
                "✏️  Edit Cronjob" => {
                    self.edit_cronjob_interactive().await?;
                }
                "🗑️  Remove Cronjob" => {
                    self.remove_cronjob_interactive().await?;
                }
                "🔄 Toggle Cronjob Status" => {
                    self.toggle_cronjob_interactive().await?;
                }
                "⚡ Execute Job Now" => {
                    self.execute_cronjob_interactive().await?;
                }
                "📊 View Statistics" => {
                    self.view_statistics().await?;
                }
                "🔙 Back to Main Menu" => {
                    break;
                }
                _ => {}
            }
        }

        Ok(())
    }

    async fn list_cronjobs(&self) -> Result<()> {
        let mut manager = CronJobManager::new(&self.config_dir);
        manager.load()?;
        list_cronjobs(&manager);
        Ok(())
    }

    async fn add_cronjob_interactive(&self) -> Result<()> {
        println!("\n➕ Menambah Cronjob Baru");
        println!("================================");

        // Get job name
        let name = Text::new("Masukkan nama cronjob:")
            .with_help_message("Contoh: Daily Backup Production")
            .prompt()?;

        // Get schedule type
        let schedule_types = vec![
            "Setiap N menit",
            "Setiap N jam",
            "Harian pukul waktu tertentu",
            "Mingguan (hari + waktu)",
            "Bulanan (tanggal + waktu)",
            "Custom cron expression",
        ];

        let schedule_choice = Select::new("Pilih jenis jadwal:", schedule_types)
            .with_page_size(8)
            .prompt()?;

        let schedule_type = match schedule_choice {
            "Setiap N menit" => {
                let interval = CustomType::<u32>::new("Interval (menit):")
                    .with_error_message("Masukkan angka yang valid (1-59)")
                                        .prompt()?;
                ScheduleType::Minutes { interval }
            }
            "Setiap N jam" => {
                let interval = CustomType::<u32>::new("Interval (jam):")
                    .with_error_message("Masukkan angka yang valid (1-23)")
                                        .prompt()?;
                ScheduleType::Hours { interval }
            }
            "Harian pukul waktu tertentu" => {
                let hour = CustomType::<u32>::new("Jam (0-23):")
                    .with_error_message("Masukkan jam yang valid (0-23)")
                                        .prompt()?;

                let minute = CustomType::<u32>::new("Menit (0-59):")
                    .with_error_message("Masukkan menit yang valid (0-59)")
                                        .prompt()?;

                ScheduleType::Daily { hour, minute }
            }
            "Mingguan (hari + waktu)" => {
                let days = vec![
                    "Minggu (0)", "Senin (1)", "Selasa (2)", "Rabu (3)",
                    "Kamis (4)", "Jumat (5)", "Sabtu (6)"
                ];

                let day_choice = Select::new("Pilih hari:", days)
                    .prompt()?;

                let day_of_week = day_choice
                    .chars()
                    .last()
                    .unwrap()
                    .to_digit(10)
                    .unwrap() as u32;

                let hour = CustomType::<u32>::new("Jam (0-23):")
                                        .prompt()?;

                let minute = CustomType::<u32>::new("Menit (0-59):")
                                        .prompt()?;

                ScheduleType::Weekly { day_of_week, hour, minute }
            }
            "Bulanan (tanggal + waktu)" => {
                let day_of_month = CustomType::<u32>::new("Tanggal (1-31):")
                    .with_error_message("Masukkan tanggal yang valid (1-31)")
                                        .prompt()?;

                let hour = CustomType::<u32>::new("Jam (0-23):")
                                        .prompt()?;

                let minute = CustomType::<u32>::new("Menit (0-59):")
                                        .prompt()?;

                ScheduleType::Monthly { day_of_month, hour, minute }
            }
            "Custom cron expression" => {
                let cron_expr = Text::new("Masukkan cron expression:")
                    .with_help_message("Format: * * * * * (menit jam hari bulan hari-minggu)")
                    .prompt()?;

                ScheduleType::Custom { cron_expression: cron_expr }
            }
            _ => unreachable!(),
        };

        // Show schedule summary
        println!("\n📅 Jadwal yang dipilih: {}", schedule_type.get_description());
        println!("📝 Cron expression: {}", schedule_type.to_cron_expression());

        let confirm = Confirm::new("Lanjutkan membuat cronjob ini?")
            .prompt()?;

        if !confirm {
            println!("❌ Pembuatan cronjob dibatalkan.");
            return Ok(());
        }

        // Create and save cronjob
        let cronjob = CronJob::new(name, schedule_type, None, None);

        let mut manager = CronJobManager::new(&self.config_dir);
        manager.load()?;
        manager.add_job(cronjob.clone())?;

        // Send notification if Telegram is configured
        self.send_cronjob_schedule_notification(&cronjob).await?;

        println!("\n✅ Cronjob berhasil dibuat!");
        println!("⏰ Scheduler akan otomatis menjalankan job ini sesuai jadwal.");

        Ok(())
    }

    async fn edit_cronjob_interactive(&self) -> Result<()> {
        let mut manager = CronJobManager::new(&self.config_dir);
        manager.load()?;

        let jobs = manager.list_jobs().to_vec();
        if jobs.is_empty() {
            println!("❌ Tidak ada cronjob yang bisa diedit.");
            return Ok(());
        }

        // Select job to edit
        let job_choices: Vec<String> = jobs.iter()
            .map(|job| format!("{} ({})", job.name, if job.enabled { "Aktif" } else { "Nonaktif" }))
            .collect();

        let choice = Select::new("Pilih cronjob yang ingin diedit:", job_choices.clone())
            .prompt()?;

        let selected_index = job_choices.iter().position(|c| *c == choice).unwrap();
        let job = &jobs[selected_index];

        println!("\n📝 Mengedit cronjob: {}", job.name);
        println!("Jadwal saat ini: {}", job.schedule_type.get_description());

        // For simplicity, only allow toggling enable/disable for now
        // Full editing can be implemented later
        let new_status = !job.enabled;

        let confirm = Confirm::new(&format!("Ubah status menjadi '{}'?",
            if new_status { "Aktif" } else { "Nonaktif" }))
            .prompt()?;

        if confirm {
            let mut manager = CronJobManager::new(&self.config_dir);
            manager.load()?;
            manager.toggle_job(&job.id)?;

            println!("✅ Status cronjob berhasil diubah!");
        } else {
            println!("❌ Perubahan dibatalkan.");
        }

        Ok(())
    }

    async fn remove_cronjob_interactive(&self) -> Result<()> {
        let mut manager = CronJobManager::new(&self.config_dir);
        manager.load()?;

        let jobs = manager.list_jobs().to_vec();
        if jobs.is_empty() {
            println!("❌ Tidak ada cronjob yang bisa dihapus.");
            return Ok(());
        }

        // Select job to remove
        let job_choices: Vec<String> = jobs.iter()
            .map(|job| format!("{} ({})", job.name, job.schedule_type.get_description()))
            .collect();

        let choice = Select::new("Pilih cronjob yang ingin dihapus:", job_choices.clone())
            .prompt()?;

        let selected_index = job_choices.iter().position(|c| *c == choice).unwrap();
        let job = &jobs[selected_index];

        println!("\n⚠️  Menghapus cronjob: {}", job.name);
        println!("Jadwal: {}", job.schedule_type.get_description());

        let confirm = Confirm::new("Apakah Anda yakin ingin menghapus cronjob ini?")
            .prompt()?;

        if confirm {
            manager.remove_job(&job.id)?;

            // Send notification if Telegram is configured
            self.send_cronjob_removed_notification(&job).await?;

            println!("✅ Cronjob berhasil dihapus!");
        } else {
            println!("❌ Penghapusan dibatalkan.");
        }

        Ok(())
    }

    async fn toggle_cronjob_interactive(&self) -> Result<()> {
        let mut manager = CronJobManager::new(&self.config_dir);
        manager.load()?;

        let jobs = manager.list_jobs().to_vec();
        if jobs.is_empty() {
            println!("❌ Tidak ada cronjob yang bisa diubah statusnya.");
            return Ok(());
        }

        // Select job to toggle
        let job_choices: Vec<String> = jobs.iter()
            .map(|job| format!("{} - Status: {}", job.name, if job.enabled { "✅ Aktif" } else { "❌ Nonaktif" }))
            .collect();

        let choice = Select::new("Pilih cronjob untuk mengubah status:", job_choices.clone())
            .prompt()?;

        let selected_index = job_choices.iter().position(|c| *c == choice).unwrap();
        let job = &jobs[selected_index];
        let job_id = job.id.clone();

        manager.toggle_job(&job_id)?;

        let new_status = if job.enabled { "Nonaktif" } else { "Aktif" };
        println!("✅ Status cronjob '{}' berhasil diubah menjadi '{}'", job.name, new_status);

        Ok(())
    }

    async fn execute_cronjob_interactive(&self) -> Result<()> {
        let mut manager = CronJobManager::new(&self.config_dir);
        manager.load()?;

        let jobs = manager.list_jobs().to_vec();
        if jobs.is_empty() {
            println!("❌ Tidak ada cronjob yang bisa dieksekusi.");
            return Ok(());
        }

        // Select job to execute
        let job_choices: Vec<String> = jobs.iter()
            .map(|job| format!("{} ({})", job.name, job.schedule_type.get_description()))
            .collect();

        let choice = Select::new("Pilih cronjob untuk dieksekusi sekarang:", job_choices.clone())
            .prompt()?;

        let selected_index = job_choices.iter().position(|c| *c == choice).unwrap();
        let job = &jobs[selected_index];
        let job_id = job.id.clone();

        println!("\n⚡ Mengeksekusi cronjob: {}", job.name);

        // Execute the job
        let result = job.execute(&self.config_dir, "/etc/backup-service/backup");

        // Update statistics
        manager.update_job_stats(&job_id, result.is_ok())?;

        if result.is_ok() {
            println!("✅ Cronjob berhasil dieksekusi!");
        } else {
            println!("❌ Cronjob gagal dieksekusi!");
        }

        Ok(())
    }

    async fn view_statistics(&self) -> Result<()> {
        let mut manager = CronJobManager::new(&self.config_dir);
        manager.load()?;

        let jobs = manager.list_jobs().to_vec();
        if jobs.is_empty() {
            println!("❌ Tidak ada cronjob yang tersedia.");
            return Ok(());
        }

        println!("\n📊 Statistik Cronjobs:");
        println!("================================");

        manager.get_jobs_summary().display();

        println!("\n📈 Detail per Job:");
        println!("┌─────┬──────────────────────────────────┬─────────┬──────────┬──────────┬───────────┐");
        println!("│ No  │ Nama Job                        │ Runs    │ Success  │ Failed   │ Success % │");
        println!("├─────┼──────────────────────────────────┼─────────┼──────────┼──────────┼───────────┤");

        for (index, job) in jobs.iter().enumerate() {
            println!("│ {:<3} │ {:<32} │ {:<7} │ {:<8} │ {:<8} │ {:<9.1}% │",
                index + 1,
                truncate_string(&job.name, 32),
                job.run_count,
                job.success_count,
                job.failure_count,
                job.get_success_rate()
            );
        }

        println!("└─────┴──────────────────────────────────┴─────────┴──────────┴──────────┴───────────┘");

        Ok(())
    }

    async fn send_cronjob_schedule_notification(&self, cronjob: &CronJob) -> Result<()> {
        use crate::config::TelegramManager;
        use crate::notifications::TelegramNotifier;

        // Initialize telegram notifier
        let mut telegram_manager = TelegramManager::new(&self.config_dir);
        if telegram_manager.load().is_ok() && telegram_manager.is_enabled() {
            if let Some(telegram_config) = telegram_manager.get_config() {
                if let Ok(notifier) = TelegramNotifier::new(&telegram_config) {
                    let _ = notifier.send_cronjob_schedule_notification(
                        &cronjob.name,
                        &cronjob.schedule_type.get_description(),
                        cronjob.next_run.map(|dt| dt.with_timezone(&chrono::Local)),
                    ).await;
                }
            }
        }
        Ok(())
    }

    async fn send_cronjob_removed_notification(&self, cronjob: &CronJob) -> Result<()> {
        use crate::config::TelegramManager;
        use crate::notifications::TelegramNotifier;

        // Initialize telegram notifier
        let mut telegram_manager = TelegramManager::new(&self.config_dir);
        if telegram_manager.load().is_ok() && telegram_manager.is_enabled() {
            if let Some(telegram_config) = telegram_manager.get_config() {
                if let Ok(notifier) = TelegramNotifier::new(&telegram_config) {
                    let _ = notifier.send_cronjob_removed_notification(
                        &cronjob.name,
                        &cronjob.schedule_type.get_description(),
                    ).await;
                }
            }
        }
        Ok(())
    }
}

fn truncate_string(s: &str, max_len: usize) -> String {
    if s.len() <= max_len {
        s.to_string()
    } else {
        format!("{}...", &s[..max_len.saturating_sub(3)])
    }
}