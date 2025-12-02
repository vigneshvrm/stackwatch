# STACKBILL: Backend Deployment Flow

**Document Version:** 1.0.0  
**Architect:** Backend System Architect and Automation Engineer  
**Last Updated:** 2024

---

## Executive Summary

This document describes the complete backend deployment flow for StackBill infrastructure. The deployment follows strict separation between frontend and backend, with backend services deployed via shell scripts and Ansible (Linux Node Exporter only).

---

## Deployment Architecture

### Component Deployment Methods

| Component | Deployment Method | Location |
|-----------|------------------|----------|
| **Firewall** | Shell Script | `scripts/configure-firewall.sh` |
| **Nginx** | Shell Script | `scripts/deploy-nginx.sh` |
| **Prometheus** | Shell Script (Podman) | `scripts/deploy-prometheus.sh` |
| **Grafana** | Shell Script (Podman) | `scripts/deploy-grafana.sh` |
| **Node Exporter (Linux)** | Ansible Playbook | `ansible/playbooks/deploy-node-exporter.yml` |
| **Windows Exporter** | Manual/External | Not automated in this repo |

---

## Complete Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: Frontend Team Pushes UI to GitHub                  │
│  - Frontend built separately (npm run build)                │
│  - Frontend code in repository                               │
│  - Backend does NOT modify frontend                          │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: Backend Deployment Orchestrator                     │
│  Script: scripts/deploy-stackbill.sh                         │
│  - Coordinates all backend services                          │
│  - Does NOT touch frontend code                              │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────┴───────────────────┐
        │                                       │
        ▼                                       ▼
┌──────────────────────┐            ┌──────────────────────┐
│  Phase 1: Firewall    │            │  Phase 2: Nginx     │
│  Script:              │            │  Script:             │
│  configure-firewall.sh│            │  deploy-nginx.sh     │
│                       │            │                      │
│  - Allow ports 80/443 │            │  - Configure Nginx   │
│  - Block internal     │            │  - Serve frontend    │
│    service ports      │            │  - Proxy /prometheus  │
│                       │            │  - Proxy /grafana    │
└───────────┬───────────┘            └───────────┬──────────┘
            │                                    │
            └────────────────┬───────────────────┘
                            │
                            ▼
        ┌───────────────────┴───────────────────┐
        │                                       │
        ▼                                       ▼
┌──────────────────────┐            ┌──────────────────────┐
│  Phase 3: Prometheus │            │  Phase 4: Grafana   │
│  Script:              │            │  Script:             │
│  deploy-prometheus.sh│            │  deploy-grafana.sh  │
│                       │            │                      │
│  - Pull image         │            │  - Pull image        │
│  - Create config      │            │  - Create config     │
│  - Run container      │            │  - Run container     │
│  - systemd service    │            │  - systemd service  │
└───────────┬───────────┘            └───────────┬──────────┘
            │                                    │
            └────────────────┬───────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 5: Node Exporter (Linux)                              │
│  Ansible: ansible/playbooks/deploy-node-exporter.yml         │
│                                                               │
│  - Deploy to Linux servers only                              │
│  - Create systemd service                                    │
│  - Verify metrics endpoint                                   │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 6: Health Check                                        │
│  Script: scripts/health-check.sh                              │
│                                                               │
│  - Verify all services running                               │
│  - Check health endpoints                                    │
│  - Generate health report                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Detailed Phase Descriptions

### Phase 1: Firewall Configuration

**Script:** `scripts/configure-firewall.sh`

**Actions:**
1. Detect firewall system (firewalld/ufw/iptables)
2. Allow HTTP (port 80)
3. Allow HTTPS (port 443)
4. Block direct access to:
   - Prometheus (port 9090)
   - Grafana (port 3000)
   - Node Exporter (port 9100)
   - Windows Exporter (port 9182)
5. Reload firewall rules

**Output:** Firewall rules configured, services protected

---

### Phase 2: Nginx Deployment

**Script:** `scripts/deploy-nginx.sh`

**Actions:**
1. Create Nginx configuration file
2. Configure frontend serving (SPA routing)
3. Configure reverse proxy for `/prometheus`
4. Configure reverse proxy for `/grafana`
5. Deploy frontend build (if exists in `dist/`)
6. Enable Nginx site
7. Test and reload Nginx

**Critical:** Serves frontend but does NOT modify frontend code

**Output:** Nginx serving frontend and proxying backend services

---

### Phase 3: Prometheus Deployment

**Script:** `scripts/deploy-prometheus.sh`

**Actions:**
1. Create Prometheus configuration directory
2. Generate `prometheus.yml` configuration
3. Pull Prometheus container image
4. Run Prometheus container (Podman)
5. Create systemd service for auto-start
6. Verify Prometheus health endpoint

