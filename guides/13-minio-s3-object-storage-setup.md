# Guide 13: Self-Hosted S3 Object Storage with MinIO & Project Isolation

> **Status**: ✅ **Implemented & Verified on Project Janus**  
> * **Platform**: Coolify PaaS (Docker Compose) or Standalone Docker CE
> * **Service Name**: `minio-s3` (in `Infrastructure` or `Core Services` project)
> * **S3 API Endpoint**: `https://s3.your-domain.duckdns.org` (Port 9000)
> * **Web Console UI**: `https://minio.your-domain.duckdns.org` (Port 9001)
> * **Internal Docker Network**: `http://minio:9000` (zero-latency container-to-container)
> * **Primary Storage**: `/data/storage/minio` on 1TB HDD (`SAMSUNG HD103SJ`)
> * **Security Model**: Strict IAM Least-Privilege (1 bucket per project, dedicated user/key, 0 cross-bucket access)
> * **Automated Backup**: Rclone AES-256 cloud sync to Google Drive (Guide 10)

---

## 1. Overview & Architecture

Modern full-stack and homelab applications (Docmost, image uploaders, file attachments, databases backups, client portfolios) rely on **Amazon S3-compatible APIs** to store and serve unstructured media.

Instead of paying cloud providers or fragmenting files across random container paths, **MinIO** centralizes all storage into a single high-performance, self-hosted S3 service running on **Project Janus**.

### Key Architectural Tenets:
1. **Multi-Project Isolation**: Every application gets its own **isolated bucket** and a **dedicated service account (Access Key + Secret Key)**. App A can never see, modify, or delete files belonging to App B.
2. **Dual-Network Access**:
   * **Internal containers** connect directly via `http://minio:9000` without routing through your router or public internet.
   * **External/client apps** connect securely via Traefik over HTTPS (`https://s3.your-domain.duckdns.org`).
3. **Storage Tiering**: Hosted on the 1TB cold storage HDD (`/data/storage`), keeping your ~456 GB LVM SSD pool free for operating systems, databases, and LLM weights.

```
                     ┌──────────────────────────────────────────────┐
                     │          Traefik Proxy (Wildcard SSL)        │
                     │    *.your-domain.duckdns.org (Ports 80/443)    │
                     └───────────────┬──────────────────────┬───────┘
                                     │                      │
       https://s3.your-domain...       │                      │  https://minio.your-domain...
                                     ▼                      ▼
                     ┌──────────────────────────────────────────────┐
                     │              MinIO S3 Service                │
                     │  • API Port: 9000    • Console Port: 9001    │
                     └──────────────────────┬───────────────────────┘
                                            │ Persistent Mount
                                            ▼
                     ┌──────────────────────────────────────────────┐
                     │  /data/storage/minio (1TB HDD Cold Storage)  │
                     └──────────────────────────────────────────────┘
                       ▲                     ▲                    ▲
               (Restricted IAM)      (Restricted IAM)     (Restricted IAM)
                       │                     │                    │
              ┌────────┴─────────┐  ┌────────┴─────────┐ ┌────────┴─────────┐
              │  Docmost Wiki    │  │  JanusDeck Hub   │ │  Future App / Dev│
              │  Bucket: docmost │  │  Bucket: janus   │ │  Bucket: app-x   │
              │  User: docmost-sa│  │  User: deck-sa   │ │  User: app-x-sa  │
              └──────────────────┘  └──────────────────┘ └──────────────────┘
```

---

## 2. Storage Directory & Permission Setup

SSH into Janus (`ssh daniel@192.168.1.68` or over WireGuard `ssh daniel@10.8.0.1`):

```bash
# 1. Create persistent storage directory on the 1TB HDD
sudo mkdir -p /data/storage/minio

# 2. Grant ownership to the current user and docker service
sudo chown -R $USER:$USER /data/storage/minio
sudo chmod -R 775 /data/storage/minio
```

---

## 3. Coolify Deployment Walkthrough

### Step 1: Create Resource in Coolify
1. Open Coolify (`http://192.168.1.68:8000` or `https://coolify.your-domain.duckdns.org`).
2. Go to your **`Core Services`** or **`Infrastructure`** project.
3. Click **+ New Resource** $\rightarrow$ **Docker Compose**.
4. Set name to: **`minio-s3`**.

### Step 2: Docker Compose Configuration

Paste the following production configuration:

