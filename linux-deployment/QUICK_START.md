# PostgreSQL Backup Management System - Linux Quick Start

## 🚀 Super Quick Start (5 Commands)

```bash
# 1. Download and deploy
git clone <repository-url>
cd backup-service
sudo ./linux-deployment/deploy.sh

# 2. Configure your database (edit server config)
sudo nano /opt/backup-service/config/servers.json

# 3. Start interactive CLI to set active server
sudo /opt/backup-service/bin/backup-service run

# 4. Test backup
sudo /opt/backup-service/bin/backup-service backup

# 5. Done! Check backups:
sudo /opt/backup-service/bin/backup-service list
```

## 📡 REST API is Running

- **Health Check**: http://localhost:8080/health
- **Trigger Backup**: `curl -X POST http://localhost:8080/backup`
- **List Backups**: `curl http://localhost:8080/backup`

## 🔧 Service Management

```bash
sudo systemctl start backup-service      # Start
sudo systemctl stop backup-service       # Stop
sudo systemctl restart backup-service    # Restart
sudo systemctl status backup-service     # Check status
sudo journalctl -u backup-service -f     # View logs
```

## ⚙️ Configuration Files

- **Servers**: `/opt/backup-service/config/servers.json`
- **Telegram**: `/opt/backup-service/config/telegram.json`
- **Backups**: `/opt/backup-service/backup/`

## 🎯 Need Help?

- **CLI Help**: `sudo /opt/backup-service/bin/backup-service --help`
- **Full Documentation**: `linux-deployment/docs/LINUX_DEPLOYMENT.md`
- **Issues**: Check logs with `sudo journalctl -u backup-service -f`

---

**🎉 Your PostgreSQL backup system is ready!**