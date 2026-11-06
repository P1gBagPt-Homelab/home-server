# Guide 11: JanusDeck Command Center & Remote Management Portal

> **Status**: ✅ **Fully Implemented & Deployed on Project Janus**  
> * **Project Repo**: [`P1gBagPt-Homelab/JanusDeck`](https://github.com/P1gBagPt-Homelab/JanusDeck)
> * **Target URL**: `https://control.your-domain.duckdns.org` (and `http://192.168.1.68:8080`)
> * **Platform**: Coolify PaaS (Docker Compose)
> * **Stack**: FastAPI (Python 3.12), SQLAlchemy 2.0 (async), asyncpg + Svelte 5 (Runes, TypeScript, Tailwind CSS)
> * **Database**: Dedicated `janusdeck` database on central shared PostgreSQL 18
> * **Core Features**: Real-time Hardware Telemetry (RTX 2070, i7-8700K, 40GB RAM), Mandatory Master PIN Security Gate with Paste & Autofill Support, 5-Second Countdown Abort Gate, One-Shot Boot to Windows Gaming Mode, Dynamic Service Directory CRUD, and Automated CI/CD via GitHub Actions Organization Runner.

---

## 1. Overview & Purpose

**JanusDeck** is the open-source management portal built specifically for Project Janus's dual-boot architecture. It serves four primary functions:

1. **Dynamic Homelab Service Directory**: An interactive dashboard with automated HTTP availability checks for all services hosted on Janus (Coolify, Docmost, Uptime Kuma, Netdata, WireGuard, Vaultwarden). Services are stored persistently in PostgreSQL 18 with a built-in Svelte 5 modal to add, edit, or delete links and icons directly from the UI.
2. **Live Hardware Telemetry**: Streams real-time Intel i7-8700K load and thermals, 40GB DDR4 memory usage, NVMe/HDD disk capacity, and ASUS ROG Strix RTX 2070 GPU stats (VRAM, temperature, fan speed) via Server-Sent Events (SSE).
3. **Remote Dual-Boot & Power Controls**: Securely commands the physical machine to:
   * **Reboot Ubuntu Server** (`systemctl reboot`).
   * **Graceful ACPI Shutdown** (`systemctl poweroff`).
   * **Switch to Windows Gaming Mode** (`grub-reboot "Windows Boot Manager (on /dev/nvme0n1p1)" && reboot`).
4. **Initial Data Seeder**: Automatically imports existing static services from `config.yaml` on first startup if the database table is empty, ensuring zero data loss during transitions.

---

## 2. Security & Authentication Architecture

1. **Mandatory Master PIN Gate**:
   * Viewing the command deck, telemetry, and power actions strictly requires authentication.
   * Unauthorized visitors see only a clean, branded security gate; telemetry streaming is stopped until unlocked.
2. **Flexible Input & Paste Integration**:
   * Supports standard clipboard pasting (`⌘V` on macOS, `Ctrl+V` on Windows/Linux).
   * 1-click **Paste PIN** button using `navigator.clipboard.readText()`.
   * Accessible input with `autocomplete="one-time-code"` for 1-tap password manager autofill (1Password, Bitwarden, Apple Keychain).
3. **Brute-Force Rate Limiting**:
   * Hardware-isolated rate limiting with exponential lockout upon repeated failed attempts.
4. **5-Second Countdown Safety Gate**:
   * Destructive power actions require a 5-second confirmation countdown with an immediate visual abort button.

---

## 3. Automated CI/CD Deployment Pipeline

JanusDeck is automatically deployed to Coolify using GitHub Actions and a self-hosted runner:

1. **Organization-Level Runner**:
   * Hosted directly on Ubuntu Server (`janus`) as a 24/7 background service:
     `actions.runner.P1gBagPt-Homelab.janus.service`
2. **Automated Trigger on Push**:
   * Whenever code is pushed or a Pull Request is merged into `main`, GitHub Actions triggers `.github/workflows/deploy.yml`.
   * The local runner executes an authenticated API request to Coolify (`http://192.168.1.68:8000/api/v1/deploy`), initiating a zero-downtime rebuild and redeploy in ~5 seconds.

---

## 4. Docker to Host Power Bridge Architecture

Because the dashboard runs as a container managed by Coolify, it interfaces with the host system via mounted control sockets:

```mermaid
sequenceDiagram
    autonumber
    actor User as You (Mobile / WireGuard)
    participant Coolify as Traefik Reverse Proxy
    participant App as JanusDeck Container
    participant DBus as Host Systemd DBus
    participant GRUB as Host GRUB Bootloader

    User->>Coolify: HTTPS https://control.your-domain.duckdns.org
    Coolify->>App: Forward to Container Port 8080
    User->>App: Tap "Switch to Windows"
    App->>User: Prompt for Security PIN
    User->>App: Enter PIN & Confirm
    App->>GRUB: Write next_entry="Windows Boot Manager"
    App->>DBus: Issue Reboot Request via login1
    DBus->>Host: Graceful OS Restart into Windows 11
    Note over User,Host: After gaming, Windows shutdown reverts next boot to Linux
```

---

## 5. Coolify Deployment Specification

When ready to deploy on Janus via Coolify:

1. In Coolify, create a new service using **Docker Compose**.
2. Configure environment variables:
   ```env
   JANUS_PIN=your-secret-pin
   TZ=UTC
   ```
3. Use the production Docker Compose configuration from [`janus-deck/docker-compose.example.yml`](file:///Users/daniel/Desktop/Projects/janus-deck/docker-compose.example.yml):
   ```yaml
   services:
     janus-deck:
       image: ghcr.io/daniel/janus-deck:latest # or build from GitHub repository
       container_name: janus-deck
       restart: unless-stopped
       pid: host
       ports:
         - "8080:8080"
       networks:
         - default
       volumes:
         - ./config.yaml:/app/config.yaml:ro
         - /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket:ro
         - /boot:/boot:rw
       deploy:
         resources:
           reservations:
             devices:
               - driver: nvidia
                 count: all
                 capabilities: [gpu]

   networks:
     default:
       name: coolify
       external: true
   ```
4. In `config.yaml`, configure the database connection to the shared PostgreSQL 18 container:
   ```yaml
   database:
     url: "postgresql+asyncpg://janusdeck:YOUR_PASSWORD@o4nipot4qcoaskqwss3zf6bq:5432/janusdeck"
   ```
5. Assign domain `https://control.your-domain.duckdns.org` in Coolify to enable automatic Let's Encrypt SSL.

---

## 6. Execution Roadmap Reference

The complete development roadmap and phase breakdown are documented in the standalone repository:
👉 [**JanusDeck Implementation Plan**](file:///Users/daniel/Desktop/Projects/janus-deck/docs/IMPLEMENTATION_PLAN.md)
