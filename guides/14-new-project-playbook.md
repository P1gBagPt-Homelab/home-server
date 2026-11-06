# Guide 14: New Mini-Project Playbook & Centralized Blueprint

> **Status**: ✅ **Standard Operational Playbook for Project Janus**  
> * **Purpose**: End-to-end developer guide and checklist for bootstrapping, developing, deploying, and integrating new mini-projects into the Janus homelab ecosystem.  
> * **Platform**: Coolify PaaS (`http://192.168.1.68:8000` / `http://10.8.0.1:8000`)  
> * **Reverse Proxy & SSL**: Traefik with automated Let's Encrypt Wildcard SSL (`*.your-domain.duckdns.org`)  
> * **Shared Resources**: Multi-Tenant PostgreSQL 18, Redis 7.2, MinIO S3 Object Storage, and Local Ollama AI (RTX 2070 8GB VRAM).  
> * **Automated CI/CD**: 24/7 Self-Hosted GitHub Actions Runner under `P1gBagPt-Homelab`.

---

## 1. Architectural Philosophy: Centralized & Concise

When you build a new mini-project on **Project Janus**, **you never start from scratch**. You do not need to configure an Nginx reverse proxy, pay for S3 buckets, run separate database servers, or deal with manual SSH deployments. 

Janus already provides a unified production-grade platform:

```
                              ┌────────────────────────────────────────┐
                              │       P1gBagPt-Homelab (GitHub)        │
                              └───────────────────┬────────────────────┘
                                                  │ git push origin main
                                                  ▼
                              ┌────────────────────────────────────────┐
                              │   Janus Self-Hosted Actions Runner     │
                              │ (actions.runner.P1gBagPt-Homelab.janus)│
                              └───────────────────┬────────────────────┘
                                                  │ Internal API trigger
                                                  ▼
                              ┌────────────────────────────────────────┐
                              │          Coolify PaaS (Janus)          │
                              │      Builds & orchestrates container   │
                              └───────────────────┬────────────────────┘
                                                  │
             ┌────────────────────────────────────┼────────────────────────────────────┐
             ▼                                    ▼                                    ▼
┌─────────────────────────┐          ┌─────────────────────────┐          ┌─────────────────────────┐
│     Public Routing      │          │  Shared Infrastructure  │          │   Persistent Storage    │
│ • Traefik Reverse Proxy │          │ • PostgreSQL 18 DB      │          │ • /data/volumes/ (SSD)  │
│ • *.your-domain.duckdns   │          │ • Redis 7.2 Cache       │          │ • /data/storage/ (HDD)  │
│ • Let's Encrypt SSL 443 │          │ • MinIO S3 (Port 9000)  │          │ • Nightly Rclone Backup │
│ • Uptime Kuma Alerts    │          │ • Ollama AI (RTX 2070)  │          │   to 5TB Google Drive   │
└─────────────────────────┘          └─────────────────────────┘          └─────────────────────────┘
```

---

## 2. The 12-Step Mini-Project Checklist

Follow this linear checklist whenever you kick off a new application:

```
[ ] 1. Create Git Repo under P1gBagPt-Homelab organization
[ ] 2. Provision dedicated DB & User on Shared PostgreSQL 18
[ ] 3. (Optional) Allocate Redis database number (0-15)
[ ] 4. (Optional) Provision MinIO S3 bucket & restricted IAM keys
[ ] 5. (Optional) Hook into Local AI via Ollama API
[ ] 6. Allocate correct storage path (/data/volumes vs /data/storage)
[ ] 7. Define Dockerfile or docker-compose.yml on 'coolify' network
[ ] 8. Implement 5 Golden Endpoints (/healthz, /readyz, /version) & Scalar (/docs)
[ ] 9. Create Bruno API test suite in repo under `bruno/`
[ ] 10. Register Application in Coolify & assign domain
[ ] 11. Add GitHub Secrets & deploy.yml with automated Bruno CLI tests
[ ] 12. Register health monitor in Uptime Kuma (/readyz) & JanusDeck Portal
```

---

## 3. Step-by-Step Implementation Guide

### Step 1: Git Repository & GitHub Organization

