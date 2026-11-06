# Guide 18: Application Error & Crash Tracking with GlitchTip (Sentry)

> **Status**: ✅ **Verified & Deployed on Project Janus**  
> * **Platform**: Coolify PaaS (Docker Compose)  
> * **Service Name**: `glitchtip` (in `Infrastructure` or `Core Services` project)  
> * **Web UI**: `https://errors.janus-lab.duckdns.org` (Internal Port 8000)  
> * **Sentry SDK Ingestion Endpoint**: `https://errors.janus-lab.duckdns.org/api/<project-id>/envelope/`  
> * **Database**: Dedicated `glitchtip` database on shared PostgreSQL 18  
> * **Cache & Celery Broker**: Dedicated DB index on shared Redis 7.2  
> * **Storage**: `/data/volumes/glitchtip` on SSD Pool (or MinIO S3 `glitchtip-data` bucket)  
> * **SDK Compatibility**: 100% standard Sentry SDKs (`sentry-sdk` for Python, `@sentry/node` for JS/TS, `Sentry` for C#/.NET, Go, etc.)  
> * **Automated Backup**: PostgreSQL database backed up daily via Rclone Crypt to Google Drive (Guide 10)

---

## 1. Overview & Architecture

While **Prometheus + Grafana** (Guide 16) monitors server load and **Loki** stores raw container log streams, neither tells you the exact root cause when your custom code fails in production. When an endpoint returns HTTP 500:
* Grafana only shows a spike in error rates.
* Loki forces you to manually dig through lines of console text.
* Neither captures the in-memory variable state, call parameters, or browser context at the exact microsecond of the failure.

**GlitchTip** is an open-source, lightweight alternative to Sentry. It acts as an error aggregation and APM forensic engine:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Traefik Reverse Proxy                           │
│               https://errors.janus-lab.duckdns.org (Port 443)          │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Port 8000 (UI & Event Ingestion API)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      GlitchTip Web Service (web)                       │
│     * Django / ASGI API Server                                         │
│     * Serves Single Page App (Angular Frontend)                        │
│     * Ingests Sentry SDK crash events & envelopes                      │
└───────────────────┬────────────────────────────────┬───────────────────┘
                    │                                │
                    ▼ Celery Tasks                   ▼ SQL Queries
┌──────────────────────────────────────┐  ┌──────────────────────────────┐
│    GlitchTip Worker (worker)         │  │    Shared PostgreSQL 18      │
│  * Processes crash stack traces      │  │    Database: glitchtip       │
│  * Groups identical errors into issues│  │    User:     glitchtip       │
│  * Dispatches Discord/Email alerts   │  └──────────────────────────────┘
└───────────────────┬──────────────────┘
                    │
                    ▼ Redis Broker (DB 2)
┌──────────────────────────────────────┐
│          Shared Redis 7.2            │
│  * Task queue & event buffering      │
└──────────────────────────────────────┘
                    ▲
       Report Errors via Sentry SDK
                    │
    ┌───────────────┴───────────────┐
    │                               │
┌───┴─────────────┐         ┌───────┴─────────┐
│ FastAPI / Python│         │ Node / Next.js  │
│ (JanusDeck API) │         │ (Mini-Projects) │
└─────────────────┘         └─────────────────┘
```

### Why GlitchTip Over Official Self-Hosted Sentry?

| Metric / Requirement | Official Self-Hosted Sentry | GlitchTip on Janus |
| :--- | :--- | :--- |
| **Idle RAM Footprint** | **12 GB – 16 GB RAM** | **~180 MB – 250 MB RAM** |
| **Containers Required** | 18 – 22 containers (Kafka, ClickHouse, Snuba, Relay, Zookeeper, etc.) | **3 lightweight services** (`migrate` one-shot, `web` + `worker`) |
| **Database** | Heavy multi-engine cluster | Reuses existing **PostgreSQL 18** & **Redis 7.2** |
| **Client SDKs** | Uses official Sentry SDKs | **Uses identical official Sentry SDKs** (drop-in replacement) |
| **Maintenance** | Complex migrations & high disk I/O | Zero-maintenance single Docker image updates |

---

## 2. PostgreSQL & Directory Preparation

### 1. Provision Database & User in Shared PostgreSQL 18
SSH into Janus (`ssh daniel@192.168.1.68` or via WireGuard `ssh daniel@10.8.0.1`):

1. Find your shared PostgreSQL 18 container ID:
   ```bash
   docker ps --filter "ancestor=postgres:18-alpine" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}"
   ```
   *(Assuming container ID is `o4nipot4qcoaskqwss3zf6bq` or similar)*

2. Open the PostgreSQL shell:
   ```bash
   docker exec -it <POSTGRES_CONTAINER_ID> psql -U postgres
   ```

3. Generate a strong password and execute the SQL commands:
   ```sql
   -- Create dedicated database user
   CREATE USER glitchtip WITH ENCRYPTED PASSWORD 'GENERATE_STRONG_PASSWORD_HERE';

   -- Create isolated database owned by glitchtip
   CREATE DATABASE glitchtip OWNER glitchtip;

   -- Grant full privileges
   GRANT ALL PRIVILEGES ON DATABASE glitchtip TO glitchtip;

   -- Connect to the newly created database and grant schema rights
   \c glitchtip
   GRANT ALL ON SCHEMA public TO glitchtip;

   -- Exit PostgreSQL
   \q
   ```

### 2. Create Persistent Host Storage
Create host directories for local static assets and file uploads:

```bash
# Create directory on SSD pool
sudo mkdir -p /data/volumes/glitchtip/uploads

