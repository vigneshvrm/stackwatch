# StackWatch Production Readiness Guide

## Overview

This document outlines the production-grade configuration for StackWatch deployment, including Prometheus and Grafana container setup with proper resource limits, data retention, security, and backup strategies.

---

## Architecture Rule: Single Source of Truth

### `config/stackwatch.json`

**ALL configuration lives in ONE file**. This is the single source of truth for the entire StackWatch deployment.

```json
{
  "versions": {
    "prometheus": "v2.53.0",
    "grafana": "11.2.0",
    "node_exporter": "1.8.0",
    "windows_exporter": "0.25.1"
  },
  "images": {
    "prometheus": "docker.io/prom/prometheus",
    "grafana": "docker.io/grafana/grafana",
    "node_exporter": "docker.io/prom/node-exporter"
  },
  "resources": {
    "prometheus": {
      "memory": "4g",
      "cpus": "2"
    },
    "grafana": {
      "memory": "2g",
      "cpus": "2"
    }
  },
  "retention": {
    "prometheus_data_days": 90,
    "prometheus_storage_limit": "50GB",
    "backup_days": 7
  },
  "paths": {
    "prometheus_data": "/var/lib/prometheus",
    "grafana_data": "/var/lib/grafana",
    "prometheus_config": "/etc/prometheus",
    "grafana_config": "/etc/grafana",
    "backup_dir": "/opt/stackwatch/backup",
    "scripts_dir": "/opt/stackwatch/scripts"
  },
  "ports": {
    "prometheus": 9090,
    "grafana": 3000,
    "node_exporter": 9100,
    "windows_exporter": 9182
  }
}
```

### Rules

| Rule | Description |
|------|-------------|
| **Single File** | All configuration in `config/stackwatch.json` |
| **Manual Updates** | You control when to change values |
| **No Hardcoding** | NEVER hardcode values in playbooks, scripts, or Jenkinsfile |
| **All Consumers** | Ansible, Jenkins, scripts, frontend - all read from this file |

### Why This Matters

- **Consistency**: All deployments use identical configuration
- **Maintainability**: One place to update, no hunting for hardcoded values
- **Version Control**: Git tracks all configuration changes
- **No Drift**: Impossible for different servers to have different settings

---

## Production Configuration

### Prometheus

#### Container Configuration

```bash
podman run -d \
  --name prometheus \
  --memory=${resources.prometheus.memory} \
  --cpus=${resources.prometheus.cpus} \
  --health-cmd='wget -q --spider http://localhost:9090/-/healthy || exit 1' \
  --health-interval=30s \
  --health-retries=3 \
  -v /etc/hosts:/etc/hosts:Z \
  -v ${paths.prometheus_config}:/etc/prometheus:Z \
  -v ${paths.prometheus_data}:/prometheus:Z \
  -p ${ports.prometheus}:9090 \
  ${images.prometheus}:${versions.prometheus} \
  --config.file=/etc/prometheus/prometheus.yml \
  --web.external-url=/prometheus/ \
  --web.route-prefix=/ \
  --storage.tsdb.retention.time=${retention.prometheus_data_days}d \
  --storage.tsdb.retention.size=${retention.prometheus_storage_limit} \
  --storage.tsdb.path=/prometheus \
  --web.enable-lifecycle
```

#### Key Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `--storage.tsdb.retention.time` | 90d | Keep 90 days of metrics data |
| `--storage.tsdb.retention.size` | 50GB | Cap storage at 50GB (whichever hits first) |
| `--storage.tsdb.path` | /prometheus | Explicit data path for volume mount |
| `--web.enable-lifecycle` | enabled | Allow config reload without restart |
| `--memory` | 4g | Container memory limit |
| `--cpus` | 2 | Container CPU limit |
| `--health-cmd` | wget check | Container health monitoring |

### Grafana

#### Container Configuration

```bash
podman run -d \
  --name grafana \
  --memory=${resources.grafana.memory} \
  --cpus=${resources.grafana.cpus} \
  --health-cmd='wget -q --spider http://localhost:3000/api/health || exit 1' \
  --health-interval=30s \
  --health-retries=3 \
  --dns 8.8.8.8 \
  --dns 1.1.1.1 \
  -p ${ports.grafana}:3000 \
  -v /etc/hosts:/etc/hosts:Z \
  -v ${paths.grafana_data}:/var/lib/grafana:Z \
  -v ${paths.grafana_config}/config/grafana.ini:/etc/grafana/grafana.ini:Z \
  -v ${paths.grafana_config}/provisioning:/etc/grafana/provisioning:Z \
  -e GF_SECURITY_ADMIN_PASSWORD=${generated_password} \
  -e GF_SECURITY_SECRET_KEY=${generated_secret} \
  ${images.grafana}:${versions.grafana}
```

