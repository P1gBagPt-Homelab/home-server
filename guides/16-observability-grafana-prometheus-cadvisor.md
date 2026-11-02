# Guide 16: Centralized Observability Stack (Grafana, Prometheus, cAdvisor & Loki)

> **Status**: ✅ **Implemented & Verified on Project Janus**  
> * **Platform**: Coolify PaaS (Docker Compose)  
> * **Stack**: Grafana (Visual Dashboards), Prometheus (Time-Series Metrics DB), cAdvisor (Per-Container Hardware Profiling), Loki & Promtail (Centralized Container Logs)  
> * **Grafana Web UI**: `https://grafana.janus-lab.duckdns.org` (Port 3000)  
> * **Internal Metrics Endpoints**:  
>   * Prometheus: `http://prometheus:9090`  
>   * cAdvisor: `http://cadvisor:8080`  
>   * Loki: `http://loki:3100`  
> * **Storage**: `/data/volumes/grafana`, `/data/volumes/prometheus/data`, `/data/volumes/loki` on SSD Pool  
> * **Network**: Attached to external `coolify` Docker network  
> * **Automated Backup**: Grafana dashboards, alert rules, and Prometheus configs synced to Google Drive (Guide 10)

---

## 1. Overview & Architecture

Project Janus hosts multiple mini-projects, databases, and background workers. While Netdata (Guide 08) monitors total physical host hardware and Uptime Kuma checks if a website is up or down, neither can answer questions like:

* *Which specific container is consuming 600 MB of RAM?*
* *How many messages are waiting in RabbitMQ queues?*
* *What is the p95 latency and 500 error rate of my mini-project APIs?*
* *What errors were printed in my container logs at the exact moment a CPU spike occurred?*

This **Observability Stack** provides a unified, single-pane-of-glass dashboard for all your services:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Traefik Reverse Proxy                           │
│               https://grafana.janus-lab.duckdns.org (Port 443)         │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Port 3000 (SSO / Admin UI)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                           Grafana Dashboard                            │
│           • Visual Dashboards     • Alert Rules (Discord/Telegram)     │
│           • Explore Log Viewer    • Correlated Metrics-to-Logs         │
└───────────────────▲────────────────────────────────┬───────────────────┘
                    │                                │
      PromQL Query  │                                │ LogQL Query
                    ▼                                ▼
