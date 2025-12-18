# Prerequisites

**Version:** 1.0.0  
**Last Updated:** 2024

This document outlines the system requirements, infrastructure setup, and configuration prerequisites for deploying the StackWatch Infrastructure Gateway.

---

## 1. Operating System Requirements

### Supported Linux Distribution

StackWatch supports **Ubuntu LTS** distributions only:

| Distribution | Minimum Version | Recommended Version | Package Manager |
|-------------|----------------|---------------------|----------------|
| **Ubuntu** | 22.04 LTS | 24.04 LTS | `apt` |

**Recommended:** Ubuntu 24.04 LTS for production deployments.

### System Architecture

- **CPU Architecture:** x86_64 (AMD64) or ARM64 (aarch64)
- **Kernel Version:** Linux 5.15+ (Ubuntu 22.04 LTS minimum)

---

## 2. Hardware Requirements

### Minimum Requirements

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **CPU** | 2 cores | 4+ cores | For container workloads |
| **RAM** | 4 GB | 8 GB+ | 2 GB for OS, 2 GB for containers |
| **Disk Space** | 50 GB | 100 GB+ | See partitioning section below |
| **Network** | 100 Mbps | 1 Gbps | For metrics collection |

### Production Recommendations

- **CPU:** 4-8 cores (for handling multiple exporters and dashboards)
- **RAM:** 16 GB (for Prometheus time-series data and Grafana dashboards)
- **Disk:** 200 GB+ with SSD for better I/O performance
- **Network:** 1 Gbps with low latency to target servers

---

## 3. Disk Partitioning Strategy

### Industry Best Practice: Separate Partitions for Data Isolation

To protect critical monitoring data in case of primary disk corruption, use separate partitions for Grafana and Prometheus data.

### Recommended Partition Layout

```
/dev/sda1  /boot         512 MB   (Boot partition)
/dev/sda2  /             20 GB    (Root filesystem - OS and applications)
/dev/sda3  /var          10 GB    (Logs, temporary files)
/dev/sda4  /opt/prometheus/data  50 GB+  (Prometheus time-series data)
/dev/sda5  /opt/grafana/data     20 GB+  (Grafana database, dashboards, plugins)
/dev/sda6  /var/www/stackwatch    5 GB    (Frontend static files)
/dev/sda7  swap          4 GB     (Swap space - 2x RAM for <8GB systems)
```

### Partition Setup Commands

**Ubuntu:**
```bash
# Example using fdisk (adjust device name as needed)
sudo fdisk /dev/sda

# Create partitions:
# n (new partition)
# p (primary)
# 4 (partition number)
# [Enter] (use default start)
# +50G (size)
# w (write and exit)

# Format Prometheus data partition
sudo mkfs.ext4 /dev/sda4
sudo mkdir -p /opt/prometheus/data
sudo mount /dev/sda4 /opt/prometheus/data

# Format Grafana data partition
sudo mkfs.ext4 /dev/sda5
sudo mkdir -p /opt/grafana/data
sudo mount /dev/sda5 /opt/grafana/data

# Add to /etc/fstab for persistent mounting
echo "/dev/sda4 /opt/prometheus/data ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
echo "/dev/sda5 /opt/grafana/data ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
```

### Benefits of Separate Partitions

- **Data Protection:** Prometheus and Grafana data isolated from OS corruption
- **Performance:** Dedicated I/O for time-series database operations
- **Backup:** Easier to backup specific partitions
- **Recovery:** Can restore data partitions independently
- **Monitoring:** Track disk usage per service separately

---

## 4. User Management and Permissions

### Service User Accounts

Create dedicated users for running services (industry best practice):

```bash
# Create Prometheus user (if not using containers)
sudo useradd --no-create-home --shell /bin/false prometheus

# Create Grafana user (if not using containers)
sudo useradd --no-create-home --shell /bin/false grafana

# Create StackWatch service account
sudo useradd -r -s /bin/false -d /opt/stackwatch stackwatch
```

### Directory Ownership

```bash
# Set ownership for Prometheus data
sudo chown -R prometheus:prometheus /opt/prometheus/data
sudo chown -R prometheus:prometheus /opt/prometheus/config

# Set ownership for Grafana data
sudo chown -R grafana:grafana /opt/grafana/data
sudo chown -R grafana:grafana /opt/grafana/config

# Set ownership for StackWatch installation
sudo chown -R stackwatch:stackwatch /opt/stackwatch
sudo chown -R www-data:www-data /var/www/stackwatch
```

### Sudo Access Requirements

The deployment user needs sudo access for:
- Installing packages (apt)
- Managing systemd services
- Configuring firewall rules
- Creating directories in /opt and /var/www

**Recommended:** Use a dedicated deployment user with limited sudo privileges:

```bash
# Create deployment user
sudo useradd -m -s /bin/bash stackwatch-deploy

# Grant sudo access
sudo usermod -aG sudo stackwatch-deploy

# Optional: Limit sudo to specific commands
sudo visudo
# Add:
# stackwatch-deploy ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/systemctl, /usr/sbin/ufw
```

