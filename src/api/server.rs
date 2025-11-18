use axum::{extract::State, http::StatusCode, response::Json, routing::{get, post}, Router};
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};
use tokio::net::TcpListener;
use std::path::PathBuf;
use anyhow::{Result, Context};
use chrono::{Local, Utc};

use crate::config::{ServerManager, TelegramManager};
use crate::database::DatabaseConnection;
use crate::backup::BackupManager;
use crate::cronjob::CronScheduler;

#[derive(Serialize)]
pub struct BackupResponse {
    success: bool,
    message: String,
    backup_filename: Option<String>,
    backup_size: Option<String>,
    schemas: Vec<String>,
    timestamp: String,
}

#[derive(Serialize)]
pub struct HealthResponse {
    status: String,
    active_server: Option<String>,
    backup_count: Option<usize>,
    timestamp: String,
}

#[derive(Clone)]
pub struct AppState {
    pub config_dir: Arc<String>,
    pub backup_dir: Arc<String>,
}

pub async fn start_rest_server(config_dir: &str, backup_dir: &str, port: u16) -> Result<()> {
    // Initialize and start cronjob scheduler in background
    let config_dir_clone = config_dir.to_string();
    let backup_dir_clone = backup_dir.to_string();

    let scheduler_handle = tokio::spawn(async move {
        println!("⏰ Starting cronjob scheduler...");

        let mut scheduler = CronScheduler::new(&config_dir_clone, &backup_dir_clone);
        if let Err(e) = scheduler.initialize().await {
            eprintln!("❌ Failed to initialize cronjob scheduler: {}", e);
            return;
        }

        if let Err(e) = scheduler.start().await {
            eprintln!("❌ Failed to start cronjob scheduler: {}", e);
            return;
        }

        println!("✅ Cronjob scheduler started successfully");

        // Keep scheduler running
        if let Err(e) = scheduler.run_forever().await {
            eprintln!("❌ Cronjob scheduler error: {}", e);
        }
    });

    // Start REST API server
    let app_state = AppState {
        config_dir: Arc::new(config_dir.to_string()),
        backup_dir: Arc::new(backup_dir.to_string()),
    };

    let app = Router::new()
        .route("/", get(health_check))
        .route("/health", get(health_check))
        .route("/backup", post(trigger_backup))
        .route("/backup", get(list_backups))
        .with_state(app_state);

    let addr = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&addr).await?;

    println!("🚀 REST API Server started on {}", listener.local_addr()?);
    println!("⏰ Cronjob scheduler running in background");
    println!("📡 Available endpoints:");
    println!("   GET  /health - Health check");
    println!("   POST /backup - Trigger backup");
    println!("   GET  /backup - List backups");
    println!("");
    println!("💡 Cronjob configuration:");
    println!("   CLI: ./backup-service cronjob");
    println!("   Or: ./backup-service run → F. Schedule Jobs");

    // Run both REST API and monitor scheduler
    tokio::select! {
        result = axum::serve(listener, app) => {
            result.context("Failed to start REST server")?;
        }
        _ = scheduler_handle => {
            eprintln!("⚠️  Cronjob scheduler stopped unexpectedly");
        }
    }

    Ok(())
}

/// Start REST API server WITHOUT cronjob scheduler
pub async fn start_rest_server_only(config_dir: &str, backup_dir: &str, port: u16) -> Result<()> {
    // Start REST API server ONLY
    let app_state = AppState {
        config_dir: Arc::new(config_dir.to_string()),
        backup_dir: Arc::new(backup_dir.to_string()),
    };

    let app = Router::new()
        .route("/", get(health_check))
        .route("/health", get(health_check))
        .route("/backup", post(trigger_backup))
        .route("/backup", get(list_backups))
        .with_state(app_state);

    let addr = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&addr).await?;

    println!("🚀 REST API Server started on {}", listener.local_addr()?);
    println!("⚠️  Cronjob scheduler NOT started (use --start-cronjob for separate service)");
    println!("📡 Available endpoints:");
    println!("   GET  /health - Health check");
    println!("   POST /backup - Trigger backup");
    println!("   GET  /backup - List backups");
    println!("");
    println!("💡 To start cronjob scheduler:");
    println!("   CLI: ./backup-service server --start-cronjob");

    // Run REST API server only
    axum::serve(listener, app)
        .await
        .context("Failed to start REST server")?;

    Ok(())
}

pub async fn health_check(
    State(state): State<AppState>,
) -> Result<Json<HealthResponse>, StatusCode> {
    let mut server_manager = ServerManager::new(&state.config_dir);
    let backup_manager = BackupManager::new(&*state.backup_dir);

    if let Err(_) = server_manager.load() {
        return Ok(Json(HealthResponse {
            status: "error".to_string(),
            active_server: None,
            backup_count: None,
            timestamp: Utc::now().to_rfc3339(),
        }));
    }

    let active_server = server_manager.get_active_server()
        .map(|s| s.display_name());

    let backup_count = backup_manager.list_backups()
        .map(|backups| backups.len())
        .ok();

    Ok(Json(HealthResponse {
        status: "healthy".to_string(),
        active_server,
        backup_count,
        timestamp: Utc::now().to_rfc3339(),
    }))
}

