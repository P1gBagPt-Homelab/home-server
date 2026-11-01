# Guide 08: Monitoring & Alerting (Uptime Kuma & Netdata)

This guide walks you through deploying **Uptime Kuma** (for service health checks and Discord/Telegram phone alerts) and **Netdata** (for real-time CPU, 40GB RAM, 4-disk storage health, and **RTX 2070 GPU metrics**) inside Coolify.

---

## 1. Deploying Uptime Kuma (Service Status & Alerts)

Uptime Kuma continuously monitors your containers, databases, and websites, sending an alert to your phone within seconds if any service crashes.

1. In Coolify (`Core Services` or `Monitoring`), click **+ New Resource > Docker Compose**.
2. Name it `Uptime-Kuma`.
3. In **Service details**, ensure **Network attachment** is set to **`Attach to predefined network`**.
4. Paste the configuration:
   ```yaml
   services:
     uptime-kuma:
       image: louislam/uptime-kuma:2
       container_name: uptime-kuma
       restart: unless-stopped
       environment:
         - TZ=Europe/Lisbon
       volumes:
         - /data/volumes/uptime-kuma:/app/data
       ports:
         - "3001:3001"
   ```
5. In **Domains**, add:  
   `https://status.janus-lab.duckdns.org` (Port: `3001`).
6. Click **Deploy**.

---

### Configuring Monitors in Uptime Kuma:
Open `https://status.janus-lab.duckdns.org` (or `http://192.168.1.68:3001`) and create your admin account, then add your core monitors:

| Monitor Name | Monitor Type | Target / Hostname |
| :--- | :--- | :--- |
| **Docmost Wiki** | HTTP(s) | `https://docs.janus-lab.duckdns.org` (or `http://docmost:3000`) |
| **Coolify Dashboard** | HTTP(s) | `http://192.168.1.68:8000` |
| **Netdata Hardware Agent** | HTTP(s) | `http://192.168.1.68:19999` (or `http://netdata:19999`) |
| **PostgreSQL Database** | TCP Port | Hostname: `<POSTGRES_INTERNAL_HOSTNAME>` (e.g. `o4nipot4qcoaskqwss3zf6bq`), Port: `5432` |
| **Redis Cache** | TCP Port | Hostname: `<REDIS_INTERNAL_HOSTNAME>` (e.g. `owc6dm4qwd4lm7q37pvoibh0`), Port: `6379` |
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
       ports:
         - "19999:19999"
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

   volumes:
     netdataconfig:
     netdatalib:
     netdatacache:
   ```

> [!WARNING]
> **Netdata Has No Built-In Password Screen!**  
> If you attach a public domain (like `https://netdata.janus-lab.duckdns.org`) without authentication, Netdata shows:  
> `⚠️ IMPORTANT: This Netdata is openly accessible from the Internet!`  
> Anyone visiting the link could view every running process, open port, and disk metric on Janus without logging in.

### How to Secure Netdata (Choose One):

* **Option A: Keep It 100% Private (Recommended)**:
  * Leave the **Domains** field in Coolify **empty**.
  * Keep `ports: - "19999:19999"`.
  * Access locally at `http://192.168.1.68:19999`, or from anywhere over **WireGuard VPN** at `http://10.8.0.1:19999`.
  * Port 19999 is not exposed to the internet, so the warning disappears and your hardware metrics remain completely confidential.

* **Option B: Free Netdata Cloud SSO**:
  * Create a free account at [app.netdata.cloud](https://app.netdata.cloud).
  * Add your `NETDATA_CLAIM_TOKEN` and `NETDATA_CLAIM_ROOMS` to Netdata's environment variables.
  * Access your dashboards securely from anywhere with Google/GitHub SSO and 2FA, without exposing public ports.

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
