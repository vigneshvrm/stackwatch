# STACKWATCH: Script Documentation and Automation Audit

**Document Version:** 1.0.0  
**Classification:** Internal Technical Documentation  
**Last Updated:** 2024  
**Architect:** Senior Cloud Infrastructure Architect and Automation Engineer

---

## Executive Summary

This document provides comprehensive documentation for all automation scripts, deployment procedures, and operational utilities expected in the StackWatch infrastructure. **Note:** Infrastructure automation scripts (Ansible playbooks, deployment scripts) are not currently present in the repository. This document serves as both an audit of existing scripts and a specification for expected automation.

---

## 1. Script Inventory and Status

### 1.1 Current Repository Script Status

**Frontend Build Scripts (Present):**
- `package.json` scripts: `dev`, `build`, `preview`
- Location: Repository root
- Status: ✅ Implemented and functional

**Infrastructure Scripts (Missing):**
- Ansible playbooks: ❌ Not in repository
- Deployment scripts: ❌ Not in repository
- Health check scripts: ❌ Not in repository
- Backup scripts: ❌ Not in repository
- Firewall configuration scripts: ❌ Not in repository

### 1.2 Expected Script Categories

1. **Ansible Automation**
   - Playbooks for infrastructure deployment
   - Roles for service configuration
   - Inventory management

2. **Deployment Scripts**
   - Frontend build and deployment
   - Service container management
   - Configuration updates

3. **Operational Scripts**
   - Health checks
   - Backup procedures
   - Recovery procedures

4. **Security Scripts**
   - Firewall rule management
   - Certificate management
   - Access control

---

## 2. Frontend Build Scripts (Documented)

### 2.1 npm run dev

**Purpose:**  
Development server for local frontend development with hot module replacement (HMR).

**Location:**  
`package.json` → `scripts.dev`

**Command:**  
```bash
npm run dev
```

**Implementation:**  
```json
"dev": "vite"
```

**Behavior:**
- Starts Vite development server
- Port: 3000 (configured in `vite.config.ts`)
- Host: 0.0.0.0 (accessible from network)
- Hot Module Replacement: Enabled
- Source maps: Enabled (development mode)

**Validation:**
- ✅ Server starts on port 3000
- ✅ Accessible at `http://localhost:3000`
- ✅ React application renders
- ✅ HMR updates on file changes

**Failure Modes:**
1. **Port Already in Use**
   - Error: `EADDRINUSE: address already in use :::3000`
   - Cause: Another process using port 3000
   - Resolution: Kill process or change port in `vite.config.ts`

2. **Missing Dependencies**
   - Error: `Cannot find module`
   - Cause: `node_modules` not installed
   - Resolution: Run `npm install`

3. **TypeScript Errors**
   - Error: Compilation errors in console
   - Cause: Type errors in source code
   - Resolution: Fix TypeScript errors

**Rollback:**  
Not applicable (development environment)

**Dependencies:**
- Node.js (version TBD, check `package.json` engines)
- npm or yarn package manager
- All dependencies from `package.json`

---

### 2.2 npm run build

**Purpose:**  
Production build of the React frontend application. Generates optimized static files for deployment.

**Location:**  
`package.json` → `scripts.build`

**Command:**  
```bash
npm run build
```

**Implementation:**  
```json
"build": "vite build"
```

**Behavior:**
- Compiles TypeScript to JavaScript
- Bundles React application
- Minifies JavaScript and CSS
- Tree-shakes unused code
- Generates source maps (production)
- Output directory: `dist/` (Vite default)

**Output Structure:**
```
dist/
├── index.html          # Entry HTML file
├── assets/
│   ├── index-<hash>.js    # Bundled JavaScript
│   └── index-<hash>.css   # Bundled CSS (if any)
└── ...
```

**Validation:**
1. **Build Success:**
   ```bash
   npm run build
   # Expected: "build completed in Xs"
   ```

2. **Output Verification:**
   ```bash
   ls -la dist/
   # Expected: index.html and assets/ directory exist
   ```

3. **Build Artifact Testing:**
   ```bash
   npm run preview
   # Expected: Application runs from dist/ directory
   ```

**Failure Modes:**
1. **TypeScript Compilation Errors**
   - Error: Type errors prevent compilation
   - Cause: Type mismatches, missing types
   - Resolution: Fix TypeScript errors in source files
   - Rollback: Previous build artifacts remain in `dist/` (if exists)

2. **Build Dependency Errors**
   - Error: Missing dependencies or version conflicts
   - Cause: `package-lock.json` out of sync
   - Resolution: `rm -rf node_modules package-lock.json && npm install`
   - Rollback: Reinstall previous `package-lock.json` version

