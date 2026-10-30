# 04. Remote Access & WireGuard VPN Setup

To manage your on-demand server securely without relying on third-party relay networks (like Tailscale), you will deploy a self-hosted **WireGuard VPN** directly on your Linux Server OS.

---

## 1. Network Requirements & Prerequisites

Before setting up WireGuard, ensure your home network satisfies these conditions:

1. **Public IP / CGNAT Check**:
   * Log into your home router and compare its WAN IP address with what you see on [whatismyipaddress.com](https://whatismyipaddress.com).
   * If both match (and the WAN IP does **not** begin with `100.64.x.x` through `100.127.x.x`), you have a real public IP and can host WireGuard directly.
   * If your ISP uses CGNAT (Carrier-Grade NAT), incoming ports cannot be opened without requesting a public IPv4 from your ISP or using an IPv6 address.
2. **Dynamic DNS (DDNS)**:
   * Most residential internet connections change IP addresses periodically.
   * Register a free DDNS hostname (e.g., [DuckDNS](https://www.duckdns.org) or [No-IP](https://www.noip.com)) so your WireGuard client always finds your home router (e.g., `myserver.duckdns.org`).
3. **Router Port Forwarding**:
   * Forward **UDP port 51820** from your home router to your Linux Server's static internal local IP (e.g., `192.168.1.150`).

---

## 2. Deploying WireGuard on the Server

The cleanest, most maintainable method is running **`wg-easy`** via Docker on your Linux Server. It provides an embedded WireGuard server with a responsive web dashboard to generate client `.conf` files and mobile QR codes in seconds.

### `docker-compose.yml` for WireGuard Easy:

```yaml
services:
  wg-easy:
    image: ghcr.io/wg-easy/wg-easy:latest
    container_name: wg-easy
    restart: unless-stopped
    environment:
      # Your Dynamic DNS domain or public IP
      - WG_HOST=your-ddns-subdomain.duckdns.org
      # Web UI Password (bcrypt hashed or plain text)
      - PASSWORD=ChooseAStrongPassword
      # WireGuard Port
      - WG_PORT=51820
      # Web UI Port
      - WG_DEVICE=eth0
      - WG_DEFAULT_ADDRESS=10.8.0.x
      - WG_DEFAULT_DNS=1.1.1.1,8.8.8.8
      - WG_ALLOWED_IPS=192.168.1.0/24, 10.8.0.0/24
    volumes:
      - /etc/wireguard-data:/etc/wireguard
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

### Launching:
```bash
sudo docker compose up -d
```
1. Open your browser to `http://<server-local-ip>:51821`.
2. Log in with your password.
3. Click **"New Client"** (e.g., *Phone*, *Laptop*).
4. Scan the QR code with the official **WireGuard app** on iOS/Android, or download the configuration file for your laptop.

---

## 3. Remote Operations Workflow (On-Demand Use)

Once WireGuard is configured, your on-demand lifecycle looks like this:

```mermaid
sequenceDiagram
    autonumber
    actor User as User (Away from Home)
    participant Plug as Smart Outlet App
    participant PC as Home Server (Linux)
    participant WG as WireGuard VPN
    
    User->>Plug: Turn Outlet ON
    Plug->>PC: Delivers AC Power (BIOS triggers boot)
    PC->>PC: Boots into Linux & starts Docker / WireGuard
    User->>WG: Connect to WireGuard via Phone/Laptop
    Note over User,PC: Secure tunnel established (10.8.0.x)
    User->>PC: Access Nextcloud / Plex / Samba / SSH
    Note over User,PC: Done using server
    User->>PC: Run: ssh user@10.8.0.1 "sudo poweroff"
    PC->>PC: Gracefully flushes disks & powers off
    User->>Plug: Turn Outlet OFF (cuts standby power)
```

---

## 4. Remote Graceful Shutdown over WireGuard

When you finish your remote session, execute a clean shutdown through the encrypted tunnel:

```bash
# From your laptop terminal or mobile SSH client (e.g. Termius):
ssh user@10.8.0.1 "sudo systemctl poweroff"
```

Once the connection drops and the machine stops responding to ping, switch the smart plug **OFF** in your smart home app.
