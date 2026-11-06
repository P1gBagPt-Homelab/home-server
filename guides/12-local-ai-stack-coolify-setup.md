# Guide 12: Local AI Stack Deployment on Coolify (Ollama + Open WebUI)

> **Status**: ✅ **Fully Deployed & Operational on Project Janus**  
> * **Platform**: Coolify PaaS (Docker Compose)
> * **Service Name**: `ai-stack` (in `Infrastructure` or `Core Services` project)
> * **Target URL**: `https://ai.janus-lab.duckdns.org` (and `http://192.168.1.68:3080`)
> * **Backend Endpoint**: `http://192.168.1.68:11434` (Ollama OpenAI-compatible API)
> * **Acceleration**: NVIDIA RTX 2070 (8GB VRAM) via NVIDIA Container Toolkit
> * **Storage**: 100% on dedicated server SSD (`/data/ai/ollama` & `/data/ai/open-webui`)

---

## 1. Overview & Architecture

This guide walks you through deploying a private, GPU-accelerated AI assistant on **Project Janus** using **Coolify PaaS**.

The stack consists of two services deployed together in a single Docker Compose resource:
1. **Ollama**: The GPU inference engine running quantized models directly inside your RTX 2070 VRAM.
2. **Open WebUI**: The feature-rich ChatGPT-like web interface offering chat, document RAG, web search, voice synthesis, and user management.

```
┌────────────────────────────────────────────────────────┐
│             TRAEFIK REVERSE PROXY (Coolify)            │
│               https://ai.janus-lab.duckdns.org         │
└───────────────────────────┬────────────────────────────┘
                            │ (Port 8080)
┌───────────────────────────▼────────────────────────────┐
│                      Open WebUI                        │
│                 (Container: open-webui)                │
└───────────────────────────┬────────────────────────────┘
                            │ (Internal network: http://ollama:11434)
┌───────────────────────────▼────────────────────────────┐
│                        Ollama                          │
│                  (Container: ollama)                   │
├────────────────────────────────────────────────────────┤
│ • GPU Passthrough: ASUS ROG Strix RTX 2070 (8GB VRAM)  │
│ • Host API Access: Port 11434 (VS Code Continue.dev)   │
│ • Model Storage: SSD `/data/ai/ollama`                 │
└────────────────────────────────────────────────────────┘
```

---

## 2. Pre-Deployment: Directory Setup on SSD

All model weights and Open WebUI databases are stored on your fast **~456 GB LVM SSD pool** (`/data`) to ensure cold-starts remain under 10 seconds.

SSH into Janus (`ssh daniel@192.168.1.68` or over WireGuard `ssh daniel@10.8.0.1`):

```bash
# Create persistent SSD directories for AI models and web UI data
sudo mkdir -p /data/ai/ollama /data/ai/open-webui

# Assign ownership to your user account
sudo chown -R $USER:$USER /data/ai
```

---

## 3. Coolify Deployment Walkthrough

### Step 1: Create the Resource in Coolify
1. Navigate to your Coolify dashboard:
   👉 `http://192.168.1.68:8000` *(or `http://10.8.0.1:8000` via WireGuard)*.
2. Select your project (e.g., **`Core Services`** or **`Infrastructure`**).
3. Click **+ New Resource** > **Docker Compose**.
4. Set the name to **`ai-stack`**.

### Step 2: Paste the Docker Compose Configuration
Paste the following complete configuration into the Docker Compose configuration editor:

```yaml
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - /data/ai/ollama:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    environment:
      - OLLAMA_KEEP_ALIVE=5m

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    ports:
      - "3080:8080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - WEBUI_SECRET_KEY=janus-ai-super-secret-key-replace-me
    volumes:
      - /data/ai/open-webui:/app/backend/data
    depends_on:
      - ollama
```

> [!TIP]
> **Why Port 11434 is exposed to the host**:  
> Exposing `11434:11434` lets developer tools on your local machines (such as the **Continue.dev** coding assistant in VS Code) talk directly to Ollama across your LAN or over WireGuard VPN.

