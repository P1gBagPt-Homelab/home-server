# Guide 06: WireGuard VPN & Remote Access Gateway

> **Status**: ✅ **Fully Deployed & Operational on Project Janus**  
> * **DDNS Domain**: `janus-lab.duckdns.org` (DuckDNS Cron sync active).
> * **VPN Gateway**: `ghcr.io/wg-easy/wg-easy:14` (`51820/udp`, Dashboard on `http://192.168.1.68:51821`).
> * **Router Forwarding**: UDP 51820, TCP 80, TCP 443 -> `192.168.1.68` (Vodafone Smart Router).

This guide walks you through setting up **Dynamic DNS (DuckDNS)**, forwarding the WireGuard UDP port on your home router, and deploying **`wg-easy`** (WireGuard VPN with a web dashboard) so you can connect to Project Janus and Coolify securely from anywhere.

---

## Step 1: Set Up Free Dynamic DNS (DuckDNS)

Since home residential IP addresses periodically change, Dynamic DNS gives your home server a permanent hostname (`janus-lab.duckdns.org`):

1. Go to [https://www.duckdns.org](https://www.duckdns.org) and log in (via GitHub, Google, or Reddit).
2. Under **Domains**, register your domain `janus-lab` and click **add domain**.
3. Note your **DuckDNS Token** displayed at the top of the page.

---

## Step 2: Router Port Forwarding & Static IP (Vodafone Smart Router)

To allow remote VPN access and web traffic through your home router:

1. **Log in to Router Admin Panel**:
   * Open your browser and navigate to `http://192.168.1.1`.
2. **Switch to Expert Mode**:
   * In the top-right corner dropdown, select **`Modo Expert`**.
3. **Configure Port Mapping (Port Forwarding)**:
   * In the top navigation bar, click **`Internet`** → **`Port Mapping`**.
   * In the upper **Port Mapping** section, click the purple **`(+)`** button to create the rules:
     * **WireGuard Gateway** (VPN):
       * **Nome**: `WireGuard` | **Protocolo**: `UDP` | **Equipamento**: `janus` (`192.168.1.68`) | **Portas**: `51820`
     * **Traefik Web & SSL Challenges** (Coolify):
       * **Nome**: `Traefik-HTTP` | **Protocolo**: `TCP` | **Equipamento**: `janus` (`192.168.1.68`) | **Portas**: `80`
     * **Traefik Encrypted HTTPS** (Web Services & Wiki):
       * **Nome**: `Traefik-HTTPS` | **Protocolo**: `TCP` | **Equipamento**: `janus` (`192.168.1.68`) | **Portas**: `443`
   * Click the purple **Confirmar** button at the bottom to save all rules to the router.
4. **Ensure Static IP Reservation**:
   * In the top menu, go to **`Definições`** → **`Rede Local (LAN)`** (or click the `(i)` info icon on `janus` from the **`Visão geral`** dashboard) to verify that `janus` is bound to `192.168.1.68` permanently.

---

## Step 3: Deploy WireGuard Gateway (`wg-easy`)

Connect via SSH to your server (`ssh daniel@<your-server-ip>`):

1. **Generate your admin password hash**:
   Choose a strong admin password and generate its bcrypt hash:
   ```bash
   docker run --rm -it ghcr.io/wg-easy/wg-easy wgpw 'YourChosenPassword'
   ```
   *(Keep your plaintext password handy for web login, and copy the full output line `PASSWORD_HASH='$2a$12$...'`)*

2. **Store the hash safely in a `.env` file**:
   Using a `.env` file ensures Docker Compose doesn't corrupt the `$` signs inside the bcrypt hash:
   ```bash
   mkdir -p /data/compose/wireguard /data/volumes/wireguard
   cd /data/compose/wireguard
   nano .env
   ```
   Paste the line output by `wgpw`:
   ```env
   PASSWORD_HASH='$2a$12$your_exact_hash_from_wgpw'
   ```

3. **Create the compose configuration**:
   ```bash
   nano docker-compose.yml
   ```

Paste the following `docker-compose.yml`:

```yaml
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:14
    container_name: wg-easy
    restart: unless-stopped
    environment:
      # Your DuckDNS Domain
      - WG_HOST=janus-lab.duckdns.org
      # Loaded cleanly from .env (no character escaping headaches)
      - PASSWORD_HASH=${PASSWORD_HASH}
      - WG_PORT=51820
      - WG_DEFAULT_ADDRESS=10.8.0.x
      - WG_DEFAULT_DNS=1.1.1.1,8.8.8.8
      - WG_ALLOWED_IPS=192.168.1.0/24, 10.8.0.0/24
    volumes:
      - /data/volumes/wireguard:/etc/wireguard
    ports:
      - "51820:51820/udp"
      - "51821:51821/tcp"
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv4.ip_forward=1
```

Save and exit (`Ctrl + O`, `Enter`, `Ctrl + X`), then start WireGuard:
```bash
docker compose up -d
```

Verify that the container is healthy:
```bash
docker ps
```

---

## Step 4: Configure WireGuard Clients (Phone & Laptop)

1. Find your server's local IP address if needed (`hostname -I`).
2. Open your browser on any home device and navigate to:  
   👉 `http://<YOUR_SERVER_IP>:51821`  *(Make sure it is `http://` and not `https://`)*
3. Log in using your **chosen plaintext password** (the one you passed to `wgpw`).
4. **Add Mobile Phone Client**:
   * Click **"New Client"**, name it `Phone`, and click **Create**.
   * Click the **QR code** icon next to `Phone`.
   * Open the official **WireGuard App** on iOS or Android.
   * Tap **"+" > Scan QR Code**, scan the screen, name the tunnel `Janus`, and save.
5. **Add Laptop Client**:
   * Click **"New Client"**, name it `Laptop`.
   * Click **Download** to get the `.conf` profile.
   * Import it into the official WireGuard desktop client.

---

## Step 5: Verify Remote Tunnel & Access to Coolify

Now test your complete encrypted tunnel from outside your home network:

1. **Disconnect your phone from home Wi-Fi** (switch to cellular 4G/5G).
2. Open the **WireGuard app** on your phone and toggle **"Janus"** ON.
3. Open your phone's browser and navigate to:
   * **Coolify PaaS Dashboard**: `http://10.8.0.1:8000` *(You can now manage all your mini-projects and databases from anywhere!)*
   * **WireGuard Admin**: `http://10.8.0.1:51821`
4. Test mobile SSH via Termius:
   ```bash
   ssh daniel@10.8.0.1
   ```

You now have a private, bank-grade encrypted tunnel directly into Project Janus from anywhere in the world!
