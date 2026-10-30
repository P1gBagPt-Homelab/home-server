# 02. Storage & Disk Allocation

A key requirement of this setup is segregating the computer's **4 physical disks**: 2 allocated for daily personal/gaming needs, and 2 dedicated entirely to the home server.

---

## 1. Physical Disk Layout Strategy

```
Total Storage (4 Drives):
├── Drive 1 (SSD/NVMe)  ──>  Host OS / Personal Apps / Game Launchers
├── Drive 2 (SSD/HDD)   ──>  Game Libraries (Steam, Epic, Game Pass)
├── Drive 3 (Server A)  ──>  Server Primary Data / Containers / Media
└── Drive 4 (Server B)  ──>  Server Redundancy / Mirror / Local Backup
```

---

## 2. Redundancy & Drive Configuration for the 2 Server Disks

When configuring the 2 dedicated server drives, choose the topology that matches your capacity vs safety priorities:

### Option A: RAID 1 / Mirrored Volume (High Availability)
* **Usable Capacity**: Size of 1 drive (50% total capacity).
* **Fault Tolerance**: Can survive 1 drive dying without any data loss.
* **Implementations**:
  * **Windows**: *Storage Spaces (Two-way mirror)* or *Disk Management Mirrored Volume*.
  * **Linux / TrueNAS**: *ZFS Mirror (zpool create tank mirror /dev/sdX /dev/sdY)* or *mdadm*.
* **Best for**: Essential documents, family photos, database state, automated backups.

### Option B: JBOD with Automated Snapshot / Sync (Max Capacity)
* **Usable Capacity**: 100% (Sum of both drives).
* **Fault Tolerance**: Drive 3 holds active server data; Drive 4 is a scheduled backup destination (via Rclone, Duplicati, or Robocopy).
* **Best for**: Media streaming libraries (Plex / Jellyfin) where you prefer maximum storage over real-time drive mirroring.

---

## 3. Storage Isolation Guidelines

To ensure your gaming environment does not corrupt or interfere with your server data:

1. **Volume Naming & Mount Points**:
   * Label server volumes clearly (e.g., `SERVER_POOL_DATA`, `SERVER_BACKUP`).
   * On Windows host setups, assign dedicated drive letters (e.g., `S:\` for Server, `B:\` for Server Backup).
2. **Exclusion from Game Launchers**:
   * Explicitly configure Steam, Epic Games, and Windows Defender to exclude the server drive mount paths to prevent unnecessary background disk scans while gaming.
3. **Smart Health Monitoring (S.M.A.R.T.)**:
   * Use **CrystalDiskInfo** (Windows) or **smartmontools** (Linux) to monitor drive temperature and reallocated sectors, especially for disks holding server data.