**Output:** Prometheus running on port 9090, accessible via Nginx

---

### Phase 4: Grafana Deployment

**Script:** `scripts/deploy-grafana.sh`

**Actions:**
1. Create Grafana configuration directory
2. Generate `grafana.ini` configuration
3. Pull Grafana container image
4. Run Grafana container (Podman)
5. Create systemd service for auto-start
6. Verify Grafana health endpoint

**Output:** Grafana running on port 3000, accessible via Nginx

---

### Phase 5: Node Exporter Deployment (Ansible)

**Playbook:** `ansible/playbooks/deploy-node-exporter.yml`

**Actions:**
1. Verify OS compatibility (Linux only)
2. Create Node Exporter user
3. Download Node Exporter binary
4. Install binary to `/usr/local/bin`
5. Create systemd service file
6. Enable and start service
7. Verify metrics endpoint

**Targets:** All servers in `[linux_servers]` inventory group

**Output:** Node Exporter running on port 9100 on all Linux servers

---

### Phase 6: Health Check

**Script:** `scripts/health-check.sh`

**Actions:**
1. Check Nginx service status
2. Check StackBill frontend accessibility
3. Check Prometheus container and health
4. Check Grafana container and health
5. Verify services via Nginx proxy
6. Generate health report

**Output:** Health status report with pass/fail indicators

---

## Backend-Frontend Separation

### Critical Rules

1. **Frontend is Built Separately**
   - Frontend team runs `npm run build`
   - Build output in `dist/` directory
   - Backend scripts copy `dist/` to Nginx web root
   - Backend does NOT modify frontend source code

2. **Backend Serves Frontend**
   - Nginx serves static files from `/var/www/stackbill/dist/`
   - Backend adapts to frontend routes without breaking
   - If frontend adds new routes, backend Nginx config may need update
   - Backend changes are backward compatible

3. **No Frontend Dependencies**
   - Backend scripts do NOT depend on frontend implementation
   - Backend does NOT assume UI structure
   - Backend does NOT hardcode HTML logic
   - Backend serves whatever frontend provides

---

## Deployment Execution

### Full Deployment

```bash
# Run complete backend deployment
sudo ./scripts/deploy-stackbill.sh
```

This executes all phases in sequence.

### Individual Service Deployment

```bash
# Deploy firewall only
sudo ./scripts/configure-firewall.sh

# Deploy Nginx only
sudo ./scripts/deploy-nginx.sh

# Deploy Prometheus only
sudo ./scripts/deploy-prometheus.sh

# Deploy Grafana only
sudo ./scripts/deploy-grafana.sh

# Deploy Node Exporter only
ansible-playbook -i ansible/inventory/production ansible/playbooks/deploy-node-exporter.yml

# Health check only
./scripts/health-check.sh
```

---

## Change Impact Assessment

### When Frontend Changes

**Backend Impact:** Minimal to None

- If frontend adds new routes: Nginx may need route configuration
- If frontend changes build output: Nginx serves new output automatically
- If frontend changes API calls: Backend services adapt (no changes needed)

### When Backend Changes

**Frontend Impact:** None

- Backend changes are isolated
- Backend services are backward compatible
- Frontend continues to work with existing backend

---

## Rollback Procedures

### Service Rollback

Each script supports rollback via backups:

- Nginx: Config backed up before changes
- Prometheus: Config backed up before changes
- Grafana: Config backed up before changes
- Node Exporter: Ansible idempotency allows re-run

### Complete Rollback

1. Restore Nginx config from backup
2. Stop and remove containers
3. Restore service configs from backups
4. Re-run deployment with previous versions

---

## Troubleshooting

### Common Issues

1. **Frontend Not Loading**
   - Check: `ls -la /var/www/stackbill/dist/`
   - Fix: Run `npm run build` in project root, then re-run `deploy-nginx.sh`

2. **Services Not Accessible via Nginx**
   - Check: Container status (`podman ps`)
   - Check: Nginx config (`nginx -t`)
   - Check: Firewall rules

3. **Node Exporter Not Scraped**
   - Check: Prometheus targets (`/prometheus/api/v1/targets`)
   - Check: Node Exporter running (`systemctl status node_exporter`)
   - Check: Prometheus config includes targets

---

## Document Control

**Version History:**
- 1.0.0 (2024): Initial backend deployment flow document

**Review Cycle:** Quarterly  
**Next Review Date:** TBD  
**Approval Required:** Backend System Architect, Operations Team Lead

---

**END OF BACKEND DEPLOYMENT FLOW DOCUMENT**