> [!NOTE]
> **Port Allocation**: Host port `3080` is mapped to container port `8080` (`3080:8080`) to avoid port collisions with services using port `3000` (e.g., Docmost Wiki). If you solely access Open WebUI through the Traefik domain (`https://ai.janus-lab.duckdns.org`), the `ports:` mapping can also be safely omitted entirely.

### Step 3: Configure Domains & SSL in Coolify
1. In the service list for `ai-stack`, click on **`open-webui`**.
2. In the **Domains** field, input:
   ```
   https://ai.janus-lab.duckdns.org
   ```
3. Ensure the internal port is set to **`8080`**.
4. Click **Save**.
5. Click **Deploy**.

Coolify will pull the containers, assign Traefik reverse proxy routes, provision Let's Encrypt wildcard SSL, and attach the NVIDIA GPU.

---

## 4. Verification & Initial Model Download

### 1. Verify NVIDIA GPU Passthrough
SSH into Janus and verify that the Ollama container can see the RTX 2070:

```bash
docker exec -it ollama nvidia-smi
```
*Expected Output: You should see the driver version (595.xx), CUDA version (13.x), and the **GeForce RTX 2070** with 8192MiB VRAM.*

---

### 2. Pull Recommended Models
Pull your first daily driver models directly from the command line:

```bash
# 1. High-speed general reasoning model (~4.7 GB, 100% in VRAM, 40+ tok/sec)
docker exec -it ollama ollama run llama3.1:8b

# 2. Top-tier coding assistant (~4.5 GB, 100% in VRAM)
docker exec -it ollama ollama run qwen2.5-coder:7b

# 3. Document embedding model for Open WebUI RAG search (~274 MB)
docker exec -it ollama ollama pull nomic-embed-text
```

> [!NOTE]
> You can also download models directly inside the **Open WebUI** interface under **Admin Panel > Settings > Models**, typing `llama3.1:8b` or `qwen2.5-coder:7b` and clicking the Download button.

---

## 5. First-Time Open WebUI Configuration

1. Visit **`https://ai.janus-lab.duckdns.org`** (or `http://192.168.1.68:3080`).
2. **Create Admin Account**: The very first user account created automatically becomes the system **Admin**.
3. **Restrict Sign-ups (Crucial for Public Subdomains)**:
   * Click your profile picture (bottom-left) > **Admin Panel** > **Settings** > **General**.
   * Toggle **Enable New Sign Ups** to **OFF** so unauthorized visitors cannot use your GPU.
4. **Select Model & Chat**:
   * At the top dropdown, select `llama3.1:8b` or `qwen2.5-coder:7b` and test a prompt!

---

## 6. Optional: Connecting VS Code (Continue.dev) to Ollama

To use your Janus server as a free, 100% private GitHub Copilot:

1. In VS Code on your desktop or laptop, install the **Continue** extension (`Continue.continue`).
2. Click the gear icon in the Continue side panel to open `config.json`.
3. Add your Janus server's Ollama endpoint:

```json
{
  "models": [
    {
      "title": "Janus Qwen 2.5 Coder 7B",
      "provider": "ollama",
      "model": "qwen2.5-coder:7b",
      "apiBase": "http://192.168.1.68:11434"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Janus Autocomplete",
    "provider": "ollama",
    "model": "qwen2.5-coder:1.5b-base",
    "apiBase": "http://192.168.1.68:11434"
  }
}
```

*Note: When working away from home, replace `192.168.1.68` with your WireGuard VPN IP `10.8.0.1`.*

---

## 7. Monitoring & Resource Maintenance

* **Netdata Telemetry**: Open your Netdata dashboard (`http://192.168.1.68:19999`) to watch RTX 2070 VRAM allocation and thermals during active token generation.
* **Auto-Unload**: With `OLLAMA_KEEP_ALIVE=5m`, the GPU will automatically drop to 0% utilization and clear its VRAM 5 minutes after your last prompt, keeping server power draw and temperatures minimal.
