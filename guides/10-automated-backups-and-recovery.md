# Guide 10: Automated Backups & Disaster Recovery (Google Drive 5TB)

Never lose your databases, Docmost wiki documentation, or mini-project code. This guide sets up an automated **3-2-1 backup pipeline**: fast daily local snapshots on Server Disk 4, paired with **zero-knowledge encrypted offsite backups** to your **5 TB Google Drive** using **Rclone**.

---

## 1. The Backup Architecture

```
┌────────────────────────────────────────────────────────┐
│                   Active Server Data                   │
│   • PostgreSQL Databases (Docmost & Mini-Projects)     │
│   • Redis State & Docker Volumes (/data/volumes)       │
│   • Coolify Configurations & Project Code              │
└──────────────────────────┬─────────────────────────────┘
                           │ Daily Automated Snapshot Script
                           ▼
┌────────────────────────────────────────────────────────┐
│             Local Backup Pool (Server Disk 4)          │
│                Path: /data/backups/daily/              │
│                 (Retained for 14 Days)                 │
└──────────────────────────┬─────────────────────────────┘
                           │ Rclone Crypt (Client-Side Encryption)
                           ▼
┌────────────────────────────────────────────────────────┐
│             Google Drive (5 TB Storage Pool)           │
│           Remote: janus-backup-encrypted:              │
│        (All files encrypted before leaving server;     │
│        Google only sees scrambled gibberish files)     │
└────────────────────────────────────────────────────────┘
```

---

## 2. Connecting Rclone to Your 5 TB Google Drive

Because your server is headless (no graphical web browser), Rclone uses a quick authorization token generated from your laptop or a web link.

### Step 1: Install Rclone on Ubuntu Server
```bash
sudo apt update && sudo apt install -y rclone
```

### Step 2: Configure Google Drive Remote
Run the configuration wizard on your server:
```bash
rclone config
```
1. Type **`n`** for *New remote*.
2. Name it: **`gdrive`**.
3. Storage type: Type **`drive`** (or find the number corresponding to Google Drive).
4. **Client Id / Client Secret**: Leave blank (press `Enter` to use defaults).
5. **Scope**: Choose **`1`** (*Full access to all files*).
6. **Root folder ID / Service Account**: Leave blank (press `Enter`).
7. **Edit advanced config**: Type **`n`** (No).
8. **Use auto config?**: Type **`n`** (since your server has no desktop browser).
9. Rclone will say:
   `Execute the following on your machine (e.g. your laptop):`
   `rclone authorize "drive"`
   * *On your laptop:* Open Command Prompt or terminal, run `rclone authorize "drive"`, log into your 5 TB Google account in your browser, and click Allow.
   * Paste the resulting authorization token back into your server terminal.
10. Confirm with **`y`** to save the `gdrive` remote.

---

## 3. Adding the Zero-Knowledge Encryption Layer (`rclone crypt`)

To ensure Google cannot inspect your database dumps, personal documentation, or project code, wrap your Google Drive remote in an encrypted layer:

1. In the still-open `rclone config` menu, type **`n`** for *New remote*.
2. Name it: **`janus-backup-encrypted`**.
3. Storage type: Choose **`crypt`**.
4. Remote to encrypt: Enter `gdrive:JanusBackups`
5. Filename encryption: Choose **`standard`** (encrypts all file and folder names).
6. Directory name encryption: Choose **`true`**.
7. Password: Enter a strong master password (and salt).
   > [!IMPORTANT]
   > Save this password in your password manager! It is the master decryption key needed to restore your backups if a disaster occurs.
8. Type **`y`** to save and **`q`** to quit.

---

## 4. The Automated Backup Script

Create the directories on Server Disk 4 and create the script:

```bash
mkdir -p /data/scripts /data/backups/daily /data/backups/temp
nano /data/scripts/backup-janus.sh
```

Paste the following automated backup script:

