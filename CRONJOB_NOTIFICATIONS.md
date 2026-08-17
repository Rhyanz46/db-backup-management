# Cronjob Telegram Notifications Integration

## 🎯 **Overview**

Cronjob system sekarang sepenuhnya terintegrasi dengan **Telegram notifications**. Semua aktivitas cronjob (success, failure, schedule, removal) akan otomatis mengirim notifikasi ke Telegram group jika sudah dikonfigurasi.

## 🔔 **Notification Types**

### 1. **✅ Success Notifications**
Dikirim saat cronjob berhasil menyelesaikan backup:
```
⏰ Cronjob Executed Successfully

Job Name: Daily Production Backup
Schedule: Harian pukul 02:00
Duration: 2m 15s
Backup File: backup_2024_01_16_02_00_00.sql
Size: 145.2 MB
Schemas: 8
• public
• products
• users
• orders
• inventory
• categories
• reviews
• analytics
• logs

Status: ✅ Completed
Timestamp: 2024-01-16 02:02:15
```

### 2. **🚨 Failure Notifications**
Dikirim saat cronjob gagal mengeksekusi:
```
🚨 Cronjob Execution Failed

Job Name: Daily Production Backup
Schedule: Harian pukul 02:00
Error: `Connection timeout to database server`
Retry Count: 1
Next Retry: 2024-01-16 02:05:00

Status: ❌ Failed
Timestamp: 2024-01-16 02:02:30
```

### 3. **📅 Schedule Notifications**
Dikirim saat cronjob baru dibuat:
```
📅 Cronjob Scheduled

Job Name: Weekly Database Backup
Schedule: Mingguan setiap hari Minggu pukul 03:00
Next Run: 2024-01-21 03:00:00

Status: ⏰ Active
Created: 2024-01-16 10:30:45
```

### 4. **🗑️ Removal Notifications**
Dikirim saat cronjob dihapus:
```
🗑️ Cronjob Removed

Job Name: Old Daily Backup
Schedule: Harian pukul 01:00

Status: ⛔ Removed
Timestamp: 2024-01-16 11:45:20
```

### 5. **📊 Statistics Reports**
Dikirim secara berkala (dapat diimplementasikan):
```
📊 Cronjob Statistics Report

Period: Weekly
Total Jobs: 8
Enabled Jobs: 6
Disabled Jobs: 2

Total Executions: 42
Success Rate: 95.2%

Report Generated: 2024-01-16 12:00:00
```

## 🔧 **Setup Configuration**

### 1. **Configure Telegram**
Pastikan Telegram notifications sudah di-setup:
```bash
# Configure via CLI
./backup-service run → E. Notification Settings

# Atau via direct command
./backup-service telegramconfig
```

### 2. **Enable Notifications**
Notifications akan otomatis aktif jika:
- Telegram bot token sudah dikonfigurasi
- Chat ID sudah disetup
- `notifications/telegram` feature enabled (default: enabled)

### 3. **Cronjob Auto-Notifications**
Tidak ada konfigurasi tambahan yang diperlukan. Semua cronjob akan otomatis:
- ✅ **Success notification** - Setiap kali job berhasil
- 🚨 **Failure notification** - Setiap kali job gagal
- 📅 **Schedule notification** - Saat job dibuat
- 🗑️ **Removal notification** - Saat job dihapus

## 📱 **Notification Features**

### **Rich Information**
- **Job Details**: Nama, jadwal, durasi eksekusi
- **Backup Info**: Filename, size, schemas yang di-backup
- **Status**: Clear success/failure indicators
- **Timestamp**: Waktu lokal yang jelas
- **Error Details**: Informasi error lengkap untuk troubleshooting

### **Error Handling**
- Graceful degradation jika Telegram tidak available
- Logging untuk debugging
- Non-blocking execution (tidak menghambat cronjob execution)

### **Performance Optimized**
- Async notification sending
- Background processing
- Timeout handling
- Error recovery

