# STACKWATCH: Operational Runbook

**Document Version:** 1.0.0  
**Classification:** Internal Technical Documentation  
**Last Updated:** 2024  
**Architect:** Senior Cloud Infrastructure Architect and Automation Engineer

---

## Executive Summary

This operational runbook provides step-by-step procedures for installing, validating, operating, and recovering the StackWatch observability infrastructure. All procedures are designed to be executed by operations personnel with appropriate system access.

---

## 1. Installation Flow

### 1.1 Prerequisites Checklist

**System Requirements:**
- [ ] Linux server (RHEL/CentOS/Ubuntu) with root/sudo access
- [ ] Minimum 4 CPU cores, 8GB RAM, 50GB disk space
- [ ] Network connectivity to target servers (for exporters)
- [ ] Firewall access configured (ports 80, 443)
- [ ] SSH access to target servers (for Ansible deployment)

**Software Requirements:**
- [ ] Node.js 18+ installed (for frontend build)
- [ ] npm or yarn package manager
- [ ] Podman installed (for Prometheus and Grafana)
- [ ] Nginx installed
- [ ] Ansible 2.9+ installed (for infrastructure automation)
- [ ] Python 3.6+ (Ansible requirement)

**Access Requirements:**
- [ ] Sudo/root access on deployment server
- [ ] SSH key-based access to target servers
- [ ] Network access to download container images
- [ ] Access to package repositories (yum/apt)

### 1.2 Installation Procedure

#### Phase 1: Frontend Build and Deployment

**Step 1.1: Clone Repository**
```bash
cd /opt
git clone <repository-url> stackwatch
cd stackwatch
```

**Step 1.2: Install Frontend Dependencies**
```bash
npm install
```

**Step 1.3: Build Frontend**
```bash
npm run build
```

**Validation:**
```bash
# Verify build output
ls -la dist/
# Expected: index.html and assets/ directory
```

**Step 1.4: Deploy to Web Root**
```bash
# Create web root directory
sudo mkdir -p /var/www/stackwatch
sudo cp -r dist/* /var/www/stackwatch/dist/
sudo chown -R nginx:nginx /var/www/stackwatch
sudo chmod -R 755 /var/www/stackwatch
```

**Step 1.5: Configure Nginx (Frontend)**
```bash
# Create Nginx configuration
sudo nano /etc/nginx/sites-available/stackwatch
```

**Nginx Configuration:**
```nginx
server {
    listen 80;
    server_name _;
    root /var/www/stackwatch/dist;
    index index.html;

    # Serve StackWatch Frontend
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Route to Prometheus
    location /prometheus/ {
        proxy_pass http://localhost:9090/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Route to Grafana
    location /grafana/ {
        proxy_pass http://localhost:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Step 1.6: Enable Nginx Site**
```bash
# Create symlink
sudo ln -s /etc/nginx/sites-available/stackwatch /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

**Validation:**
```bash
# Check Nginx status
sudo systemctl status nginx

# Test frontend access
curl http://localhost/
# Expected: HTML content from StackWatch
```

#### Phase 2: Prometheus Deployment (Podman)

**Step 2.1: Create Prometheus Configuration**
```bash
# Create configuration directory
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus/data

# Create prometheus.yml
sudo nano /etc/prometheus/prometheus.yml
```

**Prometheus Configuration:**
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['server1:9100', 'server2:9100']

  - job_name: 'windows-exporter'
    static_configs:
      - targets: ['win-server1:9182', 'win-server2:9182']
```

**Step 2.2: Deploy Prometheus Container**
```bash
# Pull Prometheus image
sudo podman pull prom/prometheus:latest

# Run Prometheus container
sudo podman run -d \
  --name prometheus \
  -p 9090:9090 \
  -v /etc/prometheus:/etc/prometheus:ro \
  -v /var/lib/prometheus/data:/prometheus \
  --restart=unless-stopped \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus
```

**Step 2.3: Create systemd Service (Optional)**
```bash
# Generate systemd service file
sudo podman generate systemd --name prometheus --files

