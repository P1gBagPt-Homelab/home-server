# Guide 10: Automated Backups & Disaster Recovery

Never lose your databases, Docmost wiki documentation, or mini-project code. This guide sets up an automated **3-2-1 backup pipeline**: fast daily local snapshots on Server Disk 4, paired with **zero-knowledge encrypted offsite backups** to the cloud using **Rclone**.

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
│            Encrypted Offsite Cloud Storage             │
│        (Google Drive / Backblaze B2 / OneDrive)        │
│          Cloud provider only sees scrambled data       │
└────────────────────────────────────────────────────────┘
```

---

## 2. Setting Up Rclone with Free Cloud Storage

`rclone` is the universal swiss-army knife of cloud storage. It natively supports **client-side encryption** (`rclone crypt`), ensuring your cloud provider can never read your files or databases.

### Step 1: Install Rclone
```bash
sudo apt update && sudo apt install -y rclone
```

### Step 2: Configure Your Cloud Destination
Run the interactive setup wizard:
```bash
rclone config
```
1. Type **`n`** for *New remote*.
2. Name it: `remote-cloud`.
3. Choose your storage provider:
   * **Google Drive** (Option `drive` – 15 GB free).
   * **Backblaze B2** (Option `b2` – 10 GB free S3-compatible storage).
   * **OneDrive / Dropbox**.
4. Follow the terminal prompts to authenticate via your web browser.

### Step 3: Add Client-Side Encryption Layer
In the same `rclone config` menu:
1. Type **`n`** for *New remote*.
2. Name it: `janus-backup-encrypted`.
3. Storage type: Choose **`crypt`**.
4. Remote to encrypt: Enter `remote-cloud:janus-backups`.
5. Enter a strong encryption password (and salt).
   > [!IMPORTANT]
   > Write down this encryption password! It is the only key capable of decrypting your backups in a disaster recovery scenario.

---

## 3. The Automated Backup Script

Create the scripts and backup directories on Disk 4:

```bash
mkdir -p /data/scripts /data/backups/daily /data/backups/temp
nano /data/scripts/backup-janus.sh
```

Paste the following automated backup script:

```bash
#!/bin/bash
# ==============================================================================
# PROJECT JANUS: Automated Backup Script
# Dumps PostgreSQL, archives Docmost & volumes, encrypts, and syncs offsite
# ==============================================================================

set -e

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="/data/backups/daily"
TEMP_DIR="/data/backups/temp/$DATE"
RETENTION_DAYS=14

echo "[$DATE] Starting Project Janus backup..."

# 1. Create temporary staging directory
mkdir -p "$TEMP_DIR/databases"
mkdir -p "$TEMP_DIR/volumes"

# 2. Dump all PostgreSQL databases (Docmost, mini-projects)
if docker ps --format '{{.Names}}' | grep -q "postgres"; then
    echo "Dumping PostgreSQL databases..."
    docker exec -t postgres pg_dumpall -U admin > "$TEMP_DIR/databases/all_databases.sql"
fi

# 3. Archive critical application volumes (Docmost wiki pages, Coolify configs)
echo "Archiving application volumes..."
tar -czf "$TEMP_DIR/volumes/docmost_storage.tar.gz" -C /data/volumes docmost 2>/dev/null || true
tar -czf "$TEMP_DIR/volumes/coolify_config.tar.gz" -C /data/coolify . 2>/dev/null || true
tar -czf "$TEMP_DIR/volumes/uptime_kuma.tar.gz" -C /data/volumes uptime-kuma-data 2>/dev/null || true

# 4. Create single compressed tarball for today's backup
ARCHIVE_NAME="janus_backup_$DATE.tar.gz"
echo "Compressing into $ARCHIVE_NAME..."
tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TEMP_DIR" .

# 5. Clean up temporary staging files
rm -rf "$TEMP_DIR"

# 6. Upload encrypted backup to offsite cloud
echo "Syncing encrypted backup to cloud..."
rclone copy "$BACKUP_DIR/$ARCHIVE_NAME" janus-backup-encrypted: --transfers 4

# 7. Purge local backups older than 14 days
echo "Cleaning up local backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f -name "janus_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

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
Check the backup folder:
```bash
ls -lh /data/backups/daily/
```

---

## 4. Automating with Systemd Timer (or Cron)

Set the backup to run automatically every night at **03:00 AM** (or whenever the machine is booted):

1. Open root crontab:
   ```bash
   sudo crontab -e
   ```
2. Add this line at the bottom:
   ```cron
   0 3 * * * /data/scripts/backup-janus.sh >> /var/log/janus-backup.log 2>&1
   ```
3. Save and exit.

---

## 5. Disaster Recovery: Restoring in 5 Minutes

If a drive fails or a database is accidentally dropped:

### 1. Download & Decrypt the Latest Cloud Backup:
```bash
rclone copy janus-backup-encrypted: /data/backups/restore/
cd /data/backups/restore/
tar -xzf janus_backup_<date>.tar.gz
```

### 2. Restore PostgreSQL Databases:
```bash
cat databases/all_databases.sql | docker exec -i postgres psql -U admin
```

### 3. Restore Docmost Wiki Files:
```bash
tar -xzf volumes/docmost_storage.tar.gz -C /data/volumes/
docker restart docmost
```

Every project, wiki document, database row, and configuration is restored exactly as it was. Project Janus is now disaster-proof!
