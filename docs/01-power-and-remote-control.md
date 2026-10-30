# 01. Power & Remote Management

Managing an on-demand server requires a reliable way to turn the machine ON and OFF remotely without risking hardware failure or filesystem corruption.

---

## 1. Turning the PC ON via Smart Outlet

Standard PC power supplies (ATX standard) remain in standby when plugged into power. To boot the machine when a smart outlet turns on, you must configure the motherboard UEFI/BIOS.

### BIOS / UEFI Configuration Steps:
1. Turn on or restart the PC and repeatedly press `DEL` or `F2` to enter the BIOS.
2. Switch to **Advanced Mode** (often `F7`).
3. Locate power management settings. Common names by motherboard vendor:
   * **ASUS**: *Advanced > APM Configuration > Restore AC Power Loss* -> Set to **Power On**.
   * **MSI**: *Settings > Advanced > Power Management Setup > Restore after AC Power Loss* -> Set to **Power On**.
   * **Gigabyte**: *Settings > Platform Power > AC BACK* -> Set to **Always On** (or **Memory / Full-On**).
   * **ASRock**: *Advanced > ACPI Configuration > Restore on AC/Power Loss* -> Set to **Power On**.
4. Save changes and exit (`F10`).

### How It Operates:
* When the smart outlet is toggled **ON**, the motherboard detects the incoming AC current and powers the system on immediately.

---

## 2. ⚠️ The Critical Warning: Turning the PC OFF

> [!CAUTION]
> **NEVER turn off your PC by cutting power with the smart plug while the OS is running.**
> Abrupt power cuts bypass the operating system's disk-cache flushing routines. This causes:
> * Filesystem corruption (NTFS / ext4 / ZFS dirty state).
> * Incomplete container/database writes (SQLite / Postgres corruption).
> * Parity synchronization errors across multi-disk arrays.
> * Head-park stress on traditional mechanical hard drives.

### Safe Two-Step Shutdown Protocol:
1. **Step 1: Graceful Software Shutdown**
   Trigger an OS-level shutdown remotely.
   * **Windows**: Run `shutdown /s /t 0` (via SSH, Home Assistant integration, or a remote shortcut).
   * **Linux**: Run `sudo systemctl poweroff` (or `sudo shutdown -h now`).
2. **Step 2: Cut Standby Power (Optional)**
   Once the fans stop spinning and the PC is in standby mode (~1–2W power draw), you can switch the smart plug to **OFF** if you want zero phantom power drain.

---

## 3. Alternative & Hybrid Remote Power Methods

If relying purely on a smart outlet feels cumbersome for shutdowns, consider these proven alternatives:

### Method A: Wake-on-LAN (WoL)
* **How it works**: The PC stays plugged into wall power in standby (~1–2W). A network "Magic Packet" sent to the motherboard's MAC address triggers boot.
* **Pros**: No smart plug needed; native support in Windows/Linux; can be triggered from phone apps (e.g., *Wake on Lan* for Android/iOS) or router web interfaces.
* **Cons**: Requires a wired Ethernet connection for reliability; cannot turn the PC *off* (only on).

### Method B: PCIe / USB WiFi Remote Power Switch
* **Examples**: Tuya / eWeLink PCIe PC Remote Switch (~$10–$15 on Amazon / AliExpress).
* **How it works**: A small expansion card plugs into a PCIe slot (or USB) and bridges directly to the motherboard front-panel `PWR_SW` pins.
* **Pros**:
  * Mimics pressing the physical power button.
  * Sends a graceful ACPI shutdown signal when toggled off.
  * Can force a hard reset if the machine freezes.
  * Works over WiFi / phone app anywhere in the world.
