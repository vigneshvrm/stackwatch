# STACKBILL: Ansible Infrastructure Automation

**Version:** 1.0.0  
**Architect:** Backend System Architect and Automation Engineer

---

## Repository Control Rules

**STRICT COMPLIANCE:**
- ✅ Add new scripts and playbooks
- ✅ Extend safely without breaking changes
- ❌ Modify existing working code
- ❌ Rename files or alter service units
- ❌ Remove firewall rules or edit roles

---

## Directory Structure

```
ansible/
├── README.md                    # This file
├── ansible.cfg                  # Ansible configuration
├── inventory/
│   └── hosts                    # Linux servers inventory
└── playbooks/
    └── deploy-node-exporter.yml # Linux Node Exporter deployment (ONLY - self-contained)
```

**CRITICAL RULE - EXPORTER INSTALLATION METHOD:**
- **Linux Node Exporter**: MUST use Ansible ONLY (this playbook)
- **Windows Exporter**: MUST use PowerShell script ONLY (NO Ansible, NO WinRM)
  - PowerShell script: `../scripts/deploy-windows-exporter.ps1`
  - Must be run directly on Windows server with Administrator privileges

All other services (Nginx, Prometheus, Grafana, Firewall) are deployed via shell scripts in `../scripts/`.

---

## Usage

### Prerequisites

- Ansible 2.9+
- Python 3.6+
- SSH access to target servers
- Sudo/root access on target servers

### Basic Usage

```bash
# Deploy Node Exporter to Linux servers (Ansible ONLY)
ansible-playbook playbooks/deploy-node-exporter.yml

# Or specify inventory explicitly
ansible-playbook -i inventory/hosts playbooks/deploy-node-exporter.yml

# Deploy with specific tags
ansible-playbook playbooks/deploy-node-exporter.yml --tags verify
```

**Windows Exporter Deployment (PowerShell ONLY - NO Ansible):**
```powershell
# Run directly on Windows server as Administrator
powershell -ExecutionPolicy Bypass -File scripts/deploy-windows-exporter.ps1

# Or with custom port
powershell -ExecutionPolicy Bypass -File scripts/deploy-windows-exporter.ps1 -NodeExporterPort 9100
```

**NOTE:** For full StackBill deployment, use the main deployment script:
```bash
./scripts/deploy-stackbill.sh
```

This script orchestrates:
1. Firewall configuration (script)
2. Nginx deployment (script)
3. Prometheus deployment (script)
4. Grafana deployment (script)
5. Node Exporter deployment (Ansible - Linux playbook ONLY)
6. Health checks (script)

**Note:** Windows Exporter MUST be deployed separately using PowerShell script on each Windows server.

---

## Backend-Frontend Separation

**CRITICAL RULE:** Backend infrastructure is independent of frontend UI.

- Backend serves frontend via Nginx (static files)
- Backend does NOT depend on frontend implementation
- Frontend changes do NOT require backend changes (unless new routes)
- Backend adapts to frontend routes without breaking existing behavior

---

## Change Impact

All changes follow strict change impact assessment:
- Risk level evaluation
- Rollback plan
- User impact analysis
- Backward compatibility verification

See `docs/CHANGE_IMPACT_TEMPLATE.md` for change documentation.

---

**END OF ANSIBLE README**

