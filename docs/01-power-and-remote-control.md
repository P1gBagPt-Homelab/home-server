# 01. Power & Remote Management (PCIe WiFi Switch)

For this build, a **PCIe WiFi Remote Power Switch card** (Tuya / eWeLink / Smart Life compatible) is the primary remote power management solution. 

Because idle standby draw (~1–2W) is not a concern, the PCIe WiFi card eliminates the complexities, safety hazards, and clunkiness of smart outlets.

---

## 1. Why the PCIe WiFi Card is the Chosen Solution

```
┌────────────────────────────────────────────────────────┐
│                   Mobile Phone App                     │
│               (Tuya / Smart Life / eWeLink)            │
└──────────────────────────┬─────────────────────────────┘
                           │ WiFi (Internet / Local)
                           ▼
┌────────────────────────────────────────────────────────┐
│             PCIe WiFi Remote Switch Card               │
│               (Powered via PCIe / USB)                 │
└────────────┬─────────────────────────────┬─────────────┘
             │ 2-Pin Splitter              │ 2-Pin Splitter (Optional)
             ▼                             ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│  Motherboard PWR_SW Header│  │ Motherboard RST_SW Header│
└──────────────────────────┘  └──────────────────────────┘
             ▲                             ▲
             │                             │
    PC Case Physical Button       PC Case Reset Button
```

### Key Advantages:
1. **Single-Tap Graceful Shutdown**:
   * Tapping "Power Off" in the app sends an ACPI shutdown signal to the motherboard.
   * Both Windows and Linux cleanly unmount the 4 disks, shut down Docker containers, flush write caches, and power off safely.
   * **Zero risk of disk or filesystem corruption.**
2. **Instant Remote Power ON**:
   * Tapping "Power On" in the app closes the circuit on the `PWR_SW` pins for 0.5s, exactly as if your finger pressed the button on the front of the computer case.
   * Works from anywhere via 4G/5G or WiFi without needing port forwarding or router configuration for the power signal.
3. **Emergency Recovery (Frozen Machine)**:
   * If an OS locks up or the kernel crashes, the app supports a **"Long Press"** (holding power for 5 seconds) to force an emergency hardware cutoff, or a **Reset** pulse to restart.
4. **Physical Case Button Remains Fully Functional**:
   * The included Y-splitter cables connect between your PC case's front panel wires and the motherboard headers. You can still use the physical power button on your desk normally.
5. **No BIOS Dependencies**:
   * Does not require finicky "Restore on AC Power Loss" settings in UEFI.

---

## 2. Hardware Installation & BIOS Standby Configuration

### Critical Motherboard BIOS Setting (ASUS PRIME Z370-A):
Before using the card, ensure your PCIe slots maintain 3.3V standby power when the computer is off:
1. Boot into BIOS (`DEL` or `F2`).
2. Go to **Advanced > APM Configuration > ErP Ready**.
3. Set **ErP Ready** to **Disabled**.
   *(If enabled, the motherboard cuts all standby power to PCIe slots upon shutdown, which would turn off the WiFi card).*

### What to Purchase:
* Search for: **"Tuya Smart PCIe Computer Power Switch"** or **"eWeLink Desktop PC Remote Switch"** (~€10–€18 on Amazon or AliExpress).
* Select a model that includes standard brackets, antenna, and the 2-pin motherboard splitter cables.

### Physical Installation Steps:
1. **Power down and unplug the PC** from the wall.
2. Locate an available **PCIe x1 slot** (it also fits into x4, x8, or x16 slots).
3. Insert the card and secure the bracket with a screw.
4. **Locate your Motherboard Front Panel Header**:
   * Find the 2 pins labeled `PWR_SW` (or `POWER SW`).
   * Unplug the existing front-panel power button cable coming from your PC case.
5. **Connect the Splitter Cable**:
   * Plug the splitter's female connector into the motherboard `PWR_SW` pins.
   * Plug one branch into the PCIe card's `POWER` header.
   * Plug the other branch back into your PC case's front panel power button cable.
6. *(Optional)* Repeat the step for the `RST_SW` (Reset Switch) pins if your card includes a reset line.
7. Plug the PC back into the wall.

---

## 3. Mobile App Setup & Configuration

1. Download the **Smart Life** or **Tuya Smart** app (iOS / Android).
2. Put the PCIe card into pairing mode (usually by holding the onboard pairing button for 5 seconds until the LED blinks rapidly).
3. Add the device in the app and connect it to your home 2.4 GHz WiFi network.
4. Rename the device (e.g., `Home PC / Server Power`).

### ACPI Behavior Settings (In OS):
* **Linux Server**: By default, `systemd-logind` handles the ACPI power button event by initiating a graceful `poweroff`. To verify, inspect `/etc/systemd/logind.conf`:
  ```ini
  HandlePowerKey=poweroff
  ```
* **Windows (Gaming)**: Ensure Windows is set to shut down when the power button is pressed:
  * *Control Panel > Power Options > Choose what the power button does > "When I press the power button: Shut down"*.

---

## 4. Alternative Reference: Smart Plug & Wake-on-LAN

While the PCIe card is the primary standard for this build, the alternatives remain documented for reference:

* **Wake-on-LAN (WoL)**: Can be used as a software fallback if the PCIe card loses WiFi connection. Send a magic packet to the PC's MAC address from your router or a local device.
* **Smart Plug**: If ever deployed to measure wattage draw, leave it permanently set to **ON** and do not use it to force power cuts while the operating system is running.
