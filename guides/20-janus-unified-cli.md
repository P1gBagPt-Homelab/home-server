# Guide 20: Janus Unified CLI — Setup & Terminal Command Center

> **Status**: ⚡ **Fully Packaged & Available (v1.1.0)**  
> * **Official Repository**: [`P1gBagPt-Homelab/janus-cli`](https://github.com/P1gBagPt-Homelab/janus-cli) (Open Source, MIT)  
> * **Binary Path**: `/usr/local/bin/janus`  
> * **1-Line Remote Install**: `curl -fsSL https://raw.githubusercontent.com/P1gBagPt-Homelab/janus-cli/main/install.sh | sudo bash`  
> * **Pre-built Debian Package**: [GitHub Releases v1.1.0](https://github.com/P1gBagPt-Homelab/janus-cli/releases/tag/v1.1.0) (`janus-cli_1.1.0_all.deb`)  
> * **Purpose**: Single command interface eliminating the need to remember fragmented `docker`, `ufw`, `nvidia-smi`, `rclone`, `grub-reboot`, and `systemctl` commands.

---

## 1. Overview & Architecture

Day-to-day administration of a hybrid gaming PC and home server traditionally requires running half a dozen complex CLI utilities:
* Inspecting GPU thermals, VRAM, and power draw: `nvidia-smi`
* Checking storage usage across LVM SSD and cold HDD: `df -h / /data`
* Checking RAM pools and CPU thermals: `free -m`, `sensors`
* Tailing container logs without memorizing hashes: `docker logs -f --tail 100 <container_name>`
* Switching OS to Windows: `sudo grub-reboot "Windows Boot Manager (on /dev/nvme0n1p1)" && sudo reboot`
* Triggering offsite backups: `sudo bash /data/scripts/backup-janus.sh`

The **Janus CLI** bundles all of these capabilities into a single, lightning-fast terminal dashboard and command set:

```
      ██╗ █████╗ ███╗   ██╗██╗   ██╗███████╗
      ██║██╔══██╗████╗  ██║██║   ██║██╔════╝
      ██║███████║██╔██╗ ██║██║   ██║███████╗
 ██   ██║██╔══██║██║╚██╗██║██║   ██║╚════██║
 ╚█████╔╝██║  ██║██║ ╚████║╚██████╔╝███████║
  ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝
   Janus CLI v1.1.0 • Hybrid Gaming & Home Server Manager
```

---

## 2. Prerequisite: Run Docker Without Sudo

To ensure `janus status` and `janus logs` can query Docker containers without requiring `sudo` or `root`, make sure your user belongs to the `docker` group:

```bash
# 1. Add your user to the docker group
sudo usermod -aG docker $USER

# 2. Activate group changes immediately in current session
newgrp docker
```

*(You can verify by running `docker ps` — if it runs without `sudo`, you are ready!)*

---

## 3. Installation Options

### Option A: Universal 1-Line Remote Installer (Fastest)
Run this single command on your Ubuntu Server terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/P1gBagPt-Homelab/janus-cli/main/install.sh | sudo bash
```

The installer will:
1. Download the latest `janus` binary into `/usr/local/bin/janus`.
2. Install the **Bash Autocompletion** script into `/etc/bash_completion.d/janus`.
3. Create the template config at `/etc/janus/janus.conf.example`.
4. Set executable permissions.

---

### Option B: Native Debian Package (`.deb`)
Download the official `.deb` package built by GitHub Actions:

```bash
# Download v1.1.0 release asset
curl -LO https://github.com/P1gBagPt-Homelab/janus-cli/releases/download/v1.1.0/janus-cli_1.1.0_all.deb

# Install package via dpkg
sudo dpkg -i janus-cli_1.1.0_all.deb
```

---

### Option C: Cloned Local Repository Symlink (Developer Mode)
If you already cloned the repo locally on the machine:

```bash
git clone https://github.com/P1gBagPt-Homelab/janus-cli.git ~/janus-cli
sudo ln -sf ~/janus-cli/bin/janus /usr/local/bin/janus
sudo cp ~/janus-cli/completions/janus.bash /etc/bash_completion.d/janus
```

---

### Verification:
Test that the CLI is accessible:
```bash
janus help
```

---

## 4. Complete Command Reference

### 1. `janus status` (or just `janus`)
Displays the complete hardware, storage, GPU, container, and network telemetry board:

```bash
janus status
```

**Real output example:**
```text
🖥️  SYSTEM OVERVIEW
  Host:     janus  |  Uptime: up 4 days, 12 hours
  Kernel:   6.8.0-45-generic
  LAN IP:   192.168.1.68  |  WireGuard IP: 10.8.0.1

⚡ CPU & LOAD
  Model:    Intel(R) Core(TM) i7-8700K CPU @ 3.70GHz (12 Cores)
  Load Avg: [1m, 5m, 15m] -> 0.32, 0.28, 0.24  |  Temp: 42.0°C

🧠 MEMORY (RAM)
  [███████░░░░░░░░░░░░░]  34%  13.6 GB / 40.0 GB

💾 STORAGE POOLS
  Mount (/):         [████████░░░░░░░░░░]  42%  192G / 456G
  Mount (/data):     [████░░░░░░░░░░░░░░]  21%  195G / 931G

🎮 NVIDIA GPU ACCELERATION
  Model:    NVIDIA GeForce RTX 2070 (Driver: 595.99)
  Temp / Fan: 38°C  |  Fan: 0%  |  Power: 12W / 175W
  VRAM:     [██████░░░░░░░░░░░░]  31%  2.48 GB / 8.0 GB
  Active Compute Processes:
    • ollama: 2048 MiB VRAM

🐳 DOCKER & HOMELAB CONTAINERS
  Overview: 14 Running / 15 Total
  ● coolify              ● coolify-proxy        ● postgres             
  ● redis                ● docmost              ● vaultwarden          
  ● janusdeck            ● minio                ● rabbitmq             
  ● ollama               ● open-webui           ● uptime-kuma          
  ● netdata              ● wg-easy              
  Stopped / Exited (1):
  ○ glitchtip            

🛡️  NETWORK PERIMETER & FIREWALL
  WireGuard: Active (3 registered client keys)
  UFW:       Active (Default Deny Incoming)
```

---

### 2. `janus to-windows`
One-click switch to your Windows Gaming Rig:

```bash
janus to-windows
# Alias: janus win
```
* **Auto-Detection**: Automatically parses `/boot/grub/grub.cfg` to find your Windows Boot Manager entry.
* **Safety Confirmation**: Prompts with `Are you sure you want to reboot into Windows now? (y/N)`.
* **Graceful Transition**: Uses `sudo grub-reboot` to set a **one-time next boot** and reboots cleanly.
* **Auto-Revert**: When you are done gaming, restarting or shutting down Windows **automatically returns to Ubuntu Server**.

---

### 3. `janus backup`
Triggers the Guide 10 automated backup pipeline:

```bash
# 1. Trigger full snapshot & encrypted cloud sync:
janus backup

# 2. Inspect recent local snapshots and Google Drive cloud quota:
janus backup --status
```

---

### 4. `janus logs <service>`
Tails live container logs without having to look up generated container IDs:

```bash
janus logs coolify
janus logs docmost
janus logs vaultwarden
janus logs postgres
janus logs minio
```
*(Press `Ctrl+C` to stop tailing logs).*

---

### 5. `janus restart <service>`
Restarts a Docker container or systemd service matching the name:

```bash
janus restart coolify-proxy
janus restart docmost
```

---

### 6. `janus update`
Performs complete host and container maintenance:
```bash
janus update
```
1. Refreshes APT repositories and upgrades security packages.
2. Runs `apt autoremove -y`.
3. Prunes dangling Docker images and build caches to reclaim SSD space.

---

## 5. Configuration & Customization (`/etc/janus/janus.conf`)

Janus CLI works automatically with zero configuration. If you wish to customize paths or watch specific containers:

```bash
sudo cp /etc/janus/janus.conf.example /etc/janus/janus.conf
sudo nano /etc/janus/janus.conf
```

Available options:
```bash
# Target GRUB entry (Leave commented to auto-detect Windows Boot Manager)
# WINDOWS_GRUB_ENTRY="Windows Boot Manager (on /dev/nvme0n1p1)"

# Custom backup execution script
BACKUP_SCRIPT="/data/scripts/backup-janus.sh"

# Local backup directory
BACKUP_DIR="/data/backups/daily"

# Rclone encrypted remote name
RCLONE_REMOTE="janus-backup-encrypted:"

# Storage mount paths to monitor (Leave commented to auto-detect all mounts)
# STORAGE_PATHS="/ /data"

# Optional: List of specific Docker containers to watch
# If commented, Janus CLI dynamically discovers and renders ALL active containers!
# WATCHED_CONTAINERS="coolify postgres redis docmost vaultwarden"
```

---

## 6. Shell Integrations & Quality of Life

### 6.1 Pro-Tip: Single-Letter Alias (`j`)

To make manual monitoring instantaneous, add this shortcut to your `~/.bashrc`:

```bash
echo "alias j='janus'" >> ~/.bashrc
source ~/.bashrc
```

Now, typing **`j`** and pressing Enter instantly displays your entire homelab telemetry!

---

### 6.2 Automatic Status Dashboard on SSH Login

To automatically greet yourself with the full system telemetry dashboard every time you open an SSH connection, add an execution guard to your remote server's `~/.bashrc`:

```bash
cat << 'EOF' >> ~/.bashrc

# Show janus status automatically on SSH login
if [[ -n "$SSH_CONNECTION" && -z "$JANUS_STATUS_SHOWN" ]]; then
    export JANUS_STATUS_SHOWN=1
    janus status
fi
EOF
source ~/.bashrc
```

#### Why this implementation is robust:
* **`[[ -n "$SSH_CONNECTION" ]]`**: Ensures `janus status` runs specifically during remote SSH login sessions, preventing it from interrupting automated SCP/SFTP transfers, non-interactive scripts, or local terminal sessions.
* **`[[ -z "$JANUS_STATUS_SHOWN" ]]` & `export JANUS_STATUS_SHOWN=1`**: Acts as a session guard. It prevents the dashboard from redundantly re-executing when you open nested subshells (e.g., inside `tmux`, `screen`, sub-bash sessions, or VS Code Remote terminal panes).
