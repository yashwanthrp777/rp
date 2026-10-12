# Docker, Nginx & AWS EC2 Linux Deployment Guide

This guide details how to build and host the application on an **AWS Linux EC2 Instance** (Amazon Linux 2023, Amazon Linux 2, or Ubuntu) using **Docker**, **Next.js Standalone**, and **Nginx Reverse Proxy**.

---

## Architecture Overview

```
                      Internet / Browser
                              │
                    ┌─────────▼─────────┐
                    │     Port 80 / 443 │
                    │   Nginx Container │
                    └─────────┬─────────┘
                              │
                      Docker Internal Network (app-network)
                              │
                    ┌─────────▼─────────┐
                    │     Port 3000     │
                    │ Next.js Container │
                    └───────────────────┘
```

- **Nginx**: Handles external HTTP/HTTPS traffic, WebSockets for Convex real-time updates, client upload limits, and static asset caching.
- **Next.js Container**: Runs the compiled standalone server as an unprivileged `node` user with ~100MB footprint.

---

## 1. Prerequisites on AWS Linux EC2

### For Amazon Linux 2023:
```bash
sudo dnf update -y
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user

# Install Docker Compose plugin
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Log out and log back in for docker group to take effect
newgrp docker
```

### For Ubuntu EC2:
```bash
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu
newgrp docker
```

---

## 2. Recommended: Enable Swap (Crucial for `t2.micro` / `t3.micro`)

Building a modern Next.js project on a 1GB/2GB RAM EC2 instance can trigger Out-Of-Memory (OOM) kills. Add a 2GB swap space:

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 3. Configure Inbound Security Group in AWS

In the AWS EC2 Management Console:
1. Navigate to **EC2 > Security Groups > Your Instance Security Group**.
2. Add **Inbound Rules**:
   - **HTTP** | Port `80` | Source: `0.0.0.0/0`
   - **HTTPS** | Port `443` | Source: `0.0.0.0/0`
   - **SSH** | Port `22` | Source: `Your IP`
   - *(Optional)* Custom TCP | Port `3000` | Source: `Your IP` (for direct debugging)

---

## 4. Setup Environment Variables

On your EC2 instance inside the project root:
```bash
cp .env.example .env.local
nano .env.local
```
Fill in your Convex, Clerk, and Gemini API keys.

---

## 5. Build and Start Application (Next.js + Nginx)

Run the following command to build Next.js and launch both containers:
```bash
docker compose up -d --build
```

### Useful Management Commands:
- **View container status:** `docker compose ps`
- **View real-time logs:** `docker compose logs -f`
- **View only Nginx logs:** `docker compose logs -f nginx`
- **View only Next.js logs:** `docker compose logs -f server`
- **Restart services:** `docker compose restart`
- **Stop containers:** `docker compose down`

---

## 6. Accessing Your Application

Open your browser and navigate to:
```
http://<YOUR-EC2-PUBLIC-IP>
```
*(No port number needed! Nginx automatically listens on standard port 80 and proxies traffic to Next.js.)*