## 🔍 **Monitoring & Troubleshooting**

### **Check Notification Status**
```bash
# Test Telegram connection
./backup-service test --server your-server-name

# Check service logs
make service-logs

# Filter cronjob logs only
make service-logs | grep -i cronjob
```

### **Common Issues**

#### **Notifications Not Sent**
```bash
# Check Telegram configuration
./backup-service run → E. Notification Settings

# Verify feature is enabled
cargo run --features telegram
```

#### **Duplicate Notifications**
```bash
# Check if multiple instances running
make service-status

# Check logs for duplicate executions
make service-logs | grep "Cronjob"
```

#### **Message Format Issues**
```bash
# Check Telegram bot permissions
# Ensure bot can send messages to chat
# Verify markdown formatting is supported
```

### **Debug Information**
```bash
# Enable debug logging
RUST_LOG=debug ./backup-service server

# Check cronjob execution
./backup-service cronjob → Execute Job Now → Check logs
```

## 📊 **Notification Analytics**

### **Automatic Tracking**
- **Success Rate**: Persentase jobs yang berhasil vs gagal
- **Execution Time**: Durasi rata-rata per job
- **Error Patterns**: Common failure types
- **Schedule Compliance**: Jobs running on expected schedule

### **Logging Integration**
Semua notifikasi terintegrasi dengan system logging:
```bash
# Success notifications
INFO: Cronjob 'Daily Backup' completed successfully in 125s

# Failure notifications
ERROR: Cronjob 'Daily Backup' failed: Connection timeout

# Notification system
INFO: Telegram notification sent successfully
WARN: Telegram notifications disabled - telegram feature not enabled
```

## 🎛️ **Security Considerations**

### **Sensitive Information**
- **Password Protection**: Database passwords tidak ditampilkan
- **Partial Error Details**: Error messages disanitized
- **Minimal Information**: Hanya informasi yang diperlukan

### **Privacy Protection**
- **Anonymized Data**: Tidak mengirim data sensitif
- **Controlled Access**: Hanya ke chat yang diotorisasi
- **Audit Trail**: Semua notifikasi ter-log untuk audit

## 🚀 **Production Best Practices**

### **Monitoring Setup**
```bash
# Monitor cronjob health
make service-status

# Monitor notification delivery
make service-logs | grep "Telegram notification"

# Set up alerts for failed jobs
# (Configure monitoring system to alert on ERROR level logs)
```

### **Notification Management**
```bash
# Enable/disable notifications
./backup-service run → E. Notification Settings

# Test notifications before production
./backup-service cronjob → Execute Job Now
```

### **Troubleshooting Workflow**
1. **Check Service Status**: `make service-status`
2. **Review Logs**: `make service-logs`
3. **Test Connection**: `./backup-service test`
4. **Manual Test**: `./backup-service cronjob → Execute Job Now`
5. **Verify Telegram**: Check group for notifications

## 📝 **Customization Options**

### **Notification Content**
Notifikasi dapat disesuaikan dengan mengedit file `src/notifications/telegram.rs`:
- Message format
- Emoji icons
- Information levels
- Language/Localization

### **Notification Frequency**
- **Success notifications**: Setiap job success
- **Failure notifications**: Setiap job failure
- **Schedule notifications**: Saat job creation/removal
- **Statistics reports**: Configurable (daily/weekly/monthly)

### **Advanced Features**
- **Batch notifications**: Multiple jobs dalam satu message
- **Threshold alerts**: Alert untuk multiple failures
- **Recovery notifications**: Success setelah failure
- **Performance alerts**: Slow execution warnings

---

**📌 Summary**: Cronjob notifications system terintegrasi penuh dengan Telegram, memberikan real-time visibility untuk semua aktivitas backup otomatis. System ini dirancang untuk non-intrusive monitoring dengan detail informasi lengkap untuk troubleshooting cepat.