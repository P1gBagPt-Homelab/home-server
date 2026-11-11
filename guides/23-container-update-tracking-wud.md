# Guide 23: Container Update Tracking & Alerts with WUD (What's Up Docker?)

> **Status**: ✅ **Implemented & Verified on Project Janus (WUD v9.8.0)**  
> * **Platform**: Coolify PaaS (Docker Compose)  
> * **Image**: `getwud/wud:latest`  
> * **Web UI**: `https://updates.your-domain.duckdns.org` (and `http://192.168.1.68:3002` / `http://10.8.0.1:3002`)  
> * **Internal Container Port**: `3000` (mapped to host port `3002` to avoid colliding with Grafana/Docmost on `3000` and Uptime Kuma on `3001`)  
> * **Storage**: `/data/volumes/wud` on SSD Pool (mounted to `/store`)  
> * **Network**: Attached to external `coolify` Docker network  
> * **Access Control**: Private LAN (`192.168.1.0/24`) & WireGuard VPN (`10.8.0.0/24`) via Traefik DNS-01 SSL (Guide 19)

---

## 1. Overview & Architecture

Project Janus runs 15+ containerized services via Coolify (Docmost, Vaultwarden, Uptime Kuma, Netdata, MinIO, RabbitMQ, Grafana, Prometheus, Jellyfin, GlitchTip, Ollama, and custom apps). Keeping track of which services have new releases — without silently breaking databases or causing Coolify state drift — requires a **notify-only** update tracker.

### Why WUD (What's Up Docker?) Over Auto-Updaters?
* **Zero Coolify Drift:** Tools like Watchtower in auto-update mode recreate containers behind Coolify's back, causing Coolify's deployment state, environment variables, and rollback history to fall out of sync. WUD mounts `/var/run/docker.sock` **read-only (`:ro`)** and never modifies containers unless you explicitly configure an update trigger.
* **Visual Web Dashboard:** Shows every running container, its current image tag/digest, and the latest available upstream version at a glance.
* **SemVer & Digest Awareness:** Tracks both pinned versions (e.g., `18.1` -> `18.2`) and mutable tags like `:latest` via registry manifest digests.
* **Native Alerts & Observability:** Sends notifications directly to **Discord** and **Telegram** (matching Guide 08), exposes a **Prometheus `/metrics` endpoint** for Grafana (Guide 16), and provides a **REST API** you can query from **JanusDeck** (Guide 11).

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Traefik Reverse Proxy                           │
│              https://updates.your-domain.duckdns.org (Port 443)        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Port 3000 (Web UI & REST API)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        WUD (getwud/wud:latest)                         │
│   • Mandatory Auth Gate (WUD_AUTH_ADMIN_USER / PASSWORD)               │
│   • Persistent State: /data/volumes/wud -> /store                      │
└──────────┬─────────────────────────┬───────────────────────┬───────────┘
           │ :ro Docker Socket       │ Registry Polls        │ Triggers & Metrics
           ▼                         ▼                       ▼
┌─────────────────────┐   ┌─────────────────────┐   ┌────────────────────┐
│ /var/run/docker.sock│   │ Docker Hub / GHCR / │   │ • Discord Webhook  │
│ Discovers all       │   │ Quay / LinuxServer  │   │ • Telegram Bot     │
│ Coolify containers  │   │ Checks tags/digests │   │ • Prometheus       │
└─────────────────────┘   └─────────────────────┘   └────────────────────┘
```

---

## 2. Host Directory Preparation

Connect to Janus via SSH (`ssh daniel@192.168.1.68` or over WireGuard `ssh daniel@10.8.0.1`) and create the persistent volume directory for WUD's local database (`/store`):

```bash
sudo mkdir -p /data/volumes/wud
```

*(Note: Keep `/data/volumes/wud` included in your automated backup path covered in [Guide 10](10-automated-backups-and-recovery.md) if you want to preserve UI-created users and update history.)*

---

## 3. Notification Prerequisites (Discord / Telegram)

WUD uses environment variables following the pattern `WUD_TRIGGER_<TYPE>_<NAME>_<SETTING>`. You can reuse the `#janus-alerts` Discord server or Telegram bot created in [Guide 08](08-monitoring-and-metrics-setup.md) (or create a dedicated `#janus-updates` channel so update pings don't mix with downtime alerts):

### Option A: Discord Webhook
1. Open your Discord channel settings (e.g., `#janus-updates`) $\rightarrow$ **Integrations** $\rightarrow$ **Webhooks** $\rightarrow$ **New Webhook**.
2. Copy the **Webhook URL** (`https://discord.com/api/webhooks/...`).

