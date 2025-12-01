# STACKBILL: Operations Guide

**Document Version:** 1.0.0  
**Audience:** System Administrators  
**Last Updated:** 2024

---

## 1. Overview

STACKBILL is a unified monitoring stack that provides centralized access to Prometheus metrics collection and Grafana visualization through a single web interface. The stack consists of:

- **Nginx** (port 80): Entry point and reverse proxy serving the StackBill frontend and routing to backend services
- **Prometheus** (port 9090): Time-series metrics database and collection engine
- **Grafana** (port 3000): Visualization and dashboard platform
- **Linux Node Exporter** (port 9100): System metrics exporter for Linux servers, deployed via Ansible
- **Windows Exporter** (port 9100): System metrics exporter for Windows servers, deployed via PowerShell script

All services are accessible through Nginx at the root path (`/`), with Prometheus at `/prometheus` and Grafana at `/grafana`.

---

## 2. Prerequisites

### Supported Operating Systems

- **Control Node (where scripts run):** Linux (RHEL/CentOS 7+, Ubuntu 18.04+, Debian 10+)
- **Linux Target Servers:** RHEL/CentOS, Debian/Ubuntu, Arch, SUSE (for Node Exporter)
- **Windows Target Servers:** Windows Server 2016+ or Windows 10+ (for Windows Exporter)

### Required Permissions

- **Control Node:** Root or sudo access for running deployment scripts
- **Linux Target Servers:** SSH access with sudo/root privileges for Ansible
- **Windows Target Servers:** Administrator privileges for PowerShell script execution

### Required Open Ports

| Port | Service | Direction | Purpose |
|------|---------|-----------|---------|
| 80 | Nginx | Inbound | Web access to StackBill frontend |
| 443 | Nginx (HTTPS) | Inbound | Secure web access (optional) |
| 9090 | Prometheus | Localhost only | Metrics collection (proxied via Nginx) |
| 3000 | Grafana | Localhost only | Dashboard access (proxied via Nginx) |
| 9100 | Node Exporter | Inbound (internal) | Linux metrics endpoint |
| 9100 | Windows Exporter | Inbound (internal) | Windows metrics endpoint |

**Note:** Ports 9090, 3000, and 9100 should NOT be directly accessible from external networks. Access is provided through Nginx reverse proxy.

### Required Packages and Tools

**On Control Node:**
- Git (to clone repository)
- Node.js 20.x (required for frontend build)
- Ansible 2.9+ (for Linux Node Exporter deployment)
- Podman (for Prometheus and Grafana containers)
- Nginx (web server)
- Bash shell
- Python 3.6+ (required by Ansible)

**On Linux Target Servers:**
- SSH server
- Python 3.6+ (required by Ansible)
- curl or wget (for downloading Node Exporter)

**On Windows Target Servers:**
- PowerShell 5.1+ (built-in on Windows 10/Server 2016+)
- Internet access (to download Windows Exporter MSI)

### Installation Commands

**RHEL/CentOS:**
```bash
sudo yum install -y git ansible podman nginx python3
```

**Debian/Ubuntu:**
```bash
sudo apt update
sudo apt install -y git ansible podman nginx python3 sshpass

# Install Node.js 20.x (required for frontend build)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install nodejs -y
```

**RHEL/CentOS:**
```bash
sudo yum install -y git ansible podman nginx python3 sshpass

# Install Node.js 20.x (required for frontend build)
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo yum install -y nodejs
```

**Why Node.js is Required:**
Node.js is required to build the StackBill frontend application. The frontend uses npm (Node Package Manager) to install dependencies and build the production-ready static files that Nginx serves. Node.js must be installed BEFORE building the frontend (Section 3.2).

**Verify Node.js Installation:**
```bash
node --version
npm --version
```

**Expected Result:** Node.js version 20.x and npm version displayed

---

## 3. Step-by-Step Installation – Nginx + Front Entry

### 3.1 Clone Repository

```bash
cd /opt
git clone <repository-url> stackbill
cd stackbill
```

**Expected Result:** Repository cloned to `/opt/stackbill`

### 3.2 Build Frontend (if needed)

If the frontend is not pre-built, build it:

```bash
npm install
npm run build
```

**Expected Result:** `dist/` directory created with frontend build files

### 3.2.1 Set Script Execution Permissions

**⚠️ MANDATORY STEP - Execute before running any scripts**

**What chmod does:**
The `chmod +x` command adds execute permission to files, allowing them to be run as programs. Without execute permission, the shell cannot execute the script files.

