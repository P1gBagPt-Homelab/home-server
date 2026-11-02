# Guide 15: Centralized Message Broker with RabbitMQ

> **Status**: ⏳ **Ready to Deploy on Project Janus**  
> * **Platform**: Coolify PaaS (Docker Compose)  
> * **Service Name**: `rabbitmq` (in `Infrastructure` or `Core Services` project)  
> * **Management Web UI**: `https://queue.janus-lab.duckdns.org` (Port 15672)  
> * **AMQP Protocol Endpoint**: `amqp://rabbitmq:5672` (Internal `coolify` Docker network)  
> * **Prometheus Metrics Port**: `http://rabbitmq:15692/metrics`  
> * **Primary Storage**: `/data/volumes/rabbitmq` on SSD LVM Pool (~456 GB)  
> * **Multi-Tenant Model**: Virtual Hosts (`vhosts`) & dedicated credentials per mini-project  
> * **Automated Backup**: Metadata definitions export + Rclone AES-256 sync to Google Drive (Guide 10)

---

## 1. Overview & Architecture

As your homelab expands with mini-projects (FastAPI APIs, Next.js web applications, scrapers, background sync jobs, local AI pipelines), running everything synchronously creates bottlenecks. A web request should not hang while waiting for an invoice to generate, an email to send, or an 8B AI model to process text.

**RabbitMQ** serves as Project Janus's centralized message broker, enabling asynchronous background execution and decoupled event-driven architectures across all your applications:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Traefik Reverse Proxy                           │
│               https://queue.janus-lab.duckdns.org (Port 443)           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Port 15672 (Management UI)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     RabbitMQ Container (rabbitmq)                      │
│   • AMQP Engine (Port 5672)         • Web Console (Port 15672)         │
│   • Prometheus Metrics (Port 15692) • Persistence: /data/volumes/rabbit │
├────────────────────────────────────────────────────────────────────────┤
│                           Virtual Hosts (VHosts)                       │
│  ┌──────────────────────┬──────────────────────┬────────────────────┐  │
│  │ /janusdeck           │ /smart-receipts      │ /ai-workers        │  │
│  │ (JanusDeck events)   │ (Invoice processing) │ (Ollama inference) │  │
│  └──────────────────────┴──────────────────────┴────────────────────┘  │
└────────▲──────────────────────────▲───────────────────────▲────────────┘
         │                          │                       │
 ┌───────┴────────┐         ┌───────┴────────┐      ┌───────┴────────┐
 │ Producer App   │         │ Background App │      │ GPU Worker     │
 │ (Next.js/API)  │         │ (Python/Node)  │      │ (RTX 2070 AI)  │
 └────────────────┘         └────────────────┘      └────────────────┘
```

### Why RabbitMQ over Redis for Messaging?
1. **Dedicated Management UI**: Live browser inspection of every queue depth, throughput (msgs/sec), active consumers, unacknowledged messages, and dead-letter queues.
2. **Guaranteed Delivery & ACKs**: Messages persist on disk until consumers acknowledge (`ack`) successful completion; failed messages automatically redirect to Dead-Letter Exchanges (DLX).
3. **Multi-Tenant Isolation**: Built-in Virtual Hosts (`vhosts`) allow each mini-project to have completely isolated queues, routing keys, and user permissions on a single shared instance.
4. **Built-in Prometheus Exporter**: Native metrics on port `15692` for instant scraping into Grafana (Guide 16).

---

## 2. Directory & Storage Preparation

SSH into Janus (`ssh daniel@192.168.1.68` or over WireGuard `ssh daniel@10.8.0.1`):

```bash
# 1. Create persistent storage directory on the fast SSD pool
sudo mkdir -p /data/volumes/rabbitmq

# 2. Assign standard RabbitMQ container UID (999) ownership
sudo chown -R 999:999 /data/volumes/rabbitmq
sudo chmod -R 770 /data/volumes/rabbitmq
```

---

## 3. Coolify Deployment Walkthrough

### Step 1: Create Resource in Coolify
1. Open Coolify: `http://192.168.1.68:8000` (or `http://10.8.0.1:8000` via WireGuard).
2. Navigate to your **`Core Services`** or **`Infrastructure`** project.
3. Click **+ New Resource** $\rightarrow$ **Docker Compose**.
4. Set name to: **`RabbitMQ`**.

### Step 2: Docker Compose Configuration

Paste the following production configuration:

```yaml
services:
  rabbitmq:
    image: rabbitmq:3.13-management-alpine
    container_name: rabbitmq
    restart: unless-stopped
    environment:
      # Change this to your desired secure administrative password
      - RABBITMQ_DEFAULT_USER=janus-admin
      - RABBITMQ_DEFAULT_PASS=GenerateAStrongPasswordHere_123!
      - RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS=-rabbitmq_management path_prefix ""
    volumes:
      - /data/volumes/rabbitmq:/var/lib/rabbitmq
    ports:
      - "5672:5672"     # AMQP Protocol (Accessible internally to other containers)
      - "15672:15672"   # Management Web UI
      - "15692:15692"   # Prometheus Metrics Plugin
    networks:
      - coolify

networks:
  coolify:
    name: coolify
    external: true
```

### Step 3: Domain & Traefik SSL Setup
1. In RabbitMQ's resource view in Coolify, go to the **Domains** tab.
2. Click **+ Add Domain**:
   * **Domain**: `https://queue.janus-lab.duckdns.org`
   * **Port**: `15672`
   * **Protocol**: `HTTP -> HTTPS`
3. Click **Save** and trigger a **Deploy** from the top-right button.
4. Traefik will automatically provision a Let's Encrypt wildcard SSL certificate for `https://queue.janus-lab.duckdns.org`.

