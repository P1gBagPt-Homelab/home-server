# 03. Dual-Boot Architecture & OS Isolation Guide

You have chosen a **Dual-Boot setup** for maximum isolation between your gaming environment (Windows) and your server environment (Linux/TrueNAS). 

This guide details how to configure bootloaders, ensure true disk isolation, and switch between operating systems remotely.

---

## 1. Disk & Operating System Layout

```
[Disks 1 & 2: Gaming Environment]
├── Disk 1 (NVMe/SSD): Windows 10/11 OS & Core Software
├── Disk 2 (SSD/HDD): Game Libraries (Steam, Epic, Xbox Game Pass)
└── Filesystems: NTFS

[Disks 3 & 4: Server Environment]
├── Disk 3 (SSD/HDD): Linux Server OS (Ubuntu Server / Debian / TrueNAS SCALE) & Containers
├── Disk 4 (HDD/SSD): Data Storage Pool / Backups (ext4, Btrfs, or ZFS mirror)
└── Filesystems: Linux native (ext4 / btrfs / zfs)
```

### Complete Cross-OS Protection:
1. **Windows cannot read or write Linux filesystems natively**: Windows natively ignores `ext4`, `btrfs`, and `ZFS` partitions. This guarantees that game anti-cheats, Windows game launchers, or rogue processes will never touch or corrupt your server data.
2. **Disable Windows Fast Startup (CRITICAL)**:
   * By default, Windows does not truly shut down; it hibernates the kernel to boot faster (*Fast Startup* / *Hiberboot*).
   * In a dual-boot setup, this leaves disks in a "dirty/locked" state and can cause data corruption if another OS touches the machine.
   * **To disable in Windows**: Run PowerShell as Administrator:
     ```powershell
     powercfg -h off
     ```

---

## 2. Bootloader Configuration for Headless Remote Boot

When you toggle the smart plug ON from outside your home, there is no one at the desk to press keys on the GRUB menu. The system must boot automatically into the **Server OS**.

### Setting the Default OS in GRUB (Linux):
1. On your Linux Server, edit `/etc/default/grub`:
   ```bash
   sudo nano /etc/default/grub
   ```
2. Configure the boot behavior:
   ```ini
   # Set the default boot entry (0 is the first entry: your Linux Server kernel)
   GRUB_DEFAULT=0

   # Set timeout to 3-5 seconds (gives you a moment to choose Windows if you are sitting at the desk)
   GRUB_TIMEOUT=3

   # Disable saving alternative selections
   GRUB_SAVEDEFAULT=false
   ```
3. Clear any sticky boot environment variables:
   ```bash
   sudo grub-set-default 0
   sudo grub-editenv /boot/grub/grubenv unset next_entry
   sudo grub-editenv /boot/grub/grubenv unset saved_entry
   ```
4. Update GRUB:
   ```bash
   sudo update-grub
   ```

*Result:* Every time the smart outlet or WETEN card powers on the PC, it waits 3 seconds and automatically boots into the Linux Server.

> For in-depth troubleshooting and recovery runbooks, see [**Guide 21: GRUB Boot Management & Remote Dual-Boot Runbook**](../guides/21-grub-boot-management-and-troubleshooting.md).

---

## 3. Remote Switching: Booting into Windows from Linux

If you are away or want to switch from Server mode to Gaming mode without entering BIOS:

### Preferred Method (Bulletproof on LVM): UEFI `BootNext` via `efibootmgr`
Because Janus hosts `/` on an LVM pool where GRUB cannot write to disk at boot time to clear volatile flags, using hardware-level UEFI NVRAM is the cleanest and most reliable method:

```bash
# 1. Identify Windows Boot Manager entry number (e.g., Boot0001)
sudo efibootmgr

# 2. Command the motherboard to boot Windows for one session only
sudo efibootmgr --bootnext 0001 && sudo reboot
```

* **Hardware Handled**: The one-shot boot is managed in motherboard NVRAM.
* **Auto-Cleared**: UEFI firmware deletes `BootNext` before launching Windows.
* **Guaranteed Auto-Revert**: Shutting down Windows returns automatically to Ubuntu (`Boot0004`).

### Alternative Method: `grub-reboot`
```bash
sudo grub-reboot "Windows Boot Manager (on /dev/nvme0n1p1)" && sudo reboot
```
> [!WARNING]
> If `/boot/grub` is on an LVM volume, GRUB may be unable to write back to clear `next_entry` at boot time, causing Windows to stay pre-selected on reboot. Use `efibootmgr --bootnext` above to prevent this.

---

## 4. Switching Back from Windows to Linux

When you are done gaming in Windows and want to return to Server mode:
* Simply shut down Windows normally (`Start > Shut down`, or `shutdown /s /t 0`).
* Next time the PC is turned on (manually or via smart plug), the motherboard follows standard `BootOrder` and automatically boots back into the **Linux Server**.
