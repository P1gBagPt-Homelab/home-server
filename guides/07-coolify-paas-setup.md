# Guide 07: Coolify PaaS Setup (Vercel-like Deployment on Janus)

> **Status**: ✅ **Fully Deployed & Operational on Project Janus**  
> * **Coolify Dashboard**: `http://192.168.1.68:8000` (and `http://10.8.0.1:8000` over WireGuard).
> * **Shared Databases**: PostgreSQL 18 & Redis 7.2 running on the shared `coolify` network.
> * **Docmost Wiki**: Deployed at `https://docs.janus-lab.duckdns.org` with Traefik Let's Encrypt SSL.
> * **GitHub Integration**: Connected to GitHub App (`daniel-github`) for automated `git push` deployments.

This guide walks you through installing **Coolify** on Ubuntu Server 24.04 LTS, setting up your GitHub integration, provisioning **Shared PostgreSQL** and **Redis**, deploying **Docmost**, and launching mini projects via `git push`.

---

## 1. Installing Coolify on Ubuntu Server

Connect to your server via SSH (`ssh daniel@192.168.1.68` or `ssh daniel@10.8.0.1` over WireGuard):

1. Run the official automated Coolify installer:
   ```bash
   curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
   ```
2. The script will automatically install any missing dependencies, pull the official Coolify containers, configure the built-in Traefik reverse proxy, and start the system.
3. Once the installation finishes (takes ~2 minutes), open your browser and navigate to:  
   👉 `http://192.168.1.68:8000` *(or `http://10.8.0.1:8000` if connected through WireGuard)*.

---

## 2. Initial Setup & Admin Account

1. Follow the onboarding wizard to create your root **Admin Account** (Email and Password).
   * *Note on Password*: Coolify requires a password with uppercase, lowercase, at least one number, and at least one symbol (e.g. `!@#$%&*`).
2. On the **Server Configuration** step:
   * Coolify will detect your local machine (`localhost`).
   * Click **Save & Continue**.

> [!NOTE]
> **Understanding `coolify-db` vs Your Databases**:
> In `docker ps`, you will see `coolify-db` (Postgres 15) and `coolify-redis`. These are Coolify's **private system engines** (storing your Coolify settings, SSL certs, and users). Never store your application data inside `coolify-db`. The databases you provision in Step 4 are completely dedicated to your apps.

---

## 3. Connect Your GitHub Account

To enable the Vercel-like experience where pushing code automatically builds and deploys your apps:

1. **Navigate to Sources**:
   * In the Coolify left sidebar, click **`< Servers`** (the back arrow at the top) or press **`⌘ + K`** and type **`Sources`**.
   * Click **Sources > + Add**.
2. Select **GitHub App**.
3. In the setup modal:
   * Name: `daniel-github`
   * Organization: *Leave blank* (connects your personal account).
   * Click **Continue**.
4. **Authorize on GitHub**:
   * It will redirect to GitHub. Choose whether to grant access to *All repositories* or *Select repositories* (your mini projects), and click **Install & Authorize**.
5. **Callback URL Gotcha**:
   * If GitHub redirects your browser to `http://<your-public-ip>:8000/webhooks/...` and Chrome shows "Site can't be reached", simply replace the public IP in your browser address bar with your server's local IP:  
     `http://192.168.1.68:8000/webhooks/source/github/redirect?code=...`  
     *(Make sure there is a colon `:8000`, not a slash `/8000`)*. Hit Enter, and Coolify will complete the integration!

---

## 4. Deploying Shared PostgreSQL & Redis (1-Click)

Inside the Coolify dashboard, create a project (e.g., named **`Core Services`** or **`Infrastructure`**):

### 1. Provision Central PostgreSQL:
1. In `Core Services > production`, click **+ New Resource**.
2. Select **Databases > PostgreSQL**.
3. Name: `postgres` (keeps default user and initial database as `postgres`).
4. Click **Deploy**.
5. Once running, go to the database's **General** tab and note the **`Postgres URL (internal)`** (e.g. `postgresql://postgres:password@<postgres-container-id>:5432/postgres`).

