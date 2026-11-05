# Guide 09: System Hardening, Maintenance & Dual-Boot Clock Sync

> **Status**: ✅ **Fully Deployed & Operational on Project Janus**  
> * **Clock Synchronization**: `timedatectl set-local-rtc 1` (Hardware RTC in local TZ matching Windows).
> * **Firewall Hardening**: `ufw` active with default deny incoming, opening SSH (22), WireGuard (51820/51821), Web (80/443), and Management (8000, 19999, 3001).
> * **Intrusion Prevention**: `fail2ban` active on SSH jail.
> * **Automated Security Updates**: `unattended-upgrades` enabled for daily background patches.
> * **Hardware Diagnostic Toolkit**: `smartmontools`, `lm-sensors`, and `btop` CLI dashboard active.

Execute this guide immediately after installing Ubuntu Server. It applies the essential **dual-boot clock synchronization fix**, locks down security via a hardened firewall and brute-force protection, enables automated security patches, and configures hardware diagnostic tools.

---

## 1. Dual-Boot Clock Synchronization (Critical!)

### The Problem:
* **Windows** stores the motherboard hardware clock (RTC) in **Local Time**.
* **Linux** by default stores the hardware clock in **UTC**.
* *Result:* Every time you switch from Windows gaming to Linux server (or vice-versa), your system clock is off by several hours, causing broken SSL certificates, failed token authentications, and scrambled cron jobs.

### The Fix:
Run this single command on your Ubuntu Server to instruct Linux to match the motherboard's local time:
```bash
sudo timedatectl set-local-rtc 1 --adjust-system-clock
```

### Verification:
```bash
timedatectl
```
*(Confirm `RTC in local TZ: yes` is displayed).*

---

## 2. One-Command Utility Installation

Install the curated maintenance, telemetry, and security toolkit:

```bash
sudo apt update && sudo apt install -y \
  ufw \
  fail2ban \
  unattended-upgrades \
  smartmontools \
  lm-sensors \
  btop \
  ncdu \
  tmux \
  git \
  curl \
  jq
```

---

## 3. Firewall Hardening with `ufw`

Block all uninvited incoming traffic by default, only opening the exact ports needed for Project Janus:

1. **Set strict default policies**:
   ```bash
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   ```

2. **Allow essential services**:
   ```bash
   # 1. SSH Management
   sudo ufw allow 22/tcp comment 'SSH Remote Access'

   # 2. WireGuard VPN & Web Dashboard
   sudo ufw allow 51820/udp comment 'WireGuard VPN'
   sudo ufw allow 51821/tcp comment 'WireGuard Web UI'

   # 3. Web & Traefik Reverse Proxy (LAN & WireGuard clients only; closed on router)
   sudo ufw allow 80/tcp comment 'HTTP Web Traffic (Internal)'
   sudo ufw allow 443/tcp comment 'HTTPS Encrypted Web (Internal)'

   # 4. Management & Telemetry Dashboards
   sudo ufw allow 8000/tcp comment 'Coolify Dashboard'
   sudo ufw allow 19999/tcp comment 'Netdata Telemetry'
   sudo ufw allow 3001/tcp comment 'Uptime Kuma'
   ```

3. **Enable the firewall**:
   ```bash
   sudo ufw enable
   ```
   *(Type `y` and press Enter when prompted).*

4. **Verify status**:
   ```bash
   sudo ufw status verbose
   ```

---

## 4. SSH Brute-Force Defense (`fail2ban`)

Bots continuously scan public IPs trying common passwords. `fail2ban` automatically monitors SSH authentication logs and temporarily bans any IP address that fails 3 consecutive logins.

1. **Create local override configuration**:
   ```bash
   sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
   ```
2. **Start and enable the service**:
   ```bash
   sudo systemctl enable --now fail2ban
   ```
3. **Verify SSH protection is active**:
   ```bash
   sudo fail2ban-client status sshd
   ```
   *(Shows currently banned IPs and active jail filter).*

---

## 5. Automated Security Updates (`unattended-upgrades`)

Ensure critical Linux kernel and security vulnerabilities are patched automatically without needing manual intervention:

1. Run the interactive setup:
   ```bash
   sudo dpkg-reconfigure -plow unattended-upgrades
   ```
2. Select **<Yes>** and press **Enter**.
3. *Result:* Ubuntu will quietly install security patches daily in the background. It will never restart running Docker containers unexpectedly.

---

## 6. Hardware & Storage Telemetry

### 1. Motherboard & CPU Thermal Sensors (`lm-sensors`):
Detect the thermal sensors on your ASUS PRIME Z370-A and i7-8700K:
```bash
sudo sensors-detect --auto
```
Check instantaneous temperatures anytime by typing:
```bash
sensors
```

### 2. S.M.A.R.T. Drive Health Checks (`smartmontools`):
Check the physical health status of your drives to prevent unexpected disk failures:
```bash
# Check overall health status (replace /dev/sdX with drive name)
sudo smartctl -H /dev/sda

# View detailed error logs and reallocated bad sectors
sudo smartctl -A /dev/sda
```
*(Look for `SMART overall-health self-assessment test result: PASSED`)*.

---

## 7. Daily Admin Command Cheat-Sheet

* **`btop`**: Beautiful, interactive terminal dashboard displaying real-time CPU, 40GB RAM, network speeds, and **RTX 2070 GPU VRAM/temperature** directly in your terminal.
* **`ncdu /data`**: Interactive storage visualizer. Instantly shows which Docker containers or logs are consuming space on your drives.
* **`tmux`**: Keeps long-running commands, builds, or scripts alive even if your laptop disconnects from SSH.
  * Start session: `tmux`
  * Detach session: Press `Ctrl + B`, then `D`
  * Reattach session: `tmux attach`

---

## 8. Safe Shutdown, Reboot & Automated Service Recovery

When operating a home server with persistent databases, always power off or reboot gracefully to prevent data corruption:

### 1. Safe Power Off (Graceful Shutdown):
```bash
sudo shutdown -h now
```
*(Or `poweroff` if logged in as root).*

### 2. Safe Reboot:
```bash
sudo reboot
```

### What Happens Behind the Scenes:
1. **Database Buffer Flush**: Linux systemd issues a `SIGTERM` signal to Docker. **PostgreSQL** and **Redis** gracefully commit transaction logs (WAL) and write cached memory pages to the NVMe disk (`/data`).
2. **Clean Unmount**: All filesystem mounts (`/` and `/data`) are safely unmounted without filesystem dirt.
3. **Hardware ACPI Power-Off**: Motherboard, CPU, GPU, and fans power down completely.

### Automated Boot Recovery:
All infrastructure services across Project Janus (WireGuard Gateway, Coolify PaaS, Traefik Reverse Proxy, PostgreSQL 18, Redis 7.2, and Docmost) are configured with `restart: unless-stopped`:
* As soon as you turn the computer back on (or wake it remotely via the Weten PCI-e card), **Ubuntu starts all containers automatically in the background**.
* No manual terminal commands or container restarts are needed; all dashboards and web services are immediately restored!

Your server OS is now hardened, synchronized with Windows, equipped with professional diagnostics, and protected with graceful shutdown procedures!