**Why it is required:**
Script files in the repository may not have execute permissions set by default. Attempting to run a script without execute permission will result in a "Permission denied" error.

**What error occurs if skipped:**
```bash
bash: ./scripts/deploy-nginx.sh: Permission denied
```

**Set permissions for all deployment scripts:**
```bash
chmod +x ./scripts/deploy-nginx.sh
chmod +x ./scripts/deploy-prometheus.sh
chmod +x ./scripts/deploy-grafana.sh
chmod +x ./scripts/configure-firewall.sh
chmod +x ./scripts/deploy-stackbill.sh
chmod +x ./scripts/health-check.sh
```

**Verification:**
```bash
ls -l ./scripts/*.sh
```

**Expected Result:** All script files show `-rwxr-xr-x` (execute permission enabled)

**Note:** If you run scripts with `bash ./scripts/deploy-nginx.sh`, execute permissions are not required, but using `./scripts/deploy-nginx.sh` requires execute permissions.

### 3.3 Deploy Nginx

**⚠️ IMPORTANT: Ensure script has execute permissions (see Section 3.2.1)**

Run the Nginx deployment script:

```bash
sudo ./scripts/deploy-nginx.sh
```

**What the script does:**
1. Creates Nginx configuration at `/etc/nginx/sites-available/stackbill`
2. Configures reverse proxy for `/prometheus` → `http://localhost:9090`
3. Configures reverse proxy for `/grafana` → `http://localhost:3000`
4. Serves frontend static files from `/var/www/stackbill/dist`
5. Enables the Nginx site
6. Tests and reloads Nginx configuration

**Verification:**

```bash
# Check Nginx service status
sudo systemctl status nginx

# Test Nginx configuration
sudo nginx -t

# Verify Nginx is listening on port 80
sudo netstat -tlnp | grep :80
# OR
sudo ss -tlnp | grep :80
```

**Expected Result:** Nginx service is active and listening on port 80

### 3.4 Test StackBill Home Page

```bash
# Test from localhost
curl http://localhost/

# Test from external (replace with your server IP)
curl http://<server-ip>/
```

**Expected Result:** HTML content from StackBill frontend is returned

**Browser Access:** Open `http://<server-ip>/` in a web browser. You should see the StackBill dashboard with links to Prometheus and Grafana.

---

## 4. Step-by-Step Installation – Podman, Prometheus, Grafana

### 4.1 Install Podman (if not installed)

**RHEL/CentOS:**
```bash
sudo yum install -y podman
```

**Debian/Ubuntu:**
```bash
sudo apt install -y podman
```

**Verification:**
```bash
podman --version
```

### 4.2 Deploy Prometheus

**⚠️ IMPORTANT: Ensure script has execute permissions (see Section 3.2.1)**

**Run the Prometheus deployment script:**

**Note:** The script will automatically pull the Prometheus image (`docker.io/prom/prometheus:latest`) before creating the container.

```bash
sudo ./scripts/deploy-prometheus.sh
```

**What the script does:**
1. Prepares host volumes and directories:
   - Creates `/etc/prometheus` directory
   - Creates `/var/lib/prometheus/data` directory
   - Creates `prometheus.yml` file if it doesn't exist
2. Creates Prometheus configuration file at `/etc/prometheus/prometheus.yml`
3. Pulls Prometheus container image (`docker.io/prom/prometheus:latest`)
4. Runs Prometheus container with proper volume mounts and SELinux context (:Z flags)
5. Creates systemd service for auto-start on boot
6. Verifies container is running


**Verification:**

```bash
# Check Prometheus container status
sudo podman ps | grep prometheus

# Check Prometheus health endpoint
curl http://localhost:9090/-/healthy

# Check Prometheus via Nginx proxy
curl http://localhost/prometheus/-/healthy

# Check systemd service (if created)
sudo systemctl status container-prometheus.service

# Check container logs for errors
sudo podman logs prometheus | tail -20
```

**Expected Result:**
- Container is running
- Health endpoint returns "Prometheus is Healthy."
- Accessible via Nginx at `http://<server-ip>/prometheus`
- No errors in container logs

**If image pull failed:**
- Verify internet connectivity: `ping 8.8.8.8`
- Check Podman can access Docker Hub: `sudo podman pull docker.io/prom/prometheus:latest`
- Review logs: `sudo podman logs prometheus`

**Browser Access:** Open `http://<server-ip>/prometheus` in a web browser. You should see the Prometheus web UI.

### 4.3 Deploy Grafana

**⚠️ IMPORTANT: Ensure script has execute permissions (see Section 3.2.1)**

**Run the Grafana deployment script:**

