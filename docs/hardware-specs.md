# Hardware Specifications & Optimization Guide

This document maps your specific hardware components to their capabilities in both **Gaming (Windows)** and **Home Server (Linux)** roles.

---

## 🖥️ System Specifications Summary

| Component | Model / Spec | Server & Workload Capability |
| :--- | :--- | :--- |
| **CPU** | Intel Core i7-8700K (6C / 12T, 4.5 GHz) | Excellent multi-threading for dozens of containers + **Intel QuickSync** (UHD 630). |
| **GPU** | ASUS ROG Strix GeForce RTX 2070 (8GB GDDR6) | 1080p/1440p Gaming + **CUDA / Tensor Cores for local AI models up to 8B parameters**. |
| **Motherboard** | ASUS PRIME Z370-A (Intel Z370 Chipset) | 4x PCIe x1 slots, Intel I219-V Gigabit LAN, dual M.2 NVMe, 6x SATA ports. |
| **Memory** | 40 GB DDR4 3200 MHz | Massive headroom for memory-heavy databases, caching, and multi-container stacks. |

---

## 🔌 Motherboard Wiring Map: ASUS PRIME Z370-A

For installing your **PCIe WiFi Remote Power Switch**, the ASUS PRIME Z370-A provides ideal headers:

### 1. PCIe Slot Selection:
* The Strix RTX 2070 is a thick 2.5-slot graphics card in the primary `PCIEX16_1` slot.
* **Recommended Slot**: Insert the PCIe WiFi card into **`PCIEX1_3`** or **`PCIEX1_4`** (the lower PCIe x1 slots near the bottom of the motherboard). This keeps clear airflow to your GPU fans.

### 2. Front-Panel Header (`PANEL`) Location:
* Located at the **bottom-right corner** of the motherboard labeled `PANEL`.
* **Power Switch Pins (`PWR_SW`)**:
  * On the ASUS 20-3 pin panel header, `PWR_SW` is located on the **top row, pins 3 and 4** (immediately next to the power LED pins).
  * Orientation/Polarity does **not** matter for `PWR_SW` (it is a momentary contact switch).
* **Reset Switch Pins (`Reset`)**:
  * Located on the **bottom row, pins 3 and 4** (directly beneath the `PWR_SW` pins).

---

## ⚡ Hardware Strengths for Server & AI

### 1. The 40 GB RAM Advantage
* Most home servers operate on 8GB to 16GB.
* With 40 GB, you can run:
  * 15–20 active Docker containers (~4–6 GB total).
  * In-memory Redis caches, staging Postgres databases, and custom backend APIs without ever touching swap space.
  * Offload larger language models into system RAM if a model exceeds VRAM.

### 2. RTX 2070 (8GB VRAM) for Local AI
Your Turing-architecture RTX 2070 has **2304 CUDA cores** and **288 Tensor Cores**, making it great for running quantized local AI models at high speed:

| AI Model | Quantization | VRAM Required | Performance on RTX 2070 |
| :--- | :--- | :--- | :--- |
| **Llama 3.1 8B** | Q4_K_M | ~4.9 GB | **~35 – 45 tokens/sec** (Fully offloaded to VRAM) |
| **Mistral 7B v0.3** | Q4_K_M | ~4.5 GB | **~40 – 50 tokens/sec** (Instantaneous responses) |
| **Phi-3 Mini (3.8B)** | Q4_K_M | ~2.5 GB | **~70+ tokens/sec** (Extremely fast, lightweight) |
| **Whisper (Small/Medium)**| FP16 | ~1.5 – 3 GB | Real-time speech-to-text transcription |
| **Stable Diffusion 1.5** | FP16 | ~4 – 6 GB | Image generation in ~2–3 seconds |

*Note: Since 8GB VRAM holds models up to ~8B parameters entirely in GPU memory, token generation will feel instant.*

### 3. Intel i7-8700K QuickSync (Bonus Media Power)
* The i7-8700K features integrated **Intel UHD Graphics 630**.
* If you ever run Plex or Jellyfin on your server, you can pass `/dev/dri` (Intel QuickSync) to the container. It will transcode 4K and 1080p video streams with near-zero CPU usage and minimal power consumption, keeping your RTX 2070 completely idle and cool.

### 4. Intel I219-V Gigabit Ethernet
* Built-in to your ASUS motherboard.
* Highly praised in Linux for stability (uses the native in-tree `e1000e` kernel driver).
* Capable of saturating a full 1 Gbps connection for WireGuard and file transfers without packet drops.
