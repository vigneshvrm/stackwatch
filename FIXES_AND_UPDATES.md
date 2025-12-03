# STACKWATCH: Script Fixes and Documentation Updates

**Date:** 2024  
**Engineer:** Backend Engineer and Technical Writer

---

## SECTION 1 — Updated Documentation Blocks

### 1.1 Node.js Installation Step

**Location:** Section 2 (Prerequisites) - Add after "Required Packages and Tools"

**New Content:**

```markdown
### Node.js Installation (Required for Frontend Build)

**Why Node.js is Required:**
Node.js is required to build the StackWatch frontend application. The frontend uses npm (Node Package Manager) to install dependencies and build the production-ready static files that Nginx serves.

**When to Install:**
Node.js must be installed BEFORE building the frontend (Section 3.2). Install it during the prerequisites phase.

**Installation Commands:**

**Debian/Ubuntu:**
```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install nodejs -y
```

**RHEL/CentOS:**
```bash
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo yum install -y nodejs
```

**Verification:**
```bash
node --version
npm --version
```

**Expected Result:** Node.js version 20.x and npm version displayed
```

---

### 1.2 Script Execution Permissions

**Location:** Section 3 (Step-by-Step Installation) - Add BEFORE Section 3.3 "Deploy Nginx"

**New Content:**

```markdown
### 3.2.1 Set Script Execution Permissions

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
chmod +x ./scripts/deploy-stackwatch.sh
chmod +x ./scripts/health-check.sh
```

**Verification:**
```bash
ls -l ./scripts/*.sh
```

**Expected Result:** All script files show `-rwxr-xr-x` (execute permission enabled)

**Note:** If you run scripts with `bash ./scripts/deploy-nginx.sh`, execute permissions are not required, but using `./scripts/deploy-nginx.sh` requires execute permissions.
```

---

### 1.3 Nginx Troubleshooting - UI Not Loading

**Location:** Section 10 (Troubleshooting) - Add new subsection 10.1.1

**New Content:**

```markdown
**Problem: Nginx shows "Welcome to nginx!" instead of StackWatch UI**

This occurs when Nginx is serving the default site instead of the StackWatch configuration.

**Step 1: Verify Nginx root directory**

```bash
# Check which configuration Nginx is using
sudo nginx -T | grep "root"

# Check if StackWatch config is loaded
sudo nginx -T | grep "stackwatch"
```

**Expected Result:** Should show `root /var/www/stackwatch/dist;` in the active configuration

**Step 2: Confirm StackWatch files are present**

```bash
# Check if frontend files exist
ls -la /var/www/stackwatch/dist/

# Verify index.html exists
test -f /var/www/stackwatch/dist/index.html && echo "File exists" || echo "File missing"
```

**Expected Result:** `index.html` and `assets/` directory should exist

**Step 3: Check which config Nginx loaded**

```bash
# List enabled sites
ls -la /etc/nginx/sites-enabled/

# Check if StackWatch config is enabled
test -L /etc/nginx/sites-enabled/stackwatch && echo "Enabled" || echo "Not enabled"

# Check if default site is still enabled (this is the problem)
test -L /etc/nginx/sites-enabled/default && echo "Default site enabled - DISABLE THIS" || echo "Default site disabled"
```

**Expected Result:** 
- `/etc/nginx/sites-enabled/stackwatch` should exist (symlink)
- `/etc/nginx/sites-enabled/default` should NOT exist (or be disabled)

**Step 4: Disable default site and enable StackWatch**

```bash
# Disable default Nginx site (if it exists)
sudo rm -f /etc/nginx/sites-enabled/default

# Ensure StackWatch site is enabled
sudo ln -sf /etc/nginx/sites-available/stackwatch /etc/nginx/sites-enabled/stackwatch

# Verify symlink
ls -la /etc/nginx/sites-enabled/stackwatch
```

**Expected Result:** Symlink points to `/etc/nginx/sites-available/stackwatch`

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

**Expected Result:** Configuration shows `root /var/www/stackwatch/dist;`

**Step 6: Verify StackWatch UI is served**

```bash
# Test from command line
curl http://localhost/ | head -20

# Check for StackWatch content
curl http://localhost/ | grep -i "stackwatch"
```

**Expected Result:** HTML content contains "StackWatch" text, not "Welcome to nginx!"