```yaml
services:
  minio:
    image: ghcr.io/coollabsio/minio:latest
    container_name: minio
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      # Change these to your own strong administrative credentials!
      MINIO_ROOT_USER: "janus-admin"
      MINIO_ROOT_PASSWORD: "GenerateAStrongAdminPasswordHere_123!"
      MINIO_SERVER_URL: "https://s3.your-domain.duckdns.org"
      MINIO_BROWSER_REDIRECT_URL: "https://minio.your-domain.duckdns.org"
    volumes:
      - /data/storage/minio:/data
    ports:
      - "9000:9000"   # S3 API Endpoint
      - "9001:9001"   # Web Console UI
    labels:
      - "traefik.enable=true"
      # S3 API Routing (s3.your-domain.duckdns.org)
      - "traefik.http.routers.minio-api.rule=Host(`s3.your-domain.duckdns.org`)"
      - "traefik.http.routers.minio-api.entrypoints=https"
      - "traefik.http.routers.minio-api.tls=true"
      - "traefik.http.routers.minio-api.service=minio-api"
      - "traefik.http.services.minio-api.loadbalancer.server.port=9000"
      # Console Web UI Routing (minio.your-domain.duckdns.org)
      - "traefik.http.routers.minio-console.rule=Host(`minio.your-domain.duckdns.org`)"
      - "traefik.http.routers.minio-console.entrypoints=https"
      - "traefik.http.routers.minio-console.tls=true"
      - "traefik.http.routers.minio-console.service=minio-console"
      - "traefik.http.services.minio-console.loadbalancer.server.port=9001"
```

### Step 3: Deploy & Verify
1. Click **Deploy** in Coolify.
2. Once healthy, open `https://minio.your-domain.duckdns.org` (or `http://192.168.1.68:9001` on LAN).
3. Log in with your `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD`.

---

## 4. Setting Up Per-Project Isolation (Step-by-Step)

To guarantee that **Project A cannot touch Project B's files**, follow this 3-step provisioning pattern for every new project:

### Step 1: Create the Project Bucket
1. Log in to the MinIO Console (`https://minio.your-domain.duckdns.org`).
2. Go to **Buckets** $\rightarrow$ **Create Bucket**.
3. Name: `docmost-data` (lowercase, alphanumeric, and hyphens only).
4. Leave Object Locking / Versioning off unless required by the project. Click **Create Bucket**.

