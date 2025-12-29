# StackWatch Client Monitoring Package Deployment Guide

**Version:** 2.0.0
**Purpose:** Deploy monitoring agents to target servers using prebuilt package

**IMPORTANT**: This client package contains ONLY monitoring agent deployment tools.
It does NOT include the StackWatch infrastructure (Nginx, Prometheus, Grafana).
The central monitoring server must be deployed separately from the source repository.

---

## Package Contents

This client package includes:
- ✅ Node Exporter deployment playbook (for Linux servers)
- ✅ Windows Exporter deployment script (for Windows servers)
- ✅ Health check scripts
- ✅ Ansible configuration and inventory templates

This package does NOT include:
- ❌ Nginx, Prometheus, Grafana deployment playbooks
- ❌ Infrastructure configuration scripts
- ❌ Full StackWatch server deployment capabilities

---

## Prerequisites

- A running StackWatch monitoring server (deployed from source)
- Target Linux/Windows servers to monitor
- Ansible installed (for Linux deployments)
- SSH access to Linux servers
- RDP/Remote access to Windows servers

---

## Deployment Steps

### Step 1: Download the Package

Download the StackWatch prebuilt package file:
```
stackwatch-prebuilt-<version>-<date>.tar.gz
```

### Step 2: Extract to /opt

Extract the package to `/opt`:

```bash
sudo tar -xzf stackwatch-prebuilt-*.tar.gz -C /opt
```

This will create `/opt/stackwatch-prebuilt/` directory.

### Step 3: Rename Directory (if needed)

If the extracted directory is not named `stackwatch`, rename it:

```bash
sudo mv /opt/stackwatch-prebuilt /opt/stackwatch
```

**Note:** The deployment script expects the installation to be at `/opt/stackwatch`.

### Step 4: Verify Package Contents

Verify the package structure:

```bash
ls -la /opt/stackwatch/
```

You should see:
- `dist/` - Frontend files
- `scripts/` - Deployment scripts
- `ansible/` - Ansible playbooks
- `CLIENT_DEPLOYMENT.md` - This file

### Step 5: Run Deployment Script (Optional - Information Only)

The package includes `deploy-from-opt.sh`, but in client mode it serves as a guide only:

```bash
sudo /opt/stackwatch/scripts/deploy-from-opt.sh
```

In client mode, this script will:
1. Detect that infrastructure playbooks are not present
2. Display instructions for deploying monitoring agents
3. Exit with guidance (no infrastructure deployment)

**Note**: For actual agent deployment, follow the instructions in Step 6 below.

### Step 6: Deploy Monitoring Agents

Now deploy the monitoring agents to your target servers:

#### A. Deploy Node Exporter to Linux Servers

1. Configure Ansible inventory:
   ```bash
   sudo nano /opt/stackwatch/ansible/inventory/hosts
   ```

2. Add your Linux servers:
   ```ini
   [linux_servers]
   server1 ansible_host=192.168.1.10 ansible_user=deploy
   server2 ansible_host=192.168.1.11 ansible_user=deploy
   ```

3. Run deployment:
   ```bash
   sudo ansible-playbook -i /opt/stackwatch/ansible/inventory/hosts \
       /opt/stackwatch/ansible/playbooks/deploy-node-exporter.yml
   ```

#### B. Deploy Windows Exporter to Windows Servers

1. Copy script to Windows server:
   ```bash
   scp /opt/stackwatch/scripts/deploy-windows-exporter.ps1 administrator@windows-server:/tmp/
   ```

2. Run on Windows (as Administrator):
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\tmp\deploy-windows-exporter.ps1
   ```

---

## Verifying Monitoring Agents

After deploying monitoring agents, verify they are running and accessible:

### Verify Node Exporter (on Linux servers)
```bash
curl http://<linux-server-ip>:9100/metrics
```

### Verify Windows Exporter (on Windows servers)
```powershell
Invoke-WebRequest -Uri http://<windows-server-ip>:9100/metrics
```

---

## Configure Prometheus Targets

On your StackWatch monitoring server, add these targets to Prometheus:

1. SSH to your central StackWatch server
2. Edit Prometheus configuration
3. Add scrape configs for your deployed exporters
4. Reload Prometheus configuration

**Note**: The StackWatch dashboard, Prometheus, and Grafana interfaces are
accessed on your central monitoring server, not from this client package.

### Example Prometheus Configuration

Add to your Prometheus `/etc/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'linux_servers'
    static_configs:
      - targets:
        - '192.168.1.10:9100'  # server1
        - '192.168.1.11:9100'  # server2

  - job_name: 'windows_servers'
    static_configs:
      - targets:
        - '192.168.1.20:9100'  # windows-server1
