# Guide 19: Network Hardening — Transition to Zero Public Exposure (DNS-01 SSL & WireGuard-Only)

> **Status**: 🛡️ **Active Hardening Reconfiguration Playbook**  
> * **Objective**: Eliminate all public web attack vectors (close Router Ports 80 & 443) while maintaining automated Let's Encrypt SSL padlocks via DuckDNS DNS-01 challenges.
> * **Security Level**: **100% Private Homelab** — reachable *only* via local LAN (`192.168.1.0/24`) and encrypted WireGuard VPN (`10.8.0.0/24`).
> * **Router Forwarding**: Only UDP 51820 (WireGuard) remains open. Zero exposed HTTP/HTTPS ports.

---

## 1. Why We Are Doing This (The Threat Model)

In the initial bootstrap phase, home routers typically forward **Port 80 (HTTP)** and **Port 443 (HTTPS)** so Let's Encrypt can reach Traefik via the **HTTP-01 ACME challenge** to issue certificates.

### The Problem with Port 80 & 443 Forwarding:
* Automated internet scanners (Censys, Shodan, malicious botnets) constantly probe all open IPv4 addresses on ports 80 and 443.
* If any application hosted on Coolify (Docmost, MinIO, GlitchTip, RabbitMQ, custom APIs) has an unpatched zero-day vulnerability or weak authentication, it can be discovered and attacked directly from the public internet.

### The Solution: DuckDNS DNS-01 Challenge:
Instead of Let's Encrypt knocking on your home server's front door (Port 80):
1. **Traefik contacts DuckDNS directly** via its secure API using your `DUCKDNS_TOKEN`.
2. Traefik creates a temporary TXT verification record on `janus-lab.duckdns.org`.
3. Let's Encrypt verifies the TXT record directly with DuckDNS's cloud servers.
4. Let's Encrypt issues your wildcard SSL certificate (`*.janus-lab.duckdns.org`).

**Result**: You receive valid, trusted HTTPS certificates with green padlocks for all your services **without opening a single web port on your router**.

```
                       ┌──────────────────────────────────────────────┐
                       │           VODAFONE SMART ROUTER              │
INTERNET               │                                              │
                       │   ❌ Port 80 (HTTP)   --> REMOVED / CLOSED   │
Web Scanners & Bots   ┼─────────────────────────────────────────────►│
                       │   ❌ Port 443 (HTTPS) --> REMOVED / CLOSED   │
Zero-Day Crawlers      ┼─────────────────────────────────────────────►│
                       │                                              │
                       │   🔒 Port 51820 (WireGuard UDP)              │
You (Phone / Laptop)   ┼─────────────────────────────────────────────►│
                       └──────────────────────┬───────────────────────┘
                                              │
                                              ▼
                                 [Ubuntu Server (janus)]
                                 • Coolify (Traefik Proxy)
                                 • JanusDeck (`control.janus-lab`)
                                 • Vaultwarden (`vault.janus-lab`)
                                 • Docmost Wiki (`docs.janus-lab`)
                                 • MinIO, RabbitMQ, GlitchTip
```

---

## 2. Prerequisites & Safety Check

