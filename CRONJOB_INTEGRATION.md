# Cronjob Integration Documentation

## 🎯 **Cronjob Integration ke Systemd Service**

Fitur cronjob telah diintegrasikan ke dalam systemd service `backup-service`. Satu service menjalankan kedua fungsi:
- **REST API Server** (port kustom)
- **Background Cronjob Scheduler** (otomatis menjalankan backup jobs)

## 🏗️ **Arsitektur Baru**

### Service Structure
```
backup-service (systemd service)
├── REST API Server
│   ├── GET /health
│   ├── POST /backup
│   └── GET /backup
└── Background Cronjob Scheduler
    ├── Load cronjobs from config
    ├── Execute jobs on schedule
    └── Update statistics
```

### Command Structure
```bash
# CLI Commands (konfigurasi):
./backup-service run           # Interactive CLI + cronjob management menu
./backup-service cronjob       # Direct cronjob configuration

# Systemd Service (REST API + Scheduler):
./backup-service server        # SATU SERVICE untuk API + cronjob
make service-start             # Start systemd service dengan kedua fungsi

# TIDAK ADA LAGI:
./backup-service scheduler     # DIHAPUS - sekarang bagian dari server
```

## 📋 **Cara Penggunaan Production**

### 1. Install Service
```bash
# Install dengan custom port
make install PORT=3724

# Service otomatis dikonfigurasi untuk menjalankan:
# - REST API server di port 3724
# - Background cronjob scheduler
```

### 2. Start Service
```bash
make service-start

# Output akan menunjukkan:
# 🚀 REST API Server started on 0.0.0.0:3724
# ⏰ Cronjob scheduler running in background
# 📡 Available endpoints:
#    GET  /health - Health check
#    POST /backup - Trigger backup
#    GET  /backup - List backups
#
# 💡 Cronjob configuration:
#    CLI: ./backup-service cronjob
#    Or: ./backup-service run → F. Schedule Jobs
```

### 3. Konfigurasi Cronjobs (via CLI)
```bash
# Method 1: Direct cronjob CLI
./backup-service cronjob

# Method 2: Interactive CLI
./backup-service run
# Pilih "F. Schedule Jobs"

# Method 3: Non-interactive (future enhancement)
./backup-service cronjob add --name "Daily Backup" --schedule "daily" --time "02:00"
```

### 4. Monitoring Service
```bash
# Check service status
make service-status

# View logs (akan menunjukkan REST API + cronjob activity)
make service-logs

# Check API health
curl http://localhost:3724/health
```

## 🔄 **Workflow Cronjob Configuration**

### Interactive Setup
```
📅 Cronjob Management
======================

Pilih operasi cronjob:
❯ 📋 List Cronjobs
  ➕ Add New Cronjob
  ✏️  Edit Cronjob
  🗑️  Remove Cronjob
  🔄 Toggle Cronjob Status
  ⚡ Execute Job Now
  📊 View Statistics
  🔙 Back to Main Menu

Pilih jenis jadwal:
❯ Setiap N menit
  Setiap N jam
  Harian pukul waktu tertentu
  Mingguan (hari + waktu)
  Bulanan (tanggal + waktu)
  Custom cron expression

Contoh Setup Harian:
- Nama job: "Daily Production Backup"
- Jadwal: "Harian pukul waktu tertentu"
- Jam: 2
- Menit: 0
- Hasil: Job akan berjalan setiap hari pukul 02:00

✅ Cronjob berhasil dibuat!
⏰ Scheduler akan otomatis menjalankan job ini
```

### Tipe Jadwal yang Didukung

1. **Setiap N menit**
   - Contoh: Setiap 30 menit
   - Cron: `*/30 * * * *`

2. **Setiap N jam**
   - Contoh: Setiap 6 jam
   - Cron: `0 */6 * * *`

3. **Harian pukul**
   - Contoh: Harian pukul 02:00
   - Cron: `0 2 * * *`

4. **Mingguan**
   - Contoh: Mingguan setiap hari Minggu pukul 03:00
   - Cron: `0 3 * * 0`

5. **Bulanan**
   - Contoh: Bulanan setiap tanggal 1 pukul 02:00
   - Cron: `0 2 1 * *`

6. **Custom**
   - Manual cron expression untuk advanced users

## 📁 **File Storage**

