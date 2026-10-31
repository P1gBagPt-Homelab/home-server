# 02. Storage & Disk Allocation (Exact Hardware Mapping)

This document maps the **4 physical drives** of your machine to their designated roles, detailing how the two 250GB SSDs are joined into a single unified high-speed volume using **LVM (Logical Volume Manager)**.

---

## 1. Physical Hardware Inventory

Based on your system hardware inspection:

```
┌────────┬──────────────────────────┬──────────┬───────────┬────────────────────────────────────────┐
│ DEV ID │ PHYSICAL MODEL           │ TYPE     │ SIZE      │ ASSIGNED ROLE                          │
├────────┼──────────────────────────┼──────────┼───────────┼────────────────────────────────────────┤
│ Disk 3 │ WD Blue SN570 1TB NVMe   │ NVMe SSD │ 931.51 GB │ Windows 10/11 Gaming OS (UNTOUCHED)    │
│ Disk 0 │ BLUERAY SSD              │ SATA SSD │ 223.57 GB │ Pooled Server Fast Storage (~456 GB)   │
│ Disk 1 │ Samsung SSD 850 EVO      │ SATA SSD │ 232.89 GB │ (Ubuntu Server OS, Coolify, Docker, DB)│
│ Disk 2 │ SAMSUNG HD103SJ 1TB      │ SATA HDD │ 931.51 GB │ Server Storage, Local Backups, Media   │
└────────┴──────────────────────────┴──────────┴───────────┴────────────────────────────────────────┘
```

---

## 2. Joining the 2 SSDs with LVM (Linear Concatenation)

Instead of managing two separate small drives (224GB and 233GB), **LVM (Logical Volume Manager)** pools both physical disks into a single continuous volume group (`vg_janus`) with **~456 GB of usable SSD space**.

```
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│       BLUERAY SSD (223.57 GB)   │       │   Samsung 850 EVO (232.89 GB)   │
│       Physical Volume (/dev/sdb)│       │   Physical Volume (/dev/sdc)    │
└────────────────┬────────────────┘       └────────────────┬────────────────┘
                 │                                         │
                 └────────────────────┬────────────────────┘
                                      ▼
             ┌──────────────────────────────────────────────────┐
             │            Volume Group: vg_janus                │
             │           Total Capacity: ~456.46 GB             │
             └────────────────────────┬─────────────────────────┘
                                      ▼
             ┌──────────────────────────────────────────────────┐
             │       Logical Volume: lv_root (Mount: /)         │
             │     Single unified ~456 GB ext4 filesystem       │
             │     Hosts Ubuntu OS, Coolify, Docker & Databases │
             └──────────────────────────────────────────────────┘
```

### Advantages of This Setup:
1. **Zero Space Waste:** You get 100% of the combined capacity without worrying which container or project goes to which SSD.
2. **Native Performance:** Both drives deliver full SATA-III SSD speeds (~500 MB/s).
3. **Disaster Protection:** Because this volume pools two drives without parity, our **Guide 10 automated backup pipeline** guarantees safety by taking daily local snapshots on the **1TB HDD** and syncing them encrypted to your **5 TB Google Drive**.

---

## 3. The 1TB HDD Role: Bulk Storage & Local Backups

The **SAMSUNG HD103SJ 1TB HDD** is mounted at **`/data/storage`**:
* **`/data/storage/backups/`**: Stores rolling 14-day snapshots of PostgreSQL databases, Docmost wiki pages, and Coolify configs.
* **`/data/storage/media/`**: Mass storage for large video files, project datasets, and archives.
* **Isolation**: If the SSD pool is ever wiped or reinstalled, the 1TB HDD data remains completely independent and safe.