**Note:** The script will automatically pull the Grafana image (`docker.io/grafana/grafana:latest`) before creating the container.

**IP Address Detection:**
- **Most client deployments:** Servers with direct private IP addresses (e.g., `192.168.1.100`, `10.0.0.50`) - auto-detection works automatically
- **NAT/Lab environments:** Servers behind NAT with public IP (e.g., `123.176.58.198`) - requires manual override (see below)

**Standard deployment (direct private IP):**
```bash
sudo ./scripts/deploy-grafana.sh
```

**NAT/Lab environment (public IP override):**
```bash
# Set the public IP or domain before deploying
export GRAFANA_DOMAIN="123.176.58.198"
sudo ./scripts/deploy-grafana.sh

# Or set inline
sudo GRAFANA_DOMAIN="123.176.58.198" ./scripts/deploy-grafana.sh
```

**What the script does:**
1. Prepares host volumes and directories:
   - Creates `/var/lib/grafana` (data directory for DB files, plugins, uploads)
   - Creates `/etc/grafana/config` (main Grafana config directory)
   - Creates `/etc/grafana/provisioning/dashboards` (dashboard provisioning)
   - Creates `/etc/grafana/provisioning/datasources` (datasource provisioning)
   - Creates `/etc/grafana/provisioning/alerting` (alerting provisioning)
2. Sets permissions:
   - Sets ownership to Grafana user (UID 472:472) for all directories
   - SELinux context handled by :Z flags in Podman volumes
3. Detects server IP address:
   - **Auto-detection:** Scans all network interfaces for IP addresses
   - **Prioritizes public IPs** over private IPs when both are available
   - **Uses private IP** when no public IP is detected (typical for direct private IP deployments)
   - **Manual override:** `GRAFANA_DOMAIN` environment variable overrides auto-detection (required for NAT/lab environments)
4. Creates `grafana.ini` configuration file at `/etc/grafana/config/grafana.ini` with detected/configured domain
5. Pulls Grafana container image (`docker.io/grafana/grafana:latest`)
6. Runs Grafana container with:
   - DNS servers (8.8.8.8, 1.1.1.1)
   - Proper volume mounts with SELinux context (:Z flags)
   - All provisioning directories mapped
6. Creates systemd service for auto-start on boot
7. Verifies container is running

**Default Credentials:**
- Username: `admin`
- Password: `admin`

**⚠️ IMPORTANT:** Change the default password in production!

**Verification:**

```bash
# Check Grafana container status
sudo podman ps | grep grafana

# Check Grafana health endpoint
curl http://localhost:3000/api/health

# Check Grafana via Nginx proxy
curl http://localhost/grafana/api/health

# Check systemd service (if created)
sudo systemctl status container-grafana.service

# Check container logs for errors
sudo podman logs grafana | tail -20
```

**If image pull failed:**
- Verify internet connectivity: `ping 8.8.8.8`
- Check Podman can access Docker Hub: `sudo podman pull docker.io/grafana/grafana:latest`
- Review logs: `sudo podman logs grafana`

**Expected Result:**
- Container is running
- Health endpoint returns JSON with `"database":"ok"`
- Accessible via Nginx at `http://<server-ip>/grafana`

**Browser Access:** Open `http://<server-ip>/grafana` in a web browser. You should see the Grafana login page.

---

## 5. Step-by-Step Installation – Linux Node Exporter (Ansible)

### 5.1 Prepare Ansible Inventory

Edit the inventory file with your Linux server details:

```bash
nano ansible/inventory/hosts
```

**Inventory Format:**
```ini
[linux_servers]
server1 ansible_host=192.168.1.11 ansible_user=deploy
server2 ansible_host=192.168.1.12 ansible_user=deploy

[all:vars]
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
```

**Replace:**
- `server1`, `server2` with your server hostnames
- `192.168.1.11`, `192.168.1.12` with actual IP addresses
- `deploy` with your SSH username
- `~/.ssh/id_rsa` with path to your SSH private key

### 5.2 Test Ansible Connectivity

```bash
ansible linux_servers -i ansible/inventory/hosts -m ping
```

**Expected Result:** All servers return `SUCCESS` with pong message

### 5.3 Deploy Node Exporter

Run the Ansible playbook:

```bash
ansible-playbook ansible/playbooks/deploy-node-exporter.yml
```