3. **Out of Memory**
   - Error: `JavaScript heap out of memory`
   - Cause: Large codebase or insufficient memory
   - Resolution: Increase Node.js memory limit: `NODE_OPTIONS=--max-old-space-size=4096 npm run build`
   - Rollback: Not applicable

4. **Vite Configuration Errors**
   - Error: Vite config syntax errors
   - Cause: Invalid `vite.config.ts` syntax
   - Resolution: Fix configuration file
   - Rollback: Revert `vite.config.ts` to previous version

**Rollback Procedure:**
1. Previous build artifacts in `dist/` remain until overwritten
2. To rollback: Restore `dist/` from backup or rebuild previous version
3. Git-based rollback: `git checkout <previous-commit> -- dist/`

**Pre-deployment Checklist:**
- [ ] Build completes without errors
- [ ] `dist/index.html` exists and is valid
- [ ] `dist/assets/` contains JavaScript bundles
- [ ] Preview test passes (`npm run preview`)
- [ ] No console errors in browser
- [ ] All service links work correctly

---

### 2.3 npm run preview

**Purpose:**  
Preview production build locally before deployment. Serves the `dist/` directory.

**Location:**  
`package.json` → `scripts.preview`

**Command:**  
```bash
npm run preview
```

**Implementation:**  
```json
"preview": "vite preview"
```

**Behavior:**
- Serves files from `dist/` directory
- Simulates production environment
- Port: 4173 (Vite default, or configured)
- No HMR (static file serving)

**Validation:**
- ✅ Server starts on port 4173
- ✅ Application loads from `dist/`
- ✅ All routes work correctly
- ✅ No 404 errors for assets

**Failure Modes:**
1. **dist/ Directory Missing**
   - Error: `dist/ directory not found`
   - Cause: Build not executed
   - Resolution: Run `npm run build` first

2. **Port Conflict**
   - Error: Port 4173 already in use
   - Cause: Another process using the port
   - Resolution: Kill process or change port

**Rollback:**  
Not applicable (preview only)

---

## 3. Expected Infrastructure Scripts (Specification)

### 3.1 Ansible Playbook: Deploy Node Exporter

**Expected Location:**  
`ansible/playbooks/deploy-node-exporter.yml` (not in repository)

**Purpose:**  
Deploy and configure Prometheus Node Exporter on Linux target servers.

**Expected Structure:**
```yaml
---
- name: Deploy Node Exporter
  hosts: linux_servers
  become: yes
  roles:
    - node-exporter
```

**Expected Behavior:**
1. Download Node Exporter binary (if not present)
2. Create systemd service file
3. Configure service to start on boot
4. Start Node Exporter service
5. Verify service is running on port 9100
6. Update Prometheus configuration (if applicable)

**Validation:**
- ✅ Service status: `systemctl status node_exporter`
- ✅ Port listening: `netstat -tlnp | grep 9100`
- ✅ Metrics endpoint: `curl http://localhost:9100/metrics`
- ✅ Service enabled: `systemctl is-enabled node_exporter`

**Failure Modes:**
1. **Service Installation Failure**
   - Cause: Insufficient permissions, network issues
   - Resolution: Check `become: yes`, verify network connectivity
   - Rollback: Ansible idempotency should handle re-runs

2. **Port Already in Use**
   - Cause: Another service using port 9100
   - Resolution: Identify and stop conflicting service
   - Rollback: Stop Node Exporter service

3. **Binary Download Failure**
   - Cause: Network connectivity, invalid URL
   - Resolution: Check network, verify download URL
   - Rollback: Use cached binary if available

**Rollback Procedure:**
```bash
# Stop and disable service
systemctl stop node_exporter
systemctl disable node_exporter

# Remove service file (if needed)
rm /etc/systemd/system/node_exporter.service
systemctl daemon-reload
```

---

### 3.2 Ansible Playbook: Configure Firewall

**Expected Location:**  
`ansible/playbooks/configure-firewall.yml` (not in repository)

**Purpose:**  
Configure firewall rules to allow required ports and block direct access to internal services.

**Expected Behavior:**
1. Allow port 80 (HTTP)
2. Allow port 443 (HTTPS)
3. Deny direct access to port 9090 (Prometheus)
4. Deny direct access to port 3000 (Grafana)
5. Deny direct access to port 9100 (Node Exporter)
6. Deny direct access to port 9182 (Windows Exporter)
7. Allow internal Prometheus scraping (if applicable)

**Validation:**
- ✅ External access to port 80 works
- ✅ External access to port 443 works (if configured)
- ✅ Direct access to port 9090 blocked
- ✅ Direct access to port 3000 blocked
- ✅ Direct access to port 9100 blocked

**Failure Modes:**
1. **Firewall Service Not Running**
   - Cause: firewalld/iptables not active
   - Resolution: Start firewall service
   - Rollback: Restore previous firewall rules