Always create your repository inside your centralized GitHub organization:
* **GitHub Organization**: `https://github.com/P1gBagPt-Homelab`
* **Naming Convention**: `kebab-case` (e.g. `smart-receipts`, `crypto-tracker`, `rss-summarizer`).
* **Why**: The server runs an **organization-level GitHub Actions runner**. Any repository in this organization automatically inherits free, instant, 24/7 CI/CD builds on your local server.

---

### Step 2: Shared PostgreSQL 18 (Multi-Tenant Pattern)

> [!IMPORTANT]
> **Never spin up a separate PostgreSQL container for a mini-project.** Project Janus has a shared, high-performance PostgreSQL 18 instance with automated daily snapshots. Always create an isolated user and database inside it.

1. **Find your active application PostgreSQL container ID**:
   ```bash
   docker ps --filter "ancestor=postgres:18-alpine" --format "{{.Names}}"
   # Example output: o4nipot4qcoaskqwss3zf6bq
   ```

2. **Generate a secure password**:
   ```bash
   openssl rand -base64 24
   ```

3. **Provision the database & user in one non-interactive command**:
   *(Replace `<app_name>`, `<app_user>`, `<app_password>`, and the container ID)*:
   ```bash
   docker exec -i o4nipot4qcoaskqwss3zf6bq psql -U postgres << 'EOF'
   CREATE USER app_user WITH ENCRYPTED PASSWORD 'GeneratedPasswordHere';
   CREATE DATABASE app_db OWNER app_user;
   GRANT ALL PRIVILEGES ON DATABASE app_db TO app_user;
   \c app_db
   GRANT ALL ON SCHEMA public TO app_user;
   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_user;
   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO app_user;
   EOF
   ```

4. **Your Internal Connection String**:
   * **Node / Go / Java / Generic**:
     ```text
     DATABASE_URL=postgresql://app_user:GeneratedPasswordHere@o4nipot4qcoaskqwss3zf6bq:5432/app_db
     ```
   * **Python Async (FastAPI / SQLAlchemy + asyncpg)**:
     ```text
     DATABASE_URL=postgresql+asyncpg://app_user:GeneratedPasswordHere@o4nipot4qcoaskqwss3zf6bq:5432/app_db
     ```
   *(Note: Remember to URL-encode any special characters like `@` or `#` if used in passwords)*.

---

### Step 3: Shared Redis 7.2 (Caching & Task Queues)

If your app needs Celery, BullMQ, Redis caching, or session storage:
* **Container Hostname**: Found under Coolify $\rightarrow$ `Infrastructure` $\rightarrow$ `Redis` (or check `docker ps --filter "ancestor=redis:7.2-alpine"`).
* **Connection String**:
  ```text
  REDIS_URL=redis://:YOUR_SHARED_REDIS_PASSWORD@<redis-container-id>:6379/1
  ```
* **Best Practice**: Use a dedicated Redis database index (`/0` for Docmost, `/1` for project A, `/2` for project B) to prevent key collision.

---

### Step 4: MinIO S3 Object Storage (Media & Files)

If your project handles file uploads, PDF processing, or media hosting:

> [!NOTE]
> IAM policies and service accounts are provisioned via the `mc` CLI on Janus (the Community Edition web console is strictly an object browser).

#### 1. Instant Provisioning Script (5 Seconds)
SSH into Janus and run this single block (replace `PROJECT_NAME="smart-receipts"` with your new project name):

```bash
PROJECT_NAME="smart-receipts"
BUCKET_NAME="${PROJECT_NAME}-data"
USER_NAME="${PROJECT_NAME}-user"
USER_SECRET=$(openssl rand -base64 24)

# 1. Create isolated bucket
mc mb "janus/${BUCKET_NAME}"

# 2. Create isolated IAM policy file
cat << EOF > /tmp/${PROJECT_NAME}-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowListBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetBucketLocation"],
      "Resource": ["arn:aws:s3:::${BUCKET_NAME}"]
    },
    {
      "Sid": "AllowAllObjectActionsInsideBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::${BUCKET_NAME}/*"]
    }
  ]
}
EOF

# 3. Register policy, create user, and attach policy
mc admin policy create janus "${PROJECT_NAME}-policy" /tmp/${PROJECT_NAME}-policy.json
mc admin user add janus "${USER_NAME}" "${USER_SECRET}"
mc admin policy attach janus "${PROJECT_NAME}-policy" --user "${USER_NAME}"
rm /tmp/${PROJECT_NAME}-policy.json

# 4. (Optional) If files are public images/downloads rendered directly in web browsers:
# mc anonymous set download "janus/${BUCKET_NAME}"

# 5. Output ready-to-copy credentials
echo ""
echo "=== PROVISIONED S3 CREDENTIALS FOR ${PROJECT_NAME} ==="
echo "S3_ENDPOINT=https://s3.your-domain.duckdns.org (or http://minio:9000)"
echo "S3_BUCKET=${BUCKET_NAME}"
echo "S3_ACCESS_KEY=${USER_NAME}"
echo "S3_SECRET_KEY=${USER_SECRET}"
echo "S3_FORCE_PATH_STYLE=true"
echo "S3_REGION=us-east-1"
```