**What the playbook does:**
1. Detects Linux distribution and architecture
2. Fetches latest Node Exporter version from GitHub (or uses default 1.10.2)
3. Downloads Node Exporter binary for the detected architecture
4. Creates `node_exporter` user and group
5. Installs Node Exporter binary to `/usr/local/bin/node_exporter`
6. Creates systemd service file at `/etc/systemd/system/node_exporter.service`
7. Enables and starts the Node Exporter service
8. Configures firewall rules (firewalld, UFW, or iptables) to allow port 9100
9. Verifies Node Exporter is running and responding

**Verification on Target Servers:**

```bash
# SSH to a target server
ssh deploy@192.168.1.11

# Check Node Exporter service status
sudo systemctl status node_exporter

# Check if port 9100 is listening
sudo netstat -tlnp | grep :9100
# OR
sudo ss -tlnp | grep :9100

# Test metrics endpoint
curl http://localhost:9100/metrics
```

**Expected Result:**
- Service is `active (running)`
- Port 9100 is listening
- Metrics endpoint returns Prometheus format metrics

**Example Metrics Output:**
```
# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 12345.67
...
```

### 5.4 Verify from Control Node

```bash
# Test metrics endpoint from control node
curl http://192.168.1.11:9100/metrics
```

**Expected Result:** Metrics are accessible from the control node (if firewall allows)

---

## 6. Step-by-Step Installation – Windows Exporter (PowerShell Script)

### 6.1 Transfer Script to Windows Server

**Option 1: Copy script from repository**
```powershell
# On Windows server, download or copy the script
# From repository: scripts/deploy-windows-exporter.ps1
```

**Option 2: Clone repository on Windows (if Git is available)**
```powershell
cd C:\
git clone <repository-url> stackbill
cd stackbill
```

### 6.2 Run PowerShell Script

**Open PowerShell as Administrator** on the Windows server, then run:

```powershell
# Navigate to script location
cd C:\stackbill\scripts

# Run the deployment script
powershell -ExecutionPolicy Bypass -File deploy-windows-exporter.ps1
```

**With Custom Port (optional):**
```powershell
powershell -ExecutionPolicy Bypass -File deploy-windows-exporter.ps1 -NodeExporterPort 9100
```

**Skip Firewall Configuration (if firewall is managed separately):**
```powershell
powershell -ExecutionPolicy Bypass -File deploy-windows-exporter.ps1 -SkipFirewall
```

**What the script does:**
1. Downloads Windows Exporter MSI installer (version 0.31.3 by default)
2. Installs Windows Exporter silently with specified port
3. Registers `windows_exporter` as a Windows service
4. Configures service to start automatically on boot
5. Creates Windows Firewall rule to allow inbound traffic on port 9100
6. Starts the Windows Exporter service
7. Verifies service is running and listening on port 9100
8. Cleans up installer files

**Verification:**

```powershell
# Check Windows Exporter service status
Get-Service windows_exporter

# Check service details
Get-WmiObject -Class Win32_Service -Filter "Name='windows_exporter'" | Select-Object Name, State, StartMode

# Test metrics endpoint
Invoke-WebRequest -Uri http://localhost:9100/metrics
# OR in browser: http://localhost:9100/metrics
```

**Expected Result:**
- Service status: `Running`
- Start mode: `Auto`
- Metrics endpoint returns Prometheus format metrics

**Example Metrics Output:**
```
# HELP windows_cpu_time_total Seconds the CPU spent in each mode.
# TYPE windows_cpu_time_total counter
windows_cpu_time_total{core="0",mode="idle"} 12345.67
...
```

### 6.3 Verify from Control Node

```bash
# Test metrics endpoint from Linux control node
curl http://<windows-server-ip>:9100/metrics
```

**Expected Result:** Metrics are accessible from the control node (if firewall allows)

---

## 7. Prometheus Configuration – Adding Scrape Targets

### 7.1 Edit Prometheus Configuration

The Prometheus configuration file is located at `/etc/prometheus/prometheus.yml`. Edit it:

```bash
sudo nano /etc/prometheus/prometheus.yml
```

### 7.2 Add Linux Node Exporter Targets

Find the `node-exporter` job in `scrape_configs` and add your Linux server targets:

```yaml
scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter (Linux)
  - job_name: 'node-exporter'
    static_configs:
      - targets:
          - '192.168.1.11:9100'  # server1
          - '192.168.1.12:9100'  # server2
        labels:
          os: 'linux'
```

**Replace IP addresses** with your actual Linux server IPs.

### 7.3 Add Windows Exporter Targets

Find the `windows-exporter` job and add your Windows server targets:

```yaml
  # Windows Exporter
  - job_name: 'windows-exporter'
    static_configs:
      - targets:
          - '192.168.1.21:9100'  # win-server1
          - '192.168.1.22:9100'  # win-server2
        labels:
          os: 'windows'
```

