# STACKWATCH: Deployment Scripts

**Version:** 1.0.0  
**Architect:** Backend System Architect and Automation Engineer

---

## Repository Control Rules

**STRICT COMPLIANCE:**
- ✅ Add new scripts
- ✅ Extend safely without breaking changes
- ❌ Modify existing working scripts
- ❌ Remove or rename existing scripts
- ❌ Touch UI directories or frontend code

---

## Script Structure

```
scripts/
├── README.md                    # This file
├── deploy-stackwatch.sh          # Main deployment orchestrator
├── deploy-nginx.sh               # Nginx configuration and deployment
├── deploy-prometheus.sh          # Prometheus Podman deployment
├── deploy-grafana.sh             # Grafana Podman deployment
├── configure-firewall.sh         # Firewall rules configuration
├── health-check.sh               # Health validation script
├── deploy-windows-exporter.ps1   # Windows Exporter (PowerShell ONLY)
├── backup-stackwatch.sh           # Backup procedures
└── recovery.sh                   # Recovery procedures
```

---

## Deployment Flow

```
1. Frontend Team pushes UI to GitHub
   ↓
2. Backend adapts WITHOUT breaking frontend
   ↓
3. Scripts deploy backend services:
   - configure-firewall.sh
   - deploy-nginx.sh (serves frontend)
   - deploy-prometheus.sh
   - deploy-grafana.sh
   ↓
4. Ansible deploys Node Exporter (Linux only)
   ↓
5. Windows Exporter deployed separately (PowerShell on Windows servers)
   ↓
6. Health check validates all services
```

---

## Deployment Scenarios

### Scenario 1: Full Infrastructure Deployment (Source Repository)

When deploying from the **source repository**, all scripts and playbooks are available for complete infrastructure setup:

```bash
# Full deployment (recommended for infrastructure server)
./scripts/deploy-stackwatch.sh
```

This deploys:
- ✅ Nginx web server
- ✅ Prometheus monitoring
- ✅ Grafana dashboards
- ✅ Firewall configuration
- ✅ All infrastructure components

**Use case:** Setting up the central StackWatch monitoring server

### Scenario 2: Client Package Deployment (Prebuilt Package)

When deploying from the **prebuilt client package**, only monitoring agent tools are included:

```bash
# Extract package
tar -xzf stackwatch-prebuilt-*.tar.gz -C /opt
mv /opt/stackwatch-prebuilt /opt/stackwatch

# Run deployment helper (informational only in client mode)
sudo /opt/stackwatch/scripts/deploy-from-opt.sh

# Deploy monitoring agents to target servers
ansible-playbook -i /opt/stackwatch/ansible/inventory/hosts \
    /opt/stackwatch/ansible/playbooks/deploy-node-exporter.yml
```

This deploys:
- ✅ Node Exporter (Linux monitoring agent)
- ✅ Windows Exporter (Windows monitoring agent)
- ❌ No infrastructure components (must be deployed separately)

**Use case:** Deploying monitoring agents to servers that will be monitored by a central StackWatch server

**Note:** The client package requires a separate StackWatch monitoring server to be already deployed and running.

---

## Usage

### Full Deployment (Source Repository Only)

```bash
# Deploy all backend services
./scripts/deploy-stackwatch.sh

# Or step by step:
./scripts/configure-firewall.sh
./scripts/deploy-nginx.sh
./scripts/deploy-prometheus.sh
./scripts/deploy-grafana.sh
ansible-playbook -i ansible/inventory/production ansible/playbooks/deploy-node-exporter.yml
# Windows Exporter: Run PowerShell script on each Windows server separately
./scripts/health-check.sh
```

### Individual Services

```bash
# Deploy Nginx only
./scripts/deploy-nginx.sh

# Deploy Prometheus only
./scripts/deploy-prometheus.sh

# Deploy Grafana only
./scripts/deploy-grafana.sh

# Configure firewall only
./scripts/configure-firewall.sh
```

### Windows Exporter Deployment (PowerShell ONLY)

**CRITICAL RULE:** Windows Exporter MUST use PowerShell script ONLY - NO Ansible, NO WinRM

```powershell
# Run directly on Windows server as Administrator
powershell -ExecutionPolicy Bypass -File scripts/deploy-windows-exporter.ps1

# With custom port
powershell -ExecutionPolicy Bypass -File scripts/deploy-windows-exporter.ps1 -NodeExporterPort 9100

# Skip firewall configuration
powershell -ExecutionPolicy Bypass -File scripts/deploy-windows-exporter.ps1 -SkipFirewall
```

---

## Backend-Frontend Separation

**CRITICAL:** Scripts serve frontend via Nginx but do NOT modify frontend code.

- Frontend is built separately (npm run build)
- Scripts copy built files to Nginx web root
- No frontend code modification
- Backward compatible routing

---

**END OF SCRIPTS README**