#### 2. Public vs. Private Buckets
* **Public Web Assets (Blog images, avatars, wiki media)**: Run `mc anonymous set download janus/<bucket-name>`. Anyone can view/download images in the browser via `{ENDPOINT}/{BUCKET}/{FILE}`, but only `<project>-user` can upload or delete.
* **Private Documents (Invoices, database backups, user documents)**: Leave default (no anonymous command). Requires signed URLs or S3 credentials to read and write.

#### 3. Standard Environment Variables Pattern
In your application `.env` or Coolify compose:

```env
# If app is running inside the Coolify Docker network:
S3_ENDPOINT=http://minio:9000
# If app is external, or generates URLs rendered directly by browsers:
# S3_ENDPOINT=https://s3.your-domain.duckdns.org

S3_BUCKET=smart-receipts-data
S3_ACCESS_KEY=smart-receipts-user
S3_SECRET_KEY=YourProvisionedSecretKey
S3_REGION=us-east-1
S3_FORCE_PATH_STYLE=true

# For Node.js apps connecting via HTTPS to internal Traefik certs:
# NODE_TLS_REJECT_UNAUTHORIZED=0
```

---

### Step 5: Local AI Integration (ASUS ROG Strix RTX 2070)

If your project needs text generation, embeddings, data extraction, or code analysis:
* **Ollama Endpoint**: `http://ollama:11434` *(on internal `coolify` Docker network)*.
* **Open WebUI**: `https://ai.your-domain.duckdns.org` (for manual prompting and model downloads).
* **Available Models**: `llama3.1:8b`, `mistral:7b`, `nomic-embed-text`.
* **Zero Cost**: No OpenAI API credits needed; runs locally with 8GB VRAM CUDA acceleration on your RTX 2070.

**Sample Python Client Call**:
```python
import requests

response = requests.post(
    "http://ollama:11434/api/generate",
    json={"model": "llama3.1:8b", "prompt": "Extract key items from this invoice...", "stream": False}
)
print(response.json()["response"])
```

---

### Step 6: Storage Paths & Disk Tiering Conventions

Project Janus uses isolated physical disks. Follow this directory rule:

| Storage Type | Physical Location | Path Pattern | Ideal Use Case |
| :--- | :--- | :--- | :--- |
| **High-Speed SSD Pool** (~456 GB LVM) | Disks 2 & 3 | `/data/volumes/<app_name>/` | Application config, databases, SQLite files, high-frequency caches. |
| **Cold Storage HDD** (1 TB) | Disk 4 | `/data/storage/<app_name>/` | Large uploads, datasets, MinIO buckets, media files, video streams. |
| **Temporary / Builds** | SSD Pool | `/data/projects/<app_name>/` | Coolify build cache and Git checkouts. |

**Permissions Setup**:
```bash
sudo mkdir -p /data/volumes/<app_name>
sudo chown -R 1000:1000 /data/volumes/<app_name>
```

---

### Step 7: Containerization & Docker Compose Template

For any mini-project, create a `docker-compose.yml` or standard `Dockerfile`. 

> [!CRITICAL]
> **Docker Network Requirement**:
> Your service container must join the external `coolify` network to talk to PostgreSQL, Redis, MinIO, and Traefik!