# Set standard permissions for GlitchTip container user (UID 1000)
sudo chown -R 1000:1000 /data/volumes/glitchtip
sudo chmod -R 770 /data/volumes/glitchtip
```

---

## 3. Coolify Deployment Walkthrough

GlitchTip runs cleanly as a 3-service Docker Compose application (`migrate`, `web`, `worker`) inside Coolify.

### Step 1: Create Resource in Coolify
1. In your Coolify dashboard, open your **`Infrastructure`** or **`Core Services`** project.
2. Click **+ New Resource**.
3. Select **Docker Compose**.
4. Set the name to **`glitchtip`**.

### Step 2: Paste the Docker Compose Configuration

Paste the following Docker Compose configuration into Coolify:

```yaml
version: '3.8'

services:
  migrate:
    image: glitchtip/glitchtip:latest
    container_name: glitchtip-migrate
    command: ./bin/run-migrate.sh
    environment:
      - DATABASE_URL=postgresql://glitchtip:YOUR_POSTGRES_PASSWORD@POSTGRES_CONTAINER_ID:5432/glitchtip
      - REDIS_URL=redis://:YOUR_REDIS_PASSWORD@REDIS_CONTAINER_ID:6379/2
      - SECRET_KEY=GENERATE_64_CHAR_SECRET_KEY
    networks:
      - coolify

  web:
    image: glitchtip/glitchtip:latest
    container_name: glitchtip-web
    restart: unless-stopped
    depends_on:
      - migrate
    ports:
      - "8000"
    environment:
      - DATABASE_URL=postgresql://glitchtip:YOUR_POSTGRES_PASSWORD@POSTGRES_CONTAINER_ID:5432/glitchtip
      - REDIS_URL=redis://:YOUR_REDIS_PASSWORD@REDIS_CONTAINER_ID:6379/2
      - SECRET_KEY=GENERATE_64_CHAR_SECRET_KEY
      - GLITCHTIP_DOMAIN=https://errors.janus-lab.duckdns.org
      - ENABLE_USER_REGISTRATION=True
      - DEFAULT_FROM_EMAIL=glitchtip@janus-lab.duckdns.org
      - EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
      - I_PAID_FOR_GLITCHTIP=True
    volumes:
      - /data/volumes/glitchtip/uploads:/code/uploads
    networks:
      - coolify

  worker:
    image: glitchtip/glitchtip:latest
    container_name: glitchtip-worker
    restart: unless-stopped
    command: ./bin/run-celery-with-beat.sh
    depends_on:
      - migrate
    environment:
      - DATABASE_URL=postgresql://glitchtip:YOUR_POSTGRES_PASSWORD@POSTGRES_CONTAINER_ID:5432/glitchtip
      - REDIS_URL=redis://:YOUR_REDIS_PASSWORD@REDIS_CONTAINER_ID:6379/2
      - SECRET_KEY=GENERATE_64_CHAR_SECRET_KEY
      - GLITCHTIP_DOMAIN=https://errors.janus-lab.duckdns.org
      - ENABLE_USER_REGISTRATION=True
      - DEFAULT_FROM_EMAIL=glitchtip@janus-lab.duckdns.org
      - EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
      - I_PAID_FOR_GLITCHTIP=True
    volumes:
      - /data/volumes/glitchtip/uploads:/code/uploads
    networks:
      - coolify