pub async fn trigger_backup(
    State(state): State<AppState>,
) -> Result<Json<BackupResponse>, StatusCode> {
    let mut server_manager = ServerManager::new(&state.config_dir);
    let backup_manager = BackupManager::new(&*state.backup_dir);
    let mut telegram_manager = TelegramManager::new(&state.config_dir);

    // Load configurations
    if let Err(e) = server_manager.load() {
        log::error!("Failed to load server config: {}", e);
        return Ok(Json(BackupResponse {
            success: false,
            message: format!("Configuration error: {}", e),
            backup_filename: None,
            backup_size: None,
            schemas: vec![],
            timestamp: Utc::now().to_rfc3339(),
        }));
    }

    if let Err(e) = telegram_manager.load() {
        log::warn!("Failed to load telegram config: {}", e);
    }

    // Get active server
    let active_server = server_manager.get_active_server()
        .ok_or_else(|| {
            log::error!("No active server configured");
            StatusCode::BAD_REQUEST
        })?;

    log::info!("Starting backup for server: {}", active_server.display_name());

    // Connect to database and get schemas
    let schemas = match DatabaseConnection::connect(active_server).await {
        Ok(connection) => {
            match connection.get_schemas().await {
                Ok(schemas) => schemas,
                Err(e) => {
                    log::error!("Failed to get schemas: {}", e);
                    return Ok(Json(BackupResponse {
                        success: false,
                        message: format!("Failed to get schemas: {}", e),
                        backup_filename: None,
                        backup_size: None,
                        schemas: vec![],
                        timestamp: Utc::now().to_rfc3339(),
                    }));
                }
            }
        }
        Err(e) => {
            log::error!("Failed to connect to database: {}", e);
            return Ok(Json(BackupResponse {
                success: false,
                message: format!("Connection failed: {}", e),
                backup_filename: None,
                backup_size: None,
                schemas: vec![],
                timestamp: Utc::now().to_rfc3339(),
            }));
        }
    };

    if schemas.is_empty() {
        log::warn!("No schemas found to backup");
        return Ok(Json(BackupResponse {
            success: false,
            message: "No schemas found to backup".to_string(),
            backup_filename: None,
            backup_size: None,
            schemas: vec![],
            timestamp: Utc::now().to_rfc3339(),
        }));
    }

    // Ensure backup directory exists
    if let Err(e) = backup_manager.ensure_backup_dir() {
        log::error!("Failed to create backup directory: {}", e);
        return Ok(Json(BackupResponse {
            success: false,
            message: format!("Failed to create backup directory: {}", e),
            backup_filename: None,
            backup_size: None,
            schemas: vec![],
            timestamp: Utc::now().to_rfc3339(),
        }));
    }

    // Generate backup filename
    let timestamp = backup_manager.generate_timestamp_filename();
    let backup_file = backup_manager.get_backup_filepath(&timestamp);

    // Perform backup
    match DatabaseConnection::backup_schemas(active_server, &schemas, backup_file.to_str().unwrap()).await {
        Ok(_) => {
            log::info!("Backup completed successfully: {}", backup_file.display());

            let backup_info = match backup_manager.get_backup_info(&backup_file) {
                Ok(info) => info,
                Err(e) => {
                    log::error!("Failed to get backup info: {}", e);
                    return Ok(Json(BackupResponse {
                        success: true,
                        message: format!("Backup created successfully, but failed to get backup info: {}", e),
                        backup_filename: Some(timestamp.clone()),
                        backup_size: None,
                        schemas: schemas.clone(),
                        timestamp: Utc::now().to_rfc3339(),
                    }));
                }
            };

            // Send notification if configured
            if telegram_manager.is_enabled() {
                if let Ok(notifier) = crate::notifications::TelegramNotifier::new(
                    telegram_manager.get_config().unwrap()
                ) {
                    if let Err(e) = notifier.send_backup_notification(
                        active_server,
                        &schemas,
                        &timestamp,
                        &backup_info.size_display()
                    ).await {
                        log::warn!("Failed to send telegram notification: {}", e);
                    }
                }
            }

            log::info!("Backup process completed successfully");
            Ok(Json(BackupResponse {
                success: true,
                message: "Backup created successfully".to_string(),
                backup_filename: Some(timestamp),
                backup_size: Some(backup_info.size_display()),
                schemas,
                timestamp: Utc::now().to_rfc3339(),
            }))
        }
        Err(e) => {
            log::error!("Backup failed: {}", e);
            Ok(Json(BackupResponse {
                success: false,
                message: format!("Backup failed: {}", e),
                backup_filename: None,
                backup_size: None,
                schemas: vec![],
                timestamp: Utc::now().to_rfc3339(),
            }))
        }
    }
}

pub async fn list_backups(
    State(state): State<AppState>,
) -> Result<Json<Vec<serde_json::Value>>, StatusCode> {
    let backup_manager = BackupManager::new(&*state.backup_dir);

    match backup_manager.list_backups() {
        Ok(backups) => {
            let backup_data: Vec<serde_json::Value> = backups.iter().map(|backup| {
                serde_json::json!({
                    "filename": backup.filename,
                    "size": backup.size_display(),
                    "size_bytes": backup.size_bytes,
                    "created_at": backup.created_at.to_rfc3339(),
                    "schemas": backup.schemas,
                    "server_name": backup.server_name
                })
            }).collect();

            Ok(Json(backup_data))
        }
        Err(e) => {
            log::error!("Failed to list backups: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}