Before touching any settings, verify:
1. **WireGuard VPN is Working**: Confirm that you can connect to `janus` from your phone or laptop using the WireGuard client and reach `http://192.168.1.68:8000` or `http://10.8.0.1:8000`.
2. **DuckDNS Token**: Log in to [DuckDNS.org](https://www.duckdns.org) and copy your **DuckDNS Token** (a 36-character UUID string like `a1b2c3d4-e5f6-7890-abcd-ef1234567890`).

---

## 3. Step 1: Configure Traefik in Coolify for DuckDNS DNS-01

Coolify manages Traefik via Docker Compose at `/data/coolify/proxy`. We will configure Traefik to use the Lego DuckDNS DNS provider.

### Option A: Via Terminal / SSH (Recommended & Fastest)

1. Connect to your server via SSH:
   ```bash
   ssh daniel@192.168.1.68
   ```

2. Open the proxy environment file `/data/coolify/proxy/.env`:
   ```bash
   sudo nano /data/coolify/proxy/.env
   ```
   Add your DuckDNS token at the bottom of the file (replace with your real token):
   ```env
   DUCKDNS_TOKEN=your_actual_duckdns_token_here
   ```
   Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

3. Inspect the Traefik Docker Compose file:
   ```bash
   sudo nano /data/coolify/proxy/docker-compose.yml
   ```

4. In the `traefik` service definition:
   * **Under `environment:`**, ensure `DUCKDNS_TOKEN` is passed:
     ```yaml
     environment:
       - DUCKDNS_TOKEN=${DUCKDNS_TOKEN}
     ```
   * **Under `command:`**, locate the `--certificatesresolvers.letsencrypt.acme...` lines.
     Replace any HTTP challenge lines with the DNS challenge configuration:
     ```yaml
     command:
       - "--ping=true"
       - "--ping.entrypoint=http"
       - "--api.dashboard=true"
       - "--icons=true"
       - "--entrypoints.http.address=:80"
       - "--entrypoints.https.address=:443"
       - "--entrypoints.http.http.redirections.entrypoint.to=https"
       - "--entrypoints.http.http.redirections.entrypoint.scheme=https"
       - "--providers.docker=true"
       - "--providers.docker.exposedbydefault=false"
       - "--certificatesresolvers.letsencrypt.acme.email=your-email@example.com"
       - "--certificatesresolvers.letsencrypt.acme.storage=/traefik/acme.json"
       - "--certificatesresolvers.letsencrypt.acme.dnschallenge=true"
       - "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=duckdns"
       - "--certificatesresolvers.letsencrypt.acme.dnschallenge.delaybeforecheck=30"
       - "--certificatesresolvers.letsencrypt.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53"
     ```
   Save and exit (`Ctrl+O`, `Enter`, `Ctrl+X`).

5. Recreate the Coolify proxy container with Docker Compose to apply the changes:
   ```bash
   cd /data/coolify/proxy
   docker compose up -d --force-recreate
   ```
   *(Note: `docker restart coolify-proxy` will NOT reload changes from `docker-compose.yml`; you must use `docker compose up -d`).*

6. Monitor the Traefik proxy startup logs to ensure there are no syntax errors:
   ```bash
   docker logs --tail 50 -f coolify-proxy
   ```
   *(Look for lines confirming ACME DNS challenge initialization. Press `Ctrl+C` to exit logs).*

---

### Option B: Via Coolify Web Dashboard

If you prefer configuring via the web UI:
1. Open Coolify: `http://192.168.1.68:8000`.
2. Go to **Servers** → **localhost** → **Proxy**.
3. Under **Environment Variables**, add:
   * Key: `DUCKDNS_TOKEN`
   * Value: `your_actual_duckdns_token_here`
4. Under **Configuration**, edit the Traefik arguments to add:
   * `--certificatesresolvers.letsencrypt.acme.dnschallenge=true`
   * `--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=duckdns`
   * `--certificatesresolvers.letsencrypt.acme.dnschallenge.delaybeforecheck=30`
   * `--certificatesresolvers.letsencrypt.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53`
5. Click **Save & Restart Proxy**.

---

## 4. Step 2: Verify SSL Issuance Internally

Before touching your router, verify that Traefik successfully generates certificates via DNS-01:

1. Open your browser on your LAN (or while connected to WireGuard).
2. Visit:
   * `https://docs.janus-lab.duckdns.org`
   * `https://control.janus-lab.duckdns.org`
3. Click the padlock icon in your browser address bar:
   * Certificate status should read: **Valid** (issued by **Let's Encrypt Authority**).
   * Connection should show **Secure (TLS 1.3)**.

---

## 5. Step 3: Remove Port 80 & 443 on Vodafone Smart Router

Now that Traefik validates certificates through the cloud via DuckDNS without needing inbound traffic, **delete the public web forwardings**:

1. Open your browser and log in to your router at `http://192.168.1.1`.
2. Ensure you are in **`Modo Expert`** (top right dropdown).
3. Navigate to **`Internet`** → **`Port Mapping`**.
4. In the list of active port forwarding rules:
   * Find **`Traefik-HTTP`** (Port 80 TCP) → Click the trash / delete icon `🗑️`.
   * Find **`Traefik-HTTPS`** (Port 443 TCP) → Click the trash / delete icon `🗑️`.
   * **DO NOT TOUCH** the **`WireGuard`** rule (`51820 UDP` → `192.168.1.68`). This is your secure entry gate!
5. Click the purple **Confirmar** button to apply the changes to the router.

---

## 6. Step 4: Verification & Penetration Test (Zero-Exposure Proof)

Run these two quick tests to confirm your new security posture:

### Test 1: From the Outside (Public Internet)
1. On your smartphone, **disconnect from home Wi-Fi** and **disconnect from WireGuard** (use 4G / 5G cellular data only).
2. Open your mobile browser and navigate to:
   * `https://docs.janus-lab.duckdns.org`
3. **Expected Result**: The browser should fail to load and display:  
   `"This site can't be reached"` or `"Connection timed out"`.
   *(This proves that no one on the public internet can touch your server).*

4. Check your public IP with an online port scanner (e.g., [CanYouSeeMe.org](https://canyouseeme.org) or [YouGetSignal](https://www.yougetsignal.com/tools/open-ports/)):
   * Port `80`: **Closed / Stealth**
   * Port `443`: **Closed / Stealth**

### Test 2: From the Inside (WireGuard VPN)
1. On your smartphone (still on 4G / 5G), open the **WireGuard** app.
2. Toggle the `Janus` tunnel **ON**.
3. Refresh `https://docs.janus-lab.duckdns.org` or `https://control.janus-lab.duckdns.org`.
4. **Expected Result**: The page loads instantly with a **valid green SSL padlock**!

---

## 7. Emergency Rollback Plan

If you ever need to temporarily re-open HTTP-01 verification:
1. Log in to `http://192.168.1.1`.
2. Go to **`Internet`** → **`Port Mapping`**.
3. Re-add Port 80 and 443 TCP pointing to `192.168.1.68` and click **Confirmar**.
4. The system immediately reverts to standard HTTP verification.
