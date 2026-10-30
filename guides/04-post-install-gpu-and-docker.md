# Guide 04: Post-Install Setup (NVIDIA Drivers & Docker)

Now that Ubuntu Server 24.04 LTS is installed, this guide walks you through connecting remotely via SSH, installing proprietary NVIDIA drivers for your **ASUS Strix RTX 2070**, and configuring **Docker with GPU acceleration**.

---

## Step 1: Connect to Your Server via SSH

From your laptop or another computer on the same home network:
1. Open PowerShell, Command Prompt, or a terminal.
2. Connect to your server using its local IP address (noted during installation):
   ```bash
   ssh daniel@192.168.1.xxx
   ```
3. Type your password when prompted. You now have full terminal control of your home server!

---

## Step 2: Update Ubuntu & Packages

Ensure your base system is up to date:
```bash
sudo apt update && sudo apt upgrade -y
```

---

## Step 3: Install NVIDIA Proprietary Drivers (For RTX 2070)

Ubuntu has an automated hardware driver manager that chooses the best, fully tested proprietary driver for your RTX 2070:

1. Run the auto-installer:
   ```bash
   sudo ubuntu-drivers install
   ```
2. Reboot the server to load the new kernel modules:
   ```bash
   sudo reboot
   ```
3. Wait 10 seconds, reconnect via SSH (`ssh daniel@192.168.1.xxx`), and verify your GPU:
   ```bash
   nvidia-smi
   ```

### Expected Output:
You will see the NVIDIA system management table displaying:
* **GPU**: `GeForce RTX 2070`
* **Driver Version**: `535.xx` or `550.xx`
* **CUDA Version**: `12.x`
* **Memory**: `0MiB / 7982MiB` (8GB VRAM ready for action)

---

## Step 4: Install Official Docker Engine & Docker Compose

To ensure maximum container compatibility and speed, install Docker from the official Docker repository:

1. **Install required dependencies**:
   ```bash
   sudo apt update
   sudo apt install -y ca-certificates curl gnupg
   ```
2. **Add Docker's official GPG key**:
   ```bash
   sudo install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   sudo chmod a+r /etc/apt/keyrings/docker.gpg
   ```
3. **Set up the official repository**:
   ```bash
   echo \
     "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
     $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
     sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   ```
4. **Install Docker Engine & Compose plugin**:
   ```bash
   sudo apt update
   sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
   ```
5. **Enable running Docker without `sudo`**:
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```
6. **Verify Docker**:
   ```bash
   docker run --rm hello-world
   ```

---

## Step 5: Configure NVIDIA Container Toolkit (GPU in Docker)

This enables Docker containers to utilize your RTX 2070's CUDA cores and Tensor cores for local AI and media transcoding:

1. **Add NVIDIA Container Toolkit repository**:
   ```bash
   curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
   curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
     sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
     sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
   ```
2. **Install the toolkit**:
   ```bash
   sudo apt update
   sudo apt install -y nvidia-container-toolkit
   ```
3. **Configure Docker to use NVIDIA runtime**:
   ```bash
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```
4. **Test GPU inside a container**:
   ```bash
   docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
   ```
   *(If you see your RTX 2070 printed inside the container, GPU pass-through is 100% functional!)*

---

## Step 6: Prepare the Dedicated Data Disk Permissions

Your second server disk is mounted at `/data`. Set your user account as the owner so you can create projects without permission roadblocks:

```bash
sudo chown -R $USER:$USER /data
mkdir -p /data/compose/projects /data/compose/infrastructure /data/volumes /data/ai
```

Your server runtime is now complete and fully primed to host containers, mini-projects, and AI workloads!