### 2. Provision Central Redis:
1. In the same project, click **+ New Resource**.
2. Select **Databases > Redis**.
3. Name: `redis`.
4. Click **Deploy**.
5. Once running, go to the database's **General** tab and note the **`Redis URL (internal)`** (e.g. `redis://:<redis-password>@<redis-container-id>:6379`).

---

## 5. Deploying Docmost (Centralized Documentation Wiki)

Deploy Docmost directly inside the same `Core Services` project and connect it to your shared databases:

1. In `Core Services`, click **+ New Resource > Docker Compose**.
2. Name it **`Docmost`**.
3. Generate a 32-character secret key on your terminal:
   ```bash
   openssl rand -hex 16
   ```
4. Click **Edit Compose File** and paste the following verified configuration:

```yaml
services:
  docmost:
    image: docmost/docmost:latest
    container_name: docmost
    restart: unless-stopped
    environment:
      - APP_URL=https://docs.janus-lab.duckdns.org
      - APP_SECRET=PASTE_YOUR_32_CHAR_SECRET_HERE
      - DATABASE_URL=postgresql://postgres:PASTE_POSTGRES_PASSWORD@PASTE_POSTGRES_CONTAINER_ID:5432/postgres?sslmode=disable
      - REDIS_URL=redis://:PASTE_REDIS_PASSWORD@PASTE_REDIS_CONTAINER_ID:6379/0
    ports:
      - "3000:3000"
    volumes:
      - /data/volumes/docmost:/app/data/storage

networks:
  default:
    name: coolify
    external: true
```

5. **Network Attachment (Critical)**:
   * In Docmost's **General** settings under **Network**, ensure **Network attachment** is set to **`Attach to predefined network`** (so Docmost can resolve the Redis and Postgres containers on the shared `coolify` network).
6. **Domain & SSL Configuration**:
   * In the left sidebar, click **Domains > + Add Domain**.
   * Protocol: `https`
   * Domain: `docs.janus-lab.duckdns.org`
   * Port: `3000`
   * Click **Save**.
7. In the top-right corner, click the dropdown next to the action button and click **Deploy** (or *Redeploy*).

### Router Port Forwarding & SSL Padlock:
Ensure your Vodafone router has Port Mapping rules for:
* **Port 80 TCP** (`Traefik-HTTP` → `192.168.1.68`)
* **Port 443 TCP** (`Traefik-HTTPS` → `192.168.1.68`)

> [!TIP]
> **Getting the Secure SSL Padlock 🔒**:
> If Chrome displays "Not Secure" on your first visit, Traefik is serving its temporary self-signed certificate while waiting for Let's Encrypt. Click the circular refresh icon `🔄` next to the domain in Coolify (or run `docker restart coolify-proxy`), wait 30 seconds, and hard-refresh (`⌘ + Shift + R`). The secure padlock will appear!

### Post-Setup Security Recommendation:
Once you create your Docmost admin workspace:
1. Navigate to **Settings > General / Workspace**.
2. **Disable User Registration / Sign-ups** so uninvited visitors cannot register accounts on your public wiki.

---

## 6. How to Deploy Your Own Mini Projects (The Vercel Experience)

Whenever you build a new mini project on your laptop (e.g., Next.js, React, Node.js, Python FastAPI):

1. Push your code to your GitHub repository:
   ```bash
   git add .
   git commit -m "initial commit"
   git push origin main
   ```
2. In Coolify, click **+ New Resource > Application > GitHub App**.
3. Select your repository and the branch (e.g. `main`).
4. Enter the domain you want:
   `https://myproject.janus-lab.duckdns.org`
5. **Connect to PostgreSQL/Redis**:
   * Under **Environment Variables**, you can reference your database using the internal connection strings found in Step 4:
     `DATABASE_URL=postgresql://postgres:<password>@<postgres-container-id>:5432/myproject_db`
6. Click **Deploy**.

From this moment on, **every time you run `git push origin main` on your laptop, Coolify automatically pulls the code, rebuilds the project, and deploys it with zero downtime!**