2. **Lockout Risk**
   - Cause: Blocking SSH port (22) accidentally
   - Resolution: Ensure SSH port remains open
   - Rollback: Restore previous rules immediately

**Rollback Procedure:**
```bash
# Restore previous firewall rules
# (Backup should be created before changes)
firewall-cmd --reload  # firewalld
# OR
iptables-restore < /backup/iptables.rules  # iptables
```

---

### 3.3 Deployment Script: Deploy Frontend

**Expected Location:**  
`scripts/deploy-frontend.sh` (not in repository)

**Purpose:**  
Build and deploy StackWatch frontend to Nginx web root.

**Expected Behavior:**
1. Run `npm run build`
2. Backup existing `dist/` directory
3. Copy `dist/` to `/var/www/stackwatch/dist/`
4. Set proper file permissions
5. Reload Nginx configuration
6. Verify deployment

**Validation:**
- ✅ Build succeeds
- ✅ Files copied to web root
- ✅ Nginx serves new files
- ✅ Application loads in browser

**Failure Modes:**
1. **Build Failure**
   - Cause: TypeScript errors, dependency issues
   - Resolution: Fix build errors
   - Rollback: Restore previous `dist/` from backup

2. **Permission Denied**
   - Cause: Insufficient permissions for web root
   - Resolution: Use sudo or correct user permissions
   - Rollback: Restore previous files

3. **Nginx Reload Failure**
   - Cause: Invalid Nginx configuration
   - Resolution: Fix Nginx config, test with `nginx -t`
   - Rollback: Restore previous Nginx config

**Rollback Procedure:**
```bash
# Restore previous dist/ directory
sudo cp -r /var/www/stackwatch/dist.backup /var/www/stackwatch/dist
sudo systemctl reload nginx
```

---

### 3.4 Health Check Script

**Expected Location:**  
`scripts/health-check.sh` (not in repository)

**Purpose:**  
Comprehensive health check of all StackWatch services.

**Expected Behavior:**
1. Check Nginx status and port 80/443
2. Check StackWatch frontend loads
3. Check Prometheus health endpoint
4. Check Grafana health endpoint
5. Check Node Exporter on target servers
6. Check Windows Exporter on target servers
7. Verify Prometheus scraping targets
8. Generate health report

**Expected Output:**
```
StackWatch Health Check Report
=============================
Date: 2024-XX-XX XX:XX:XX

[✓] Nginx: OK (port 80 responding)
[✓] StackWatch Frontend: OK
[✓] Prometheus: OK (/-/healthy)
[✓] Grafana: OK (/api/health)
[✓] Node Exporter (server1): OK
[✓] Node Exporter (server2): OK
[✓] Windows Exporter (win-server1): OK
[✓] Prometheus Targets: 4/4 up

Overall Status: HEALTHY
```

**Validation:**
- ✅ All services return expected status
- ✅ Exit code 0 for healthy, non-zero for unhealthy
- ✅ Report generated with timestamps

**Failure Modes:**
1. **Service Unavailable**
   - Cause: Service crashed, network issue
   - Resolution: Investigate service logs, restart service
   - Rollback: Not applicable (diagnostic only)

2. **Network Connectivity Issues**
   - Cause: Firewall rules, network configuration
   - Resolution: Check network configuration
   - Rollback: Not applicable

**Rollback:**  
Not applicable (read-only diagnostic script)

---

### 3.5 Backup Script

**Expected Location:**  
`scripts/backup-stackwatch.sh` (not in repository)

**Purpose:**  
Backup critical StackWatch data and configurations.

**Expected Behavior:**
1. Backup Prometheus TSDB data
2. Backup Grafana dashboards and configuration
3. Backup Nginx configuration
4. Backup Ansible playbooks and inventory
5. Create timestamped backup archive
6. Optionally upload to remote storage

**Backup Targets:**
- Prometheus data: `/var/lib/prometheus/data/` (or Podman volume)
- Grafana data: `/var/lib/grafana/` (or Podman volume)
- Nginx config: `/etc/nginx/sites-available/stackwatch`
- Ansible: `ansible/` directory
- Frontend build: `/var/www/stackwatch/dist/` (optional)

**Validation:**
- ✅ Backup archive created
- ✅ Archive contains expected files
- ✅ Archive size reasonable
- ✅ Backup can be restored (test restore)

**Failure Modes:**
1. **Insufficient Disk Space**
   - Cause: Backup destination full
   - Resolution: Free disk space or change backup location
   - Rollback: Delete old backups

2. **Permission Denied**
   - Cause: Cannot read source files or write backup
   - Resolution: Run with appropriate permissions
   - Rollback: Not applicable

**Rollback:**  
Not applicable (backup operation)

---

## 4. Script Execution Environment

### 4.1 Prerequisites