```bash
#!/bin/bash
# ==============================================================================
# PROJECT JANUS: Automated Backup Script
# Backs up Postgres, Docmost, volumes -> Disk 4 -> Encrypted 5TB Google Drive
# ==============================================================================

set -e

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="/data/backups/daily"
TEMP_DIR="/data/backups/temp/$DATE"
LOCAL_RETENTION_DAYS=14
CLOUD_RETENTION_DAYS=60

echo "[$DATE] Starting Project Janus backup..."

# 1. Create temporary staging directories
mkdir -p "$TEMP_DIR/databases"
mkdir -p "$TEMP_DIR/volumes"

# 2. Dump all PostgreSQL databases (Docmost, mini-projects)
if docker ps --format '{{.Names}}' | grep -q "postgres"; then
    echo "Dumping PostgreSQL databases..."
    docker exec -t postgres pg_dumpall -U admin > "$TEMP_DIR/databases/all_databases.sql"
fi

# 3. Archive critical application volumes & configurations
echo "Archiving application volumes..."
tar -czf "$TEMP_DIR/volumes/docmost_storage.tar.gz" -C /data/volumes docmost 2>/dev/null || true
tar -czf "$TEMP_DIR/volumes/coolify_config.tar.gz" -C /data/coolify . 2>/dev/null || true
tar -czf "$TEMP_DIR/volumes/uptime_kuma.tar.gz" -C /data/volumes uptime-kuma-data 2>/dev/null || true

# 4. Create single compressed archive
ARCHIVE_NAME="janus_backup_$DATE.tar.gz"
echo "Compressing into $ARCHIVE_NAME..."
tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TEMP_DIR" .

# 5. Clean up temporary staging files
rm -rf "$TEMP_DIR"

# 6. Upload encrypted backup to 5TB Google Drive
echo "Uploading encrypted backup to 5TB Google Drive..."
rclone copy "$BACKUP_DIR/$ARCHIVE_NAME" janus-backup-encrypted:daily/ --transfers 4

# 7. Retention Cleanup
echo "Purging local backups older than $LOCAL_RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f -name "janus_backup_*.tar.gz" -mtime +$LOCAL_RETENTION_DAYS -delete

# (With 5TB available, we keep 60 days of history in the cloud)
echo "Purging cloud backups older than $CLOUD_RETENTION_DAYS days..."
rclone delete --min-age ${CLOUD_RETENTION_DAYS}d janus-backup-encrypted:daily/ 2>/dev/null || true

echo "[$DATE] Backup completed successfully!"
```

Make the script executable:
```bash
chmod +x /data/scripts/backup-janus.sh
```

### Test the Backup Manually:
```bash
sudo /data/scripts/backup-janus.sh
```

Verify that the backup reached your Google Drive:
```bash
rclone lsd janus-backup-encrypted:
rclone ls janus-backup-encrypted:daily/
```
*(You will see your clean archive name; on the actual Google Drive web interface, Google only sees encrypted random character strings).*

---

## 5. Schedule Nightly Backups (Cron)

1. Open the root crontab:
   ```bash
   sudo crontab -e
   ```
2. Schedule it to run every night at **03:00 AM**:
   ```cron
   0 3 * * * /data/scripts/backup-janus.sh >> /var/log/janus-backup.log 2>&1
   ```

---

## 6. Disaster Recovery: Restoring in 5 Minutes

If a disk dies or a database is corrupted:

1. **Pull and decrypt the latest backup from Google Drive**:
   ```bash
   mkdir -p /data/backups/restore
   rclone copy janus-backup-encrypted:daily/ /data/backups/restore/
   cd /data/backups/restore/
   tar -xzf $(ls -t janus_backup_*.tar.gz | head -n 1)
   ```

2. **Restore PostgreSQL Databases**:
   ```bash
   cat databases/all_databases.sql | docker exec -i postgres psql -U admin
   ```

3. **Restore Docmost Wiki Pages & Attachments**:
   ```bash
   tar -xzf volumes/docmost_storage.tar.gz -C /data/volumes/
   docker restart docmost
   ```

With **5 Terabytes** of encrypted cloud storage, Project Janus has enterprise-grade disaster resilience!
