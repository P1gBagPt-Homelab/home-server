# 06. Shopping & Hardware Checklist

This guide outlines the exact hardware needed to complete the hybrid gaming and on-demand server setup, distinguishing between network cards and IoT power switches.

---

## 1. Selected Hardware: WETEN / Tuya JH-PcPro

* **Device Selected**: **WETEN JH-PcPro (Tuya Smart / Smart Life PCIe Switch)**
* **Platform**: Tuya IoT / Smart Life (iOS & Android)
* **Connectivity**: 2.4 GHz Wi-Fi + Bluetooth BLE + 433 MHz RF
* **Key Features**:
  * Plugs into any PCIe slot (installed into `PCIEX1_4` on ASUS PRIME Z370-A).
  * Direct 2-pin Y-splitter connection to motherboard `PWR_SW` and `RST_SW` pins.
  * Preserves PC case front-panel button functionality.
  * Includes a wireless 433 MHz desktop button for quick local physical control without opening the app or bending under the desk.
  * No Zigbee bridge or hub required (connects directly to home router).

---

## 2. Where to Buy & Alternative Links

* **Purchased Item**: [Vinted: Tuya wifi interruptor computador + Botão Wireless](https://www.vinted.pt/items/5965973958-tuya-wifi-interruptor-computador-botao-wireless)
* **Amazon.es Alternative**: [Direct Search for Tuya PCIe PC Switch](https://www.amazon.es/s?k=tarjeta+pcie+encendido+pc+tuya) (~€15 – €28).
* **AliExpress Alternative**: [Direct Search for Tuya PCIe PC Switch](https://es.aliexpress.com/w/wholesale-tuya-pcie-power-switch.html) (~€8 – €14).

---

## 3. Pre-Build Inventory Checklist

| Hardware Item | Status | Purpose / Action |
| :--- | :---: | :--- |
| **WETEN / Tuya PCIe Switch + RF Button** | 📦 **Purchased (In Transit from Vinted)** | Remote power ON/OFF via Tuya + 433MHz desk button. |
| **TP-Link Archer T4E** | Keep | Kept in `PCIEX1_3` for Windows WiFi if needed. |
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
4. **`PCIEX1_4`**: **WETEN JH-PcPro** (installed at the very bottom slot, keeping clear airflow for the GPU).

---

## 5. Critical BIOS Setting: ErP Ready

* Location in ASUS BIOS: **Advanced > APM Configuration > ErP Ready** -> Set to **Disabled**.
* *Why*: If ErP Ready is enabled, the motherboard cuts all 3.3V standby current to PCIe slots upon shutdown. Setting it to Disabled ensures the WETEN card stays connected to WiFi to listen for your power commands.
