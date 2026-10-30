# 06. Shopping & Hardware Checklist

This guide outlines the exact hardware needed to complete the hybrid gaming and on-demand server setup, distinguishing between network cards and IoT power switches.

---

## 1. Network Card vs. Smart Power Switch (Crucial Distinction)

* **Your current card (TP-Link Archer T4E AC1200)**:
  * A standard PCIe WiFi **network interface card (NIC)**.
  * Provides internet connectivity to the OS while the computer is turned on.
  * **Cannot** turn the PC on, pulse motherboard pins, or initiate ACPI shutdowns when the computer is off.
* **The device to purchase (PCIe Smart PC Remote Switch)**:
  * An **IoT relay switch** on a PCIe bracket.
  * Stays connected to your home 2.4 GHz WiFi even while the PC is powered down (using 3.3V standby).
  * Physically connects to the motherboard `PWR_SW` and `RST_SW` headers using 2-pin jumper cables.
  * Operates via the **Tuya / Smart Life** or **eWeLink** smartphone app.

---

## 2. What to Buy

### Primary Item: Tuya / eWeLink PCIe PC Remote Power Switch
* **Keywords to search** (Amazon.es, AliExpress, etc.):
  * `Tuya PCIe PC remote power switch`
  * `eWeLink smart computer switch PCIe`
  * `Interruptor arranque PC WiFi Tuya`
* **Price Range**: ~€10 – €18.
* **What must come in the box**:
  1. The PCIe card (fits in any PCIe x1, x4, or x16 slot).
  2. Motherboard 2-pin Y-splitter cables (allows both the PCIe card and your physical PC case button to trigger power).
  3. PCIe slot mounting screw / low-profile or standard bracket.

---

## 3. Pre-Build Inventory Checklist

Before setting up the server, inspect your PC and desk setup for the following items:

| Hardware Item | Required? | Notes |
| :--- | :---: | :--- |
| **PCIe Smart PC Switch Card** | **YES (Buy)** | ~€12–€15 on Amazon.es / AliExpress. |
| **TP-Link Archer T4E** | Keep | Keep in a separate PCIe x1 slot for Windows WiFi if not wired. |
| **Cat 6 Ethernet Cable** | Highly Recommended | Plug motherboard Intel LAN directly into router for server & WireGuard stability. |
| **2x SATA Data Cables** | Yes | To connect the 2 server disks to the ASUS Z370-A SATA 6Gb/s ports. |
| **SATA Power Cables** | Yes | Ensure your PSU has 2 free SATA power leads. |
| **2x Dedicated Server Disks** | Yes | The 2 physical drives dedicated to Linux Server (ext4/ZFS). |
| **USB Flash Drive (8GB+)** | Yes | For creating the Linux Server installation media (Ubuntu Server / Debian). |

---

## 4. Slot Arrangement on ASUS PRIME Z370-A

To ensure optimal cooling for the ASUS ROG Strix RTX 2070:

1. **`PCIEX16_1`**: ASUS ROG Strix RTX 2070 (Primary Graphics).
2. **`PCIEX1_1` / `PCIEX1_2`**: Leave empty (covered or partially blocked by the 2.5-slot GPU cooler).
3. **`PCIEX1_3`**: TP-Link Archer T4E AC1200 (WiFi Network Card).
4. **`PCIEX1_4`**: PCIe Smart WiFi Power Switch (plenty of breathing room at the bottom of the case).
