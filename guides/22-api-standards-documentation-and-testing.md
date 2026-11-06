# Guide 22: Standardized API Architecture, Git-Native Testing (Bruno), and Zero-Cost Documentation (Scalar)

> **Status**: ✅ **Standard Operational Specification for Project Janus Applications**  
> * **Philosophy**: 100% Free and Open-Source (FOSS), zero cloud subscription lock-in, zero external data leaks, and zero cost ($0.00).  
> * **Key Components**:
>   * **API Contract & Testing**: [Bruno](https://www.usebruno.com/) (plain-text Git-native `.bru` collections + `@usebruno/cli` in CI).
>   * **Interactive Documentation**: [Scalar](https://scalar.com/) (embedded directly in runtime containers; 0MB extra server overhead).
>   * **Contract Linting**: [Spectral](https://stoplight.io/open-source/spectral) (FOSS OpenAPI schema enforcement in CI).
>   * **Runtime Standards**: 5 Golden Endpoints (`/healthz`, `/readyz`, `/version`, `/openapi.json`, `/docs`), RFC 7807 Error Details, and GlitchTip correlation headers.

---

## 1. Why Traditional API Tooling Drifts & Fails

| Problem with Common Tools | Why It Drifts | The Janus 100% Free Solution |
| :--- | :--- | :--- |
| **Postman / Insomnia Cloud** | Collections are trapped in proprietary clouds, limited to tiny free quotas, or force team subscriptions. Code and tests get out of sync. | **Bruno**: Saved as human-readable `.bru` plain-text files inside your project's git repository. |
| **SwaggerHub / Readme** | Cloud-hosted document portals charge monthly per-user fees and require manual web sync. | **Scalar**: Zero extra containers. Bundled as an open-source library inside each microservice; auto-generates docs at `/docs` directly from runtime code. |
| **Silent API Regressions** | Endpoints break because developers test manually in a local client and forget to test in CI. | **Bruno CLI (`bru run`)**: Runs smoke tests automatically on your Janus self-hosted GitHub Actions runner on every `git push`. |
| **Inconsistent Error Formats** | One endpoint returns `{ "msg": "failed" }`, another `{ "error": "Not Found" }`. | **RFC 7807 Problem Details**: Standardized structured JSON with request correlation IDs connected to **GlitchTip**. |

---

## 2. One-Time Manual Setup (Developer Workstation)

Install these 100% free developer tools once on your development machine (Mac, Windows, or Linux):

### 1. Install Bruno Desktop GUI
Bruno is a fast, offline-first API client that saves all your collections as plain text in the repo.

* **macOS (Homebrew)**:
  ```bash
  brew install bruno
  ```
* **Windows (Winget)**:
  ```powershell
  winget install Bruno.Bruno
  ```
* **Linux (Debian/Ubuntu)**:
  ```bash
  snap install bruno
  # OR via apt:
  sudo mkdir -p /etc/apt/keyrings
  sudo gpg --no-default-keyring --keyring /etc/apt/keyrings/bruno.gpg --keyserver keyserver.ubuntu.com --recv-keys 9FA6017ECABE0266
  echo "deb [signed-by=/etc/apt/keyrings/bruno.gpg] http://debian.usebruno.com/ bruno stable" | sudo tee /etc/apt/sources.list.d/bruno.list
  sudo apt update && sudo apt install bruno
  ```

### 2. Install Bruno CLI & Spectral (Test & Lint Engines)
Install globally or run via `npx`:
```bash
npm install -g @usebruno/cli @stoplight/spectral-cli
```

---

## 3. Standard Repository Structure for Any New App

Every backend or full-stack application repository under `P1gBagPt-Homelab` should structure its API testing and specs like this:

```text
my-project/
├── .github/
│   └── workflows/
│       └── deploy.yml            # CI test runner + Coolify deploy
├── .spectral.yaml                # OpenAPI linting rules
├── src/
│   ├── main.py (or server.ts)    # Embeds Scalar & exposes /openapi.json
│   └── ...
├── tests/
└── bruno/                        # Git-committed API collection
    ├── bruno.json                # Bruno collection metadata
    ├── environments/
    │   ├── Local.bru             # http://localhost:8000
    │   └── Janus-Prod.bru        # https://<app>.your-domain.duckdns.org
    ├── 01-Health/
    │   ├── Liveness-Healthz.bru
    │   └── Readiness-Readyz.bru
    └── 02-Endpoints/
        ├── List-Items.bru
        └── Create-Item.bru
```

---

## 4. Setting Up Bruno in a New Repository

### Step 1: Initialize the Collection
Inside your project root:
```bash
mkdir -p bruno/environments
```

Create `bruno/bruno.json`:
```json
{
  "version": "1",
  "name": "My App API",
  "type": "collection",
  "ignore": [
    "node_modules",
    ".git"
  ]
}
```

### Step 2: Define Environments
Create `bruno/environments/Local.bru`:
```text
vars {
  baseUrl: http://localhost:8000
}
```

Create `bruno/environments/Janus-Prod.bru`:
```text
vars {
  baseUrl: https://my-app.your-domain.duckdns.org
}
```

### Step 3: Create Automated Smoke Tests
Create `bruno/01-Health/Readiness-Readyz.bru`:
```text
meta {
  name: Readiness Check
  type: http
  seq: 1
}

get {
  url: {{baseUrl}}/readyz
  body: none
  auth: none
}

assert {
  res.status: eq 200
  res.body.status: eq ok
  res.body.dependencies.database: eq connected
}
```

### Step 4: Run Locally via CLI
Run tests from terminal anytime without opening the GUI:
```bash
bru run bruno --env Local
```

---

## 5. Embedding Scalar Documentation (Zero Servers, Zero Cost)

Do not run an external docs container. Embed Scalar directly in your code so the documentation is always versioned with the running code.

### Option A: Python (FastAPI)
Install the free open-source adapter:
```bash
pip install scalar-fastapi
```

In your `main.py`:
```python
from fastapi import FastAPI
from scalar_fastapi import get_scalar_api_reference

app = FastAPI(
    title="My Service API",
    version="1.0.0",
    docs_url=None,       # Disable default Swagger UI
    redoc_url=None       # Disable default ReDoc
)

# Mount modern Scalar UI at /docs
@app.get("/docs", include_in_schema=False)
async def scalar_docs():
    return get_scalar_api_reference(
        openapi_url=app.openapi_url,
        title="My Service API - Documentation",
        servers=[{"url": "https://my-app.your-domain.duckdns.org", "description": "Janus Production"}]
    )
```

### Option B: Node.js / Express / Fastify / NestJS
Install the free package:
```bash
npm install @scalar/express-api-reference
```

In Express:
```typescript
import { apiReference } from '@scalar/express-api-reference';

// Mount Scalar on /docs pointing to your OpenAPI JSON spec
app.use(
  '/docs',
  apiReference({
    spec: {
      url: '/openapi.json',
    },
    theme: 'elysia',
  })
);
```

### Option C: Standalone HTML (Go, Rust, .NET, or any Docker container)
If using an arbitrary framework, serve this static HTML page at `GET /docs`:
```html
<!doctype html>
<html>
  <head>
    <title>API Documentation</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
  </head>
  <body>
    <script id="api-reference" data-url="/openapi.json"></script>
    <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
  </body>
</html>
```

---

## 6. Standardizing the 5 "Golden Endpoints"

Every application running on Janus must implement these 5 operational endpoints to integrate cleanly with **Traefik**, **Uptime Kuma**, and **JanusDeck**:

### 1. `GET /healthz` (Liveness)
* **Purpose**: Tells Traefik and Docker if the web process is alive.
* **Return**: `HTTP 200 {"status": "alive"}`.

### 2. `GET /readyz` (Readiness)
* **Purpose**: Verifies that PostgreSQL, Redis, RabbitMQ, and MinIO are actively reachable. Used by **Uptime Kuma** for proactive alerting.
* **Return**:
  ```json
  {
    "status": "ok",
    "timestamp": "2026-11-06T12:00:00Z",
    "dependencies": {
      "database": "connected",
      "redis": "connected",
      "storage": "connected"
    }
  }
  ```
  *(If DB fails, return `HTTP 503` so Uptime Kuma triggers an instant alert).*

### 3. `GET /version` (Release Metadata)
* **Purpose**: Allows JanusDeck and debugging tools to know what code is live.
* **Return**:
  ```json
  {
    "version": "1.2.0",
    "git_sha": "a1b2c3d4",
    "environment": "production"
  }
  ```

### 4. `GET /openapi.json`
* **Purpose**: Machine-readable OpenAPI 3.1 specification used by Bruno, code generators, and Scalar.

### 5. `GET /docs`
* **Purpose**: Interactive Scalar UI for human developers and API consumers.

---

## 7. Standardized Error Format (RFC 7807) & GlitchTip

Never return generic error strings like `{"error": "Something went wrong"}`. 

Enforce **RFC 7807 Problem Details** on all `4xx` and `5xx` responses:

```json
{
  "type": "https://janus.homelab/errors/validation-failed",
  "title": "Validation Error",
  "status": 422,
  "detail": "Field 'email' is required and must be a valid email address.",
  "instance": "/api/v1/users",
  "trace_id": "req_84f93a902c"
}
```

### Correlation Headers & GlitchTip:
1. Every incoming HTTP request is assigned a unique `X-Request-ID` (UUID or nanoid) by your middleware.
2. The `trace_id` is passed into your logger and attached to the GlitchTip (Sentry) exception context:
   ```python
   # Example Python middleware
   import uuid
   from sentry_sdk import set_tag

   @app.middleware("http")
   async def correlation_id_middleware(request, call_next):
       request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
       set_tag("request_id", request_id)
       response = await call_next(request)
       response.headers["X-Request-ID"] = request_id
       return response
   ```
3. When a user or Bruno test encounters a 500 error, search the `trace_id` in your **GlitchTip** dashboard (`https://errors.your-domain.duckdns.org`) to view the exact stack trace and memory dump.

---

## 8. Automating API Testing in GitHub Actions CI

Update your application's `.github/workflows/deploy.yml` on the self-hosted Janus runner so that tests are executed **before** Coolify triggers a redeploy:

```yaml
name: Test and Deploy to Janus

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

jobs:
  test:
    name: Lint Spec & Run Bruno Tests
    runs-on: self-hosted  # Runs on your Janus server for $0
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Node.js (for CLI tools)
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install Test CLIs
        run: npm install -g @usebruno/cli @stoplight/spectral-cli

      # 1. Spin up the container locally to test
      - name: Build and Start Container for Smoke Testing
        run: |
          docker compose up -d --build
          # Wait for /healthz
          timeout 30 sh -c 'until curl -sf http://localhost:8000/healthz; do sleep 1; done'

      # 2. Lint the OpenAPI specification
      - name: Lint OpenAPI Spec
        run: |
          curl -sf http://localhost:8000/openapi.json -o openapi.json
          spectral lint openapi.json

      # 3. Execute Bruno Collection Smoke Tests
      - name: Run Bruno Test Suite
        run: |
          bru run bruno --env Local --bail

      - name: Clean Up Test Containers
        if: always()
        run: docker compose down -v

  deploy:
    name: Trigger Coolify Deployment
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: self-hosted
    steps:
      - name: Trigger Coolify Webhook
        env:
          COOLIFY_HOST: ${{ secrets.COOLIFY_HOST }}
          COOLIFY_UUID: ${{ secrets.COOLIFY_UUID }}
          COOLIFY_TOKEN: ${{ secrets.COOLIFY_TOKEN }}
        run: |
          echo "🚀 Quality gates passed. Triggering deployment on Janus..."
          curl -s -f -X POST \
            -H "Authorization: Bearer ${COOLIFY_TOKEN}" \
            -H "Content-Type: application/json" \
            "${COOLIFY_HOST}/api/v1/deploy?uuid=${COOLIFY_UUID}&force=false"
```

> **Why this keeps you on track:**  
> If an endpoint path changes or a required payload property is missing without updating the Bruno collection, the `bru run` step **fails**, stopping the deployment before bad code ever reaches your production server.

---

## 9. (Optional) Self-Hosted Web API Client: Hoppscotch

If you ever want an in-browser API testing UI (like Postman Web) accessible over your local network or WireGuard:

1. Open Coolify: `http://192.168.1.68:8000`.
2. Add a new service using Docker Compose: `hoppscotch/hoppscotch:latest`.
3. Route domain: `https://api-client.your-domain.duckdns.org` with Traefik DNS-01 SSL.
4. *Cost:* 100% Free, open-source, and self-hosted.

---

## 10. Summary Checklist for New Apps

```
[ ] 1. Install Bruno Desktop on local dev machine.
[ ] 2. Create `bruno/` directory in repo with `Local.bru` and `Janus-Prod.bru`.
[ ] 3. Embed Scalar on `GET /docs` and serve `GET /openapi.json`.
[ ] 4. Implement 5 Golden Endpoints (`/healthz`, `/readyz`, `/version`, `/openapi.json`, `/docs`).
[ ] 5. Implement RFC 7807 error responses and `X-Request-ID` correlation middleware.
[ ] 6. Attach GlitchTip DSN from Guide 18.
[ ] 7. Add Bruno CLI test step to `.github/workflows/deploy.yml`.
[ ] 8. Configure Uptime Kuma to ping `GET /readyz`.
```
