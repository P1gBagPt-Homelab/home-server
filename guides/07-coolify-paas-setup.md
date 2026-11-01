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

### 3. PostgreSQL Administration: Adding Databases & Users for Future Apps

When adding new applications (e.g. **Vaultwarden**, custom APIs, Nextcloud, Immich) to your home server, you should **never** use the default `postgres` superuser or dump all tables into the default `postgres` database. Instead, follow the standard multi-tenant pattern: **one isolated database and dedicated user per application**.

> [!CAUTION]
> **Important: Identify the Correct PostgreSQL Container**:
> * `coolify-db` (`postgres:15-alpine`): **DO NOT TOUCH.** This is Coolify's internal system database.
> * Your application database (`postgres:18-alpine`): Running under a generated container name (e.g. `o4nipot4qcoaskqwss3zf6bq`).
>
> Run this command to find your active application database container:
> ```bash
> docker ps --filter "ancestor=postgres:18-alpine" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}"
> ```

#### Option A: Interactive PostgreSQL Shell

1. Open `psql` directly inside the container as the `postgres` user:
   ```bash
   docker exec -it <POSTGRES_CONTAINER_ID_OR_NAME> psql -U postgres
   ```
   *(For example: `docker exec -it o4nipot4qcoaskqwss3zf6bq psql -U postgres`)*

2. Run the SQL provisioning commands:
   ```sql
   -- 1. Create the dedicated user
   CREATE USER <app_user> WITH ENCRYPTED PASSWORD 'YourSecurePasswordHere';

   -- 2. Create the dedicated database owned by that user
   CREATE DATABASE <app_db> OWNER <app_user>;

   -- 3. Grant database privileges
   GRANT ALL PRIVILEGES ON DATABASE <app_db> TO <app_user>;

   -- 4. Switch to the newly created database
   \c <app_db>

   -- 5. Grant public schema privileges (Mandatory for PostgreSQL 15 & 18)
   GRANT ALL ON SCHEMA public TO <app_user>;
   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO <app_user>;
   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO <app_user>;
   ```

3. Exit the PostgreSQL shell:
   ```text
   \q
   ```

---

#### Option B: Automated One-Liner (Terminal Scripting)

You can run the entire setup in a single non-interactive command from your host terminal (replace container name, username, password, and database name):

```bash
docker exec -i o4nipot4qcoaskqwss3zf6bq psql -U postgres << 'EOF'
CREATE USER myapp WITH ENCRYPTED PASSWORD 'SuperSecretPassword123';
CREATE DATABASE myapp OWNER myapp;
GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp;
\c myapp
GRANT ALL ON SCHEMA public TO myapp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO myapp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO myapp;
EOF
```

---

#### Connecting the New Application

1. **Internal Connection String (`DATABASE_URL`)**:
   Construct the database URL using the PostgreSQL container name or Coolify service name:
   ```text
   DATABASE_URL=postgresql://<app_user>:<app_password>@<POSTGRES_CONTAINER_NAME>:5432/<app_db>
   ```
   *Example for Vaultwarden:*
   ```text
   DATABASE_URL=postgresql://vaultwarden:SuperSecretPassword123@o4nipot4qcoaskqwss3zf6bq:5432/vaultwarden
   ```

2. **Docker Network Requirement**:
   For the application container to resolve the database container's hostname, it must be attached to the shared `coolify` Docker network:
   ```yaml
   networks:
     default:
       name: coolify
       external: true
   ```

> [!TIP]
> **Password Special Characters Note**:
> If your password contains characters such as `@`, `:`, `#`, `/`, or `%`, ensure they are **URL-encoded** when pasted into `DATABASE_URL` (e.g. `@` becomes `%40`, `#` becomes `%23`).

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

## 6. Automated CI/CD Pipeline (GitHub Actions Organization Runner + Coolify)

### The Homelab Challenge:
In a homelab environment, Coolify is hosted inside your private local network (`http://192.168.1.68:8000`). GitHub's cloud servers cannot route webhook requests to private RFC-1918 LAN IP addresses.