### Step 2: Create the Scoped IAM Policy
1. In the sidebar, navigate to **Policies** $\rightarrow$ **Create Policy**.
2. Name: `docmost-isolated-policy`.
3. In the Policy editor, paste the JSON document below:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowListBucket",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::docmost-data"
      ]
    },
    {
      "Sid": "AllowAllObjectActionsInsideBucket",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::docmost-data/*"
      ]
    }
  ]
}
```
4. Click **Save**.

### Step 3: Create the Service Account / Access Key
1. In the sidebar, navigate to **Access Keys** (or **Identity** $\rightarrow$ **Users**).
2. Click **Create Access Key**.
3. Toggle on **Restrict additional permissions**.
4. Select `docmost-isolated-policy` from the policy list.
5. MinIO will display your **Access Key** and **Secret Key**.
   > [!IMPORTANT]
   > Copy both keys immediately into your project `.env` or password vault (Vaultwarden). MinIO will not show the secret key again.

---

## 5. Quick Automation Script (`mc` CLI)

If you prefer provisioning buckets and credentials in 5 seconds from the Ubuntu terminal without clicking through the UI:

```bash
# 1. Install MinIO client on Ubuntu (one-time setup)
sudo curl -fsSL https://github.com/minio/mc/releases/download/RELEASE.2025-08-13T08-35-41Z/mc.linux-amd64.RELEASE.2025-08-13T08-35-41Z -o /usr/local/bin/mc
sudo chmod +x /usr/local/bin/mc

# 2. Configure alias for local MinIO admin
mc alias set janus http://localhost:9000 janus-admin "YourAdminPasswordHere"

# 3. Provision a new isolated project in one script:
PROJECT_NAME="portfolio"
BUCKET_NAME="${PROJECT_NAME}-storage"
USER_NAME="${PROJECT_NAME}-user"
USER_SECRET=$(openssl rand -base64 24)

# Create bucket
mc mb "janus/${BUCKET_NAME}"

# Create isolated policy file
cat << EOF > /tmp/${PROJECT_NAME}-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetBucketLocation"],
      "Resource": ["arn:aws:s3:::${BUCKET_NAME}"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::${BUCKET_NAME}/*"]
    }
  ]
}
EOF

# Register policy and create user
mc admin policy create janus "${PROJECT_NAME}-policy" /tmp/${PROJECT_NAME}-policy.json
mc admin user add janus "${USER_NAME}" "${USER_SECRET}"
mc admin policy attach janus "${PROJECT_NAME}-policy" --user "${USER_NAME}"
rm /tmp/${PROJECT_NAME}-policy.json

# Output credentials ready for .env
echo "=== PROVISIONED CREDENTIALS FOR ${PROJECT_NAME} ==="
echo "S3_ENDPOINT=http://minio:9000 (or https://s3.your-domain.duckdns.org)"
echo "S3_BUCKET=${BUCKET_NAME}"
echo "S3_ACCESS_KEY=${USER_NAME}"
echo "S3_SECRET_KEY=${USER_SECRET}"
```

---

## 6. How Projects Consume Your MinIO Service

### Docmost Integration Example (Verified on Janus)

For Docmost (deployed in Guide 07), files and wiki attachments are uploaded to MinIO and served directly to browsers:

1. **Enable public download access on the bucket** (so client browsers can render images):
   ```bash
   mc anonymous set download janus/docmost-data
   ```

2. **Add to Docmost Docker Compose environment**:
   ```yaml
   environment:
     - NODE_TLS_REJECT_UNAUTHORIZED=0  # Required if Traefik uses self-signed / staging certificates
     - STORAGE_DRIVER=s3
     - AWS_S3_ACCESS_KEY_ID=docmost-user
     - AWS_S3_SECRET_ACCESS_KEY=JobDY9qfV6BSW3F6mZqYeDz8rsU5MrYF
     - AWS_S3_REGION=us-east-1
     - AWS_S3_BUCKET=docmost-data
     - AWS_S3_ENDPOINT=https://s3.your-domain.duckdns.org
     - AWS_S3_FORCE_PATH_STYLE=true
   ```

---

### Standard `.env` Pattern for Custom Projects

Any application that supports S3 (Next.js, FastAPI, Spring Boot, Supabase, Strapi, Docmost) takes standard S3 environment variables:

```env
# If app is inside Janus Docker/Coolify network:
S3_ENDPOINT=http://minio:9000
# If app is running outside (e.g., your laptop or cloud runner):
# S3_ENDPOINT=https://s3.your-domain.duckdns.org

S3_BUCKET=docmost-data
S3_ACCESS_KEY=docmost-user
S3_SECRET_KEY=DocmostSuperSecretPassword123!
S3_REGION=us-east-1
S3_FORCE_PATH_STYLE=true
```

> [!NOTE]
> `S3_FORCE_PATH_STYLE=true` (or `s3ForcePathStyle: true`) tells the SDK to use `endpoint/bucket/file` instead of AWS virtual-host subdomain format (`bucket.endpoint/file`). Always enable this for self-hosted S3!

---

### Code Examples

#### Node.js / TypeScript (`@aws-sdk/client-s3`)

```typescript
import { S3Client, PutObjectCommand, GetObjectCommand } from "@aws-sdk/client-s3";

const s3 = new S3Client({
  endpoint: process.env.S3_ENDPOINT, // "http://minio:9000"
  region: "us-east-1",
  credentials: {
    accessKeyId: process.env.S3_ACCESS_KEY!,
    secretAccessKey: process.env.S3_SECRET_KEY!,
  },
  forcePathStyle: true, // Required for self-hosted MinIO
});

// Upload a file
export async function uploadFile(filename: string, fileBuffer: Buffer, mimeType: string) {
  await s3.send(new PutObjectCommand({
    Bucket: process.env.S3_BUCKET,
    Key: `uploads/${filename}`,
    Body: fileBuffer,
    ContentType: mimeType,
  }));
}
```

#### Python (`boto3`)

```python
import os
import boto3
from botocore.client import Config

s3 = boto3.client(
    "s3",
    endpoint_url=os.getenv("S3_ENDPOINT", "http://minio:9000"),
    aws_access_key_id=os.getenv("S3_ACCESS_KEY"),
    aws_secret_access_key=os.getenv("S3_SECRET_KEY"),
    config=Config(s3={"addressing_style": "path"}),
    region_name="us-east-1",
)

# Upload an avatar
s3.upload_file("avatar.png", "docmost-data", "avatars/user-1.png")

# Generate a 1-hour presigned download link
download_url = s3.generate_presigned_url(
    "get_object",
    Params={"Bucket": "docmost-data", "Key": "avatars/user-1.png"},
    ExpiresIn=3600,
)
```

---

## 7. Automated Cloud Backup Integration (Guide 10)

Because MinIO organizes all stored objects as standard files on the host filesystem under `/data/storage/minio`, your automated **Rclone backup job** (from Guide 10) can seamlessly encrypt and back up all buckets to Google Drive.

### Add MinIO to Nightly Backup Script
In `/data/scripts/backup-homelab.sh`:

```bash
# Add MinIO data snapshot to Rclone Crypt routine
rclone sync /data/storage/minio gdrive-crypt:janus-backups/minio \
  --fast-list \
  --transfers 4 \
  --log-file /var/log/rclone-minio.log
```

---

## 8. Verification & Isolation Test

To verify that isolation is functioning 100% and no data leaks between projects:

1. Attempt to list the assigned bucket using project credentials:
   ```bash
   AWS_ACCESS_KEY_ID=docmost-user AWS_SECRET_ACCESS_KEY=DocmostPassword \
   aws --endpoint-url http://localhost:9000 s3 ls s3://docmost-data
   # Result: 200 OK (Bucket contents listed)
   ```
2. Attempt to list or read another project's bucket:
   ```bash
   AWS_ACCESS_KEY_ID=docmost-user AWS_SECRET_ACCESS_KEY=DocmostPassword \
   aws --endpoint-url http://localhost:9000 s3 ls s3://janusdeck-data
   # Result: An error occurred (AccessDenied) when calling the ListObjectsV2 operation
   ```

Isolation is confirmed! You now have an enterprise-grade, multi-tenant S3 storage platform ready to serve every project on Janus.