**Replace IP addresses** with your actual Windows server IPs.

### 7.4 Complete Example Configuration

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_url: 'http://localhost:9090'

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter (Linux)
  - job_name: 'node-exporter'
    static_configs:
      - targets:
          - '192.168.1.11:9100'
          - '192.168.1.12:9100'
        labels:
          os: 'linux'

  # Windows Exporter
  - job_name: 'windows-exporter'
    static_configs:
      - targets:
          - '192.168.1.21:9100'
          - '192.168.1.22:9100'
        labels:
          os: 'windows'
```

### 7.5 Validate and Reload Prometheus

**Validate Configuration:**
```bash
# Check Prometheus container logs for configuration errors
sudo podman logs prometheus | tail -20
```

**Reload Prometheus:**
```bash
# Restart Prometheus container to apply new configuration
sudo podman restart prometheus
```

**Alternative: Reload via API (if supported):**
```bash
curl -X POST http://localhost:9090/-/reload
```

### 7.6 Verify Targets in Prometheus UI

1. Open Prometheus in browser: `http://<server-ip>/prometheus`
2. Navigate to **Status** → **Targets**
3. Verify all targets show **UP** status (green)

**Expected Result:** All configured targets (Prometheus, Node Exporter, Windows Exporter) show as **UP**

**If targets show DOWN:**
- Check firewall rules (port 9100 must be accessible from Prometheus server)
- Verify exporters are running on target servers
- Check network connectivity: `ping <target-ip>`
- Verify IP addresses and ports in `prometheus.yml`

---

## 8. Grafana Configuration – Data Source and Dashboard

### 8.1 Access Grafana

1. Open browser and navigate to: `http://<server-ip>/grafana`
2. Login with default credentials:
   - Username: `admin`
   - Password: `admin`
3. **Change password** when prompted (recommended for production)

### 8.2 Configure Prometheus Data Source

1. Click **Configuration** (gear icon) → **Data Sources**
2. Click **Add data source**
3. Select **Prometheus**
4. Configure the data source:
   - **Name:** `Prometheus` (or any name)
   - **URL:** `http://localhost:9090`
     - **Important:** Use `localhost:9090` (not the Nginx proxy URL) because Grafana runs in a container and accesses Prometheus directly
   - **Access:** Select **Server (default)**
5. Click **Save & Test**

**Expected Result:** Green banner showing "Data source is working"

**If test fails:**
- Verify Prometheus container is running: `sudo podman ps | grep prometheus`
- Check Prometheus is accessible: `curl http://localhost:9090/api/v1/status/config`
- Verify network connectivity between Grafana and Prometheus containers

### 8.3 Create a Simple Dashboard

**Option 1: Create Dashboard Manually**

1. Click **+** (plus icon) → **Create** → **Dashboard**
2. Click **Add visualization**
3. Select **Prometheus** as data source
4. In the query editor, enter a PromQL query:

   **CPU Usage Example:**
   ```promql
   100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
   ```

   **Memory Usage Example:**
   ```promql
   (node_memory_MemTotal_bytes - node_memory_MemFree_bytes) / node_memory_MemTotal_bytes * 100
   ```

5. Click **Run query** to see the graph
6. Click **Apply** to save the panel
7. Click **Save dashboard** (disk icon) and give it a name

**Option 2: Import Pre-built Dashboard**

1. Click **+** (plus icon) → **Import**
2. Enter dashboard ID or upload JSON:
   - **Node Exporter Full:** Dashboard ID `1860`
   - **Windows Exporter:** Dashboard ID `14663`
3. Select **Prometheus** as data source
4. Click **Import**

**Recommended Dashboards:**
- **Node Exporter Full** (ID: 1860): Comprehensive Linux system metrics
- **Windows Exporter** (ID: 14663): Windows system metrics
- **Prometheus Stats** (ID: 2): Prometheus server statistics

### 8.4 Verify Dashboard Shows Data

1. Navigate to your dashboard
2. Verify panels display graphs with data points
3. Check time range selector (top right) - ensure it's set to a recent time range (e.g., "Last 5 minutes")

**Expected Result:** Dashboard panels show live metrics with data points

**If no data appears:**
- Verify Prometheus targets are UP (see Section 7.6)
- Check Prometheus is collecting metrics: `curl http://localhost:9090/api/v1/query?query=up`
- Verify data source URL is correct (`http://localhost:9090`)
- Check time range is set correctly

---

## 9. Validation Checklist

Use this checklist to verify the complete installation:

### Infrastructure Services

