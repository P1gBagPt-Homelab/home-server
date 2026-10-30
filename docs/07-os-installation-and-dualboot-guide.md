# 07. Ubuntu Server 24.04 LTS Installation & Dual-Boot Guide

This step-by-step walkthrough covers installing **Ubuntu Server 24.04 LTS** onto your dedicated server drives while ensuring your existing Windows installation and games remain **100% protected and untouched**.

---

## 1. Pre-Installation Preparation

### Step 1: Disable Windows Fast Startup (Crucial!)
Boot into Windows, open **PowerShell as Administrator**, and run:
```powershell
powercfg -h off
```
*Why: If Fast Startup is left on, Windows puts the drives in a hibernated/locked state, which can cause disk errors when multi-booting.*

### Step 2: Note Your Drive Sizes and Models in Windows
Open **Disk Management** in Windows (`Win + X > Disk Management`):
* Note the brand and capacity of your **Windows OS and Gaming drives** (e.g. *Samsung 970 EVO 1TB*, *Crucial MX500 1TB*).
* Note the brand and capacity of the **2 drives dedicated to the server** (e.g. *WD Blue 2TB*, *Seagate 2TB*).
* *Knowing the exact model names ensures you never pick the wrong drive during installation.*

### Step 3: Flash Ubuntu Server to a USB Drive
1. Download the [Ubuntu Server 24.04 LTS ISO](https://ubuntu.com/download/server).
2. Download **Rufus** (or **BalenaEtcher**).
3. Insert an 8GB+ USB flash drive and flash the ISO (use default GPT / UEFI settings).

---

## 2. Booting the Installer on ASUS PRIME Z370-A

1. Plug the USB flash drive and your Ethernet cable into the PC.
2. Turn on the PC and tap `F8` repeatedly to open the **ASUS Boot Menu**.
3. Select **`UEFI: <Your USB Drive Name>`**.
4. Choose **"Try or Install Ubuntu Server"**.

---

## 3. Safe Partitioning: Protecting Windows Drives

During the installer steps (Language, Keyboard, Network), proceed with standard defaults until you reach the **Storage configuration** screen.

> [!CAUTION]
> **DO NOT** select "Use an entire disk" without carefully verifying the target disk name.  
> Select **"Custom storage layout"** to explicitly choose your dedicated server drives.

### Storage Configuration Walkthrough:

```
Available Disks:
├── nvme0n1 / sda (Windows NVMe/SSD)   ──> DO NOT TOUCH / DO NOT FORMAT
├── sdb (Game Library SSD/HDD)         ──> DO NOT TOUCH / DO NOT FORMAT
├── sdc (Server Disk 3 - Primary OS)   ──> SELECT FOR UBUNTU SERVER
└── sdd (Server Disk 4 - Storage/Data) ──> SELECT FOR /data MOUNT
```

1. **Locate Server Disk 3 (Primary Server Drive)**:
   * Select the disk by its model name and capacity.
   * Add a GPT partition table if it is blank.
   * Add Partition:
     * **Size**: 1 GB (or 1024M)
     * **Format**: `fat32`
     * **Mount**: `/boot/efi` *(Dedicated EFI partition so Ubuntu's bootloader never touches the Windows bootloader partition)*.
   * Add Partition (Remaining Space):
     * **Size**: Maximum available
     * **Format**: `ext4`
     * **Mount**: `/` (Root filesystem)
2. **Locate Server Disk 4 (Data / Project Storage)**:
   * Select the second server disk.
   * Add Partition:
     * **Size**: Maximum available
     * **Format**: `ext4`
     * **Mount**: `/data`
3. Review the summary: Verify that your Windows drive letters/models are listed with **NO actions** scheduled against them.
4. Select **"Continue"** to begin installation.

---

## 4. Post-Install: NVIDIA Drivers & Docker Setup

Once the installer finishes, remove the USB drive and reboot. The PC will boot into Ubuntu Server.

Log in using the username and password you configured during setup, then run:

### 1. Update the System
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install NVIDIA Proprietary Drivers (For RTX 2070 & AI)
Ubuntu's driver utility will detect the RTX 2070 and install the verified proprietary driver:
```bash
sudo ubuntu-drivers install
sudo reboot
```
After rebooting, verify that the GPU is recognized:
```bash
nvidia-smi
```
*(You will see the RTX 2070 details, VRAM status, and CUDA version).*

### 3. Install Official Docker Engine & Docker Compose
```bash
# Add Docker's official GPG key:
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker:
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow running docker without sudo:
sudo usermod -aG docker $USER
```

### 4. Verify Dual-Boot GRUB Detection of Windows
Run:
```bash
sudo os-prober
```
*(Output will confirm `Windows Boot Manager found on /dev/...`)*.

Update GRUB to finalize the boot menu:
```bash
sudo update-grub
```
Your server is now fully configured and ready for the WETEN remote power switch and WireGuard container!
