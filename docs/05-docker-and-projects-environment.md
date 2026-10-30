# 05. Application Platform: Coolify PaaS & AI Architecture

The application layer of Project Janus is powered by **Coolify** (an open-source, self-hosted Platform-as-a-Service, often called the *"Self-Hosted Vercel"*). 

Coolify provides Git-based automated deployments, 1-click database provisioning, integrated reverse-proxy management with automated SSL, and complete compatibility with **GPU-accelerated local AI**.

---

## 1. Why Coolify on Janus?

```
┌────────────────────────────────────────────────────────┐
│                   GitHub / Git Repo                    │
│                 (Developer Workflow)                   │
└──────────────────────────┬─────────────────────────────┘
                           │ git push
                           ▼
┌────────────────────────────────────────────────────────┐
│               Coolify PaaS on Janus                    │
│            (Web UI at port 8000 via VPN)               │
├────────────────────────────────────────────────────────┤
│ • Automated Builds (Node, Python, Go, Next.js, Rust)   │
│ • Integrated Traefik Reverse Proxy & Wildcard SSL      │
│ • Automatic internal networking between services       │
└────────────┬─────────────────────────────┬─────────────┘
             │                             │
             ▼                             ▼
   ┌───────────────────┐         ┌───────────────────┐
   │ 1-Click Databases │         │ 1-Click Apps & AI │
   │ • PostgreSQL 16   │         │ • Docmost Wiki    │
   │ • Redis 7         │         │ • Ollama (GPU)    │
   └───────────────────┘         └───────────────────┘
```

### Key Benefits:
1. **The Vercel Developer Experience**:
   * Connect your GitHub account once.
   * Every time you push code to `main`, Coolify pulls the repo, builds the container, and deploys it automatically with zero terminal commands.
2. **Full-Stack on Your Own Hardware**:
   * Unlike cloud Vercel (which only hosts stateless frontends), Coolify on Janus hosts your frontends, backend APIs, persistent databases, and file storage on your dedicated server disks.
3. **No More Manual Proxy Configuration**:
   * Coolify has an embedded **Traefik** reverse proxy. Whenever you deploy a project or database, you simply enter your domain (e.g., `https://myapp.janus-server.duckdns.org`), and Coolify provisions SSL and handles routing automatically.

---

## 2. Storage Organization on Dedicated Server Disks

Coolify stores all application configurations, Docker persistent volumes, and databases on your dedicated server disk (`/data`):

```
/data/ (Mounted to dedicated Server Disk 4)
├── coolify/                      # Coolify configuration and internal state
├── volumes/                      # Persistent database & application data
│   ├── postgres/                 # Central PostgreSQL 16 data
│   ├── redis/                    # Central Redis 7 cache
│   └── docmost/                  # Docmost wiki pages and attachments
├── projects/                     # Git clone directories and build caches
└── ai/                           # Dedicated directory for local AI models
    └── ollama/
```

---

## 3. Database & Shared Services Tier

In Coolify, shared services are created through the UI with one click:
* **PostgreSQL 16**: Central database container running on an internal network. When you launch mini projects, Coolify injects the internal connection string:
  ```
  postgres://postgres:password@postgres:5432/app_db
  ```
* **Redis 7**: Central in-memory caching and queuing service.
* **Docmost**: Centralized documentation wiki running alongside your apps.

---

## 4. Future AI Readiness (Leveraging RTX 2070 GPU)

Because Coolify is fully Docker-native, any project or service can access your **ASUS Strix RTX 2070** via the NVIDIA Container Toolkit.

### Deploying Local AI (Ollama + Open-WebUI) in Coolify:
In Coolify, you can deploy **Ollama** as a custom Docker Compose service with GPU reservations:

```yaml
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    volumes:
      - /data/ai/ollama:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    volumes:
      - /data/volumes/open-webui:/app/backend/data
```

With your RTX 2070's 8GB VRAM and 40GB system RAM, Coolify will host models like **Llama 3.1 8B** and **Mistral 7B** running at 40+ tokens per second, completely private and accessible to all your mini projects!