- [ ] **Nginx is running**
  ```bash
  sudo systemctl status nginx
  ```
  Expected: `active (running)`

- [ ] **StackBill home page is accessible**
  ```bash
  curl http://localhost/
  ```
  Expected: HTML content returned

- [ ] **Prometheus container is running**
  ```bash
  sudo podman ps | grep prometheus
  ```
  Expected: Container listed and status shows "Up"

- [ ] **Prometheus is accessible via Nginx**
  ```bash
  curl http://localhost/prometheus/-/healthy
  ```
  Expected: "Prometheus is Healthy."

- [ ] **Grafana container is running**
  ```bash
  sudo podman ps | grep grafana
  ```
  Expected: Container listed and status shows "Up"

- [ ] **Grafana is accessible via Nginx**
  ```bash
  curl http://localhost/grafana/api/health
  ```
  Expected: JSON with `"database":"ok"`

### Exporter Services

- [ ] **Linux Node Exporter is running on target servers**
  ```bash
  # On each Linux target server
  sudo systemctl status node_exporter
  curl http://localhost:9100/metrics
  ```
  Expected: Service active, metrics returned

- [ ] **Windows Exporter is running on target servers**
  ```powershell
  # On each Windows target server
  Get-Service windows_exporter
  Invoke-WebRequest -Uri http://localhost:9100/metrics
  ```
  Expected: Service Running, metrics returned

### Prometheus Configuration

- [ ] **All Prometheus targets are UP**
  - Navigate to: `http://<server-ip>/prometheus/targets`
  - Expected: All targets show green (UP) status

- [ ] **Prometheus is collecting metrics**
  ```bash
  curl 'http://localhost:9090/api/v1/query?query=up'
  ```
  Expected: JSON response with metric data

### Grafana Configuration

- [ ] **Prometheus data source is working**
  - Navigate to: `http://<server-ip>/grafana`
  - Go to: Configuration → Data Sources → Prometheus
  - Click: "Save & Test"
  - Expected: Green "Data source is working" message

- [ ] **Dashboard displays live data**
  - Open a dashboard
  - Expected: Graphs show data points, not empty panels

---

## 10. Troubleshooting

### 10.1 Nginx Issues

**Problem: Nginx shows "Welcome to nginx!" instead of StackBill UI**

This occurs when Nginx is serving the default site instead of the StackBill configuration.

**Step 1: Verify Nginx root directory**

```bash
# Check which configuration Nginx is using
sudo nginx -T | grep "root"

# Check if StackBill config is loaded
sudo nginx -T | grep "stackbill"
```

**Expected Result:** Should show `root /var/www/stackbill/dist;` in the active configuration

**Step 2: Confirm StackBill files are present**

```bash
# Check if frontend files exist
ls -la /var/www/stackbill/dist/

# Verify index.html exists
test -f /var/www/stackbill/dist/index.html && echo "File exists" || echo "File missing"
```

**Expected Result:** `index.html` and `assets/` directory should exist

**Step 3: Check which config Nginx loaded**

```bash
# List enabled sites
ls -la /etc/nginx/sites-enabled/

# Check if StackBill config is enabled
test -L /etc/nginx/sites-enabled/stackbill && echo "Enabled" || echo "Not enabled"

# Check if default site is still enabled (this is the problem)
test -L /etc/nginx/sites-enabled/default && echo "Default site enabled - DISABLE THIS" || echo "Default site disabled"
```

**Expected Result:** 
- `/etc/nginx/sites-enabled/stackbill` should exist (symlink)
- `/etc/nginx/sites-enabled/default` should NOT exist (or be disabled)

**Step 4: Disable default site and enable StackBill**

```bash
# Disable default Nginx site (if it exists)
sudo rm -f /etc/nginx/sites-enabled/default

# Ensure StackBill site is enabled
sudo ln -sf /etc/nginx/sites-available/stackbill /etc/nginx/sites-enabled/stackbill

# Verify symlink
ls -la /etc/nginx/sites-enabled/stackbill
```

**Expected Result:** Symlink points to `/etc/nginx/sites-available/stackbill`

**Step 5: Reload Nginx properly**

```bash
# Test configuration first
sudo nginx -t

# If test passes, reload
sudo systemctl reload nginx

# OR if systemctl not available
sudo service nginx reload

# Verify Nginx is using correct config
sudo nginx -T 2>&1 | grep -A 5 "server_name _"
```

**Expected Result:** Configuration shows `root /var/www/stackbill/dist;`

**Step 6: Verify StackBill UI is served**

```bash
# Test from command line
curl http://localhost/ | head -20

# Check for StackBill content
curl http://localhost/ | grep -i "stackbill"
```