┌──────────────────────────────────────┐ ┌──────────────────────────────┐
│       Prometheus Time-Series DB      │ │      Grafana Loki (Logs)     │
│       (http://prometheus:9090)       │ │     (http://loki:3100)       │
└───────────────────▲──────────────────┘ └───────────────▲──────────────┘
                    │                                    │
    Scrapes every 15s                                    │ Ships logs
                    │                                    │
    ┌───────────────┼───────────────┐                    │
    ▼               ▼               ▼                    │
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌─────┴──────────────┐
│ cAdvisor     │ │ RabbitMQ     │ │ Mini-Project │ │ Promtail Daemon    │
│ (Google)     │ │ Metrics      │ │ (/metrics)   │ │ • Scrapes all      │
│ Per-container│ │ Queue depths │ │ API latency  │ │   Docker container │
│ CPU/RAM MB   │ │ Throughput   │ │ HTTP counts  │ │   console logs     │
└──────────────┘ └──────────────┘ └──────────────┘ └────────────────────┘
```

---

## 2. Directory & Configuration Setup on Host

Connect via SSH (`ssh daniel@192.168.1.68` or over WireGuard `ssh daniel@10.8.0.1`):

### 1. Create Persistent Directories
```bash
sudo mkdir -p /data/volumes/grafana
sudo mkdir -p /data/volumes/prometheus/config
sudo mkdir -p /data/volumes/prometheus/data
sudo mkdir -p /data/volumes/loki
sudo mkdir -p /data/volumes/promtail

# Set ownership for Grafana (472:472) and Prometheus (65534:65534)
sudo chown -R 472:472 /data/volumes/grafana
sudo chown -R 65534:65534 /data/volumes/prometheus/data
sudo chown -R 10001:10001 /data/volumes/loki
```

---

### 2. Create Prometheus Scrape Configuration (`prometheus.yml`)

Create the configuration file at `/data/volumes/prometheus/config/prometheus.yml`:

```bash
sudo tee /data/volumes/prometheus/config/prometheus.yml > /dev/null << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # 1. Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # 2. cAdvisor: Per-container CPU, RAM, Network & Disk I/O
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  # 3. RabbitMQ: Queue depths, messages ready, and throughput (Guide 15)
  - job_name: 'rabbitmq'
    static_configs:
      - targets: ['rabbitmq:15692']

  # 4. Homelab Mini-Projects (Add your apps here as they deploy)
  - job_name: 'janusdeck'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['janusdeck:8080']
EOF
```

---

### 3. Create Promtail Configuration (`promtail-config.yml`)

Create the configuration file at `/data/volumes/promtail/promtail-config.yml` so Promtail collects all container logs:

```bash
sudo tee /data/volumes/promtail/promtail-config.yml > /dev/null << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker-containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs: attrs
            tag: attrs.tag
      - regex:
          expression: '^/var/lib/docker/containers/(?P<container_id>[a-f0-9]+)/.*\.log$'
          source: filename
      - labels:
          stream:
          container_id:
EOF
```

---

## 3. Coolify Deployment Walkthrough

### Step 1: Create Resource in Coolify
1. Open Coolify: `http://192.168.1.68:8000` (or `http://10.8.0.1:8000` via WireGuard).
2. Go to your **`Core Services`** or **`Infrastructure`** project.
3. Click **+ New Resource** $\rightarrow$ **Docker Compose**.
4. Set name to: **`Observability-Stack`**.

### Step 2: Paste the Unified Docker Compose Configuration

```yaml
services:
  # 1. Grafana Dashboard UI
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=janus-admin
      - GF_SECURITY_ADMIN_PASSWORD=GenerateAStrongPasswordHere_123!
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=https://grafana.janus-lab.duckdns.org
    volumes:
      - /data/volumes/grafana:/var/lib/grafana
    ports:
      - "3000:3000"
    networks:
      - coolify

  # 2. Prometheus Time-Series Metrics Database
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    volumes:
      - /data/volumes/prometheus/config/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - /data/volumes/prometheus/data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - coolify

  # 3. Google cAdvisor (Per-Container Resource Telemetry)
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    # Note: No host port binding needed; Prometheus scrapes cadvisor:8080 internally.
    # Exposing 8080 on the host clashes with Traefik (coolify-proxy).
    networks:
      - coolify

  # 4. Grafana Loki (Log Ingestion & Indexing Engine)
  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - /data/volumes/loki:/loki
    ports:
      - "3100:3100"
    networks:
      - coolify

  # 5. Promtail (Log Collector & Shipper)
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    command: -config.file=/etc/promtail/config.yml
    volumes:
      - /data/volumes/promtail/promtail-config.yml:/etc/promtail/config.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - coolify

networks:
  coolify:
    name: coolify
    external: true
```

### Step 3: Domain & Traefik SSL Setup
1. In the **`Observability-Stack`** resource in Coolify, go to the **Domains** tab:
2. Click **+ Add Domain**:
   * **Service application**: Select **`grafana (grafana/grafana:latest)`** *(Important: ensure it is `grafana`, not `cadvisor`)*
   * **Domain**: `https://grafana.janus-lab.duckdns.org`
   * **Port**: `3000`
   * **Protocol**: `HTTP -> HTTPS`
3. Click **Save** and click **Deploy**.
4. Traefik will automatically provision wildcard SSL for `https://grafana.janus-lab.duckdns.org`.

---

## 4. Connecting Data Sources in Grafana

1. Open `https://grafana.janus-lab.duckdns.org` and log in with your `janus-admin` password.
2. Go to **Connections > Data Sources > + Add data source**.

### A. Add Prometheus:
* **Type**: `Prometheus`
* **Prometheus server URL**: `http://prometheus:9090` *(Internal zero-latency Docker network address)*
* Click **Save & test**. You should see a green checkmark: *"Data source is working"*.

### B. Add Loki:
* **Type**: `Loki`
* **Loki URL**: `http://loki:3100`
* Click **Save & test**. You should see: *"Data source successfully connected"*.

---

## 5. Instant Pre-Built Dashboards (Import via ID)

Instead of designing charts manually from scratch, Grafana lets you import production-grade community dashboards with 1 click:

1. In Grafana, click **Dashboards > New > Import**.
2. Enter the **Dashboard ID** from the table below and click **Load**:

| Dashboard Name | Grafana ID | What It Displays |
| :--- | :---: | :--- |
| **Docker & System Monitoring (cAdvisor)** | **`14282`** | Per-container CPU %, RAM MB, network throughput, and disk I/O across every active container. |
| **RabbitMQ Overview (Native Prometheus)** | **`10991`** | Live queue depths, consumer counts, message publish/deliver rates, unacked messages. |
| **Prometheus 2.0 Stats** | **`3662`** | Scrape durations, time-series sample ingestion rates, and storage engine health. |
| **Node Exporter / Host Overview** | **`1860`** | System CPU package load, memory pressure, and filesystem capacities. |

3. Select your **Prometheus** data source and click **Import**.

---

## 6. Instrumenting Mini-Projects for Metrics & Logs

To make any new mini-project automatically visible inside your Grafana charts:

### 1. Python / FastAPI Example:
Install the official instrumentor:
```bash
pip install prometheus-fastapi-instrumentator
```

Add 2 lines to your `main.py`:
```python
from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()

# Enable automatic Prometheus metrics collection at /metrics
Instrumentator().instrument(app).expose(app)

@app.get("/")
def read_root():
    return {"message": "Hello from Project Janus!"}
```

### 2. Node.js / Express Example:
Install `prom-client`:
```bash
npm install prom-client
```

Add to `server.js`:
```javascript
import express from 'express';
import client from 'prom-client';

const app = express();
client.collectDefaultMetrics();

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

app.listen(3000, () => console.log('Server running on port 3000'));
```

### 3. Add to `prometheus.yml`:
Whenever you deploy the app, add its target to `/data/volumes/prometheus/config/prometheus.yml`:
```yaml
  - job_name: 'my-mini-project'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['my-mini-project:3000']
```
Reload Prometheus without downtime:
```bash
curl -X POST http://localhost:9090/-/reload
```

---

## 7. Using Loki to Correlate Spikes with Logs

When you see a CPU or error spike on a Grafana chart:
1. Go to **Explore** in Grafana.
2. Select **Loki** as your data source.
3. Query logs for any project using LogQL:
   ```logql
   {job="docker"} |= "error"
   ```
4. Or filter by specific container:
   ```logql
   {job="docker"} |~ "(?i)exception"
   ```
5. You can view timestamp-aligned container logs alongside your Prometheus metrics graph, eliminating guesswork when debugging crashes.

---

## 8. Backups & Disaster Recovery

* **Grafana Dashboards & Users**: Stored persistently in `/data/volumes/grafana/grafana.db` (SQLite).
* **Prometheus Metrics History**: Stored in `/data/volumes/prometheus/data`.
* Both directories are mounted under `/data/volumes` on the fast SSD pool, and are automatically included in `/data/scripts/backup-janus.sh` for nightly Rclone Crypt encryption to your **5 TB Google Drive** (Guide 10).