#### Recommended `docker-compose.yml` Template:
```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    restart: unless-stopped
    environment:
      - PORT=3000
      - NODE_ENV=production
      # Central Database & Cache
      - DATABASE_URL=postgresql://app_user:PASSWORD@o4nipot4qcoaskqwss3zf6bq:5432/app_db
      - REDIS_URL=redis://:PASSWORD@<redis-container-id>:6379/1
      # Central S3 Storage
      - S3_ENDPOINT=http://minio:9000
      - S3_PUBLIC_URL=https://s3.your-domain.duckdns.org
      - S3_BUCKET=my-app-bucket
      - S3_ACCESS_KEY=my-access-key
      - S3_SECRET_KEY=my-secret-key
      # Local AI
      - OLLAMA_BASE_URL=http://ollama:11434
    volumes:
      - /data/volumes/my-app:/app/data
    networks:
      - coolify

networks:
  coolify:
    name: coolify
    external: true
```

---

### Step 8: Standardized Endpoints & Scalar Documentation

Every backend application on Janus must implement standardized operational endpoints and self-contained documentation (see **[Guide 22](22-api-standards-documentation-and-testing.md)** for full details):

1. **Expose the 5 Golden Endpoints**:
   * `GET /healthz`: Process liveness check (`{"status": "alive"}`).
   * `GET /readyz`: Dependency readiness checking active connections to PostgreSQL, Redis, and MinIO.
   * `GET /version`: Current semantic version, git commit SHA, and environment.
   * `GET /openapi.json`: Machine-readable OpenAPI 3.1 specification.
   * `GET /docs`: Modern, zero-overhead interactive **Scalar** API documentation embedded directly in the app.

2. **Error Standards & GlitchTip Integration**:
   * Standardize error responses using RFC 7807 Problem Details (`type`, `title`, `status`, `detail`, `instance`, `trace_id`).
   * Pass incoming or generated `X-Request-ID` headers to **GlitchTip** ([Guide 18](18-application-error-tracking-glitchtip.md)) so production errors map directly to stack traces.

---

### Step 9: Git-Native API Test Suite (Bruno)

Never let APIs break in silence. Commit functional tests directly into your repository using **Bruno** (100% Free & Open-Source):

1. Initialize a `bruno/` directory in your repo:
   ```bash
   mkdir -p bruno/environments
   ```
2. Define `bruno/environments/Local.bru` (`baseUrl: http://localhost:8000`) and `Janus-Prod.bru`.
3. Add smoke tests for `/healthz`, `/readyz`, and primary CRUD routes with assertions.
4. Verify locally using the free Bruno Desktop GUI or CLI:
   ```bash
   bru run bruno --env Local
   ```

---

### Step 10: Coolify PaaS Registration & Domain Routing

1. Open Coolify: `http://192.168.1.68:8000` (or `http://10.8.0.1:8000` via WireGuard).
2. Go to your **Projects** $\rightarrow$ select your project (e.g. `Applications` or `Mini-Projects`).
3. Click **+ New Resource** $\rightarrow$ **Application** $\rightarrow$ **GitHub App** (`daniel-github`).
4. Select your repo: `P1gBagPt-Homelab/<repo-name>` and branch `main`.
5. Under **Domains**:
   * Add: `https://<app_name>.your-domain.duckdns.org`
   * Internal Port: Match your container port (e.g. `3000` or `8000`).
   * Traefik will automatically issue a Let's Encrypt SSL certificate via DuckDNS DNS-01!
6. Note the application's unique **UUID** from the browser URL (e.g. `rvi8hu1owmes3shdpsiuyz3q`).

---

### Step 11: Automated CI/CD with Bruno Quality Gates (GitHub Actions)

Add continuous deployment so pushing to `main` executes Bruno tests and linters on the Janus self-hosted runner before triggering a Coolify update:

1. **Add Repository Secrets** in GitHub (`Settings > Secrets and variables > Actions`):
   * `COOLIFY_HOST`: `http://192.168.1.68:8000`
   * `COOLIFY_UUID`: `<app-uuid-from-step-10>`
   * `COOLIFY_TOKEN`: `<your-coolify-api-token>`

