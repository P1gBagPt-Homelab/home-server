# Guide 05: WETEN PCIe Switch Installation & App Pairing

This guide details physically installing the **WETEN JH-PcPro** card into your **ASUS PRIME Z370-A** motherboard, wiring the splitter cables, and pairing the device with the **Smart Life / Tuya** app and wireless desk button.

---

## 🛠️ Required Tools & Preparation
* Phillips #2 screwdriver.
* The WETEN JH-PcPro kit (card, antenna, Y-splitter cables, 433MHz desk button).
* Smartphone with **Smart Life** or **Tuya Smart** app installed (iOS or Android).

---

## Step 1: Safety & Power Discharge

1. Shut down the computer completely.
2. Turn off the power switch on the back of your Power Supply Unit (PSU) and **unplug the AC power cord**.
3. **Press the physical PC case power button once** while unplugged to drain residual electricity from motherboard capacitors.
4. Open the side panel of your PC case.

---

## Step 2: Physical Card Installation

1. Locate the **`PCIEX1_4`** slot (the lowest PCIe x1 slot at the very bottom of your ASUS motherboard).
   > [!TIP]
   > Installing in the bottom-most slot gives your thick ASUS ROG Strix RTX 2070 fans 100% unrestricted airflow.
2. Remove the metal case bracket cover for that slot.
3. Firmly insert the WETEN PCIe card into the slot until seated.
4. Secure the card bracket with a case screw.
5. Screw the 2.4 GHz WiFi antenna onto the threaded gold connector on the rear bracket.

---

## Step 3: Motherboard Header Wiring (ASUS `PANEL`)

Look at the **bottom-right corner** of your ASUS PRIME Z370-A motherboard. You will see a header block labeled **`PANEL`**.

```
ASUS PRIME Z370-A "PANEL" Header Pinout:
   Top Row:    [PLED+] [PLED-] [PWR_SW] [PWR_SW] [Ground]
   Bottom Row: [HDLED+] [HDLED-] [RESET] [RESET] [Ground]
```

### Wiring the Power Splitter Cable:
1. Locate your PC case's existing front panel **`POWER SW`** cable plugged into the motherboard. Gently pull it off the pins.
2. Take the **Y-splitter cable** from the WETEN box:
   * **Female Connector** (two holes): Plug directly onto the motherboard's **`PWR_SW` pins** (top row, pins 3 and 4). *Orientation/polarity does not matter.*
   * **Male Connector Branch 1**: Plug into your PC case's physical front-panel power button cable.
   * **Male Connector Branch 2**: Plug onto the 2-pin header labeled **`POWER`** on the WETEN PCIe card.
3. *(Optional)* If your kit includes a Reset splitter, repeat the process for the **`RESET` pins** (bottom row, pins 3 and 4) to the card's `RESET` header.
4. Ensure all cables are tidy and not touching any GPU or case fan blades.
5. Close the PC case, plug the power cable back into the wall, and turn the PSU switch **ON**.

---

## Step 4: Mobile App Pairing (Smart Life / Tuya)

1. Ensure your smartphone has **Bluetooth ON** and is connected to your **home 2.4 GHz Wi-Fi**.
2. Open the **Smart Life** or **Tuya Smart** app and log in / create a free account.
3. Put the WETEN card into pairing mode:
   * Look at the rear bracket of the WETEN card; press and hold the small onboard button for **5 seconds** until the blue indicator LED begins flashing rapidly.
4. In the app:
   * Tap **"+"** in the top right corner > **Add Device**.
   * The app will automatically discover the card via Bluetooth: *"Smart PC Switch"*.
   * Tap **Add**, select your 2.4 GHz WiFi network, and enter your WiFi password.
5. Rename the device to **"Home Server"** and tap **Done**.

---

## Step 5: Pairing the 433 MHz Wireless Desk Button

The "Pro" kit includes an adhesive wireless desk button:
1. Press the wireless button once. If the computer turns on, it is already paired from the factory.
2. If not paired:
   * Press and hold the **RF pairing button** on the rear of the PCIe card for **3 seconds** until the LED turns solid.
   * Immediately press the wireless desk button once. The LED will flash, confirming pairing.
3. Peel the 3M tape backing and stick the button anywhere convenient on your desk or monitor stand.

---

## Step 6: Testing the Remote Power Lifecycle

1. **Test Remote Power On**:
   * Open the Smart Life app from anywhere (even over cellular 4G/5G).
   * Tap **"Power On"**. The PC will turn on immediately and boot into Ubuntu Server.
2. **Test Safe ACPI Graceful Shutdown**:
   * In the Smart Life app, tap **"Power Off"**.
   * Observe the PC: Ubuntu Server will cleanly stop running services, flush disk writes, and power off safely into standby (~1–2W).
3. **Test Physical Case Button**:
   * Press the physical button on your PC case: it still turns on the computer as before.

Your hardware remote switch is now fully operational!
