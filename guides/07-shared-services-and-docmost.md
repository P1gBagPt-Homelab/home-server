# Guide 07: Shared Services (PostgreSQL, Redis, Docmost & Nginx with DuckDNS)

You have chosen **Option A: Free DuckDNS Subdomains**. 

This gives you clean, professional URLs (e.g., `https://docs.your-domain.duckdns.org`) with **valid SSL certificates (HTTPS)** across all your devices, completely free and without editing `hosts` files.

---

## 1. How DuckDNS Wildcard Routing Works

When you create a domain on DuckDNS (e.g., `myhomelab.duckdns.org`), DuckDNS automatically enables **wildcard resolution (`*.myhomelab.duckdns.org`)**.

This means any subdomain you invent automatically points to your home server:
* `docs.myhomelab.duckdns.org` ──> **Docmost Wiki**
* `dockge.myhomelab.duckdns.org` ──> **Dockge Container Manager**
* `proxy.myhomelab.duckdns.org` ──> **Nginx Proxy Manager Admin**
* `app1.myhomelab.duckdns.org` ──> **Your Custom Mini Project**

When connected through your **WireGuard VPN** (or on your home Wi-Fi), Nginx intercepts these names and directs traffic to the correct internal container.

---

## 2. Setting Up the Shared Docker Network

Create the internal Docker network so containers communicate privately:

```bash
docker network create server-net
```

---

## 3. The Core Infrastructure Stack (`docker-compose.yml`)

Create the directory structure and open the compose file:

```bash
mkdir -p /data/compose/infrastructure /data/volumes/postgres /data/volumes/redis /data/volumes/docmost /data/volumes/npm-data /data/volumes/npm-letsencrypt
cd /data/compose/infrastructure
nano docker-compose.yml
```

Paste the stack configuration (replace `your-domain.duckdns.org` with your actual DuckDNS subdomain):

```yaml
services:
  # 1. Nginx Proxy Manager (Reverse Proxy & Free SSL)
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "81:81"     # Web Admin Dashboard
      - "443:443"
    volumes:
      - /data/volumes/npm-data:/data
      - /data/volumes/npm-letsencrypt:/etc/letsencrypt
    networks:
      - server-net

  # 2. Shared PostgreSQL Database Tier
  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: ChooseAStrongMasterPassword
    volumes:
      - /data/volumes/postgres:/var/lib/postgresql/data
    networks:
      - server-net
    ports:
      - "127.0.0.1:5432:5432"

  # 3. Shared Redis Caching Tier
  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ChooseAStrongRedisPassword
    volumes:
      - /data/volumes/redis:/data
    networks:
      - server-net
    ports:
      - "127.0.0.1:6379:6379"

  # 4. Docmost: Centralized Documentation Wiki
  docmost:
    image: docmost/docmost:latest
    container_name: docmost
    restart: unless-stopped
    depends_on:
      - postgres
      - redis
    environment:
      - APP_URL=https://docs.your-domain.duckdns.org
      - APP_SECRET=generate_32_random_characters_secret_here
      - DATABASE_URL=postgresql://admin:ChooseAStrongMasterPassword@postgres:5432/docmost?sslmode=disable
      - REDIS_URL=redis://:ChooseAStrongRedisPassword@redis:6379/0
    volumes:
      - /data/volumes/docmost:/app/data/storage
    networks:
      - server-net

networks:
  server-net:
    external: true
```

### Launch the Stack:
```bash
docker compose up -d
```

---

## 4. Initialize the Docmost Database

Create the `docmost` database in the shared PostgreSQL container:

```bash
docker exec -it postgres psql -U admin -c "CREATE DATABASE docmost;"
docker restart docmost
```

---

## 5. Free Wildcard SSL Certificate via Let's Encrypt

To get real HTTPS (green padlock) with zero certificate warnings:

1. Open Nginx Proxy Manager at `http://192.168.1.150:81`.
2. Log in (`admin@example.com` / `changeme`, then set your admin account).
3. Navigate to **SSL Certificates > Add SSL Certificate > Let's Encrypt**:
   * **Domain Names**: `your-domain.duckdns.org` and `*.your-domain.duckdns.org`
   * Check: **Use a DNS Challenge**
   * **DNS Provider**: Select **DuckDNS**
   * In the configuration box, enter your DuckDNS Token:
     ```ini
     dns_duckdns_token = your-duckdns-token-here
     ```
   * Agree to the Let's Encrypt Terms of Service and click **Save**.
4. Nginx will automatically generate a wildcard SSL certificate that covers all your subdomains and renews automatically every 90 days.

---

## 6. Creating Proxy Hosts in Nginx

Go to **Hosts > Proxy Hosts > Add Proxy Host** to configure your web routes:

### Route 1: Docmost Wiki
* **Domain Names**: `docs.your-domain.duckdns.org`
* **Scheme**: `http`
* **Forward Hostname / IP**: `docmost`
* **Forward Port**: `3000`
* Check: **Block Common Exploits**, **Websockets Support**
* Under the **SSL** tab:
  * Select your Wildcard Certificate.
  * Check **Force SSL** and **HTTP/2 Support**.
* Click **Save**.

### Route 2: Dockge Container Manager
* **Domain Names**: `dockge.your-domain.duckdns.org`
* **Scheme**: `http`
* **Forward Hostname / IP**: `dockge` (or your host IP `192.168.1.150`)
* **Forward Port**: `5001`
* Under the **SSL** tab: Select your Wildcard Certificate, enable **Force SSL**.
* Click **Save**.

---

## 7. Connecting Mini Projects to Shared Postgres & Redis

When building a mini project in `/data/compose/projects/<project-name>/docker-compose.yml`:

```yaml
services:
  my-app:
    build: .
    container_name: my-app
    restart: unless-stopped
    environment:
      # Connect to Postgres & Redis by their container names:
      - DATABASE_URL=postgres://admin:ChooseAStrongMasterPassword@postgres:5432/my_app_db
      - REDIS_URL=redis://:ChooseAStrongRedisPassword@redis:6379/1
    networks:
      - server-net

networks:
  server-net:
    external: true
```

* Each project simply attaches to `server-net`.
* No redundant database containers to maintain.
* Easily accessible from anywhere securely over WireGuard at `https://myapp.your-domain.duckdns.org`.