# Enable and start service
sudo systemctl enable container-prometheus.service
sudo systemctl start container-prometheus.service
```

**Validation:**
```bash
# Check container status
sudo podman ps | grep prometheus

# Test Prometheus endpoint
curl http://localhost:9090/-/healthy
# Expected: "Prometheus is Healthy."

# Test via Nginx proxy
curl http://localhost/prometheus/-/healthy
# Expected: "Prometheus is Healthy."
```

#### Phase 3: Grafana Deployment (Podman)

**Step 3.1: Create Grafana Configuration**
```bash
# Create configuration directory
sudo mkdir -p /etc/grafana
sudo mkdir -p /var/lib/grafana/data

# Create grafana.ini
sudo nano /etc/grafana/grafana.ini
```

**Grafana Configuration (Minimal):**
```ini
[server]
http_port = 3000
root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana/

[database]
type = sqlite3
path = /var/lib/grafana/data/grafana.db

[security]
admin_user = admin
admin_password = <change-this-password>
```

**Step 3.2: Deploy Grafana Container**
```bash
# Pull Grafana image
sudo podman pull grafana/grafana:latest

# Run Grafana container
sudo podman run -d \
  --name grafana \
  -p 3000:3000 \
  -v /etc/grafana:/etc/grafana:ro \
  -v /var/lib/grafana/data:/var/lib/grafana \
  --restart=unless-stopped \
  grafana/grafana:latest
```

**Step 3.3: Create systemd Service (Optional)**
```bash
# Generate systemd service file
sudo podman generate systemd --name grafana --files

# Enable and start service
sudo systemctl enable container-grafana.service
sudo systemctl start container-grafana.service
```

**Step 3.4: Configure Prometheus Data Source in Grafana**
1. Access Grafana: `http://server-ip/grafana`
2. Login with admin credentials
3. Navigate: Configuration → Data Sources → Add data source
4. Select: Prometheus
5. URL: `http://localhost:9090`
6. Click: Save & Test

**Validation:**
```bash
# Check container status
sudo podman ps | grep grafana

# Test Grafana health endpoint
curl http://localhost:3000/api/health
# Expected: JSON with "database": "ok"

# Test via Nginx proxy
curl http://localhost/grafana/api/health
# Expected: JSON with "database": "ok"
```

#### Phase 4: Node Exporter Deployment (Ansible)

**Step 4.1: Prepare Ansible Inventory**
```bash
# Create inventory file
nano ansible/inventory/hosts
```

**Inventory File:**
```ini
[linux_servers]
server1 ansible_host=192.168.1.10
server2 ansible_host=192.168.1.11

[linux_servers:vars]
ansible_user=deploy
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

**Step 4.2: Create Ansible Playbook**
```bash
# Create playbook
nano ansible/playbooks/deploy-node-exporter.yml
```

**Step 4.3: Execute Ansible Playbook**
```bash
# Run playbook
ansible-playbook -i inventory/hosts playbooks/deploy-node-exporter.yml
```

**Note:** Detailed Ansible playbook content not in repository (see Script Documentation).

**Validation:**
```bash
# Check service on target server
ssh server1 "systemctl status node_exporter"

# Test metrics endpoint
curl http://server1:9100/metrics
# Expected: Prometheus metrics format
```

#### Phase 5: Firewall Configuration

**Step 5.1: Configure Firewall Rules**
```bash
# Using firewalld
sudo firewall-cmd --zone=public --add-service=http --permanent
sudo firewall-cmd --zone=public --add-service=https --permanent

# Deny direct access to internal services
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" port port="9090" protocol="tcp" reject' --permanent
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" port port="3000" protocol="tcp" reject' --permanent
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" port port="9100" protocol="tcp" reject' --permanent
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" port port="9182" protocol="tcp" reject' --permanent

# Reload firewall
sudo firewall-cmd --reload
```

**Validation:**
```bash
# Test external access to port 80
curl http://server-ip/
# Expected: StackWatch frontend