**Expected Result:** HTML content contains "StackBill" text, not "Welcome to nginx!"

**If files are missing, rebuild frontend:**
```bash
cd /opt/stackbill
npm run build
sudo ./scripts/deploy-nginx.sh
```

---

**Problem: Nginx not serving StackBill frontend**

**Check:**
```bash
# Verify Nginx is running
sudo systemctl status nginx

# Check Nginx configuration syntax
sudo nginx -t

# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Verify frontend files exist
ls -la /var/www/stackbill/dist/
```

**Solution:**
- If frontend files missing: Run `npm run build` in project root, then re-run `sudo ./scripts/deploy-nginx.sh`
- If configuration error: Fix syntax errors shown by `nginx -t`
- If permission denied: `sudo chown -R nginx:nginx /var/www/stackbill/dist`

**Problem: Cannot access /prometheus or /grafana via Nginx**

**Check:**
```bash
# Verify backend services are running
sudo podman ps | grep -E 'prometheus|grafana'

# Test direct access to services
curl http://localhost:9090/-/healthy
curl http://localhost:3000/api/health
```

**Solution:**
- If containers not running: Restart containers with deployment scripts
- If 502 Bad Gateway: Check Nginx proxy configuration in `/etc/nginx/sites-available/stackbill`

### 10.2 Prometheus Issues

**Problem: Prometheus image pull fails**

**Error:** `short-name "prom/prometheus:latest" did not resolve to an alias`

**Check:**
```bash
# Test image pull manually
sudo podman pull docker.io/prom/prometheus:latest

# Check Podman registries configuration
cat /etc/containers/registries.conf
```

**Solution:**
- Script has been fixed to use `docker.io/prom/prometheus:latest`
- If still failing, verify internet connectivity: `ping 8.8.8.8`
- Check firewall allows outbound HTTPS (port 443) for Docker Hub access

**Problem: Prometheus container not starting**

**Check:**
```bash
# Check container logs
sudo podman logs prometheus

# Check if port 9090 is already in use
sudo netstat -tlnp | grep :9090
```

**Solution:**
- If port conflict: Stop conflicting service or change Prometheus port
- If configuration error: Check `/etc/prometheus/prometheus.yml` syntax
- If permission error: Verify `/var/lib/prometheus/data` permissions
- If image missing: Re-run deployment script or manually pull: `sudo podman pull docker.io/prom/prometheus:latest`

**Problem: Prometheus targets showing DOWN**

**Check:**
```bash
# Test connectivity to target from Prometheus server
ping <target-ip>
curl http://<target-ip>:9100/metrics

# Check firewall rules
sudo firewall-cmd --list-all  # firewalld
sudo ufw status              # UFW
```

**Solution:**
- If network unreachable: Check network connectivity and routing
- If port blocked: Configure firewall to allow port 9100 from Prometheus server
- If wrong IP/port: Verify `prometheus.yml` has correct target addresses

### 10.3 Grafana Issues

**Problem: Grafana image pull fails**

**Error:** `short-name "grafana/grafana:latest" did not resolve`

**Check:**
```bash
# Test image pull manually
sudo podman pull docker.io/grafana/grafana:latest

# Check Podman registries configuration
cat /etc/containers/registries.conf
```

**Solution:**
- Script has been fixed to use `docker.io/grafana/grafana:latest`
- If still failing, verify internet connectivity: `ping 8.8.8.8`
- Check firewall allows outbound HTTPS (port 443) for Docker Hub access

**Problem: Cannot login to Grafana**

**Check:**
```bash
# Verify Grafana container is running
sudo podman ps | grep grafana

# Check Grafana logs
sudo podman logs grafana | tail -50
```

**Solution:**
- Default credentials: `admin` / `admin`
- If forgot password: Reset via Grafana database or recreate container
- If container not running: Restart with `sudo ./scripts/deploy-grafana.sh`

**Problem: Grafana image pull fails**

**Error:** `short-name "grafana/grafana:latest" did not resolve`

**Check:**
```bash
# Test image pull manually
sudo podman pull docker.io/grafana/grafana:latest

# Check Podman registries configuration
cat /etc/containers/registries.conf
```

**Solution:**
- Script has been fixed to use `docker.io/grafana/grafana:latest`
- If still failing, verify internet connectivity: `ping 8.8.8.8`
- Check firewall allows outbound HTTPS (port 443) for Docker Hub access

**Problem: Prometheus data source test fails**

