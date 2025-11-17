# Hot-Reload Feature untuk Cronjob Scheduler

## Overview

Cronjob scheduler sekarang mendukung **automatic hot-reload** yang memungkinkan perubahan konfigurasi cronjob diterapkan secara otomatis tanpa perlu restart daemon.

## Cara Kerja

### 1. **File Monitoring**
- Scheduler memonitor file konfigurasi `/etc/backup-service/cronjobs.json` setiap **30 detik**
- Menggunakan `SystemTime` untuk track modification time file
- Tidak memerlukan dependency tambahan (menggunakan `std::fs` dan `std::time`)

### 2. **Change Detection**
```rust
// Check modification time
if config_file.modified_time > last_check_time {
    trigger_reload()
}
```

### 3. **Reload Process**
Ketika perubahan terdeteksi:
1. **Shutdown** scheduler yang sedang berjalan
2. **Reload** konfigurasi dari file
3. **Reinitialize** scheduler baru
4. **Re-schedule** semua jobs yang enabled
5. **Log** hasil reload

## Fitur

### ✅ Deteksi Otomatis
- Perubahan file config otomatis terdeteksi
- Check interval: 30 detik
- Tidak perlu manual trigger

### ✅ Zero Downtime*
- Jobs yang sedang berjalan tidak akan terinterrupt
- Jobs baru akan di-schedule segera setelah reload
- *Catatan: Ada gap kecil (< 1 detik) saat recreate scheduler

### ✅ Error Handling
- Jika reload gagal, scheduler tetap berjalan dengan jobs lama
- Corrupted config akan di-handle oleh auto-recovery
- Semua error di-log untuk debugging

### ✅ Logging Lengkap
```
[INFO] Config file change detected!
[INFO] 🔄 Reloading cronjob configuration...
[DEBUG] Shutting down existing scheduler...
[INFO] Cronjob scheduler initialized
[INFO] Cronjob scheduler started with 3 jobs
[INFO] ✅ Configuration reloaded successfully! Active jobs: 3
```

## Penggunaan

### Scenario 1: Menambah Cronjob Baru
```bash
# 1. Daemon sudah running
sudo systemctl status backup-service
# ● backup-service.service - loaded and running

# 2. Tambah cronjob via CLI
backup-service cronjob add
# Input: Daily backup at 02:00

# 3. TIDAK PERLU RESTART!
# Dalam 30 detik, scheduler akan otomatis reload dan schedule job baru

# 4. Cek log untuk konfirmasi
sudo journalctl -u backup-service -f
# [INFO] Config file change detected!
# [INFO] ✅ Configuration reloaded successfully! Active jobs: 3
```

### Scenario 2: Edit Cronjob Existing
```bash
# 1. Edit schedule cronjob
backup-service cronjob edit
# Ubah dari "Daily 02:00" ke "Daily 03:00"

# 2. Otomatis reload dalam 30 detik
# Job lama akan dihapus, job baru akan di-schedule
```

### Scenario 3: Disable/Enable Cronjob
```bash
# Disable cronjob
backup-service cronjob toggle

# Otomatis reload - job akan dihapus dari scheduler
```

### Scenario 4: Hapus Cronjob
```bash
# Hapus cronjob
backup-service cronjob remove

# Otomatis reload - job akan dihapus dari scheduler
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ run_forever() Loop (every 30s)                      │
├─────────────────────────────────────────────────────┤
│                                                     │
│ 1. Check if config file modified                   │
│    ├─ Get current modification time                │
│    └─ Compare with last known time                 │
│                                                     │
│ 2. If changed:                                      │
│    ├─ Shutdown current scheduler                   │
│    ├─ Reload config from file                      │
│    ├─ Initialize new scheduler                     │
│    └─ Schedule all enabled jobs                    │
│                                                     │
│ 3. Health check                                     │
│    └─ Ensure scheduler is running                  │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## Implementation Details

### File: `src/cronjob/scheduler.rs`

**Struct Fields:**
```rust
pub struct CronScheduler {
    scheduler: Option<JobScheduler>,
    job_manager: Arc<RwLock<CronJobManager>>,
    config_dir: String,
    backup_dir: String,
    last_config_modified: Option<SystemTime>,  // NEW!
}
```

**Key Methods:**
- `get_config_modified_time()` - Get file modification timestamp
- `has_config_changed()` - Check if file changed since last check
- `reload_jobs()` - Reload config and re-schedule all jobs
- `run_forever()` - Main loop with hot-reload integration

## Configuration Protection

Hot-reload bekerja dengan sistem proteksi config yang sudah ada:

### 🔒 Atomic Operations
- Config changes ditulis secara atomic
- Tidak ada partial writes yang bisa corrupt config

### 🔄 Auto-Recovery
- Jika config corrupt, otomatis recovery dari backup
- Reload akan retry dengan backup file

### 📝 Validation
- Config di-validasi sebelum di-apply
- Invalid config akan ditolak, scheduler tetap dengan config lama

### 💾 Backup System
- Setiap perubahan config = backup otomatis dibuat
- 10 backup terakhir disimpan

## Monitoring

### Logs
```bash
# Monitor reload events
sudo journalctl -u backup-service -f | grep -i reload

# Monitor config changes
sudo journalctl -u backup-service -f | grep "Config file"
```

### Metrics
- Reload frequency: Check logs untuk `Config file change detected`
- Reload success rate: Check untuk `✅ Configuration reloaded successfully`
- Reload failures: Check untuk `Failed to reload jobs`

## Troubleshooting

### Issue: Config berubah tapi tidak reload
**Solusi:**
1. Cek apakah daemon running: `sudo systemctl status backup-service`
2. Cek log: `sudo journalctl -u backup-service -f`
3. Tunggu max 30 detik (polling interval)

### Issue: Reload gagal dengan error
**Solusi:**
1. Cek log error: `sudo journalctl -u backup-service | grep ERROR`
2. Config corrupt? Akan auto-recover dari backup
3. Scheduler akan tetap berjalan dengan jobs lama

### Issue: Jobs tidak jalan setelah reload
**Solusi:**
1. Cek apakah jobs enabled: `backup-service cronjob list`
2. Cek schedule expression valid: Lihat log validasi
3. Cek next run time: `backup-service cronjob list` (lihat Next Run)

## Performance Impact

- **CPU**: Minimal (1x file stat call setiap 30 detik)
- **Memory**: Negligible (hanya SystemTime tracking)
- **Disk I/O**: Minimal (1x metadata read setiap 30 detik)
- **Reload time**: < 1 detik (shutdown + reinit + reschedule)

## Future Improvements

1. **Configurable polling interval** - Allow user to set check interval
2. **Incremental reload** - Only update changed jobs (not full recreate)
3. **Reload notification** - Send Telegram notification on reload
4. **Reload history** - Track reload events in database
5. **Manual reload trigger** - Add CLI command to force reload

## Notes

- Hot-reload hanya untuk cronjob config, tidak untuk config lain (database, telegram, dll)
- Jobs yang sedang execute tidak akan di-interrupt saat reload
- Reload adalah graceful shutdown → reinit, bukan hard restart
- Config validation tetap berlaku - invalid config akan ditolak

---

**Version:** 1.0
**Last Updated:** 2025-01-18
**Feature Status:** ✅ Production Ready