### Konfigurasi Cronjobs
- **Location**: `/etc/backup-service/config/cronjobs.json`
- **Format**: JSON dengan metadata lengkap
- **Auto-backup**: Terintegrasi dengan sistem backup yang ada

### Example cronjobs.json
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Daily Production Backup",
    "schedule": "0 2 * * *",
    "schedule_type": {
      "Daily": {"hour": 2, "minute": 0}
    },
    "server_name": null,
    "schemas": null,
    "enabled": true,
    "created_at": "2024-01-15T10:30:00Z",
    "last_run": "2024-01-16T02:00:00Z",
    "next_run": "2024-01-17T02:00:00Z",
    "run_count": 15,
    "success_count": 14,
    "failure_count": 1
  }
]
```

## 🔧 **Service Management**

### Systemd Service Benefits
- **Single Point of Management**: Hanya satu service untuk dikelola
- **Automatic Startup**: Cronjobs otomatis aktif saat boot
- **Integrated Monitoring**: Logs terpusat untuk API dan scheduler
- **Resource Efficiency**: Shared resources antara API dan scheduler

### Service Commands
```bash
# Standard systemd management (tidak berubah)
make service-start      # Start service (API + scheduler)
make service-stop       # Stop service
make service-restart    # Restart service
make service-status     # Check status
make service-logs       # View combined logs
```

## 🚨 **Troubleshooting**

### Common Issues

1. **Service tidak mau start**
   ```bash
   # Check logs
   make service-logs

   # Check configuration
   ./backup-service cronjob
   ```

2. **Cronjobs tidak berjalan**
   ```bash
   # Verify scheduler started
   make service-logs | grep "scheduler"

   # Check cronjob configuration
   ./backup-service cronjob -> List Cronjobs

   # Test manual execution
   ./backup-service cronjob -> Execute Job Now
   ```

3. **API tidak accessible**
   ```bash
   # Check if service is running
   make service-status

   # Test health endpoint
   curl http://localhost:PORT/health
   ```

### Health Check Response
```json
{
  "status": "ok",
  "active_server": "production-db",
  "backup_count": 25,
  "timestamp": "2024-01-16T10:30:00Z"
}
```

## 📊 **Monitoring & Logging**

### Log Sources
- **Systemd Journal**: `sudo journalctl -u backup-service -f`
- **Combined Logs**: REST API + cronjob scheduler activity
- **Structured Logging**: Info, error, dan debug messages

### Monitoring Commands
```bash
# Real-time logs
make service-logs

# Logs with time filter
sudo journalctl -u backup-service --since "1 hour ago"

# Error logs only
sudo journalctl -u backup-service --since "1 hour ago" | grep -i error

# Cronjob specific logs
sudo journalctl -u backup-service | grep "cronjob"
```

### Performance Metrics
- **Job Execution Time**: Tertrack per job
- **Success/Failure Rate**: Statistik otomatis
- **Resource Usage**: Shared dengan REST API
- **Backup Sizes**: Terintegrasi dengan existing backup system

## ✅ **Benefits dari Integration**

### 1. **Simplified Management**
- Hanya satu systemd service untuk dikelola
- Satu set logs untuk semua aktivitas
- Satu monitoring point

### 2. **Automatic Execution**
- Cronjobs otomatis start saat service start
- Tidak perlu manual intervention
- Graceful shutdown dengan service stop

### 3. **Resource Efficiency**
- Shared memory dan resources
- Single process untuk multiple functions
- Reduced system overhead

### 4. **Consistent Configuration**
- Same config directory untuk API dan cronjobs
- Unified backup directory
- Consistent logging format

## 🎯 **Best Practices**

### Production Setup
1. **Install dengan production port**:
   ```bash
   make install PROD_PORT=3724
   make firewall-setup PORT=3724
   ```

2. **Konfigurasi cronjobs sebelum start**:
   ```bash
   # Setup jobs via CLI
   ./backup-service cronjob

   # Then start service
   make service-start
   ```

3. **Monitoring regular**:
   ```bash
   # Check service health
   make service-status

   # Review job execution
   ./backup-service cronjob -> View Statistics
   ```

### Security Considerations
- Cronjob executions use same user as service
- Backup files stored in secure directory
- No additional security exposure
- Same authentication as main service

---

**📌 Summary**: Cronjob scheduler sekarang terintegrasi penuh ke dalam systemd service `backup-service`, menyediakan solusi backup otomatis yang handal dalam single service management.