# Guide 03: Ubuntu Server Installation & Custom Partitioning

This guide walks you through installing **Ubuntu Server 24.04 LTS** with custom partitioning, ensuring your Windows OS and gaming disks remain untouched.

---

## 📋 Prerequisites
* Prepared USB drive from [**Guide 01**](01-create-bootable-usb.md).
* Completed Disk Identification Card from [**Guide 02**](02-windows-and-disk-preparation.md).
* Ethernet cable connected to the motherboard LAN port.

---

## Step 1: Boot from the USB on ASUS PRIME Z370-A

1. Insert your bootable USB flash drive into a rear USB port.
2. Turn on the PC and immediately tap **`F8`** repeatedly until the **ASUS Boot Menu** appears.
3. Select the entry starting with **`UEFI: <Your USB Flash Drive Name>`**.
4. In the GRUB menu, choose **"Try or Install Ubuntu Server"** and press **Enter**.

---

## Step 2: Language, Keyboard & Network Configuration

1. **Language & Keyboard**: Select your preferred language and keyboard layout (e.g., *Portuguese* or *English*).
2. **Type of Install**: Choose **"Ubuntu Server"** (standard, default).
3. **Network Connections**:
   * The installer will automatically detect your **Intel I219-V Ethernet** interface (e.g. `eno1` or `eth0`).
   * Verify it receives an IP address via DHCP (e.g., `192.168.1.xxx`).
   * Select **Done**.
4. **Configure Proxy & Ubuntu Archive Mirror**: Leave blank / default and select **Done**.

---

## Step 3: Storage Configuration (CRITICAL STEP)

> [!CAUTION]
> **DO NOT** select *"Use an entire disk"*. That could wipe your Windows drive!  
> You must select **"Custom storage layout"**.

1. Navigate down to **"Custom storage layout"**, press `Space` to select it, and select **Done**.
2. You will see a list of all 4 physical disks (e.g., `/dev/nvme0n1`, `/dev/sda`, `/dev/sdb`, `/dev/sdc`).
3. **Match your drives using your Disk Identification Card from Guide 02**:
   * Locate the 2 Windows/Gaming drives -> **DO NOT TOUCH THEM**.

```
┌────────────────────────────────────────────────────────────────────────┐
│ EXACT CUSTOM STORAGE LAYOUT MAPPING FOR JANUS                          │
├────────────────────────────────────────────────────────────────────────┤
│ /dev/nvme0n1 [WD Blue SN570 1TB NVMe]   ──> DO NOT TOUCH (Windows)     │
│                                                                        │
│ /dev/sdb     [BLUERAY SSD ~224GB]       ──> SERVER FAST POOL (~456 GB) │
│ /dev/sdc     [Samsung 850 EVO ~233GB]   ──> (LVM Volume Group: vg_janus│
│   ├── Partition 1 (on sdb): 1024 MB (FAT32) -> Mount: /boot/efi       │
│   └── Logical Volume (spanning sdb + sdc)   -> Mount: / (Root & Docker)│
│                                                                        │
│ /dev/sda     [SAMSUNG HD103SJ 1TB HDD]  ──> Mount: /data/storage       │
│   └── Single ext4 partition (Full 1TB)  -> (Backups, Media, Archives)  │
└────────────────────────────────────────────────────────────────────────┘
```

### Partitioning Steps:

#### 1. Setup Boot EFI (on BLUERAY SSD):
* Select the **BLUERAY SSD** (or whichever is the first server SSD).
* Add Partition:
  * **Size**: `1G` (or `1024M`)
  * **Format**: `boot/efi` (or `fat32`)
  * **Mount**: `/boot/efi`
* Leave the remaining space on that SSD unformatted for LVM.

#### 2. Pool Both SSDs into LVM (~456 GB):
* On the installer screen, select **"Create Volume Group (LVM)"**:
  * Name: `vg_janus`
  * Select the free space on **BLUERAY SSD** AND the free space on **Samsung 850 EVO**.
* Under `vg_janus`, select **"Create Logical Volume"**:
  * Name: `lv_root`
  * Size: Leave blank (uses all ~456 GB of both combined SSDs).
  * Format: `ext4`
  * Mount: `/` (Root)

#### 3. Format the 1TB HDD (SAMSUNG HD103SJ):
* Select the **SAMSUNG HD103SJ 1TB HDD**:
* Add Partition:
  * Size: Maximum available (~931 GB)
  * Format: `ext4`
  * Mount: `/data/storage`

> [!CAUTION]
> Double check that the **WD Blue SN570 1TB NVMe** has **NO mount points** and **NO changes** scheduled. It holds your Windows OS and games!

### Verification:
* Inspect the summary screen: Confirm that your Windows drive shows **no changes** and has no mount points assigned.
* Select **Done**, then confirm the dialog: **"Continue"**.

---

## Step 4: Profile Configuration & User Setup

1. **Your name**: Your name (e.g., `Daniel`).
2. **Your server's name**: `janus`
3. **Pick a username**: `daniel`.
4. **Choose a password**: Set a strong password (this password will be used for `sudo` commands and SSH).
5. Select **Done**.

---

## Step 5: SSH Setup (MANDATORY)

1. On the **SSH Setup** screen, press `Space` to check **[X] Install OpenSSH server**.
   * *(This allows you to manage the server remotely from your laptop or phone).*
2. Leave *"Import SSH identity"* as None.
3. Select **Done**.

---

## Step 6: Featured Server Snaps & Finish

1. On the **Featured Server Snaps** screen, **do not select anything** (press `Done` immediately). We will install official Docker directly via standard repositories for maximum reliability.
2. The installation will now run (takes ~3 to 5 minutes).
3. When the screen displays **"Install complete!"**, select **"Reboot Now"**.
4. When prompted with *"Please remove the installation medium, then press ENTER"*:
   * Unplug your USB flash drive.
   * Press **Enter**.

---

## Step 7: First Boot Verification

The PC will reboot into the **GRUB Bootloader**:
* It will show **Ubuntu** at the top and **Windows Boot Manager** further down.
* After 3 seconds, it will automatically boot into your new **Ubuntu Server**.
* Log in with your username and password.

Congratulations! Your server operating system is cleanly installed with zero impact on your Windows gaming setup!
