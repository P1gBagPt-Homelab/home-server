# Guide 01: Creating the Ubuntu Server 24.04 LTS Bootable USB

This guide walks you through preparing a bootable USB flash drive with **Ubuntu Server 24.04 LTS** from your Windows machine using **Rufus**.

---

## 📋 Prerequisites

* **USB Flash Drive**: Minimum **8 GB** capacity.
  > [!WARNING]
  > All existing files on this USB drive will be permanently erased during the flashing process. Back up any important files first.
* **Computer**: Your current Windows 10/11 system.
* **Estimated Time**: 5 minutes.

---

## Step 1: Download the Official Ubuntu Server ISO

1. Go to the official Ubuntu release page:  
   👉 [Ubuntu Server 24.04 LTS Download](https://ubuntu.com/download/server) (or direct link: [releases.ubuntu.com/24.04/](https://releases.ubuntu.com/24.04/)).
2. Download the **Live Server AMD64** ISO file (filename will look like `ubuntu-24.04.x-live-server-amd64.iso`, ~2.6 GB).

> [!NOTE]
> Make sure to download **Ubuntu Server**, not Ubuntu Desktop. Ubuntu Server comes without heavy desktop environments (GNOME, bloatware), saving CPU cycles and RAM for your Docker containers.

---

## Step 2: Download Rufus

1. Go to the official Rufus website:  
   👉 [https://rufus.ie](https://rufus.ie)
2. Scroll down to the **Download** section and download **Rufus Portable** (e.g. `rufus-x.x.p.exe`).
3. No installation is required; simply double-click the downloaded `.exe` to open it.

---

## Step 3: Configure Rufus for ASUS PRIME Z370-A (UEFI)

Insert your USB flash drive into your computer and launch Rufus. Configure the settings exactly as shown:

```
┌────────────────────────────────────────────────────────┐
│ Rufus Configuration for UEFI Boot                      │
├────────────────────────────────────────────────────────┤
│ Device:           [Select your USB Flash Drive]        │
│ Boot selection:   [SELECT -> choose downloaded .iso]   │
│ Partition scheme: [GPT]  <-- CRITICAL for Z370-A UEFI  │
│ Target system:    [UEFI (non CSM)]                     │
│ Volume label:     [UBUNTU_24_04 (or leave default)]   │
│ File system:      [FAT32 (Default)]                    │
│ Cluster size:     [Default]                            │
└────────────────────────────────────────────────────────┘
```

### Key Setting Details:
1. **Device**: Double-check that the drive letter and size match your USB drive (do not select an external backup drive!).
2. **Boot Selection**: Click **SELECT** and browse to the `ubuntu-24.04.x-live-server-amd64.iso` file you downloaded in Step 1.
3. **Partition Scheme**: Ensure **`GPT`** is selected. (Do not use MBR; your ASUS motherboard uses modern UEFI boot).
4. **Target System**: Will automatically lock to **`UEFI (non CSM)`**.

---

## Step 4: Flash the USB Drive

1. Click the **START** button at the bottom of Rufus.
2. If prompted with a dialog saying *"ISOHybrid image detected: Write in ISO Image mode or DD Image mode"*:
   * Select **Write in ISO Image mode (Recommended)** and click **OK**.
3. If prompted to download additional GRUB/Syslinux binaries:
   * Click **Yes**.
4. A final warning will appear: *"WARNING: ALL DATA ON DEVICE ... WILL BE DESTROYED"*:
   * Double-check the drive name one last time, then click **OK**.
5. Wait 2 to 5 minutes for the progress bar to fill. When it reaches 100% and displays **READY**, click **CLOSE**.

---

## Step 5: Safe Ejection

1. In the Windows taskbar (system tray at the bottom right), click the **Safely Remove Hardware and Eject Media** icon.
2. Select your USB drive.
3. Once Windows says *"Safe to Remove Hardware"*, unplug the USB flash drive.

Your bootable installer drive is now ready to boot your PC into the Ubuntu Server installation environment!