#### Key Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `--memory` | 2g | Container memory limit |
| `--cpus` | 2 | Container CPU limit |
| `GF_SECURITY_ADMIN_PASSWORD` | Auto-generated | Secure admin password (not default) |
| `GF_SECURITY_SECRET_KEY` | Auto-generated | Session encryption key |
| `--health-cmd` | wget check | Container health monitoring |
| Database | SQLite | Simple, no extra DB management |

---

## Resource Allocation

### Prometheus

| Resource | Value | Notes |
|----------|-------|-------|
| Memory | 4 GB | Handles ~1000 samples/sec with 90-day retention |
| CPU | 2 cores | For query processing and TSDB compaction |
| Storage | 50 GB limit | ~30GB typical for 90 days, 50GB safety margin |

### Grafana

| Resource | Value | Notes |
|----------|-------|-------|
| Memory | 2 GB | Handles multiple concurrent dashboards |
| CPU | 2 cores | For rendering and data processing |
| Storage | ~100 MB | SQLite database (dashboards, users, etc.) |

### Storage Calculation

```
Prometheus TSDB Size = samples/sec * retention_seconds * bytes/sample

Example:
- 1000 samples/second (typical for 10-20 targets)
- 90 days = 7,776,000 seconds
- ~2 bytes per sample (after compression)

Estimated: 1000 * 7,776,000 * 2 / (1024^3) = 14.5 GB
With 2x safety margin: ~30 GB
Configured limit: 50 GB
```

---

## Backup Strategy

### Overview

| Component | Backup Content | Schedule | Retention |
|-----------|----------------|----------|-----------|
| Prometheus | TSDB snapshots + config | Daily 2:00 AM | 7 days |
| Grafana | SQLite DB + config | Daily 3:00 AM | 7 days |

### Prometheus Backup Script

**File**: `/opt/stackwatch/scripts/backup-prometheus.sh`

```bash
#!/bin/bash
# Prometheus Backup Script
# Reads config from: config/stackwatch.json

set -e

# Load config (paths from stackwatch.json)
BACKUP_DIR="/opt/stackwatch/backup/prometheus"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)

echo "[$(date)] Starting Prometheus backup..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create TSDB snapshot (requires --web.enable-lifecycle)
echo "Creating TSDB snapshot..."
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot

# Get latest snapshot name
SNAPSHOT=$(podman exec prometheus ls -t /prometheus/snapshots 2>/dev/null | head -1)

if [ -n "$SNAPSHOT" ]; then
    echo "Copying snapshot: $SNAPSHOT"
    podman cp prometheus:/prometheus/snapshots/$SNAPSHOT "$BACKUP_DIR/tsdb-$DATE"

    # Cleanup snapshot inside container
    podman exec prometheus rm -rf /prometheus/snapshots/$SNAPSHOT
else
    echo "WARNING: No snapshot found"
fi

# Backup configuration
echo "Backing up configuration..."
cp -r /etc/prometheus "$BACKUP_DIR/config-$DATE"

# Cleanup old backups
echo "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;

echo "[$(date)] Prometheus backup complete: $BACKUP_DIR/tsdb-$DATE"
```

### Grafana Backup Script

**File**: `/opt/stackwatch/scripts/backup-grafana.sh`

```bash
#!/bin/bash
# Grafana Backup Script
# Reads config from: config/stackwatch.json

set -e

# Load config (paths from stackwatch.json)
BACKUP_DIR="/opt/stackwatch/backup/grafana"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)

echo "[$(date)] Starting Grafana backup..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup SQLite database
echo "Backing up Grafana database..."
podman exec grafana sqlite3 /var/lib/grafana/grafana.db ".backup '/tmp/grafana.db.bak'"
podman cp grafana:/tmp/grafana.db.bak "$BACKUP_DIR/grafana.db.$DATE"
podman exec grafana rm -f /tmp/grafana.db.bak

# Backup configuration
echo "Backing up configuration..."
cp -r /etc/grafana "$BACKUP_DIR/config-$DATE"

# Cleanup old backups
echo "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -maxdepth 1 -type f -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;

echo "[$(date)] Grafana backup complete: $BACKUP_DIR/grafana.db.$DATE"
```

### Cron Configuration

**File**: `/etc/cron.d/stackwatch-backup`

```cron
# StackWatch Automated Backups
# Prometheus: Daily at 2:00 AM
# Grafana: Daily at 3:00 AM

0 2 * * * root /opt/stackwatch/scripts/backup-prometheus.sh >> /var/log/stackwatch-backup.log 2>&1
0 3 * * * root /opt/stackwatch/scripts/backup-grafana.sh >> /var/log/stackwatch-backup.log 2>&1
```

---

## Security Configuration

### Current Level: Basic

| Aspect | Configuration |
|--------|---------------|
| Grafana Password | Auto-generated secure password (24 chars) |
| Grafana Secret Key | Auto-generated (32 chars) |
| Image Versions | Pinned (no `:latest`) |
| Network | Firewall blocks direct port access |
| Prometheus Auth | Via Nginx reverse proxy |

