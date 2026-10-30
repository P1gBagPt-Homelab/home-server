# Guide 02: Windows & Disk Preparation (Safety Checks)

Before plugging in the installation USB or formatting any drives, complete these safety preparations inside Windows. This guarantees that your Windows operating system and games remain **100% untouched and safe**.

---

## Step 1: Disable Windows Fast Startup (Mandatory)

By default, Windows does not completely shut down when you select *"Shut down"*; it puts the kernel and storage into a hybrid hibernation state (*Fast Startup* / *Hiberboot*). In a dual-boot machine, this causes:
* Locked NTFS filesystems.
* Potential partition table corruption if another OS boots.
* Failed UEFI handoffs.

### How to Disable It:
1. Press the **Windows Key**, type **PowerShell**, right-click it, and select **Run as Administrator**.
2. Run this single command:
   ```powershell
   powercfg -h off
   ```
3. Press **Enter**. (No output means it succeeded). Fast Startup and Hibernation are now completely disabled.

---

## Step 2: Identify and Document Your 4 Physical Disks

You must know the exact model names and capacities of your drives so you can easily identify them during the Ubuntu installation.

### Run This PowerShell Command:
In the same Administrator PowerShell window, run:
```powershell
Get-PhysicalDisk | Select-Object DeviceId, FriendlyName, MediaType, @{Name="Size (GB)";Expression={[math]::round($_.Size/1GB, 2)}} | Format-Table -AutoSize
```

### Fill Out Your Disk Identification Card:
Use the output from PowerShell or Windows **Disk Management** (`Win + X > Disk Management`) to note your 4 disks:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PHYSICAL DISK RECORD                            │
├─────────┬──────────────────────┬───────────┬───────────────────────────┤
│ DISK ID │ MODEL / FRIENDLY NAME│ SIZE (GB) │ ASSIGNED ROLE             │
├─────────┼──────────────────────┼───────────┼───────────────────────────┤
│ Disk 0  │ [e.g. Samsung 970]   │ [e.g. 500]│ Windows 10/11 OS (DO NOT TOUCH)
│ Disk 1  │ [e.g. Crucial MX500] │ [e.g. 1000│ Game Library     (DO NOT TOUCH)
│ Disk 2  │ [e.g. WD Blue 2TB]   │ [e.g. 2000│ Server OS (Disk 3) [FORMAT EXT4]
│ Disk 3  │ [e.g. Seagate 2TB]   │ [e.g. 2000│ Server Data (Disk 4) [FORMAT EXT4]
└─────────┴──────────────────────┴───────────┴───────────────────────────┘
```

> [!TIP]
> Take a photo of this table or write it on a piece of paper. When the Ubuntu installer asks where to install, you will match the drive by its exact model name and capacity.

---

## Step 3: Check ASUS PRIME Z370-A BIOS Settings

Before booting into the Ubuntu installer, verify two critical UEFI settings:

1. Restart your PC and press `DEL` or `F2` to enter the ASUS UEFI BIOS.
2. Press `F7` to switch to **Advanced Mode**.
3. **Standby Power for PCIe Switch Card**:
   * Navigate to: **Advanced > APM Configuration > ErP Ready**.
   * Set **ErP Ready** to **Disabled**.
   * *(Ensures the WETEN PCIe switch card receives 3.3V power when the computer is turned off).*
4. **SATA Operation Mode**:
   * Navigate to: **Advanced > SATA Configuration > SATA Mode Selection**.
   * Verify it is set to **AHCI** (do NOT use RAID mode).
5. **Secure Boot Check**:
   * Navigate to: **Boot > Secure Boot > OS Type**.
   * Ubuntu 24.04 LTS natively supports Secure Boot, but setting OS Type to **Other OS** (or keeping Standard) works reliably with NVIDIA proprietary drivers.
6. Press `F10` to save changes and exit.

Your system and disks are now fully prepped for the Ubuntu Server installation!