### Option B: Telegram Bot
1. Use your bot token from `@BotFather` and your target **Chat ID** (e.g., via `@userinfobot` or your group chat ID).

---

## 4. Coolify Deployment Walkthrough

### Step 1: Create Resource in Coolify
1. Open Coolify: `http://192.168.1.68:8000` (or `http://10.8.0.1:8000` via WireGuard).
2. Navigate to your **`Core Services`** or **`Monitoring`** project.
3. Click **+ New Resource** $\rightarrow$ **Docker Compose**.
4. Name it: **`WUD-Update-Tracker`**.
5. In **Service details**, verify the network connects to the external **`coolify`** network (just like Grafana and Uptime Kuma).

### Step 2: Paste the Docker Compose Configuration

> **Important:** Current versions of `getwud/wud` enforce authentication at startup and will exit immediately if no administrator credentials are provided. Always set `WUD_AUTH_ADMIN_USER` and `WUD_AUTH_ADMIN_PASSWORD` (the older `WUD_AUTH_BASIC_*` variables are deprecated).

```yaml
services:
  wud:
    image: getwud/wud:latest
    container_name: wud
    restart: unless-stopped
    ports:
      # Mapped to 3002 on host because 3000 is used by Grafana/Docmost and 3001 by Uptime Kuma
      - "3002:3000"
    labels:
      # Enable digest tracking on WUD itself since it uses the mutable :latest tag
      - "wud.watch.digest=true"
    volumes:
      # Read-only mount so WUD can inspect containers without modifying anything
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /data/volumes/wud:/store
    environment:
      - TZ=Europe/Lisbon
      - WUD_LOG_LEVEL=info

      # 1. Mandatory Admin Account Bootstrap (used on first start to create the UI/API admin)
      - WUD_AUTH_ADMIN_USER=janus-admin
      - WUD_AUTH_ADMIN_PASSWORD=ReplaceWithAStrongPassword_123!

      # 2. Local Docker Watcher Schedule & Discovery
      # Runs daily at 08:00 AM (default if omitted is hourly: 0 * * * *)
      - WUD_WATCHER_LOCAL_CRON=0 8 * * *
      - WUD_WATCHER_LOCAL_WATCHBYDEFAULT=true

      # 3. Discord Update Alerts (remove if using Telegram only)
      - WUD_TRIGGER_DISCORD_JANUS_URL=https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN
      - WUD_TRIGGER_DISCORD_JANUS_BOTUSERNAME=Janus WUD
      - WUD_TRIGGER_DISCORD_JANUS_THRESHOLD=all
      - WUD_TRIGGER_DISCORD_JANUS_MODE=batch

      # 4. Telegram Update Alerts (uncomment if using Telegram)
      # - WUD_TRIGGER_TELEGRAM_JANUS_BOTTOKEN=123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ
      # - WUD_TRIGGER_TELEGRAM_JANUS_CHATID=-100123456789
      # - WUD_TRIGGER_TELEGRAM_JANUS_THRESHOLD=all
      # - WUD_TRIGGER_TELEGRAM_JANUS_MODE=batch
    networks:
      - coolify

networks:
  coolify:
    external: true
```