---

## 4. Multi-Tenant Project Isolation (Best Practice)

Just like shared PostgreSQL (Guide 07/14), **never mix queues from different mini-projects into the default `/` vhost**. Always create an isolated virtual host and dedicated user.

### Option A: Via Management Web UI (`https://queue.janus-lab.duckdns.org`)
1. Log in with your `janus-admin` credentials.
2. Go to the **Admin** tab.
3. Click **Virtual Hosts** $\rightarrow$ Add a new virtual host (e.g. `/my-app`).
4. Click **Users** $\rightarrow$ Add a new user (e.g. `my-app-user`), set a secure password, and tag it as `monitoring` or none (no `administrator` tag).
5. Under **Permissions**, grant `my-app-user` access to `/my-app` with Configure: `.*`, Write: `.*`, Read: `.*`.

### Option B: Via Terminal One-Liner (Automated Scripting)
Run directly on the server:
```bash
# 1. Create a dedicated vhost
docker exec -it rabbitmq rabbitmqctl add_vhost /my-app

# 2. Create dedicated user
docker exec -it rabbitmq rabbitmqctl add_user my-app-user "SecureAppPassword123!"

# 3. Grant full permissions strictly to that vhost
docker exec -it rabbitmq rabbitmqctl set_permissions -p /my-app my-app-user ".*" ".*" ".*"
```

---

## 5. Connecting Mini-Projects to RabbitMQ

All containers attached to the `coolify` Docker network connect via the container hostname `rabbitmq:5672`.

### 1. Connection String Format
```text
amqp://my-app-user:SecureAppPassword123@rabbitmq:5672/my-app
```
*(Remember: URL-encode any special characters in passwords, e.g. `@` $\rightarrow$ `%40`)*.

---

### 2. Python Example (FastAPI / Celery / Pika)

Using the official lightweight `pika` library:

#### Producer (`send_task.py`):
```python
import pika
import json

credentials = pika.PlainCredentials('my-app-user', 'SecureAppPassword123!')
parameters = pika.ConnectionParameters(
    host='rabbitmq',
    port=5672,
    virtual_host='/my-app',
    credentials=credentials
)

connection = pika.BlockingConnection(parameters)
channel = connection.channel()

# Ensure the durable queue exists
channel.queue_declare(queue='task_queue', durable=True)

message = {"task_id": "1001", "action": "generate_report", "payload": {"user_id": 42}}

channel.basic_publish(
    exchange='',
    routing_key='task_queue',
    body=json.dumps(message),
    properties=pika.BasicProperties(delivery_mode=pika.DeliveryMode.Persistent)
)

print(" [x] Sent task to RabbitMQ")
connection.close()
```

#### Consumer Worker (`worker.py`):
```python
import pika
import json
import time

credentials = pika.PlainCredentials('my-app-user', 'SecureAppPassword123!')
parameters = pika.ConnectionParameters('rabbitmq', 5672, '/my-app', credentials)

connection = pika.BlockingConnection(parameters)
channel = connection.channel()
channel.queue_declare(queue='task_queue', durable=True)
channel.basic_qos(prefetch_count=1)

def callback(ch, method, properties, body):
    data = json.loads(body)
    print(f" [x] Processing task: {data['task_id']}")
    time.sleep(2)  # Simulate processing
    print(" [x] Task finished")
    ch.basic_ack(delivery_tag=method.delivery_tag)

channel.basic_consume(queue='task_queue', on_message_callback=callback)
print(' [*] Worker waiting for messages. To exit press CTRL+C')
channel.start_consuming()
```

---

### 3. Node.js Example (`amqplib`)

```javascript
import amqp from 'amqplib';

const AMQP_URL = 'amqp://my-app-user:SecureAppPassword123@rabbitmq:5672/my-app';

async function sendTask(task) {
  const connection = await amqp.connect(AMQP_URL);
  const channel = await connection.createChannel();
  const queue = 'task_queue';

  await channel.assertQueue(queue, { durable: true });
  channel.sendToQueue(queue, Buffer.from(JSON.stringify(task)), { persistent: true });
  
  console.log(' [x] Sent %s', JSON.stringify(task));
  await channel.close();
  await connection.close();
}
```

---

## 6. Enabling Prometheus Metrics for Grafana

RabbitMQ 3.13 includes a native high-performance Prometheus plugin that exports queue depths, memory consumption, socket counts, and message rates.

1. Ensure the plugin is enabled (default in `rabbitmq:3.13-management-alpine`):
   ```bash
   docker exec -it rabbitmq rabbitmq-plugins enable rabbitmq_prometheus
   ```
2. Test the metrics endpoint from the server terminal:
   ```bash
   curl -s http://localhost:15692/metrics | head -n 15
   ```
   *(You will see standard Prometheus metrics like `rabbitmq_queue_messages_ready`, `rabbitmq_process_resident_memory_bytes`, etc. Ready to be scraped by Guide 16)*.

---

## 7. Backups & Disaster Recovery

RabbitMQ metadata (users, vhosts, queues, exchanges, and permissions) can be backed up automatically:

1. **Definitions Export Command**:
   ```bash
   docker exec rabbitmq rabbitmqctl export_definitions /var/lib/rabbitmq/definitions.json
   ```
2. **Inclusion in Daily Backup Script**:
   Add `/data/volumes/rabbitmq` to `/data/scripts/backup-janus.sh`. During the nightly 03:00 run, all queue configurations and persistent message storage will be encrypted via Rclone Crypt and synced to your **5 TB Google Drive** (Guide 10).
