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

## 2. Where to Buy

### Recommended Products:
* **Amazon.es**: [Direct Search for Tuya PCIe PC Switch](https://www.amazon.es/s?k=tarjeta+pcie+encendido+pc+tuya) (~€15 – €22, Prime shipping).
* **AliExpress**: [Direct Search for Tuya PCIe PC Switch](https://es.aliexpress.com/w/wholesale-tuya-pcie-power-switch.html) (~€8 – €12).

### What Must Be in the Box:
1. PCIe expansion card with standard full-height bracket (and low-profile if needed).
2. External 2.4 GHz WiFi antenna.
3. 2-pin motherboard Y-splitter cables (allows both the PCIe card and your physical PC case button to trigger power).

---

## 3. Pre-Build Inventory Checklist

| Hardware Item | Status | Purpose / Action |
| :--- | :---: | :--- |
| **PCIe Smart PC Switch Card** | 🛒 **Need to buy** | ~€15 on Amazon.es (Tuya / Smart Life compatible). |
| **TP-Link Archer T4E** | Keep | Keep in `PCIEX1_3` for Windows WiFi if needed. |
| **Cat 6 Ethernet Cable** | Highly Recommended | Plug ASUS Intel I219-V LAN port directly into router for server & WireGuard stability. |
| **2x SATA Data Cables** | Ready at home | Connect the 2 dedicated server disks to ASUS Z370-A SATA ports. |
| **SATA Power Cables** | Ready at home | 2 free SATA power leads from power supply. |
| **2x Dedicated Server Disks** | Ready at home | The 2 physical drives dedicated to Linux Server (ext4/ZFS). |
| **USB Flash Drive (8GB+)** | Ready at home | To create bootable Linux Server installer (Ubuntu Server / Debian). |

---

## 4. Slot Arrangement on ASUS PRIME Z370-A

To ensure optimal cooling for the ASUS ROG Strix RTX 2070:

1. **`PCIEX16_1`**: ASUS ROG Strix RTX 2070 (Primary Graphics).
2. **`PCIEX1_1` / `PCIEX1_2`**: Leave empty (covered or partially blocked by the 2.5-slot GPU cooler).
3. **`PCIEX1_3`**: TP-Link Archer T4E AC1200 (WiFi Network Card).
4. **`PCIEX1_4`**: PCIe Smart WiFi Power Switch (plenty of breathing room at the bottom of the case).

---

## 5. Critical BIOS Setting: ErP Ready

* Location in ASUS BIOS: **Advanced > APM Configuration > ErP Ready** -> Set to **Disabled**.
* *Why*: If ErP Ready is enabled, the motherboard cuts all 3.3V standby current to PCIe slots when powered off. Setting it to Disabled ensures the PCIe switch card stays connected to WiFi to listen for your power commands.