# Test direct access to port 9090 (should be blocked)
curl http://server-ip:9090
# Expected: Connection refused or timeout
```

---

## 2. Health Validation

### 2.1 Post-Installation Health Check

**Comprehensive Health Check Script:**
```bash
#!/bin/bash
# health-check.sh

echo "StackWatch Health Check Report"
echo "============================="
echo "Date: $(date)"
echo ""

# Check Nginx
echo -n "[ ] Nginx: "
if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200"; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

# Check StackWatch Frontend
echo -n "[ ] StackWatch Frontend: "
if curl -s http://localhost/ | grep -q "StackWatch"; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

# Check Prometheus
echo -n "[ ] Prometheus: "
if curl -s http://localhost/prometheus/-/healthy | grep -q "Healthy"; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

# Check Grafana
echo -n "[ ] Grafana: "
if curl -s http://localhost/grafana/api/health | grep -q '"database":"ok"'; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

# Check Prometheus Container
echo -n "[ ] Prometheus Container: "
if sudo podman ps | grep -q prometheus; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

# Check Grafana Container
echo -n "[ ] Grafana Container: "
if sudo podman ps | grep -q grafana; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

# Check Node Exporter (if accessible)
echo -n "[ ] Node Exporter Targets: "
TARGETS=$(curl -s http://localhost/prometheus/api/v1/targets | grep -o '"health":"up"' | wc -l)
echo "$TARGETS targets up"

echo ""
echo "Health Check Complete"
```

**Execution:**
```bash
chmod +x health-check.sh
./health-check.sh
```

### 2.2 Service Status Verification

**Manual Verification Steps:**

1. **Nginx Status:**
   ```bash
   sudo systemctl status nginx
   sudo nginx -t
   ```

2. **Prometheus Status:**
   ```bash
   sudo podman ps | grep prometheus
   curl http://localhost:9090/-/healthy
   curl http://localhost/prometheus/api/v1/status/config
   ```

3. **Grafana Status:**
   ```bash
   sudo podman ps | grep grafana
   curl http://localhost:3000/api/health
   curl http://localhost/grafana/api/health
   ```

4. **Frontend Access:**
   ```bash
   curl http://localhost/
   # Open in browser: http://server-ip/
   ```

5. **Proxy Routing:**
   ```bash
   # Test Prometheus via proxy
   curl http://localhost/prometheus/-/healthy
   
   # Test Grafana via proxy
   curl http://localhost/grafana/api/health
   ```

### 2.3 Metrics Collection Validation

**Verify Prometheus Scraping:**
```bash
# Check targets
curl http://localhost/prometheus/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Check if metrics are being collected
curl http://localhost/prometheus/api/v1/query?query=up | jq '.data.result'
```

**Verify Grafana Data Source:**
1. Access Grafana: `http://server-ip/grafana`
2. Navigate: Configuration → Data Sources
3. Click: Prometheus data source
4. Click: "Save & Test"
5. Expected: "Data source is working"

---

## 3. Recovery Procedures

### 3.1 Service Recovery

#### Nginx Recovery

**Symptoms:**
- Frontend not accessible
- 502 Bad Gateway errors
- Nginx service down

**Recovery Steps:**
```bash
# Check Nginx status
sudo systemctl status nginx

# Check Nginx configuration
sudo nginx -t

# If configuration error, fix and reload
sudo nano /etc/nginx/sites-available/stackwatch
sudo nginx -t
sudo systemctl reload nginx

# If service stopped, start it
sudo systemctl start nginx

# Check logs
sudo tail -f /var/log/nginx/error.log
```

#### Prometheus Recovery

**Symptoms:**
- Prometheus not accessible via `/prometheus`
- Container stopped
- Metrics not updating

**Recovery Steps:**
```bash
# Check container status
sudo podman ps -a | grep prometheus

# If container stopped, start it
sudo podman start prometheus

# If container not found, recreate it (see installation steps)

# Check logs
sudo podman logs prometheus

# Verify data directory permissions
sudo ls -la /var/lib/prometheus/data/
sudo chown -R <user>:<group> /var/lib/prometheus/data/
```

#### Grafana Recovery

**Symptoms:**
- Grafana not accessible via `/grafana`
- Container stopped
- Dashboards not loading

**Recovery Steps:**
```bash
# Check container status
sudo podman ps -a | grep grafana

# If container stopped, start it
sudo podman start grafana

# If container not found, recreate it (see installation steps)

# Check logs
sudo podman logs grafana

# Verify data directory permissions
sudo ls -la /var/lib/grafana/data/
sudo chown -R <user>:<group> /var/lib/grafana/data/
```

### 3.2 Data Recovery

#### Prometheus Data Recovery

**Backup Location:** `/backup/prometheus/` (or configured location)

**Recovery Steps:**
```bash
# Stop Prometheus
sudo podman stop prometheus

# Backup current data (if needed)
sudo cp -r /var/lib/prometheus/data /var/lib/prometheus/data.backup

# Restore from backup
sudo rm -rf /var/lib/prometheus/data/*
sudo cp -r /backup/prometheus/data/* /var/lib/prometheus/data/
sudo chown -R <user>:<group> /var/lib/prometheus/data/

# Start Prometheus
sudo podman start prometheus

# Verify data
curl http://localhost:9090/api/v1/query?query=up
```

#### Grafana Data Recovery

**Backup Location:** `/backup/grafana/` (or configured location)

**Recovery Steps:**
```bash
# Stop Grafana
sudo podman stop grafana

# Backup current data (if needed)
sudo cp -r /var/lib/grafana/data /var/lib/grafana/data.backup

# Restore from backup
sudo rm -rf /var/lib/grafana/data/*
sudo cp -r /backup/grafana/data/* /var/lib/grafana/data/
sudo chown -R <user>:<group> /var/lib/grafana/data/

# Start Grafana
sudo podman start grafana

# Verify access
curl http://localhost:3000/api/health
```

### 3.3 Configuration Recovery

#### Nginx Configuration Recovery

**Backup Location:** `/etc/nginx/sites-available/stackwatch.backup`

**Recovery Steps:**
```bash
# Restore configuration
sudo cp /etc/nginx/sites-available/stackwatch.backup /etc/nginx/sites-available/stackwatch

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

#### Prometheus Configuration Recovery

**Backup Location:** `/etc/prometheus/prometheus.yml.backup`

**Recovery Steps:**
```bash
# Restore configuration
sudo cp /etc/prometheus/prometheus.yml.backup /etc/prometheus/prometheus.yml

# Restart Prometheus container
sudo podman restart prometheus

# Verify configuration
curl http://localhost:9090/api/v1/status/config
```

### 3.4 Complete System Recovery

**Scenario:** Complete system failure or migration to new server

**Recovery Procedure:**
1. Install prerequisites (see Installation Flow)
2. Restore frontend build or rebuild from source
3. Restore Nginx configuration
4. Restore Prometheus data and configuration
5. Restore Grafana data and configuration
6. Restore firewall rules
7. Restart all services
8. Execute health validation
9. Verify metrics collection

---

## 4. Operational Procedures

### 4.1 Daily Operations

**Routine Checks:**
- [ ] Verify all services are running
- [ ] Check service logs for errors
- [ ] Verify metrics are being collected
- [ ] Check disk space usage
- [ ] Review security logs (if available)

**Automated Monitoring:**
- Set up Prometheus alerts for service downtime
- Monitor disk space usage
- Monitor container resource usage

### 4.2 Weekly Operations

**Maintenance Tasks:**
- [ ] Review and rotate logs
- [ ] Check for security updates
- [ ] Review Prometheus retention policy
- [ ] Verify backup procedures
- [ ] Review Grafana dashboard performance

### 4.3 Monthly Operations

**Maintenance Tasks:**
- [ ] Apply security patches
- [ ] Update container images
- [ ] Review and update documentation
- [ ] Conduct security audit
- [ ] Test backup and recovery procedures

### 4.4 Update Procedures

#### Frontend Update

```bash
# Pull latest code
cd /opt/stackwatch
git pull

# Rebuild
npm install
npm run build

# Deploy
sudo cp -r dist/* /var/www/stackwatch/dist/
sudo systemctl reload nginx
```

#### Prometheus Update

```bash
# Pull new image
sudo podman pull prom/prometheus:latest

# Stop and remove old container
sudo podman stop prometheus
sudo podman rm prometheus

# Start new container (see installation steps)
sudo podman run -d ... prom/prometheus:latest
```

#### Grafana Update

```bash
# Pull new image
sudo podman pull grafana/grafana:latest

# Stop and remove old container
sudo podman stop grafana
sudo podman rm grafana

# Start new container (see installation steps)
sudo podman run -d ... grafana/grafana:latest
```

---

## 5. Troubleshooting Guide

### 5.1 Common Issues

#### Issue: 502 Bad Gateway

**Symptoms:**
- Nginx returns 502 error
- Backend service not responding

**Diagnosis:**
```bash
# Check backend service
sudo podman ps | grep prometheus
sudo podman ps | grep grafana

# Check Nginx error log
sudo tail -f /var/log/nginx/error.log

# Test backend directly
curl http://localhost:9090/-/healthy
curl http://localhost:3000/api/health
```

**Resolution:**
- Start stopped container
- Check container logs for errors
- Verify firewall rules allow localhost connections

#### Issue: Frontend Not Loading

**Symptoms:**
- Blank page or 404 error
- Assets not loading

**Diagnosis:**
```bash
# Check Nginx status
sudo systemctl status nginx

# Check file permissions
ls -la /var/www/stackwatch/dist/

# Check Nginx configuration
sudo nginx -t
```

**Resolution:**
- Fix file permissions: `sudo chown -R nginx:nginx /var/www/stackwatch`
- Verify Nginx configuration
- Check Nginx error logs

#### Issue: Metrics Not Collecting

**Symptoms:**
- Prometheus targets show as down
- No metrics in Grafana

**Diagnosis:**
```bash
# Check Prometheus targets
curl http://localhost/prometheus/api/v1/targets | jq

# Test exporter endpoints
curl http://target-server:9100/metrics

# Check Prometheus configuration
cat /etc/prometheus/prometheus.yml
```

**Resolution:**
- Verify exporter services are running
- Check network connectivity
- Verify Prometheus scrape configuration
- Check firewall rules

---

## 6. Backup Procedures

### 6.1 Backup Schedule

**Daily Backups:**
- Prometheus TSDB data
- Grafana database and dashboards

**Weekly Backups:**
- Configuration files
- Frontend build artifacts (optional)

### 6.2 Backup Execution

**Prometheus Backup:**
```bash
# Stop Prometheus (optional, for consistent backup)
sudo podman stop prometheus

# Create backup
sudo tar -czf /backup/prometheus-$(date +%Y%m%d).tar.gz /var/lib/prometheus/data/

# Start Prometheus
sudo podman start prometheus
```

**Grafana Backup:**
```bash
# Stop Grafana (optional)
sudo podman stop grafana

# Create backup
sudo tar -czf /backup/grafana-$(date +%Y%m%d).tar.gz /var/lib/grafana/data/

# Start Grafana
sudo podman start grafana
```

**Configuration Backup:**
```bash
# Backup all configurations
sudo tar -czf /backup/config-$(date +%Y%m%d).tar.gz \
  /etc/nginx/sites-available/stackwatch \
  /etc/prometheus/prometheus.yml \
  /etc/grafana/grafana.ini
```

---

## Document Control

**Version History:**
- 1.0.0 (2024): Initial operational runbook

**Review Cycle:** Quarterly  
**Next Review Date:** TBD  
**Approval Required:** Operations Team Lead, Infrastructure Team Lead

---

**END OF OPERATIONAL RUNBOOK**