2. **Add `.github/workflows/deploy.yml`**:
   ```yaml
   name: Quality Gates and Deploy to Janus

   on:
     push:
       branches:
         - main
     workflow_dispatch:

   jobs:
     test:
       name: Lint & Bruno Smoke Tests
       runs-on: self-hosted  # 100% free runner on Janus
       timeout-minutes: 5    # Never block runner if network or container hangs
       steps:
         - name: Checkout Code
           uses: actions/checkout@v4

         - name: Install Bruno CLI
           run: npm install -g @usebruno/cli

         - name: Start Ephemeral App Container
           run: |
             docker compose up -d --build
             timeout 30 sh -c 'until curl -sf http://localhost:8000/healthz; do sleep 1; done'

         - name: Run Bruno Test Suite
           run: bru run bruno --env Local --bail

         - name: Tear Down Test Container
           if: always()
           run: docker compose down -v

     deploy:
       name: Trigger Coolify Redeploy
       needs: test
       runs-on: self-hosted
       steps:
         - name: Trigger Coolify Deployment
           env:
             COOLIFY_HOST: ${{ secrets.COOLIFY_HOST }}
             COOLIFY_UUID: ${{ secrets.COOLIFY_UUID }}
             COOLIFY_TOKEN: ${{ secrets.COOLIFY_TOKEN }}
           run: |
             echo "🚀 Quality gates passed. Triggering deployment on Janus..."
             RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
               -H "Authorization: Bearer ${COOLIFY_TOKEN}" \
               -H "Content-Type: application/json" \
               "${COOLIFY_HOST}/api/v1/deploy?uuid=${COOLIFY_UUID}&force=false")
             
             HTTP_STATUS=$(echo "${RESPONSE}" | tail -n1)
             if [ "${HTTP_STATUS}" -eq 200 ]; then
               echo "✅ Deployment queued successfully on Coolify!"
             else
               echo "❌ Coolify deployment failed with HTTP ${HTTP_STATUS}"
               exit 1
             fi
   ```

---

### Step 12: Observability, Alerts & Portal Listing

Complete the operational lifecycle so you always know your app is healthy:

1. **Uptime Kuma Health Check**:
   * Visit `https://status.your-domain.duckdns.org`.
   * Click **+ Add New Monitor**.
   * Type: `HTTP(s)` $\rightarrow$ URL: `https://<app_name>.your-domain.duckdns.org/readyz`.
   * Heartbeat: `60 seconds`.
   * *Outcome:* Proactively monitors dependencies (DB, Redis, S3). You get immediate Discord/Telegram alerts if the app or any dependency degrades.

2. **JanusDeck Listing**:
   * Visit `https://control.your-domain.duckdns.org`.
   * Click **+ Add Service** $\rightarrow$ Name: `<App Name>`, URL: `https://<app_name>.your-domain.duckdns.org`, Category: `Mini-Projects`.
   * *Outcome:* App appears in your central launcher with real-time green/red availability indicators.

3. **Automated Nightly Backups**:
   * Any database created in PostgreSQL 18 is automatically included in `/data/scripts/backup-janus.sh`.
   * If your app stores critical files outside PostgreSQL, verify its directory under `/data/volumes/<app_name>` is listed in the backup tar list to be encrypted via Rclone Crypt to your **5 TB Google Drive**.

---

## 4. Quick Reference Cheatsheet

### Core Endpoints & Internal Hostnames:
| Service | Internal Docker Hostname | External Public / VPN URL | Port |
| :--- | :--- | :--- | :--- |
| **Coolify PaaS** | Host LAN | `http://192.168.1.68:8000` / `http://10.8.0.1:8000` | `8000` |
| **Shared PostgreSQL 18** | `o4nipot4qcoaskqwss3zf6bq` | *Internal only via Docker/WireGuard* | `5432` |
| **Shared Redis 7.2** | `<redis-container-id>` | *Internal only via Docker/WireGuard* | `6379` |
| **MinIO S3 API** | `minio` | `https://s3.your-domain.duckdns.org` | `9000` |
| **MinIO Console** | `minio` | `https://minio.your-domain.duckdns.org` | `9001` |
| **Ollama AI (RTX 2070)** | `ollama` | `https://ai.your-domain.duckdns.org` | `11434` |
| **Uptime Kuma** | `uptime-kuma` | `https://status.your-domain.duckdns.org` | `3001` |
| **JanusDeck** | `janusdeck` | `https://control.your-domain.duckdns.org` | `8080` |
| **Vaultwarden** | `vaultwarden` | `https://vault.your-domain.duckdns.org` | `80` |

### Handy CLI Commands:
```bash
# Check running containers and statuses
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Stream logs of an application container
docker logs -f --tail 100 <container-name>

# Check GPU utilization & VRAM during AI inference
nvidia-smi

# Check self-hosted GitHub Actions runner status
sudo systemctl status actions.runner.P1gBagPt-Homelab.janus.service
```