**Check:**
```bash
# Verify Prometheus is accessible from Grafana container
sudo podman exec grafana curl http://host.docker.internal:9090/api/v1/status/config
# OR if host.docker.internal not available:
sudo podman exec grafana curl http://<host-ip>:9090/api/v1/status/config
```

**Solution:**
- Use `http://localhost:9090` (not Nginx proxy URL) in data source configuration
- If still fails: Check network connectivity between containers
- Verify Prometheus container is running

### 10.4 Linux Node Exporter Issues

**Problem: Ansible playbook fails**

**Check:**
```bash
# Test SSH connectivity
ansible linux_servers -i ansible/inventory/hosts -m ping

# Run playbook with verbose output
ansible-playbook -v ansible/playbooks/deploy-node-exporter.yml
```

**Solution:**
- If SSH fails: Verify SSH keys and credentials in inventory
- If permission denied: Ensure user has sudo access
- If download fails: Check internet connectivity on target servers

**Problem: Node Exporter service not running on target**

**Check:**
```bash
# SSH to target server
ssh deploy@<target-ip>

# Check service status
sudo systemctl status node_exporter

# Check service logs
sudo journalctl -u node_exporter -n 50
```

**Solution:**
- If service failed: Check logs for error messages
- If port in use: Identify and stop conflicting service
- If binary missing: Re-run Ansible playbook

### 10.5 Windows Exporter Issues

**Problem: PowerShell script execution fails**

**Check:**
```powershell
# Verify PowerShell execution policy
Get-ExecutionPolicy

# Run with bypass
powershell -ExecutionPolicy Bypass -File deploy-windows-exporter.ps1
```

**Solution:**
- If execution policy blocked: Use `-ExecutionPolicy Bypass` flag
- If download fails: Check internet connectivity
- If installation fails: Check Windows Event Viewer for errors

**Problem: Windows Exporter service not running**

**Check:**
```powershell
# Check service status
Get-Service windows_exporter

# Check service details
Get-WmiObject -Class Win32_Service -Filter "Name='windows_exporter'"

# Check Windows Event Viewer
Get-EventLog -LogName Application -Source windows_exporter -Newest 10
```

**Solution:**
- If service stopped: Start with `Start-Service windows_exporter`
- If port conflict: Change port in script parameters
- If firewall blocking: Verify firewall rule exists: `Get-NetFirewallRule -DisplayName "Windows Exporter*"`

### 10.6 Common Log Locations

**Nginx:**
- Access logs: `/var/log/nginx/access.log`
- Error logs: `/var/log/nginx/error.log`

**Prometheus:**
- Container logs: `sudo podman logs prometheus`
- Configuration: `/etc/prometheus/prometheus.yml`

**Grafana:**
- Container logs: `sudo podman logs grafana`
- Configuration: `/etc/grafana/grafana.ini`
- Database: `/var/lib/grafana/data/grafana.db`

**Linux Node Exporter:**
- Service logs: `sudo journalctl -u node_exporter -f`

**Windows Exporter:**
- Event Viewer: Windows Logs → Application
- Service logs: Check Windows Event Viewer

---

## Quick Reference Commands

### Service Management

```bash
# Nginx
sudo systemctl status nginx
sudo systemctl restart nginx
sudo nginx -t

# Prometheus container
sudo podman ps | grep prometheus
sudo podman restart prometheus
sudo podman logs prometheus

# Grafana container
sudo podman ps | grep grafana
sudo podman restart grafana
sudo podman logs grafana

# Linux Node Exporter (on target server)
sudo systemctl status node_exporter
sudo systemctl restart node_exporter
```

```powershell
# Windows Exporter (on Windows server)
Get-Service windows_exporter
Restart-Service windows_exporter
```

### Health Checks

```bash
# StackBill frontend
curl http://localhost/

# Prometheus
curl http://localhost:9090/-/healthy
curl http://localhost/prometheus/-/healthy

# Grafana
curl http://localhost:3000/api/health
curl http://localhost/grafana/api/health

# Node Exporter (Linux)
curl http://<linux-server-ip>:9100/metrics

# Windows Exporter
curl http://<windows-server-ip>:9100/metrics
```

### Configuration Files

- Nginx: `/etc/nginx/sites-available/stackbill`
- Prometheus: `/etc/prometheus/prometheus.yml`
- Grafana: `/etc/grafana/grafana.ini`
- Ansible Inventory: `ansible/inventory/hosts`

---

## Document Control

**Version History:**
- 1.0.0 (2024): Initial operations guide

**Review Cycle:** Quarterly  
**Next Review Date:** TBD  
**Approval Required:** Operations Team Lead

---

**END OF OPERATIONS GUIDE**