### The Solution: 24/7 Self-Hosted Runner on Project Janus
To enable automated deployments on every `git push` or PR merge without exposing Coolify's management port to the public internet:

1. **Central GitHub Organization**:
   * All homelab repositories reside under the **`P1gBagPt-Homelab`** GitHub organization.
2. **Dedicated Organization Runner**:
   * A single, official GitHub Actions runner (`actions-runner-linux-x64`) is installed directly on Ubuntu Server (`janus`).
   * Runs 24/7 as a background systemd service: `actions.runner.P1gBagPt-Homelab.janus.service`.
   * **Organization-wide**: Any repository in `P1gBagPt-Homelab` with `runs-on: self-hosted` is automatically served by this runner.
3. **Internal API Trigger**:
   * When code is pushed or a PR is merged into `main`, GitHub signals your local runner.
   * The runner fires an internal authenticated POST request to Coolify's deployment API (`http://192.168.1.68:8000/api/v1/deploy?uuid=...`), triggering an instant rebuild and container redeploy in seconds.

---

### Step-by-Step: Adding a New Project with Automated Deployment

Whenever you create a new application (e.g. Next.js, FastAPI, Node.js, Go) for your homelab:

#### 1. Create the Repo in the Organization
Create the repository under **`P1gBagPt-Homelab`** (e.g. `https://github.com/P1gBagPt-Homelab/my-new-project`).

#### 2. Create the Application in Coolify
1. In Coolify (`http://192.168.1.68:8000`), navigate to your project and click **+ New Resource > Application > GitHub App**.
2. Select your repository (`P1gBagPt-Homelab/my-new-project`) and branch `main`.
3. Note the application's unique **UUID** from the URL bar (e.g. `rvi8hu1owmes3shdpsiuyz3q`).

#### 3. Add GitHub Secrets to the Repository
In the repository's **Settings > Secrets and variables > Actions**, add:
* `COOLIFY_HOST`: `http://192.168.1.68:8000`
* `COOLIFY_UUID`: `<your-app-uuid-from-coolify>`
* `COOLIFY_TOKEN`: `<your-coolify-api-token>`

*(Tip: You can set these in 5 seconds from your terminal using `gh secret set COOLIFY_TOKEN`)*.

#### 4. Add the Universal Deployment Workflow
Create `.github/workflows/deploy.yml` in your project:

```yaml
name: Deploy to Coolify

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  deploy:
    name: Trigger Coolify Redeploy
    runs-on: self-hosted
    steps:
      - name: Trigger Coolify Deployment
        env:
          COOLIFY_HOST: ${{ secrets.COOLIFY_HOST }}
          COOLIFY_UUID: ${{ secrets.COOLIFY_UUID }}
          COOLIFY_TOKEN: ${{ secrets.COOLIFY_TOKEN }}
        run: |
          echo "🚀 Triggering Coolify redeploy on ${COOLIFY_HOST}..."
          RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Authorization: Bearer ${COOLIFY_TOKEN}" \
            -H "Content-Type: application/json" \
            "${COOLIFY_HOST}/api/v1/deploy?uuid=${COOLIFY_UUID}&force=false")
          
          HTTP_STATUS=$(echo "${RESPONSE}" | tail -n1)
          BODY=$(echo "${RESPONSE}" | sed '$d')
          
          if [ "${HTTP_STATUS}" -eq 200 ]; then
            echo "✅ Deployment successfully queued on Coolify!"
          else
            echo "❌ Coolify deployment failed with HTTP ${HTTP_STATUS}"
            exit 1
          fi
```

#### 5. Verify the Runner Service
On the Ubuntu server, the runner service can be monitored at any time:
```bash
# Check runner daemon status
sudo systemctl status actions.runner.P1gBagPt-Homelab.janus.service

# Or using the runner helper:
cd ~/actions-runner && sudo ./svc.sh status
```

From this point on, **every `git push origin main` or merged Pull Request automatically queues a fresh build in Coolify in under 5 seconds!**