**Frontend Scripts:**
- Node.js (version TBD)
- npm or yarn
- All dependencies installed (`npm install`)

**Infrastructure Scripts (Expected):**
- Ansible 2.9+ (for playbooks)
- Python 3.6+ (Ansible requirement)
- SSH access to target servers
- Sudo/root access on target servers (for system services)
- firewalld or iptables (for firewall scripts)

### 4.2 Execution Context

**Frontend Scripts:**
- Execution: Local development machine or CI/CD pipeline
- User: Developer or CI/CD service account
- Permissions: Standard user (no sudo required)

**Infrastructure Scripts:**
- Execution: Ansible control node or deployment server
- User: Deployment service account
- Permissions: Sudo/root on target servers (via Ansible become)

---

## 5. Script Validation and Testing

### 5.1 Frontend Script Validation

**Development Script (`npm run dev`):**
```bash
# Test: Start dev server
npm run dev
# Expected: Server starts, application accessible

# Test: HMR functionality
# Edit a component file
# Expected: Browser auto-refreshes with changes
```

**Build Script (`npm run build`):**
```bash
# Test: Production build
npm run build
# Expected: dist/ directory created with optimized files

# Test: Build output
ls -la dist/
# Expected: index.html and assets/ present

# Test: Preview build
npm run preview
# Expected: Application runs from dist/
```

### 5.2 Infrastructure Script Validation (Expected)

**Ansible Playbooks:**
```bash
# Test: Syntax check
ansible-playbook --syntax-check playbook.yml

# Test: Dry run (check mode)
ansible-playbook --check playbook.yml

# Test: Execution
ansible-playbook playbook.yml
# Expected: Services deployed, no errors
```

**Deployment Scripts:**
```bash
# Test: Script syntax
bash -n script.sh

# Test: Execution with dry-run flag (if supported)
./script.sh --dry-run
```

---

## 6. Script Maintenance and Updates

### 6.1 Version Control

**Current Status:**
- Frontend scripts: ✅ Version controlled in `package.json`
- Infrastructure scripts: ❌ Not in repository

**Recommendation:**
- All scripts should be version controlled
- Use semantic versioning for script changes
- Document breaking changes in CHANGELOG

### 6.2 Script Documentation Standards

**Required Documentation for Each Script:**
1. Purpose and description
2. Usage and command syntax
3. Parameters and options
4. Expected behavior
5. Validation steps
6. Failure modes and resolutions
7. Rollback procedures
8. Dependencies and prerequisites

---

## 7. Security Considerations

### 7.1 Script Security

**Frontend Scripts:**
- ✅ No sensitive data in scripts
- ✅ Dependencies from npm registry (verify integrity)
- ⚠️ Environment variables: Use `.env.local` (not committed)

**Infrastructure Scripts (Expected):**
- ⚠️ Ansible vault for secrets (passwords, API keys)
- ⚠️ SSH key management for remote access
- ⚠️ Sudo permissions: Principle of least privilege
- ⚠️ Script execution: Audit logs for security compliance

### 7.2 Access Control

**Script Execution Permissions:**
- Frontend scripts: Standard user permissions
- Infrastructure scripts: Requires elevated permissions (documented)

**Recommendation:**
- Use service accounts for automated execution
- Implement audit logging for privileged operations
- Review and approve script changes before execution

---

## 8. Gap Analysis: Missing Scripts

### 8.1 Critical Missing Scripts

1. **Ansible Playbooks**
   - Impact: High
   - Risk: Manual deployment, inconsistency
   - Recommendation: Create playbooks for all infrastructure components

2. **Health Check Script**
   - Impact: Medium
   - Risk: Manual health validation, delayed issue detection
   - Recommendation: Implement automated health checks

3. **Backup Script**
   - Impact: High
   - Risk: Data loss, no recovery procedure
   - Recommendation: Implement automated backups

4. **Deployment Script**
   - Impact: Medium
   - Risk: Manual deployment, human error
   - Recommendation: Automate frontend deployment

5. **Firewall Configuration Script**
   - Impact: High
   - Risk: Security misconfiguration, manual errors
   - Recommendation: Automate firewall rule management

### 8.2 Recommended Script Implementation Priority

1. **Priority 1 (Critical):**
   - Ansible playbooks for infrastructure deployment
   - Backup script for data protection

2. **Priority 2 (High):**
   - Health check script for monitoring
   - Firewall configuration automation

3. **Priority 3 (Medium):**
   - Deployment script for frontend
   - Recovery/rollback scripts

---

## Document Control

**Version History:**
- 1.0.0 (2024): Initial script documentation and audit

**Review Cycle:** Quarterly  
**Next Review Date:** TBD  
**Approval Required:** Infrastructure Team Lead, DevOps Team Lead

---

**END OF SCRIPT DOCUMENTATION**