```

Then reload Prometheus:
```bash
sudo systemctl reload container-prometheus
```

---

## Accessing StackWatch Dashboard

The StackWatch dashboard and monitoring interfaces are on your central monitoring server:

### StackWatch Dashboard
```
http://<monitoring-server-ip>/
```

### Prometheus
```
http://<monitoring-server-ip>/prometheus/
```

### Grafana
```
http://<monitoring-server-ip>/grafana/
```

---

## Post-Deployment Configuration

### 1. Verify Metrics Collection

After configuring Prometheus targets:

1. Access Prometheus on your monitoring server
2. Go to Status → Targets
3. Verify all exporters are showing as "UP"
4. Query metrics: `up{job=~"linux_servers|windows_servers"}`

### 2. Create Grafana Dashboards

1. Access Grafana on your monitoring server
2. Import pre-built dashboards:
   - Node Exporter Full (Dashboard ID: 1860)
   - Windows Exporter Dashboard (Dashboard ID: 14694)
3. Customize as needed for your environment

---

## Troubleshooting

### Node Exporter Not Accessible

**Symptom:** Cannot access metrics at `http://<server>:9100/metrics`

**Solutions:**
1. Check if Node Exporter is running:
   ```bash
   sudo systemctl status node_exporter
   ```

2. Check Node Exporter logs:
   ```bash
   sudo journalctl -u node_exporter -n 50
   ```

3. Verify port is listening:
   ```bash
   sudo netstat -tlnp | grep 9100
   ```

4. Check firewall rules:
   ```bash
   sudo firewall-cmd --list-ports  # firewalld
   sudo ufw status                  # ufw
   ```

5. Restart Node Exporter:
   ```bash
   sudo systemctl restart node_exporter
   ```

### Windows Exporter Not Accessible

**Symptom:** Cannot access metrics on Windows server

**Solutions:**
1. Check if service is running (on Windows):
   ```powershell
   Get-Service -Name "windows_exporter"
   ```

2. Check if port is listening:
   ```powershell
   netstat -an | findstr ":9100"
   ```

3. Check Windows Firewall:
   ```powershell
   Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*exporter*"}
   ```

4. Restart service:
   ```powershell
   Restart-Service -Name "windows_exporter"
   ```

### Ansible Deployment Fails

**Symptom:** Ansible playbook fails with connection errors

**Solutions:**
1. Verify SSH connectivity:
   ```bash
   ssh user@target-server
   ```

2. Check Ansible inventory:
   ```bash
   ansible -i /opt/stackwatch/ansible/inventory/hosts all --list-hosts
   ```

3. Test Ansible ping:
   ```bash
   ansible -i /opt/stackwatch/ansible/inventory/hosts all -m ping
   ```

4. Run playbook with verbose output:
   ```bash
   ansible-playbook -i /opt/stackwatch/ansible/inventory/hosts \
       /opt/stackwatch/ansible/playbooks/deploy-node-exporter.yml -vvv
   ```

### Metrics Not Showing in Prometheus

**Symptom:** Exporters are running but metrics don't appear in Prometheus

**Solutions:**
1. Verify Prometheus targets (on monitoring server):
   - Go to `http://<monitoring-server>/prometheus/targets`
   - Check if targets are showing as "UP"

2. Check Prometheus configuration (on monitoring server):
   ```bash
   sudo cat /etc/prometheus/prometheus.yml
   ```

3. Verify network connectivity from monitoring server to exporters:
   ```bash
   curl http://<target-server>:9100/metrics
   ```

4. Check Prometheus logs (on monitoring server):
   ```bash
   sudo podman logs container-prometheus
   ```

---

## Manual Service Management

### Managing Node Exporter on Linux Servers

Start Node Exporter:
```bash
sudo systemctl start node_exporter
```

Stop Node Exporter:
```bash
sudo systemctl stop node_exporter
```

Restart Node Exporter:
```bash
sudo systemctl restart node_exporter
```

View logs:
```bash
sudo journalctl -u node_exporter -f
```

### Managing Windows Exporter on Windows Servers

Start service:
```powershell
Start-Service -Name "windows_exporter"
```

Stop service:
```powershell
Stop-Service -Name "windows_exporter"
```

Restart service:
```powershell
Restart-Service -Name "windows_exporter"
```

---

## Uninstallation

### Remove Node Exporter from Linux Servers

```bash
# Stop service
sudo systemctl stop node_exporter
sudo systemctl disable node_exporter

# Remove service file
sudo rm -f /etc/systemd/system/node_exporter.service
sudo systemctl daemon-reload

# Remove binary
sudo rm -f /usr/local/bin/node_exporter

# Remove user (optional)
sudo userdel node_exporter
```

### Remove Windows Exporter from Windows Servers

```powershell
# Stop and remove service
Stop-Service -Name "windows_exporter"
sc.exe delete windows_exporter

# Remove installation directory
Remove-Item -Path "C:\Program Files\windows_exporter" -Recurse -Force

# Remove firewall rule
Remove-NetFirewallRule -DisplayName "Windows Exporter"
```

### Remove Client Package

```bash
# Remove installation directory
sudo rm -rf /opt/stackwatch
```

---

## Support

For additional support:
- Review exporter logs for error details
- Verify network connectivity between monitoring server and exporters
- Check Prometheus targets page: `http://<monitoring-server>/prometheus/targets`
- Test exporter endpoints directly: `curl http://<target-server>:9100/metrics`
- Contact your system administrator

---

**Last Updated:** 2025-12-29
**Package Type:** Client Monitoring Tools Only

