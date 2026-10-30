# Guide 07: Shared Services (PostgreSQL, Redis, Docmost & Nginx)

This guide walks you through deploying your **shared database and caching tier** (PostgreSQL 16 & Redis 7), your centralized documentation wiki (**Docmost**), and **Nginx Proxy Manager** for domain routing without buying a domain.

---

## 1. Domain Strategy: Clean Hostnames for Free

You do not need to purchase a public domain. You can use free **`.home`** or **`.local`** virtual hosts, or your free **DuckDNS** subdomain:

* **Docmost Wiki**: `http://docs.home` (or `http://docs.your-domain.duckdns.org`)
* **Dockge Manager**: `http://dockge.home`
* **Nginx Admin**: `http://proxy.home` (Port 81)

When connected to your home network or through **WireGuard VPN**, these URLs resolve directly to your server.

---

## 2. Setting Up the Shared Docker Network

To allow mini projects to securely communicate with PostgreSQL and Redis without exposing database ports to the open internet, create a dedicated Docker bridge network:

```bash
docker network create server-net
```

Any container attached to `server-net` can reach:
* **PostgreSQL** via hostname: `postgres:5432`
* **Redis** via hostname: `redis:6379`
* **Nginx** via hostname: `nginx-proxy-manager:80`

---

## 3. The Core Stack Compose File

On your server, create the directory and edit the infrastructure compose file:

```bash
mkdir -p /data/compose/infrastructure /data/volumes/postgres /data/volumes/redis /data/volumes/docmost /data/volumes/npm-data /data/volumes/npm-letsencrypt
cd /data/compose/infrastructure
nano docker-compose.yml
```

Paste the unified infrastructure stack:

```yaml
services:
  # 1. Reverse Proxy for Clean Domain Routing
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "81:81"     # Web Management Dashboard
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
      - "127.0.0.1:5432:5432" # Accessible locally or via internal Docker network

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
      - APP_URL=http://docs.home # or http://docs.your-domain.duckdns.org
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

## 4. Initializing the Docmost Database

Before Docmost starts for the first time, create its database in the shared PostgreSQL container:

```bash
docker exec -it postgres psql -U admin -c "CREATE DATABASE docmost;"
docker restart docmost
```

---

## 5. Routing `docs.home` in Nginx Proxy Manager

1. Open your browser and go to `http://192.168.1.150:81`.
2. Default login credentials:
   * **Email**: `admin@example.com`
   * **Password**: `changeme`
   *(You will be prompted to change these immediately).*
3. Go to **Hosts > Proxy Hosts > Add Proxy Host**:
   * **Domain Names**: `docs.home` (or `docs.your-domain.duckdns.org`)
   * **Scheme**: `http`
   * **Forward Hostname / IP**: `docmost`
   * **Forward Port**: `3000`
   * Check: **Block Common Exploits** and **Websockets Support**.
4. Click **Save**.

### How Your Computer Resolves `docs.home`:
* **On Windows**: Open `C:\Windows\System32\drivers\etc\hosts` (as Administrator) and add:
  ```
  192.168.1.150 docs.home dockge.home
  ```
* **Over WireGuard**: In `wg-easy`, set DNS to resolve directly, or access via `http://docs.your-domain.duckdns.org`.

---

## 6. How Your Mini Projects Consume Shared Postgres & Redis

When building a new mini project in `/data/compose/projects/<project-name>/docker-compose.yml`:

```yaml
services:
  my-app:
    build: .
    container_name: my-app
    restart: unless-stopped
    environment:
      # Connect to the central Postgres & Redis using container names:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=admin
      - DB_PASS=ChooseAStrongMasterPassword
      - DB_NAME=my_app_db
      - REDIS_URL=redis://:ChooseAStrongRedisPassword@redis:6379/1
    networks:
      - server-net

networks:
  server-net:
    external: true
```

* **Zero redundant containers**: Your mini-projects don't need their own PostgreSQL or Redis instances, saving RAM and CPU.
* **Centralized Backups**: Backing up `/data/volumes/postgres` backs up data for all your apps and Docmost in one place.