---

## 5. Software Dependencies

### Required Packages

**Ubuntu:**
```bash
sudo apt update
sudo apt install -y \
    git \
    curl \
    wget \
    ansible \
    podman \
    podman-docker \
    nginx \
    python3 \
    python3-pip \
    sshpass \
    build-essential
```

### Node.js Installation (Required for Frontend Build)

**Ubuntu:**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

**Verify Installation:**
```bash
node --version  # Should show v20.x.x
npm --version   # Should show 10.x.x
```

### Podman Configuration

**Enable Podman socket (for systemd integration):**
```bash
sudo systemctl enable --now podman.socket
sudo systemctl status podman.socket
```

**Configure Podman for rootless containers (optional but recommended):**
```bash
# Enable user namespaces
echo "kernel.unprivileged_userns_clone=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

---

## 6. Network Requirements

### Port Requirements

| Port | Service | Access | Purpose |
|------|---------|--------|---------|
| **80** | Nginx | Public | HTTP web interface |
| **443** | Nginx | Public | HTTPS (if configured) |
| **9090** | Prometheus | Localhost only | Prometheus UI (proxied via Nginx) |
| **3000** | Grafana | Localhost only | Grafana UI (proxied via Nginx) |
| **9100** | Node Exporter / Windows Exporter | Internal | Linux and Windows metrics endpoint |
| **22** | SSH | Internal/Management | Server administration |

**Important Notes:**
- Both Linux Node Exporter and Windows Exporter use port **9100** by default
- Port 9100 is blocked from external access by default (only accessible internally by Prometheus)
- The Windows Exporter script accepts a `-NodeExporterPort` parameter to change the port if needed

### Firewall Configuration

**Ubuntu (UFW):**
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
# Note: Port 9100 is blocked by default for security (only Prometheus can access via internal network)
sudo ufw enable
```

### Network Connectivity

- **Internet Access:** Required for downloading container images and packages
- **DNS Resolution:** Must resolve Docker Hub (docker.io) and package repositories
- **Target Server Access:** SSH access to servers where exporters will be deployed
- **Internal Network:** Access to port 9100 on target servers for metrics scraping

---

## 7. Security Prerequisites

### SSH Key-Based Authentication

**Generate SSH key pair (if not exists):**
```bash
ssh-keygen -t ed25519 -C "stackwatch-deployment" -f ~/.ssh/stackwatch_key
```

**Copy public key to target servers:**
```bash
ssh-copy-id -i ~/.ssh/stackwatch_key.pub user@target-server
```

### AppArmor Configuration

**Ensure AppArmor allows Podman operations:**
```bash
sudo systemctl status apparmor
# AppArmor should be active, Podman works with default profiles
```

---

## 8. Storage Considerations

### Prometheus Data Retention

- **Default Retention:** 15 days
- **Storage Calculation:** ~1-2 GB per 1,000 metrics per day
- **Example:** 10,000 metrics × 15 days = ~150-300 GB

**Adjust partition size based on:**
- Number of targets being monitored
- Scrape interval (default: 15s)
- Retention period requirements

### Grafana Storage

- **Database:** SQLite (default) or PostgreSQL (recommended for production)
- **Storage Needs:** ~100 MB base + ~10 MB per dashboard + plugin storage
- **Recommended:** 20 GB partition for Grafana data

---

## 9. Pre-Deployment Checklist

Before deploying StackWatch, verify:

- [ ] Ubuntu 22.04 LTS or 24.04 LTS installed and up-to-date
- [ ] Minimum hardware requirements met (4 CPU, 8 GB RAM, 50 GB disk)
- [ ] Separate partitions created for Prometheus and Grafana data
- [ ] Required packages installed (Podman, Nginx, Ansible, Node.js)
- [ ] Node.js version 20.x installed and verified
- [ ] Podman installed and socket enabled
- [ ] Firewall configured (ports 80, 443, 22)
- [ ] SSH key-based authentication configured for target servers
- [ ] Dedicated service users created (prometheus, grafana, stackwatch)
- [ ] Directory ownership set correctly
- [ ] Network connectivity verified (internet, DNS, target servers)
- [ ] Sudo access configured for deployment user
- [ ] AppArmor configured (Ubuntu default)

---

## 10. Post-Installation Verification

After meeting prerequisites, verify system readiness:

```bash
# Check Ubuntu version
lsb_release -a

# Check Podman
podman --version
podman info

# Check Node.js
node --version
npm --version

# Check Ansible
ansible --version

# Check Nginx
nginx -v

# Check disk space
df -h

# Check partitions
lsblk

# Check network
ping -c 3 8.8.8.8  # Internet connectivity
curl -I https://docker.io  # Docker Hub access
```

---

## Next Steps

Once all prerequisites are met, proceed to:
1. **Grafana Configuration Doc** - Configure Grafana dashboards and data sources
2. **Prometheus Configuration** - Set up Prometheus targets and scrape configuration

---

**Note:** This document follows industry best practices for production monitoring infrastructure deployment, emphasizing data isolation, security, and operational reliability.
