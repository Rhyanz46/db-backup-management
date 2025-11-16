use std::env;
use tokio_postgres::NoTls;

#[tokio::main]
async fn main() {
    let args: Vec<String> = env::args().collect();

    if args.len() < 6 {
        eprintln!("Usage: {} <host> <port> <database> <username> <password>", args[0]);
        std::process::exit(1);
    }

    let host = &args[1];
    let port: u16 = args[2].parse().expect("Invalid port");
    let database = &args[3];
    let username = &args[4];
    let password = &args[5];

    let connection_string = format!("postgresql://{}:{}@{}:{}/{}",
                                   username, password, host, port, database);

    println!("Testing connection to: postgresql://{}:***@{}:{}/{}",
             username, host, port, database);

    match tokio_postgres::connect(&connection_string, NoTls).await {
        Ok((client, connection)) => {
            println!("✅ Connection successful!");

            // Spawn connection handler
            let connection_handle = tokio::spawn(async move {
                if let Err(e) = connection.await {
                    eprintln!("Database connection error: {}", e);
                }
            });

            // Test a simple query
            match client.query_one("SELECT version()", &[]).await {
                Ok(row) => {
                    let version: String = row.get(0);
                    println!("PostgreSQL version: {}", version);
                }
                Err(e) => {
                    eprintln!("Query failed: {}", e);
                }
            }

            // Abort connection
            connection_handle.abort();
        }
        Err(e) => {
            eprintln!("❌ Connection failed: {}", e);
            eprintln!("Error details: {:?}", e);
        }
    }
}