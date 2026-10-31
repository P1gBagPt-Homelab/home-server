# Guide 08: Monitoring & Alerting (Uptime Kuma & Netdata)

This guide walks you through deploying **Uptime Kuma** (for service health checks and Discord/Telegram phone alerts) and **Netdata** (for real-time CPU, 40GB RAM, 4-disk storage health, and **RTX 2070 GPU metrics**) inside Coolify.

---

## 1. Deploying Uptime Kuma (Service Status & Alerts)

Uptime Kuma continuously monitors your containers, databases, and websites, sending an alert to your phone within seconds if any service crashes.

### Deployment in Coolify:
1. Open Coolify (`http://10.8.0.1:8000`).
2. Go to **Projects > Default > Production > + New Resource**.
3. Select **Docker Compose** (or 1-Click Service if listed).
4. Name it `Uptime-Kuma`.
5. Configuration:
   ```yaml
   services:
     uptime-kuma:
       image: louislam/uptime-kuma:1
       container_name: uptime-kuma
       restart: unless-stopped
       volumes:
         - uptime-kuma-data:/app/data
       networks:
         - server-net

   volumes:
     uptime-kuma-data:

   networks:
     server-net:
       external: true
   ```
6. In the **Domains** field, enter:  
   `https://status.janux-lab.duckdns.org`
7. Click **Deploy**.

---

### Configuring Monitors in Uptime Kuma:
Open `https://status.janux-lab.duckdns.org` and create your admin account, then add your core monitors:

| Monitor Name | Monitor Type | Target / Hostname |
| :--- | :--- | :--- |
| **Docmost Wiki** | HTTP(s) | `http://docmost:3000` |
| **Coolify Dashboard** | HTTP(s) | `http://192.168.1.150:8000` |
| **PostgreSQL Database** | TCP Port | Hostname: `janus-postgres`, Port: `5432` |
| **Redis Cache** | TCP Port | Hostname: `janus-redis`, Port: `6379` |
| **Home Router Internet** | Ping | `1.1.1.1` (or `8.8.8.8`) |

---

### Setting Up Instant Phone Notifications (Discord / Telegram):
1. In Uptime Kuma, go to **Settings > Notifications > Setup Notification**.
2. **Discord**:
   * Create a private Discord channel on your server (e.g., `#janus-alerts`).
   * Channel Settings > Integrations > Webhooks > Copy Webhook URL.
   * Paste the Webhook URL into Uptime Kuma and click **Test**.
3. **Telegram**:
   * Create a bot via `@BotFather` and enter the Bot Token and your Chat ID.
4. *Result:* Whenever an app crashes or recovers, you get an instant ping on your phone.

---

## 2. Deploying Netdata (Hardware & RTX 2070 GPU Metrics)

Netdata provides per-second live graphs of CPU temperatures, RAM usage, disk I/O across your 4 drives, and full hardware metrics for your **ASUS Strix RTX 2070**.

### Deployment in Coolify:
1. In Coolify, click **+ New Resource > Docker Compose**.
2. Name it `Netdata`.
3. Configuration:
   ```yaml
   services:
     netdata:
       image: netdata/netdata:stable
       container_name: netdata
       restart: unless-stopped
       hostname: janus
       cap_add:
         - SYS_PTRACE
         - SYS_ADMIN
       security_opt:
         - apparmor:unconfined
       volumes:
         - /etc/passwd:/host/etc/passwd:ro
         - /etc/group:/host/etc/group:ro
         - /proc:/host/proc:ro
         - /sys:/host/sys:ro
         - /etc/os-release:/host/etc/os-release:ro
         - /var/run/docker.sock:/var/run/docker.sock:ro
         - netdataconfig:/etc/netdata
         - netdatalib:/var/lib/netdata
         - netdatacache:/var/cache/netdata
       deploy:
         resources:
           reservations:
             devices:
               - driver: nvidia
                 count: all
                 capabilities: [gpu]
       networks:
         - server-net

   volumes:
     netdataconfig:
     netdatalib:
     netdatacache:

   networks:
     server-net:
       external: true
   ```
4. In the **Domains** field, enter:  
   `https://netdata.janux-lab.duckdns.org`
   *(Or keep it private on `http://10.8.0.1:19999` accessible only over WireGuard).*
5. Click **Deploy**.

---

## 3. What Netdata Monitors on Janus:

* **ASUS Strix RTX 2070 GPU Dashboard**:
  * Real-time GPU processor load (%)
  * 8 GB VRAM allocation and free memory
  * GPU core temperature and fan speeds
  * Total power consumption (Watts)
* **Intel i7-8700K (6C / 12T)**:
  * Per-core frequency and thermal package temperatures
  * System load averages
* **40 GB DDR4 Memory**:
  * Real-time cache vs application memory breakdown
  * ZFS / Docker memory allocations
* **4-Drive Storage Health**:
  * Disk space utilization on `/data`
  * Real-time read/write I/O throughput
  * S.M.A.R.T. disk temperature and bad sector warnings

Your monitoring stack is now complete, providing total visibility and immediate alerting for Project Janus!
