use crate::config::ServerConfig;
use anyhow::{Result, Context};
use tokio_postgres::{Client, NoTls};
use std::process::Command;
use std::path::Path;
use std::error::Error;

#[derive(Debug)]
pub struct DatabaseConnection {
    client: Client,
}

impl DatabaseConnection {
    pub async fn connect(config: &ServerConfig) -> Result<Self> {
        let connection_string = config.connection_string();
        let (client, connection) = tokio_postgres::connect(&connection_string, NoTls)
            .await
            .with_context(|| format!("Failed to connect to PostgreSQL server at {}:{}", config.host, config.port))?;

        // The connection object needs to be polled to handle database operations
        tokio::spawn(async move {
            if let Err(e) = connection.await {
                log::error!("Database connection error: {}", e);
            }
        });

        Ok(Self { client })
    }

    pub async fn test_connection(config: &ServerConfig) -> Result<String> {
        let connection_string = config.connection_string();

        // Debug: print connection string (without password)
        let safe_connection_string = format!("postgresql://{}:***@{}:{}/{}",
                config.username, config.host, config.port, config.database);
        println!("🔍 DEBUG: Attempting to connect to: {}", safe_connection_string);
        println!("🔍 DEBUG: SSL Mode: {}", config.ssl_mode);
        println!("🔍 DEBUG: Full connection string: {}", connection_string);

        // Try different connection approaches with SSL support
        let attempts = vec![
            ("original", config.connection_string()),
            ("localhost", format!("postgresql://{}:{}@localhost:{}/{}?sslmode={}",
                config.username, config.password, config.port, config.database, config.ssl_mode)),
            ("127.0.0.1", format!("postgresql://{}:{}@127.0.0.1:{}/{}?sslmode={}",
                config.username, config.password, config.port, config.database, config.ssl_mode)),
            ("172.18.0.2", format!("postgresql://{}:{}@172.18.0.2:{}/{}?sslmode={}",
                config.username, config.password, config.port, config.database, config.ssl_mode)),
            ("votin.id", format!("postgresql://{}:{}@votin.id:{}/{}?sslmode={}",
                config.username, config.password, config.port, config.database, config.ssl_mode)),
            ("Unix socket", format!("postgresql://{}:{}@:{}/{}?sslmode={}",
                config.username, config.password, config.port, config.database, config.ssl_mode)),
        ];

        let mut last_error = None;

        for (name, test_connection_string) in attempts {
            println!("🔍 DEBUG: Trying {} connection...", name);
            println!("🔍 DEBUG: Connection string: {}", test_connection_string);

            // For now, always use NoTls since your PostgreSQL server has SSL disabled
            // SSL mode configuration is stored for future use but connections use NoTls
            let connect_result = tokio_postgres::connect(&test_connection_string, NoTls).await;

            match connect_result {
                Ok((client, connection)) => {
                    println!("✅ Connected successfully using {} (sslmode: {})!", name, config.ssl_mode);

                    // Spawn connection handler
                    let connection_handle = tokio::spawn(async move {
                        if let Err(e) = connection.await {
                            log::error!("Database connection error: {}", e);
                        }
                    });

                    // Get server version
                    let row = client.query_one("SELECT version()", &[])
                        .await
                        .context("Failed to query server version")?;

                    let version: String = row.get(0);

                    // Get count of schemas
                    let schemas_row = client.query_one(
                        "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')",
                        &[]
                    )
                        .await
                        .context("Failed to count schemas")?;

                    let schema_count: i64 = schemas_row.get(0);

                    // Abort connection
                    connection_handle.abort();

                    return Ok(format!("PostgreSQL {} - {} schemas (connected via {}, sslmode: {})", version, schema_count, name, config.ssl_mode));
                }
                Err(e) => {
                    println!("❌ {} connection failed: {}", name, e);
                    println!("🔬 DEBUG: Error details for {}:", name);
                    if let Some(source) = e.source() {
                        println!("   Source: {}", source);
                    }
                    println!("   Error type: {}", std::any::type_name::<tokio_postgres::Error>());
                    last_error = Some(e);
                }
            }
        }

        Err(last_error.map(|e| anyhow::anyhow!("Failed to connect to PostgreSQL server using any method: {}", e))
            .unwrap_or_else(|| anyhow::anyhow!("Failed to connect to PostgreSQL server")))
    }