networks:
  coolify:
    external: true
```

> [!TIP]
> **Generate Secret Key in 5 Seconds**:
> Run on your Janus terminal:
> ```bash
> openssl rand -hex 32
> ```
> Paste this value into `SECRET_KEY` for all three services (`migrate`, `web`, and `worker`).

### Step 3: Domain & Traefik SSL Routing
1. In the Coolify resource configuration, click the **web** service.
2. In the left sidebar, click **Domains > + Add Domain**.
3. Configure:
   * **Domain**: `https://errors.janus-lab.duckdns.org`
   * **Port**: `8000`
4. Click **Save**.
5. Ensure **Network** is set to `Attach to predefined network` (`coolify`).

### Step 4: Deploy
Click **Deploy** in the top right corner. 
On deploy, the `migrate` service runs `./bin/run-migrate.sh` first to execute all Django database migrations on PostgreSQL 18. Once finished, `web` and `worker` start cleanly.

---

## 4. Initial Account & Security Hardening

### Option A: Web Registration (Temporarily Enabled)
1. Open your browser and navigate to:
   ```text
   https://errors.janus-lab.duckdns.org/register
   ```
2. Enter your email (e.g. `daniel@...`) and set your master password.
3. Click **Sign Up**. You will be logged into your new GlitchTip instance.

### Option B: CLI Superuser Creation (Bypasses Web Registration)
If you prefer not opening registration even temporarily, run directly on Janus:
```bash
docker exec -it glitchtip-web ./manage.py createsuperuser
```
Follow the interactive prompt for email and password, then log in directly at `/login`.

### Lock Down Open Registration
Because your instance is reachable via Traefik over DuckDNS, **disable public registration** immediately so strangers cannot create accounts on your crash tracker:

1. In Coolify, open the `glitchtip` Docker Compose file.
2. Under both `web` and `worker`, change:
   ```yaml
   - ENABLE_USER_REGISTRATION=False
   ```
   > [!NOTE]
   > Modern GlitchTip uses `ENABLE_USER_REGISTRATION` (the legacy variable `ENABLE_OPEN_USER_REGISTRATION` is deprecated and ignored).
3. Click **Redeploy**. Existing accounts remain active, but the `/register` endpoint is completely locked down.

---

## 5. Setting Up Your First Project & Getting DSN

