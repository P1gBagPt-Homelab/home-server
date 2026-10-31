# Guide 07: Coolify PaaS Setup (Vercel-like Deployment on Janus)

This guide walks you through installing **Coolify** on Ubuntu Server 24.04 LTS, setting up your GitHub integration, provisioning **Shared PostgreSQL** and **Redis**, deploying **Docmost**, and launching mini projects via `git push`.

---

## 1. Installing Coolify on Ubuntu Server

Connect to your server via SSH (`ssh daniel@192.168.1.150` or `ssh daniel@10.8.0.1` over WireGuard):

1. Run the official automated Coolify installer:
   ```bash
   curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
   ```
2. The script will automatically install any missing dependencies, pull the official Coolify containers, configure the built-in Traefik reverse proxy, and start the system.
3. Once the installation finishes (takes ~2 minutes), open your browser and navigate to:  
   👉 `http://192.168.1.150:8000` *(or `http://10.8.0.1:8000` if connected through WireGuard)*.

---

## 2. Initial Setup & Admin Account

1. Follow the onboarding wizard to create your root **Admin Account** (Email and Password).
2. On the **Server Configuration** step:
   * Coolify will detect your local machine (`localhost`).
   * Click **Save & Continue**.

---

## 3. Connect Your GitHub Account

To enable the Vercel-like experience where pushing code automatically builds and deploys your apps:

1. In the Coolify sidebar, click **Sources > + Add**.
2. Select **GitHub App**.
3. Follow the guided 1-click link to GitHub:
   * It will ask for permission to install the Coolify App on your personal GitHub account.
   * You can choose to grant access to *All repositories* or *Select repositories* (your mini projects).
4. Save the integration. Coolify can now listen to GitHub webhooks and pull private/public repositories automatically!

---

## 4. Deploying Shared PostgreSQL & Redis (1-Click)

Inside the Coolify dashboard:

### 1. Provision PostgreSQL:
1. Go to **Projects > Default > Production > + New Resource**.
2. Select **Databases > PostgreSQL**.
3. Name it `janus-postgres`.
4. Click **Deploy**.
   * *Coolify automatically pulls PostgreSQL 16, creates a persistent volume on your server disk, and generates root credentials.*

### 2. Provision Redis:
1. In the same project, click **+ New Resource**.
2. Select **Databases > Redis**.
3. Name it `janus-redis`.
4. Click **Deploy**.

*Both databases now run securely on Coolify's internal Docker network, ready to be consumed by your apps and Docmost.*

---

## 5. Deploying Docmost (Centralized Documentation Wiki)

To deploy Docmost directly inside Coolify and connect it to your shared databases:

1. Click **+ New Resource > Docker Compose**.
2. Name it `Docmost`.
3. Paste the following configuration:

```yaml
services:
  docmost:
    image: docmost/docmost:latest
    container_name: docmost
    restart: unless-stopped
    environment:
      - APP_URL=https://docs.janux-lab.duckdns.org
      - APP_SECRET=replace_with_32_random_characters_string
      - DATABASE_URL=postgresql://postgres:password@janus-postgres:5432/docmost?sslmode=disable
      - REDIS_URL=redis://janus-redis:6379/0
    volumes:
      - docmost-storage:/app/data/storage

volumes:
  docmost-storage:
```

4. In the **Domains** field in Coolify, enter:  
   `https://docs.janux-lab.duckdns.org`
5. Click **Deploy**.  
   *Coolify starts Docmost, points the domain to it, and automatically provisions a Let's Encrypt SSL certificate.*

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
   `https://myproject.janux-lab.duckdns.org`
5. **Connect to PostgreSQL/Redis**:
   * Under **Environment Variables**, you can reference your database:
     `DATABASE_URL=postgresql://postgres:password@janus-postgres:5432/myproject_db`
6. Click **Deploy**.

From this moment on, **every time you run `git push origin main` on your laptop, Coolify automatically pulls the code, rebuilds the project, and deploys it with zero downtime!**