    pub async fn get_schemas(&self) -> Result<Vec<String>> {
        let rows = self.client.query(
            "SELECT schema_name FROM information_schema.schemata
             WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast')
             ORDER BY schema_name",
            &[]
        )
            .await
            .context("Failed to fetch schemas")?;

        let schemas: Vec<String> = rows.iter()
            .map(|row| row.get(0))
            .collect();

        Ok(schemas)
    }

    pub async fn get_schema_tables(&self, schema_name: &str) -> Result<Vec<String>> {
        let rows = self.client.query(
            "SELECT table_name FROM information_schema.tables
             WHERE table_schema = $1 AND table_type = 'BASE TABLE'
             ORDER BY table_name",
            &[&schema_name]
        )
            .await
            .context("Failed to fetch tables for schema")?;

        let tables: Vec<String> = rows.iter()
            .map(|row| row.get(0))
            .collect();

        Ok(tables)
    }

    pub async fn backup_schema(
        config: &ServerConfig,
        schema_name: &str,
        output_file: &str
    ) -> Result<()> {
        let output = Command::new("pg_dump")
            .arg("-h")
            .arg(&config.host)
            .arg("-p")
            .arg(config.port.to_string())
            .arg("-U")
            .arg(&config.username)
            .arg("-d")
            .arg(&config.database)
            .arg("-n")
            .arg(schema_name)
            .arg("--no-owner")
            .arg("--no-privileges")
            .arg("--verbose")
            .arg("-f")
            .arg(output_file)
            .env("PGPASSWORD", &config.password)
            .output()
            .context("Failed to execute pg_dump command")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow::anyhow!(
                "pg_dump failed for schema '{}': {}",
                schema_name,
                stderr
            ));
        }

        log::info!("Successfully backed up schema '{}' to {}", schema_name, output_file);
        Ok(())
    }

    pub async fn backup_schemas(
        config: &ServerConfig,
        schemas: &[String],
        output_file: &str
    ) -> Result<()> {
        let output = Command::new("pg_dump")
            .arg("-h")
            .arg(&config.host)
            .arg("-p")
            .arg(config.port.to_string())
            .arg("-U")
            .arg(&config.username)
            .arg("-d")
            .arg(&config.database)
            .args(schemas.iter().flat_map(|s| ["-n", s]))
            .arg("--no-owner")
            .arg("--no-privileges")
            .arg("--verbose")
            .arg("-f")
            .arg(output_file)
            .env("PGPASSWORD", &config.password)
            .output()
            .context("Failed to execute pg_dump command")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow::anyhow!(
                "pg_dump failed for schemas {:?}: {}",
                schemas,
                stderr
            ));
        }

        log::info!("Successfully backed up schemas {:?} to {}", schemas, output_file);
        Ok(())
    }

    pub async fn restore_backup(
        config: &ServerConfig,
        backup_file: &str
    ) -> Result<()> {
        if !Path::new(backup_file).exists() {
            return Err(anyhow::anyhow!("Backup file '{}' does not exist", backup_file));
        }

        let output = Command::new("psql")
            .arg("-h")
            .arg(&config.host)
            .arg("-p")
            .arg(config.port.to_string())
            .arg("-U")
            .arg(&config.username)
            .arg("-d")
            .arg(&config.database)
            .arg("-v")
            .arg("ON_ERROR_STOP=1")
            .arg("-f")
            .arg(backup_file)
            .env("PGPASSWORD", &config.password)
            .output()
            .context("Failed to execute psql command")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(anyhow::anyhow!(
                "psql restore failed for file '{}': {}",
                backup_file,
                stderr
            ));
        }

        log::info!("Successfully restored backup from {}", backup_file);
        Ok(())
    }

    pub async fn get_server_version(config: &ServerConfig) -> Result<String> {
        let connection_string = config.connection_string();
        let (client, connection) = tokio_postgres::connect(&connection_string, NoTls)
            .await
            .context("Failed to connect to PostgreSQL server")?;

        // Spawn connection handler
        let connection_handle = tokio::spawn(async move {
            if let Err(e) = connection.await {
                log::error!("Database connection error: {}", e);
            }
        });

        let row = client.query_one("SELECT version()", &[])
            .await
            .context("Failed to query server version")?;

        let version: String = row.get(0);

        // Abort connection
        connection_handle.abort();

        Ok(version)
    }
}