1. In the GlitchTip sidebar, click **Organizations** (or create `Janus Lab`).
2. Go to **Projects > + New Project**:
   * **Platform**: Select your tech stack (e.g., *Python*, *Node.js*, *C#*).
   * **Project Name**: e.g., `janusdeck`, `smart-receipts`, or `media-bot`.
3. Click **Create Project**.
4. GlitchTip displays your project's **DSN (Data Source Name)**:
   ```text
   https://4f9a0c1e82b74052bf19aa910243e8@errors.janus-lab.duckdns.org/1
   ```
   *(Keep this DSN handy—this is the single URL you pass to your applications to report crashes).*

---

## 6. Application Integration Examples

GlitchTip uses standard Sentry client libraries. You do not install any special GlitchTip package; use standard Sentry packages.

### A. Python (FastAPI, Flask, or Scripts)

Install standard Sentry SDK:
```bash
pip install sentry-sdk
```

In your application entry point (`main.py`):
```python
import sentry_sdk

sentry_sdk.init(
    dsn="https://4f9a0c1e82b74052bf19aa910243e8@errors.janus-lab.duckdns.org/1",
    # Set traces_sample_rate to 1.0 to capture 100% of transactions for performance monitoring
    traces_sample_rate=1.0,
    # Attach local variables to stack traces
    send_default_pii=True,
    environment="production",
    release="janusdeck@1.0.0"
)

# Test error capture:
def trigger_test_crash():
    division_by_zero = 1 / 0

# If unhandled, sentry_sdk automatically catches and pushes to GlitchTip!
```

If using **FastAPI**:
```python
from fastapi import FastAPI
import sentry_sdk

sentry_sdk.init(
    dsn="https://4f9a0c1e82b74052bf19aa910243e8@errors.janus-lab.duckdns.org/1",
    traces_sample_rate=0.2
)

app = FastAPI()

@app.get("/error-test")
def error_test():
    items = ["cpu", "ram"]
    return items[5]  # IndexError! Automatically captured with call stack!
```

---

### B. Node.js & TypeScript (Express / Fastify / Next.js)

Install the Sentry Node SDK:
```bash
npm install @sentry/node
```

In your `server.ts` or `index.js`:
```typescript
import * as Sentry from "@sentry/node";

Sentry.init({
  dsn: "https://4f9a0c1e82b74052bf19aa910243e8@errors.janus-lab.duckdns.org/1",
  tracesSampleRate: 1.0,
  environment: "production",
});

// Any uncaughtException or unhandledRejection is immediately pushed to GlitchTip
```

---

### C. .NET / C# (ASP.NET Core or Console)

Install Sentry for .NET:
```bash
dotnet add package Sentry.AspNetCore
```

In `Program.cs`:
```csharp
var builder = WebApplication.CreateBuilder(args);

builder.WebHost.UseSentry(o =>
{
    o.Dsn = "https://4f9a0c1e82b74052bf19aa910243e8@errors.janus-lab.duckdns.org/1";
    o.Debug = false;
    o.TracesSampleRate = 1.0;
    o.SendDefaultPii = true;
});

var app = builder.Build();
app.UseSentryTracing();
app.Run();
```

---

## 7. Verifying Crash Capture in GlitchTip

1. Trigger a test error in one of your applications.
2. Open `https://errors.janus-lab.duckdns.org/issues`.
3. Within 2 seconds, you will see a new issue appear:
   * **Issue Title**: e.g., `ZeroDivisionError: division by zero` or `IndexError: list index out of range`.
   * **Stack Trace**: Highlights the exact line in your source code file.
   * **Environment**: Shows Python/Node runtime, host OS, container name, and client IP.
   * **Local Variables**: Shows the exact values of variables inside the function when it crashed.
   * **Tags & Breadcrumbs**: Shows actions that occurred right before the crash (e.g. `GET /api/v1/auth`, `Database query SELECT * FROM users`).

---

## 8. Discord / Telegram Instant Alerts

When an app crashes in production at 3 AM, you want an immediate notification on your phone:

1. In GlitchTip, navigate to **Settings > Alerts & Integrations**.
2. Select your project (e.g. `janusdeck`).
3. Click **+ Add Webhook / Integration**.
4. **For Discord**:
   * Create a Discord webhook in your private server (e.g. `#alerts` channel).
   * Paste the webhook URL into GlitchTip.
   * Configure Rule: *"Send alert when a new issue is created or recurs"*.
5. Test the webhook: Discord immediately receives a rich embed card containing the error summary and a direct 1-click link to inspect the stack trace.

---

## 9. Backup & Maintenance

* **PostgreSQL Backup**: The `glitchtip` database is included in your daily automated Rclone Crypt backup to Google Drive (Guide 10).
* **Storage Pruning**: In GlitchTip, you can set event retention rules (e.g. delete resolved errors older than 30 or 60 days) to keep PostgreSQL database storage compact and fast.
