# Guide 06: WireGuard VPN & Core Infrastructure Setup

This guide walks you through setting up **Dynamic DNS (DuckDNS)**, deploying your self-hosted **WireGuard VPN (`wg-easy`)**, and launching **Dockge** (the Docker Compose manager for your mini-projects).

---

## Step 1: Set Up Free Dynamic DNS (DuckDNS)

Since home residential IP addresses periodically change, Dynamic DNS gives your home server a permanent hostname (e.g., `daniel-server.duckdns.org`):

1. Go to [https://www.duckdns.org](https://www.duckdns.org) and log in (via GitHub, Google, or Reddit).
2. Under **Domains**, pick a unique subdomain (e.g., `janus-server` or `janus-daniel`) and click **add domain**.
3. Note your **DuckDNS Token** displayed at the top of the page.

---

## Step 2: Router Port Forwarding & Static IP

To allow encrypted WireGuard VPN packets through your home router:

1. Log into your home router's admin panel (usually `192.168.1.1` or `192.168.1.254`).
2. **Assign Static DHCP Lease**:
   * Find your Ubuntu Server (MAC address of your Intel I219-V port) and bind it to a fixed local IP (e.g., `192.168.1.150`).
3. **Port Forwarding Rule**:
   * **Service Name**: `WireGuard`
   * **Protocol**: **`UDP`** *(Crucial: must be UDP, not TCP)*
   * **External / WAN Port**: `51820`
   * **Internal / LAN Port**: `51820`
   * **Internal IP**: `192.168.1.150` (your server's IP)
4. Save and apply router settings.

---

## Step 3: Deploy Core Infrastructure Stack (WireGuard + Dockge)

Connect via SSH to your server (`ssh daniel@192.168.1.150`) and create the core infrastructure directory:

```bash
mkdir -p /data/compose/infrastructure /data/volumes/wireguard /data/volumes/dockge /data/compose/projects
cd /data/compose/infrastructure
nano docker-compose.yml
```

Paste the following `docker-compose.yml`:

```yaml
services:
  # WireGuard VPN with Web Dashboard
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wg-easy
    restart: unless-stopped
    environment:
      # Your DuckDNS Domain
      - WG_HOST=janus-server.duckdns.org
      # Set a strong password for the WireGuard Web Admin
      - PASSWORD=YourSecureAdminPassword
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

  # Dockge: Web UI for Managing Docker Compose Mini-Projects
  dockge:
    image: louislam/dockge:latest
    container_name: dockge
    restart: unless-stopped
    ports:
      - "5001:5001"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /data/volumes/dockge:/app/data
      - /data/compose/projects:/data/compose/projects
    environment:
      - DOCKGE_STACKS_DIR=/data/compose/projects
```

Save and exit (`Ctrl + O`, `Enter`, `Ctrl + X`), then start the containers:
```bash
docker compose up -d
```

---

## Step 4: Configure WireGuard Clients (Phone & Laptop)

1. Open your browser on any home device and go to:  
   👉 `http://192.168.1.150:51821`
2. Log in using the password you set in the compose file.
3. **Add Mobile Phone Client**:
   * Click **"New Client"**, name it `Phone`, and click **Create**.
   * Click the **QR code** icon next to `Phone`.
   * Open the official **WireGuard App** on iOS or Android.
   * Tap **"+" > Scan QR Code**, scan the screen, name the tunnel `Home`, and save.
4. **Add Laptop Client**:
   * Click **"New Client"**, name it `Laptop`.
   * Click **Download** to get the `.conf` profile.
   * Import it into the WireGuard desktop client.

---

## Step 5: The Ultimate Remote Test

Now test your complete on-demand lifecycle from outside your local network:

1. **Disconnect phone from home Wi-Fi** (switch to 4G/5G mobile data).
2. Open the **WireGuard app** on your phone and toggle **"Home"** ON.
3. Open your phone's browser and go to:
   * **Dockge UI**: `http://10.8.0.1:5001` *(You can now manage all your mini-projects from anywhere!)*
   * **WireGuard Admin**: `http://10.8.0.1:51821`
4. Test mobile SSH via Termius or Prompt:
   ```bash
   ssh daniel@10.8.0.1
   ```

---

## 🚀 Complete Setup Finished!

Your hybrid setup is now 100% architected and documented:
* **To Game**: Press the power button or wireless desk button -> Select Windows in GRUB -> 100% native gaming.
* **To Use Server Remotely**: Tap "Power On" in Smart Life -> Boots to Ubuntu Server -> Connect WireGuard on phone/laptop -> Access projects -> Tap "Power Off" in Smart Life for a safe shutdown.