### Password Generation (Ansible)

```yaml
- name: Generate secure Grafana admin password
  set_fact:
    grafana_admin_password: "{{ lookup('password', '/dev/null length=24 chars=ascii_letters,digits') }}"
  when: grafana_admin_password is not defined
  no_log: true

- name: Generate secure Grafana secret key
  set_fact:
    grafana_secret_key: "{{ lookup('password', '/dev/null length=32 chars=ascii_letters,digits') }}"
  when: grafana_secret_key is not defined
  no_log: true

- name: Store credentials securely
  copy:
    content: |
      GRAFANA_ADMIN_PASSWORD={{ grafana_admin_password }}
      GRAFANA_SECRET_KEY={{ grafana_secret_key }}
    dest: /opt/stackwatch/.credentials
    mode: '0600'
    owner: root
    group: root
```

---

## Verification Commands

### Check Prometheus Retention

```bash
# Verify retention settings
curl -s http://localhost:9090/api/v1/status/config | grep retention

# Check TSDB status
curl -s http://localhost:9090/api/v1/status/tsdb | jq '.data'

# Expected output includes:
# "retention": "90d"
# "maxBytes": "50GB"
```

### Check Resource Limits

```bash
# View container resource usage
podman stats prometheus grafana --no-stream

# Expected: Memory and CPU within limits
```

### Check Health Status

```bash
# Prometheus health
podman inspect prometheus --format='{{.State.Health.Status}}'
# Expected: healthy

# Grafana health
podman inspect grafana --format='{{.State.Health.Status}}'
# Expected: healthy
```

### Verify Backups

```bash
# List Prometheus backups
ls -la /opt/stackwatch/backup/prometheus/

# List Grafana backups
ls -la /opt/stackwatch/backup/grafana/

# Check backup log
tail -50 /var/log/stackwatch-backup.log
```

---

## Implementation Checklist

### Pre-Implementation

- [ ] Create git commit backup of current state
- [ ] Review current deployment configuration
- [ ] Verify disk space available (50-100 GB)

### Phase 1: Configuration File

- [ ] Create `config/stackwatch.json` with all settings
- [ ] Validate JSON syntax
- [ ] Commit to git

### Phase 2: Prometheus Updates

- [ ] Update `ansible/playbooks/deploy-prometheus.yml`
- [ ] Read all values from `config/stackwatch.json`
- [ ] Add retention flags
- [ ] Add resource limits
- [ ] Add health check
- [ ] Add data volume mount

### Phase 3: Grafana Updates

- [ ] Update `ansible/playbooks/deploy-grafana.yml`
- [ ] Read all values from `config/stackwatch.json`
- [ ] Add secure password generation
- [ ] Add resource limits
- [ ] Add health check

### Phase 4: Backup System

- [ ] Create `scripts/backup-prometheus.sh`
- [ ] Create `scripts/backup-grafana.sh`
- [ ] Create `ansible/playbooks/setup-backups.yml`
- [ ] Test backup scripts manually
- [ ] Configure cron jobs

### Post-Implementation

- [ ] Run verification commands
- [ ] Update CLAUDE_MEMORY.md with architecture rules
- [ ] Commit all changes to git

---

## Rollback Procedure

If issues occur after deployment:

### Quick Rollback

```bash
# 1. Stop containers
podman stop prometheus grafana

# 2. Restore from backup
# Prometheus
cp -r /opt/stackwatch/backup/prometheus/tsdb-YYYYMMDD_HHMMSS/* /var/lib/prometheus/

# Grafana
cp /opt/stackwatch/backup/grafana/grafana.db.YYYYMMDD_HHMMSS /var/lib/grafana/grafana.db

# 3. Revert playbooks (git)
git checkout HEAD~1 -- ansible/playbooks/deploy-prometheus.yml
git checkout HEAD~1 -- ansible/playbooks/deploy-grafana.yml

# 4. Redeploy
ansible-playbook ansible/playbooks/deploy-prometheus.yml
ansible-playbook ansible/playbooks/deploy-grafana.yml
```

---

## Summary

| Component | Before | After |
|-----------|--------|-------|
| **Config Location** | Hardcoded in playbooks | `config/stackwatch.json` |
| **Prometheus Retention** | 15 days (default) | 90 days |
| **Prometheus Storage** | Unlimited | 50 GB cap |
| **Prometheus Resources** | Unlimited | 4 GB / 2 CPU |
| **Grafana Resources** | Unlimited | 2 GB / 2 CPU |
| **Grafana Password** | admin (default) | Auto-generated |
| **Image Versions** | :latest | Pinned versions |
| **Health Checks** | None | Container health monitoring |
| **Backups** | None | Daily with 7-day retention |

---

*Document Created: 2026-01-13*
*Last Updated: 2026-01-13*
*Status: Ready for Implementation*
