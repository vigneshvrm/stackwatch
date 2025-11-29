# STACKBILL: Deployment Scripts

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
├── deploy-stackbill.sh          # Main deployment orchestrator
├── deploy-nginx.sh               # Nginx configuration and deployment
├── deploy-prometheus.sh          # Prometheus Podman deployment
├── deploy-grafana.sh             # Grafana Podman deployment
├── configure-firewall.sh         # Firewall rules configuration
├── health-check.sh               # Health validation script
├── deploy-windows-exporter.ps1   # Windows Exporter (PowerShell ONLY)
├── backup-stackbill.sh           # Backup procedures
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

## Usage

### Full Deployment

```bash
# Deploy all backend services
./scripts/deploy-stackbill.sh

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