### Step 3: Configure Domain & Deploy
1. In Coolify's **Domains** field for the `wud` service, set:
   ```
   https://updates.your-domain.duckdns.org:3000
   ```
   *(Make sure `:3000` is specified so Traefik routes to WUD's internal container port `3000`, while direct LAN/WireGuard fallback works on `:3002`.)*
2. Click **Deploy**.
3. Open `https://updates.your-domain.duckdns.org` (or `http://192.168.1.68:3002`) and sign in with the `WUD_AUTH_ADMIN_USER` / `WUD_AUTH_ADMIN_PASSWORD` credentials you defined.

---

## 5. Fine-Tuning Watched Containers with Docker Labels

Because `WUD_WATCHER_LOCAL_WATCHBYDEFAULT=true` is enabled, WUD automatically tracks every container running on Janus. You can customize behavior per container using Docker labels inside any service's Compose configuration in Coolify:

| Label | Example Value | Purpose |
| :--- | :--- | :--- |
| `wud.watch` | `false` | Exclude a container from WUD checks (e.g., temporary runners, one-shot migration containers, or custom locally built images with no remote registry). |
| `wud.watch.digest` | `true` | Track image manifest **digests** for mutable tags like `:latest` or `:stable` (essential for services like `netdata/netdata:stable` or `ollama/ollama:latest`). |
| `wud.tag.include` | `^\d+\.\d+\.\d+$` | Regex filter restricting update alerts to clean SemVer tags (prevents `-rc`, `-alpha`, or `-alpine` suffix mismatches). |
| `wud.tag.exclude` | `(?i)(rc\|beta\|alpha\|dev)` | Ignore pre-release tags. |

### Recommended Exclusions for Project Janus
For containers built locally from your own GitHub repos (like **JanusDeck** or custom mini-projects deployed via Coolify CI/CD), WUD cannot look up a public Docker Hub image unless you push to a registry. Add the following label to those Compose definitions to prevent registry lookup warnings:

```yaml
labels:
  - "wud.watch=false"
```

For services running mutable `:latest` or `:stable` tags (like `louislam/uptime-kuma:2` or `netdata/netdata:stable`), add digest watching so WUD detects when the tag's underlying image is rebuilt:

```yaml
labels:
  - "wud.watch.digest=true"
```

---

## 6. Optional: Avoiding Docker Hub Rate Limits

Docker Hub enforces anonymous pull/manifest-check rate limits per IP. If you run 15–20+ containers and scan frequently:
1. Keep `WUD_WATCHER_LOCAL_CRON=0 8 * * *` (once per day) or `0 */6 * * *` (every 6 hours) instead of every few minutes.
2. Optionally add a free Docker Hub Personal Access Token (PAT) to WUD's `environment:` block:
   ```yaml
   - WUD_REGISTRY_HUB_PUBLIC_LOGIN=your_dockerhub_username
   - WUD_REGISTRY_HUB_PUBLIC_PASSWORD=your_dockerhub_pat_token
   ```

---

## 7. Optional: Prometheus & Grafana Integration

WUD exposes native Prometheus metrics at `http://wud:3000/metrics` on the shared `coolify` Docker network (metrics include `wud_containers` with `update_available="true"`/`"false"`, current tag, and target result tag).

1. Because WUD enforces authentication across endpoints, create a dedicated **read-only (`ro`)** user in the WUD Web UI (**Configuration** $\rightarrow$ **Users**) for Prometheus scraping (e.g., `prometheus-ro`).
2. Add a new scrape job to `/data/volumes/prometheus/config/prometheus.yml` ([Guide 16](16-observability-grafana-prometheus-cadvisor.md)):
   ```yaml
   - job_name: 'wud'
     metrics_path: '/metrics'
     basic_auth:
       username: 'prometheus-ro'
       password: 'YourReadOnlyUserPassword'
     static_configs:
       - targets: ['wud:3000']
   ```
3. Reload Prometheus configuration without restarting:
   ```bash
   curl -X POST http://192.168.1.68:9090/-/reload
   ```
4. Useful PromQL query for Grafana stat panels (number of containers with pending updates):
   ```promql
   count(wud_containers{update_available="true"})
   ```

---

## 8. Safe Update Workflow with Coolify

When WUD sends a Discord/Telegram notification that an update is available for Service X:

1. **Check Breaking Changes:** Review the service's GitHub Releases / changelog (especially for stateful services like `postgres`, `rabbitmq`, `glitchtip`, or `minio`).
2. **Verify Recent Backup:** Ensure your daily backup ran cleanly (or trigger `janus backup` from [Guide 20](20-janus-unified-cli.md)).
3. **Update in Coolify:**
   * If pinned to a version tag (e.g., `v1.2.0` $\rightarrow$ `v1.3.0`), update the tag in Coolify's Compose editor and click **Deploy**.
   * If using a rolling tag (e.g., `:2` or `:latest`), click **Redeploy** (with Pull Latest Image) in Coolify.
4. **Reclaim Old Images:** Run `janus update` ([Guide 20](20-janus-unified-cli.md)) or `docker image prune -f` periodically to clear superseded layers from the SSD pool.

---

## 9. Verification & Troubleshooting Checklist

* [ ] Check container logs after first deploy to confirm authentication and watcher startup:
  ```bash
  janus logs wud
  # or: docker logs -n 50 wud
  ```
* [ ] Confirm all expected containers appear in `https://updates.your-domain.duckdns.org`.
* [ ] Trigger a manual watcher scan from the WUD Web UI (**Watchers** $\rightarrow$ **local** $\rightarrow$ **Watch now**) and verify your test alert arrives in Discord/Telegram.
* [ ] Verify `WUD_LOG_LEVEL` shows zero permission errors on `/store` or `/var/run/docker.sock`.
* [ ] *(Optional)* Add `https://updates.your-domain.duckdns.org` to your **JanusDeck** service directory ([Guide 11](11-janus-deck-command-center.md)).
