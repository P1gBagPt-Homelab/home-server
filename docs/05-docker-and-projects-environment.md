# 05. Docker Environment & Mini-Projects Architecture

The primary purpose of the Linux Server is to host self-contained **mini projects** packaged as **Docker containers**, with built-in readiness for **GPU-accelerated AI workloads** (Ollama, Whisper, local models) down the road.

---

## 1. Storage & Directory Hierarchy for Projects

To keep things structured, maintainable, and easy to back up, all container definitions and persistent volumes will live on the dedicated server disks:

```
/data/ (Mounted to dedicated Server Disk 3)
├── compose/                      # Central repository of compose stacks
│   ├── infrastructure/           # Core server services (Proxy, Portainer, WireGuard)
│   │   └── docker-compose.yml
│   └── projects/                 # Individual mini projects
│       ├── project-alpha/
│       │   ├── docker-compose.yml
│       │   └── .env
│       └── project-beta/
│           └── docker-compose.yml
├── volumes/                      # Persistent database & app data
│   ├── nginx-proxy-manager/
│   ├── portainer/
│   └── project-alpha-db/
└── ai/                           # Dedicated directory for local AI models/weights
    └── ollama-models/
```

---

## 2. Core Server Infrastructure Stack

Before launching your custom mini projects, deploy two foundational tools:
1. **Dockge** or **Portainer CE**: A clean web UI to monitor, start, stop, and edit Docker Compose files.
2. **Nginx Proxy Manager**: Allows you to access your projects via clean local hostnames (e.g., `http://alpha.home`, `http://portainer.home`) instead of remembering raw port numbers (`:3000`, `:8080`).

### `/data/compose/infrastructure/docker-compose.yml`:

```yaml
services:
  # Container Management UI
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

  # Reverse Proxy for clean internal domains
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - "80:80"
      - "81:81"     # Web Admin UI
      - "443:443"
    volumes:
      - /data/volumes/npm-data:/data
      - /data/volumes/npm-letsencrypt:/etc/letsencrypt
```

---

## 3. Template for Custom Mini-Projects

When spinning up a new mini project, create a subfolder in `/data/compose/projects/<project-name>/`:

```yaml
services:
  app:
    build: . # or image: your-custom-image:latest
    container_name: my-mini-project
    restart: unless-stopped
    environment:
      - DATABASE_URL=postgres://user:password@db:5432/appdb
    networks:
      - internal-net
      - proxy-net

  db:
    image: postgres:16-alpine
    container_name: my-mini-project-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
      - POSTGRES_DB=appdb
    volumes:
      - /data/volumes/my-mini-project-db:/var/lib/postgresql/data
    networks:
      - internal-net

networks:
  internal-net:
    driver: bridge
  proxy-net:
    external: true # Shared network connected to Nginx Proxy Manager
```

---

## 4. Future AI Readiness (Leveraging Your Gaming GPU)

Because this PC has a dedicated graphics card for gaming, you can harness its full GPU compute power on Linux for AI without disrupting your Windows gaming setup.

### How GPU Compute Works in Docker:
By installing the **NVIDIA Container Toolkit**, Docker containers can directly access your GPU's CUDA cores and VRAM.

### Preparing the Linux Server (One-Time Setup):
1. Install proprietary NVIDIA drivers on Linux:
   ```bash
   sudo apt install -y nvidia-driver-535 nvidia-utils-535
   ```
2. Install NVIDIA Container Toolkit:
   ```bash
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
   curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
     sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
     sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
   sudo apt update && sudo apt install -y nvidia-container-toolkit
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```

### Running Local AI in One Command (When Ready):
Whenever you are ready to experiment with AI, you can run **Ollama** (for local LLMs like Llama 3, Mistral, DeepSeek) with direct GPU acceleration:

```yaml
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - /data/ai/ollama-models:/root/.ollama
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
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
    volumes:
      - /data/volumes/open-webui:/app/backend/data
```

This gives you a fully private, ChatGPT-like interface running 100% locally on your gaming hardware whenever the PC is booted into server mode.