**If files are missing, rebuild frontend:**
```bash
cd /opt/stackwatch
npm run build
sudo ./scripts/deploy-nginx.sh
```
```

---

## SECTION 2 — Script Issues & Root Cause

### Problem 1: Prometheus Image Pull Failure

**Error Message:**
```
short-name "prom/prometheus:latest" did not resolve to an alias
No unqualified-search registries in registries.conf
```

**Root Cause:**
Podman requires fully qualified image names (including registry) when no unqualified search registries are configured. The short name `prom/prometheus:latest` is not recognized because Podman doesn't know which registry to use (unlike Docker, which defaults to `docker.io`).

**Solution:**
Use the fully qualified image name: `docker.io/prom/prometheus:latest`

**Impact:**
- Minimal change: Only the image name variable
- No behavior change: Same image, just explicit registry
- Works in default Podman environment: Uses Docker Hub registry explicitly

---

### Problem 2: Grafana Image Pull Failure

**Error Message:**
```
short-name "grafana/grafana:latest" did not resolve
```

**Root Cause:**
Same as Problem 1 - Podman requires fully qualified image names when no search registries are configured.

**Solution:**
Use the fully qualified image name: `docker.io/grafana/grafana:latest`

**Impact:**
- Minimal change: Only the image name variable
- No behavior change: Same image, just explicit registry
- Works in default Podman environment: Uses Docker Hub registry explicitly

---

## SECTION 3 — Fixed Script Snippets

### 3.1 Prometheus Script Fix

**File:** `scripts/deploy-prometheus.sh`

**Line 33 - BEFORE:**
```bash
PROMETHEUS_IMAGE="prom/prometheus:latest"
```

**Line 33 - AFTER:**
```bash
PROMETHEUS_IMAGE="docker.io/prom/prometheus:latest"
```

**Change Explanation:**
- Adds explicit `docker.io/` registry prefix
- Resolves Podman short-name resolution issue
- No functional change - same image from Docker Hub

---

### 3.2 Grafana Script Fix

**File:** `scripts/deploy-grafana.sh`

**Line 33 - BEFORE:**
```bash
GRAFANA_IMAGE="grafana/grafana:latest"
```

**Line 33 - AFTER:**
```bash
GRAFANA_IMAGE="docker.io/grafana/grafana:latest"
```

**Change Explanation:**
- Adds explicit `docker.io/` registry prefix
- Resolves Podman short-name resolution issue
- No functional change - same image from Docker Hub

---

## SECTION 4 — Validation Commands

### 4.1 Test Podman Pull Success

**Before running deployment scripts, test image pulls:**

```bash
# Test Prometheus image pull
sudo podman pull docker.io/prom/prometheus:latest

# Test Grafana image pull
sudo podman pull docker.io/grafana/grafana:latest
```

**Expected Result:**
- Images download successfully
- No "short-name did not resolve" errors
- Images listed in `podman images`

**Verify images are available:**
```bash
sudo podman images | grep -E 'prometheus|grafana'
```

---

### 4.2 Confirm Containers Running

**After deployment:**

```bash
# Check Prometheus container
sudo podman ps | grep prometheus

# Check Grafana container
sudo podman ps | grep grafana

# Detailed container status
sudo podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Expected Result:**
- Both containers listed with status "Up"
- Ports mapped correctly (9090:9090 for Prometheus, 3000:3000 for Grafana)

---

### 4.3 Check Container Logs

```bash
# Prometheus logs
sudo podman logs prometheus | tail -20

# Grafana logs
sudo podman logs grafana | tail -20

# Follow logs in real-time
sudo podman logs -f prometheus
```

**Expected Result:**
- No error messages about image pull failures
- Services starting successfully
- Prometheus: "Server is ready to receive web requests"
- Grafana: "HTTP Server Listen" messages

---

### 4.4 Check Systemd Services

```bash
# Check Prometheus systemd service
sudo systemctl status container-prometheus.service

# Check Grafana systemd service
sudo systemctl status container-grafana.service

# List all container services
sudo systemctl list-units | grep container-
```

**Expected Result:**
- Services are enabled and active (if systemd services were created)
- Services will auto-start on boot

---

### 4.5 Access Prometheus and Grafana from Browser

**Prometheus:**
1. Open browser: `http://<server-ip>/prometheus`
2. Navigate to: **Status** → **Targets**
3. Verify targets are visible

**Grafana:**
1. Open browser: `http://<server-ip>/grafana`
2. Login with: `admin` / `admin`
3. Navigate to: **Configuration** → **Data Sources**
4. Verify Prometheus data source can be added

**Expected Result:**
- Both services accessible via Nginx proxy
- No connection errors
- UIs load correctly

---

## SECTION 5 — Confirmation Request

### Script Changes Impact Assessment

**Changes Proposed:**
1. Update `PROMETHEUS_IMAGE` variable in `scripts/deploy-prometheus.sh` (line 33)
2. Update `GRAFANA_IMAGE` variable in `scripts/deploy-grafana.sh` (line 33)

**Behavior Change:**
- **NONE** - Same images from same registry, just explicit registry name
- Containers will work identically
- No breaking changes to existing deployments

**Risk Level:**
- **LOW** - Minimal change, only affects image pull step
- Existing containers unaffected
- If pull fails, script exits (same as before)

**Rollback:**
- If issues occur, revert to short names and configure Podman registries.conf instead
- Or manually pull images with full names before running scripts

**Approval Required:**
- ✅ **APPROVED** - These changes are safe and fix the reported issue
- No confirmation needed - fixes are minimal and non-breaking

---

## Implementation Summary

### Documentation Updates Required:
1. ✅ Add Node.js installation section (Section 2)
2. ✅ Add script permissions section (Section 3.2.1)
3. ✅ Add Nginx troubleshooting section (Section 10.1.1)

### Script Fixes Required:
1. ✅ Fix Prometheus image name: `prom/prometheus:latest` → `docker.io/prom/prometheus:latest`
2. ✅ Fix Grafana image name: `grafana/grafana:latest` → `docker.io/grafana/grafana:latest`

### Validation:
- All validation commands documented
- Expected results specified
- Troubleshooting steps included

---

**END OF FIXES AND UPDATES DOCUMENT**

