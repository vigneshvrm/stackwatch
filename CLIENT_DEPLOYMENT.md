# StackBill Client Deployment Guide

**Version:** 1.0.0  
**Purpose:** Step-by-step instructions for deploying StackBill from prebuilt package

---

## Prerequisites

- Linux server (Ubuntu/Debian/CentOS/RHEL)
- Root or sudo access
- Network connectivity
- Port 80 available (for Nginx)
- Ports 9090 and 3000 available (for Prometheus and Grafana)

---

## Deployment Steps

### Step 1: Download the Package

Download the StackBill prebuilt package file:
```
stackbill-prebuilt-<version>-<date>.tar.gz
```

### Step 2: Extract to /opt

Extract the package to `/opt`:

```bash
sudo tar -xzf stackbill-prebuilt-*.tar.gz -C /opt
```

This will create `/opt/stackbill-prebuilt/` directory.

### Step 3: Rename Directory (if needed)

If the extracted directory is not named `stackbill`, rename it:

```bash
sudo mv /opt/stackbill-prebuilt /opt/stackbill
```

**Note:** The deployment script expects the installation to be at `/opt/stackbill`.

### Step 4: Verify Package Contents

Verify the package structure:

```bash
ls -la /opt/stackbill/
```

You should see:
- `dist/` - Frontend files
- `scripts/` - Deployment scripts
- `ansible/` - Ansible playbooks
- `CLIENT_DEPLOYMENT.md` - This file

### Step 5: Run Deployment Script

Execute the deployment script:

```bash
sudo /opt/stackbill/scripts/deploy-from-opt.sh
```

This script will:
1. Copy frontend files to `/var/www/stackbill/dist/`
2. Configure firewall rules
3. Deploy and configure Nginx
4. Deploy Prometheus container
5. Deploy Grafana container
6. Run health checks

**Expected Duration:** 5-10 minutes depending on network speed (image downloads)

### Step 6: Verify Deployment

After deployment completes, verify services:

```bash
# Check service status
sudo /opt/stackbill/scripts/health-check.sh

# Check Nginx
sudo systemctl status nginx

# Check Prometheus container
sudo podman ps | grep prometheus

# Check Grafana container
sudo podman ps | grep grafana
```

---

## Accessing Services

After successful deployment, access services using your server's IP address:

### StackBill Dashboard
```
http://<server-ip>/
```

### Prometheus
```
http://<server-ip>/prometheus/
```

### Grafana
```
http://<server-ip>/grafana/
```
**Default Credentials:**
- Username: `admin`
- Password: `admin`
- **⚠️ IMPORTANT:** Change these credentials immediately in production!

### Help Documentation
```
http://<server-ip>/help
```

---

## Post-Deployment Configuration

### 1. Configure Grafana

1. Access Grafana at `http://<server-ip>/grafana/`
2. Log in with default credentials (admin/admin)
3. Change the admin password when prompted
4. Add Prometheus as a data source:
   - Go to Configuration → Data Sources
   - Add Prometheus
   - URL: `http://localhost:9090`
   - Save & Test

### 2. Configure Ansible Inventory

To deploy Node Exporter on Linux servers:

1. Edit the inventory file:
   ```bash
   sudo nano /opt/stackbill/ansible/inventory/hosts
   ```

2. Add your target servers:
   ```ini
   [linux_servers]
   server1 ansible_host=192.168.1.10
   server2 ansible_host=192.168.1.11
   ```

3. Deploy Node Exporter:
   ```bash
   sudo ansible-playbook -i /opt/stackbill/ansible/inventory/hosts \
       /opt/stackbill/ansible/playbooks/deploy-node-exporter.yml
   ```

### 3. Deploy Windows Exporter

For Windows servers, use the PowerShell script:

1. Copy the script to Windows server:
   ```bash
   scp /opt/stackbill/scripts/deploy-windows-exporter.ps1 administrator@windows-server:/tmp/
   ```

2. Run on Windows server (as Administrator):
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\tmp\deploy-windows-exporter.ps1
   ```

---

## Troubleshooting

### Frontend Not Loading

**Symptom:** Browser shows 404 or blank page

**Solutions:**
1. Check if frontend files exist:
   ```bash
   ls -la /var/www/stackbill/dist/
   ```

2. Check Nginx status:
   ```bash
   sudo systemctl status nginx
   sudo nginx -t
   ```

3. Check Nginx error logs:
   ```bash
   sudo tail -f /var/log/nginx/error.log
   ```

4. Redeploy frontend:
   ```bash
   sudo cp -r /opt/stackbill/dist/* /var/www/stackbill/dist/
   sudo systemctl reload nginx
   ```

### Prometheus Not Accessible

**Symptom:** Cannot access `/prometheus/` endpoint

**Solutions:**
1. Check Prometheus container:
   ```bash
   sudo podman ps | grep prometheus
   sudo podman logs container-prometheus
   ```

2. Check service status:
   ```bash
   sudo systemctl status container-prometheus
   ```

3. Restart Prometheus:
   ```bash
   sudo systemctl restart container-prometheus
   ```

### Grafana Redirect Loop

**Symptom:** ERR_TOO_MANY_REDIRECTS when accessing Grafana

**Solutions:**
1. Check Grafana configuration:
   ```bash
   sudo cat /etc/grafana/config/grafana.ini | grep -A 5 "\[server\]"
   ```

2. Verify Grafana domain matches server IP:
   ```bash
   # Get server IP
   hostname -I | awk '{print $1}'
   
   # Update Grafana domain (if needed)
   sudo GRAFANA_DOMAIN="<server-ip>" /opt/stackbill/scripts/deploy-grafana.sh
   ```

### Services Not Starting

**Symptom:** Containers fail to start

**Solutions:**
1. Check Podman service:
   ```bash
   sudo systemctl status podman
   ```

2. Check container logs:
   ```bash
   sudo podman logs container-prometheus
   sudo podman logs container-grafana
   ```

3. Check disk space:
   ```bash
   df -h
   ```

4. Check ports in use:
   ```bash
   sudo netstat -tlnp | grep -E '9090|3000|80'
   ```

---

## Manual Service Management

### Start Services
```bash
sudo systemctl start container-prometheus
sudo systemctl start container-grafana
sudo systemctl start nginx
```

### Stop Services
```bash
sudo systemctl stop container-prometheus
sudo systemctl stop container-grafana
sudo systemctl stop nginx
```

### Restart Services
```bash
sudo systemctl restart container-prometheus
sudo systemctl restart container-grafana
sudo systemctl restart nginx
```

### View Logs
```bash
# Prometheus logs
sudo podman logs container-prometheus

# Grafana logs
sudo podman logs container-grafana

# Nginx logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

---

## Uninstallation

To remove StackBill:

```bash
# Stop services
sudo systemctl stop container-prometheus
sudo systemctl stop container-grafana
sudo systemctl stop nginx

# Remove containers
sudo podman rm -f container-prometheus container-grafana

# Remove Nginx configuration
sudo rm -f /etc/nginx/sites-enabled/stackbill
sudo rm -f /etc/nginx/sites-available/stackbill
sudo systemctl reload nginx

# Remove web files
sudo rm -rf /var/www/stackbill

# Remove installation (optional)
sudo rm -rf /opt/stackbill
```

---

## Support

For additional support:
- Review service logs for error details
- Check health check output: `sudo /opt/stackbill/scripts/health-check.sh`
- Contact your system administrator

---

**Last Updated:** 2025-01-01

