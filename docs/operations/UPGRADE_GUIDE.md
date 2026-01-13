# StackWatch Upgrade Guide

> **Document Version**: 1.0.0
> **Last Updated**: 2026-01-13
> **Status**: R&D / Planning Phase

This document provides comprehensive guidance for upgrading StackWatch and its bundled components (Prometheus, Grafana) with minimal disruption and data preservation.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Understanding](#architecture-understanding)
3. [Upgrade Strategy](#upgrade-strategy)
4. [Pre-Upgrade Checklist](#pre-upgrade-checklist)
5. [Prometheus Upgrade Guide](#prometheus-upgrade-guide)
6. [Grafana Upgrade Guide](#grafana-upgrade-guide)
7. [StackWatch Frontend Upgrade](#stackwatch-frontend-upgrade)
8. [Backup Procedures](#backup-procedures)
9. [Upgrade Procedures](#upgrade-procedures)
10. [Rollback Procedures](#rollback-procedures)
11. [Known Issues & Mitigations](#known-issues--mitigations)
12. [Version Compatibility Matrix](#version-compatibility-matrix)
13. [Troubleshooting](#troubleshooting)
14. [References](#references)

---

## Overview

### What is StackWatch?

StackWatch is a bundled observability solution consisting of:
- **Prometheus** - Metrics collection and alerting
- **Grafana** - Visualization and dashboards
- **StackWatch Frontend** - Unified web interface
- **Nginx** - Reverse proxy and routing

### Upgrade Philosophy

StackWatch follows a **Chrome-like update model**:
1. **Check** - Automatically check for updates (hourly)
2. **Notify** - Display update availability in the UI
3. **Download** - Background download (no user interruption)
4. **Apply** - User-initiated installation with brief restart
5. **Rollback** - Automatic rollback if health checks fail

### Update Types

| Type | Priority | Downtime | User Action |
|------|----------|----------|-------------|
| **Security** | Critical | Zero (blue-green) | Auto-apply after download |
| **Feature** | Normal | 2-5 minutes | Manual apply |
| **Maintenance** | Low | 2-5 minutes | Manual apply |

---

## Architecture Understanding

### Data Flow During Upgrade

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        STACKWATCH UPGRADE FLOW                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   BEFORE UPGRADE                    DURING UPGRADE                          │
│   ┌─────────────────┐               ┌─────────────────┐                     │
│   │   Prometheus    │               │   Prometheus    │                     │
│   │   Container     │               │   (stopped)     │                     │
│   │   ┌───────────┐ │               │                 │                     │
│   │   │   TSDB    │ │ ─── backup ──►│   TSDB intact   │                     │
│   │   │  (data)   │ │               │                 │                     │
│   │   └───────────┘ │               │                 │                     │
│   └─────────────────┘               └─────────────────┘                     │
│                                                                              │
│   ┌─────────────────┐               ┌─────────────────┐                     │
│   │    Grafana      │               │    Grafana      │                     │
│   │   Container     │               │   (stopped)     │                     │
│   │   ┌───────────┐ │               │                 │                     │
│   │   │ SQLite DB │ │ ─── backup ──►│   DB migrates   │                     │
│   │   │(dashboards│ │               │   on restart    │                     │
│   │   └───────────┘ │               │                 │                     │
│   └─────────────────┘               └─────────────────┘                     │
│                                                                              │
│   ┌─────────────────┐               ┌─────────────────┐                     │
│   │   Frontend      │               │   Frontend      │                     │
│   │   (static)      │ ─── replace ─►│   (new files)   │                     │
│   └─────────────────┘               └─────────────────┘                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Locations

| Component | Data Type | Location | Preserved? |
|-----------|-----------|----------|------------|
| Prometheus | TSDB (metrics) | `/prometheus/data` | Yes (snapshot) |
| Prometheus | WAL | `/prometheus/wal` | No (regenerates) |
| Prometheus | Config | `/etc/prometheus/prometheus.yml` | Yes (backup) |
| Prometheus | Rules | `/etc/prometheus/rules/` | Yes (backup) |
| Grafana | Database | `/var/lib/grafana/grafana.db` | Yes (backup + migration) |
| Grafana | Plugins | `/var/lib/grafana/plugins/` | Reinstall required |
| Grafana | Provisioning | `/etc/grafana/provisioning/` | Yes (backup) |
| Frontend | Config | `/opt/stackwatch/config/` | Yes (backup) |
| Frontend | User prefs | Browser localStorage | Yes (client-side) |

---

## Upgrade Strategy

### Recommended Approach

```
┌─────────────────────────────────────────────────────────────────┐
│                    UPGRADE DECISION TREE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Is this a SECURITY update?                                      │
│        │                                                         │
│        ├── YES ──► Blue-Green Deployment (Zero Downtime)        │
│        │           1. Start parallel instance                    │
│        │           2. Validate health                            │
│        │           3. Switch traffic                             │
│        │           4. Shutdown old instance                      │
│        │                                                         │
│        └── NO ──► Standard Upgrade (2-5 min downtime)           │
│                   1. Notify users                                │
│                   2. Create backup                               │
│                   3. Stop services                               │
│                   4. Apply update                                │
│                   5. Start services                              │
│                   6. Validate health                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Rollback Window

- **Duration**: 7 days
- **Previous version retained** for quick rollback
- **Automatic cleanup** after 7 days

---

## Pre-Upgrade Checklist

### System Requirements

```bash
# Check available disk space (need 3x current usage)
df -h /opt/stackwatch
df -h /var/lib/prometheus
df -h /var/lib/grafana

# Check current versions
cat /opt/stackwatch/metadata.json
podman exec prometheus prometheus --version
podman exec grafana grafana-cli --version
```

### Compatibility Checks

Before upgrading, verify:

- [ ] **Disk Space**: At least 3x current data size available
- [ ] **Prometheus Version Path**: Check if intermediate version needed
- [ ] **Grafana Plugins**: Verify plugin compatibility with target version
- [ ] **Alert Rules**: Export and validate all alerting rules
- [ ] **Dashboards**: Export critical dashboards as backup
- [ ] **Data Sources**: Document all configured data sources

### Pre-Upgrade Validation Script

```bash
#!/bin/bash
# pre-upgrade-check.sh

echo "=== StackWatch Pre-Upgrade Check ==="

# 1. Check disk space
REQUIRED_SPACE_GB=10
AVAILABLE_SPACE=$(df -BG /opt/stackwatch | tail -1 | awk '{print $4}' | tr -d 'G')

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE_GB" ]; then
    echo "ERROR: Insufficient disk space. Need ${REQUIRED_SPACE_GB}GB, have ${AVAILABLE_SPACE}GB"
    exit 1
fi
echo "✓ Disk space: ${AVAILABLE_SPACE}GB available"

# 2. Check services running
for service in prometheus grafana nginx; do
    if podman ps | grep -q $service; then
        echo "✓ $service is running"
    else
        echo "WARNING: $service is not running"
    fi
done

# 3. Check current versions
echo ""
echo "Current Versions:"
cat /opt/stackwatch/metadata.json 2>/dev/null || echo "No metadata.json found"

echo ""
echo "Pre-upgrade check complete"
```

---

## Prometheus Upgrade Guide

### Version Upgrade Paths

```
SAFE UPGRADE PATHS:

  v2.0 ─► v2.45 ─► v2.55 ─► v3.0
           │         │        │
           │         │        └── Latest features
           │         └── REQUIRED before v3.0 (for rollback)
           └── Standard v2.x upgrade

UNSAFE (DATA LOSS RISK):

  v2.45 ─────────────────────► v3.0  ❌ Skip v2.55
  v3.0  ────► v2.45                  ❌ Rollback too far
```

### Breaking Changes: Prometheus v2 → v3

| Change | Impact | Mitigation |
|--------|--------|------------|
| Label normalization (`le="1"` → `le="1.0"`) | Breaks queries/dashboards | Update all `le` and `quantile` queries |
| PromQL `.` matches newlines | Query behavior change | Use `[^\n]` for old behavior |
| Range selector boundaries | Complex query changes | Test queries before upgrade |
| Alertmanager API v1 removed | Alert integration fails | Upgrade Alertmanager to 0.16.0+ |
| Scrape ports not auto-added | Targets may fail | Explicitly specify ports in config |
| `scrape_classic_histograms` renamed | Config error | Rename to `always_scrape_classic_histograms` |

### Prometheus Upgrade Procedure

```bash
#!/bin/bash
# upgrade-prometheus.sh

CURRENT_VERSION=$(podman exec prometheus prometheus --version | head -1 | awk '{print $3}')
TARGET_VERSION="2.55.0"

echo "Upgrading Prometheus from $CURRENT_VERSION to $TARGET_VERSION"

# 1. Create TSDB snapshot
echo "Creating TSDB snapshot..."
podman exec prometheus promtool tsdb snapshot /prometheus/snapshots
SNAPSHOT_DIR=$(podman exec prometheus ls -t /prometheus/snapshots | head -1)
echo "Snapshot created: $SNAPSHOT_DIR"

# 2. Backup configuration
echo "Backing up configuration..."
cp /etc/prometheus/prometheus.yml /opt/stackwatch/backup/prometheus.yml.$(date +%Y%m%d)
cp -r /etc/prometheus/rules /opt/stackwatch/backup/rules.$(date +%Y%m%d)

# 3. Stop Prometheus
echo "Stopping Prometheus..."
systemctl stop stackwatch-prometheus

# 4. Pull new image
echo "Pulling new Prometheus image..."
podman pull prom/prometheus:v${TARGET_VERSION}

# 5. Update container
echo "Updating container..."
podman rm prometheus
podman run -d --name prometheus \
    -v /etc/prometheus:/etc/prometheus:ro \
    -v /var/lib/prometheus:/prometheus \
    prom/prometheus:v${TARGET_VERSION} \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/prometheus

# 6. Verify health
echo "Verifying health..."
sleep 10
if curl -s http://localhost:9090/-/healthy | grep -q "Healthy"; then
    echo "✓ Prometheus upgrade successful"
else
    echo "✗ Health check failed - initiating rollback"
    # Rollback procedure here
fi
```

### TSDB Compatibility Notes

| Prometheus Version | TSDB Readable By |
|--------------------|------------------|
| v3.x | v2.55+ only |
| v2.55 | v2.x and v3.x |
| v2.x (< 2.55) | v2.x only |

**Critical**: Always upgrade to v2.55 before v3.0 to maintain rollback capability.

---

## Grafana Upgrade Guide

### Version Upgrade Paths

```
SAFE UPGRADE PATHS:

  v10.x ─► v11.x ─► v12.x
             │        │
             │        └── Angular support REMOVED
             └── Angular OFF by default (can re-enable)

RISKY PATHS:

  v10.x ────────────────► v12.x  ⚠️ Skip v11 (Angular migration issues)
  v11.x ────► v10.x              ⚠️ Rollback may lose data
```

### Breaking Changes: Grafana v10 → v11 → v12

| Version | Change | Impact | Mitigation |
|---------|--------|--------|------------|
| v11.0 | AngularJS OFF by default | Angular plugins fail | Re-enable via config OR migrate plugins |
| v11.0 | Legacy alerting EOL | Grafana fails to start | Migrate to new alerting system |
| v12.0 | AngularJS REMOVED | No workaround | Must migrate all Angular plugins |
| v12.0 | Annotation table rewrite | 2-3x disk space needed | Ensure disk space before upgrade |

### Plugin Compatibility Check

```bash
#!/bin/bash
# check-grafana-plugins.sh

echo "=== Grafana Plugin Compatibility Check ==="

# List installed plugins
PLUGINS=$(podman exec grafana grafana-cli plugins ls)

echo "Installed plugins:"
echo "$PLUGINS"

# Check for Angular-based plugins (will fail in v12)
ANGULAR_PLUGINS=(
    "grafana-piechart-panel"
    "grafana-worldmap-panel"
    # Add known Angular plugins here
)

echo ""
echo "Checking for Angular plugins..."
for plugin in "${ANGULAR_PLUGINS[@]}"; do
    if echo "$PLUGINS" | grep -q "$plugin"; then
        echo "⚠️  WARNING: $plugin uses AngularJS - will not work in Grafana 12+"
    fi
done
```

### Grafana Upgrade Procedure

```bash
#!/bin/bash
# upgrade-grafana.sh

CURRENT_VERSION=$(podman exec grafana grafana-cli --version | awk '{print $2}')
TARGET_VERSION="11.2.0"

echo "Upgrading Grafana from $CURRENT_VERSION to $TARGET_VERSION"

# 1. Backup database
echo "Backing up Grafana database..."
podman exec grafana sqlite3 /var/lib/grafana/grafana.db ".backup '/tmp/grafana.db.backup'"
podman cp grafana:/tmp/grafana.db.backup /opt/stackwatch/backup/grafana.db.$(date +%Y%m%d)

# 2. Backup configuration
echo "Backing up configuration..."
cp /etc/grafana/grafana.ini /opt/stackwatch/backup/grafana.ini.$(date +%Y%m%d)
cp -r /etc/grafana/provisioning /opt/stackwatch/backup/provisioning.$(date +%Y%m%d)

# 3. Export dashboards (optional but recommended)
echo "Exporting dashboards..."
# Use Grafana API to export dashboards

# 4. Stop Grafana
echo "Stopping Grafana..."
systemctl stop stackwatch-grafana

# 5. Pull new image
echo "Pulling new Grafana image..."
podman pull grafana/grafana:${TARGET_VERSION}

# 6. Update container
echo "Updating container..."
podman rm grafana
podman run -d --name grafana \
    -v /etc/grafana:/etc/grafana:ro \
    -v /var/lib/grafana:/var/lib/grafana \
    grafana/grafana:${TARGET_VERSION}

# 7. Wait for database migration
echo "Waiting for database migration..."
sleep 30

# 8. Update plugins
echo "Updating plugins..."
podman exec grafana grafana-cli plugins update-all

# 9. Verify health
echo "Verifying health..."
if curl -s http://localhost:3000/api/health | grep -q "ok"; then
    echo "✓ Grafana upgrade successful"
else
    echo "✗ Health check failed - check logs"
    podman logs grafana --tail 50
fi
```

### Grafana v11 → v12 Special Considerations

The annotation table rewrite in v12 can cause issues:

```bash
# Check annotation table size
podman exec grafana sqlite3 /var/lib/grafana/grafana.db \
    "SELECT COUNT(*) as count,
     ROUND(SUM(LENGTH(text) + LENGTH(tags))/1024.0/1024.0, 2) as size_mb
     FROM annotation;"

# If large, consider cleaning old annotations first
podman exec grafana sqlite3 /var/lib/grafana/grafana.db \
    "DELETE FROM annotation WHERE created < strftime('%s', 'now', '-90 days') * 1000;"
```

---

## StackWatch Frontend Upgrade

### Frontend Upgrade Procedure

The frontend is the simplest component to upgrade:

```bash
#!/bin/bash
# upgrade-frontend.sh

BACKUP_DIR="/opt/stackwatch/backup/frontend.$(date +%Y%m%d)"
NEW_BUILD="/opt/stackwatch/staging/dist"
DEPLOY_DIR="/var/www/stackwatch"

# 1. Backup current frontend
echo "Backing up current frontend..."
cp -r $DEPLOY_DIR $BACKUP_DIR

# 2. Deploy new frontend
echo "Deploying new frontend..."
rm -rf $DEPLOY_DIR/*
cp -r $NEW_BUILD/* $DEPLOY_DIR/

# 3. Reload Nginx
echo "Reloading Nginx..."
nginx -t && nginx -s reload

echo "✓ Frontend upgrade complete"
```

---

## Backup Procedures

### Full Backup Script

```bash
#!/bin/bash
# backup-stackwatch.sh

BACKUP_ROOT="/opt/stackwatch/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

mkdir -p $BACKUP_DIR

echo "=== StackWatch Full Backup ==="
echo "Backup directory: $BACKUP_DIR"

# 1. Prometheus TSDB Snapshot
echo "1. Creating Prometheus snapshot..."
podman exec prometheus promtool tsdb snapshot /prometheus/snapshots
SNAPSHOT=$(podman exec prometheus ls -t /prometheus/snapshots | head -1)
podman cp prometheus:/prometheus/snapshots/$SNAPSHOT $BACKUP_DIR/prometheus-tsdb/

# 2. Prometheus Configuration
echo "2. Backing up Prometheus config..."
cp /etc/prometheus/prometheus.yml $BACKUP_DIR/
cp -r /etc/prometheus/rules $BACKUP_DIR/prometheus-rules/

# 3. Grafana Database
echo "3. Backing up Grafana database..."
podman exec grafana sqlite3 /var/lib/grafana/grafana.db ".backup '/tmp/grafana.db.backup'"
podman cp grafana:/tmp/grafana.db.backup $BACKUP_DIR/grafana.db

# 4. Grafana Configuration
echo "4. Backing up Grafana config..."
cp /etc/grafana/grafana.ini $BACKUP_DIR/
cp -r /etc/grafana/provisioning $BACKUP_DIR/grafana-provisioning/

# 5. StackWatch Configuration
echo "5. Backing up StackWatch config..."
cp /opt/stackwatch/metadata.json $BACKUP_DIR/
cp -r /opt/stackwatch/config $BACKUP_DIR/stackwatch-config/

# 6. Nginx Configuration
echo "6. Backing up Nginx config..."
cp /etc/nginx/conf.d/stackwatch.conf $BACKUP_DIR/

# 7. Create backup manifest
echo "7. Creating backup manifest..."
cat > $BACKUP_DIR/manifest.json << EOF
{
    "timestamp": "$TIMESTAMP",
    "components": {
        "prometheus": "$(podman exec prometheus prometheus --version 2>/dev/null | head -1)",
        "grafana": "$(podman exec grafana grafana-cli --version 2>/dev/null)",
        "stackwatch": "$(cat /opt/stackwatch/metadata.json 2>/dev/null | jq -r '.version')"
    },
    "files": [
        "prometheus-tsdb/",
        "prometheus.yml",
        "prometheus-rules/",
        "grafana.db",
        "grafana.ini",
        "grafana-provisioning/",
        "metadata.json",
        "stackwatch-config/",
        "stackwatch.conf"
    ]
}
EOF

# 8. Compress backup
echo "8. Compressing backup..."
tar -czf $BACKUP_DIR.tar.gz -C $BACKUP_ROOT $TIMESTAMP
rm -rf $BACKUP_DIR

echo ""
echo "✓ Backup complete: $BACKUP_DIR.tar.gz"
echo "  Size: $(du -h $BACKUP_DIR.tar.gz | cut -f1)"
```

### Backup Retention Policy

```bash
#!/bin/bash
# cleanup-old-backups.sh

BACKUP_DIR="/opt/stackwatch/backup"
RETENTION_DAYS=7

echo "Cleaning up backups older than $RETENTION_DAYS days..."

find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Remaining backups:"
ls -lh $BACKUP_DIR/*.tar.gz 2>/dev/null || echo "No backups found"
```

---

## Upgrade Procedures

### Complete Upgrade Script

```bash
#!/bin/bash
# upgrade-stackwatch.sh

set -e  # Exit on error

VERSION=$1
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.2.0"
    exit 1
fi

ARTIFACT_URL="https://artifact.stackwatch.io"
STAGING_DIR="/opt/stackwatch/staging"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "=== StackWatch Upgrade to v${VERSION} ==="
echo "Started at: $(date)"

# Phase 1: Pre-flight checks
echo ""
echo "Phase 1: Pre-flight checks..."
/opt/stackwatch/bin/pre-upgrade-check.sh
if [ $? -ne 0 ]; then
    echo "Pre-flight checks failed. Aborting."
    exit 1
fi

# Phase 2: Download and verify
echo ""
echo "Phase 2: Downloading update..."
mkdir -p $STAGING_DIR
wget -q "${ARTIFACT_URL}/stackwatch/build/latest/stackwatch-${VERSION}.tar.gz" -O $STAGING_DIR/update.tar.gz
wget -q "${ARTIFACT_URL}/stackwatch/build/latest/stackwatch-${VERSION}.tar.gz.sha256" -O $STAGING_DIR/update.sha256

echo "Verifying checksum..."
cd $STAGING_DIR
if ! sha256sum -c update.sha256; then
    echo "Checksum verification failed. Aborting."
    exit 1
fi

echo "Extracting..."
tar -xzf update.tar.gz

# Phase 3: Backup
echo ""
echo "Phase 3: Creating backup..."
/opt/stackwatch/bin/backup-stackwatch.sh

# Phase 4: Apply upgrade
echo ""
echo "Phase 4: Applying upgrade..."

# Stop services
echo "Stopping services..."
systemctl stop stackwatch-nginx
systemctl stop stackwatch-grafana
systemctl stop stackwatch-prometheus

# Apply updates (simplified - actual logic depends on what changed)
echo "Applying frontend update..."
cp -r $STAGING_DIR/dist/* /var/www/stackwatch/

echo "Updating metadata..."
cp $STAGING_DIR/metadata.json /opt/stackwatch/

# Start services
echo "Starting services..."
systemctl start stackwatch-prometheus
sleep 5
systemctl start stackwatch-grafana
sleep 5
systemctl start stackwatch-nginx

# Phase 5: Verify
echo ""
echo "Phase 5: Verifying upgrade..."
sleep 10
/opt/stackwatch/bin/health-check.sh
if [ $? -ne 0 ]; then
    echo "Health check failed. Initiating rollback..."
    /opt/stackwatch/bin/rollback.sh $TIMESTAMP
    exit 1
fi

# Cleanup
echo ""
echo "Cleaning up..."
rm -rf $STAGING_DIR/*

echo ""
echo "=== Upgrade Complete ==="
echo "StackWatch is now running version ${VERSION}"
echo "Completed at: $(date)"
```

---

## Rollback Procedures

### Manual Rollback Script

```bash
#!/bin/bash
# rollback.sh

BACKUP_TIMESTAMP=$1
if [ -z "$BACKUP_TIMESTAMP" ]; then
    echo "Usage: $0 <backup_timestamp>"
    echo "Available backups:"
    ls /opt/stackwatch/backup/*.tar.gz 2>/dev/null | sed 's/.*\//  /' | sed 's/.tar.gz//'
    exit 1
fi

BACKUP_FILE="/opt/stackwatch/backup/${BACKUP_TIMESTAMP}.tar.gz"
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup not found: $BACKUP_FILE"
    exit 1
fi

echo "=== StackWatch Rollback ==="
echo "Restoring from: $BACKUP_TIMESTAMP"

# Warning
echo ""
echo "⚠️  WARNING: This will:"
echo "   - Stop all StackWatch services"
echo "   - Restore previous version"
echo "   - Any data collected after ${BACKUP_TIMESTAMP} will be LOST"
echo ""
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Rollback cancelled."
    exit 0
fi

# Extract backup
echo ""
echo "Extracting backup..."
RESTORE_DIR="/opt/stackwatch/restore_${BACKUP_TIMESTAMP}"
mkdir -p $RESTORE_DIR
tar -xzf $BACKUP_FILE -C $RESTORE_DIR

# Stop services
echo "Stopping services..."
systemctl stop stackwatch-nginx
systemctl stop stackwatch-grafana
systemctl stop stackwatch-prometheus

# Restore Prometheus
echo "Restoring Prometheus..."
# Note: TSDB restoration is complex - this is simplified
cp $RESTORE_DIR/$BACKUP_TIMESTAMP/prometheus.yml /etc/prometheus/
cp -r $RESTORE_DIR/$BACKUP_TIMESTAMP/prometheus-rules/* /etc/prometheus/rules/

# Restore Grafana
echo "Restoring Grafana..."
podman cp $RESTORE_DIR/$BACKUP_TIMESTAMP/grafana.db grafana:/var/lib/grafana/grafana.db
cp $RESTORE_DIR/$BACKUP_TIMESTAMP/grafana.ini /etc/grafana/

# Restore StackWatch
echo "Restoring StackWatch config..."
cp $RESTORE_DIR/$BACKUP_TIMESTAMP/metadata.json /opt/stackwatch/
# Note: Frontend files should be from previous build

# Start services
echo "Starting services..."
systemctl start stackwatch-prometheus
sleep 5
systemctl start stackwatch-grafana
sleep 5
systemctl start stackwatch-nginx

# Verify
echo "Verifying rollback..."
sleep 10
/opt/stackwatch/bin/health-check.sh

# Cleanup
rm -rf $RESTORE_DIR

echo ""
echo "=== Rollback Complete ==="
```

### Automatic Rollback Trigger

The health check script should trigger automatic rollback on failure:

```bash
#!/bin/bash
# health-check.sh

RETRY_COUNT=3
RETRY_DELAY=5

check_prometheus() {
    curl -sf http://localhost:9090/-/healthy > /dev/null
}

check_grafana() {
    curl -sf http://localhost:3000/api/health | grep -q "ok"
}

check_nginx() {
    curl -sf http://localhost/health > /dev/null
}

echo "Running health checks..."

for service in prometheus grafana nginx; do
    for i in $(seq 1 $RETRY_COUNT); do
        if check_$service; then
            echo "✓ $service is healthy"
            break
        else
            echo "⚠️  $service check failed (attempt $i/$RETRY_COUNT)"
            if [ $i -eq $RETRY_COUNT ]; then
                echo "✗ $service is unhealthy"
                exit 1
            fi
            sleep $RETRY_DELAY
        fi
    done
done

echo ""
echo "All health checks passed"
exit 0
```

---

## Known Issues & Mitigations

### Issue 1: Prometheus Label Normalization (v3)

**Problem**: Float labels like `le="1"` become `le="1.0"`, breaking queries and dashboards.

**Detection**:
```bash
# Find affected queries in Grafana
podman exec grafana sqlite3 /var/lib/grafana/grafana.db \
    "SELECT title, data FROM dashboard WHERE data LIKE '%le=%';"
```

**Mitigation**:
- Update all dashboard queries before upgrade
- Use `float64` comparison instead of string matching
- Example fix: `le="1"` → `le=~"1(\\.0)?"`

---

### Issue 2: Grafana Annotation Table (v11→v12)

**Problem**: Full table rewrite needs 2-3x disk space, can take hours.

**Detection**:
```bash
# Check annotation table size
podman exec grafana sqlite3 /var/lib/grafana/grafana.db \
    "SELECT COUNT(*) FROM annotation;"
```

**Mitigation**:
- Ensure 3x disk space available
- Clean old annotations (> 90 days) before upgrade
- Schedule during maintenance window

---

### Issue 3: Angular Plugin Removal (Grafana v12)

**Problem**: All AngularJS-based plugins completely stop working.

**Detection**:
```bash
# Check for Angular plugins
podman exec grafana grafana-cli plugins ls 2>&1 | grep -i angular
```

**Mitigation**:
- Migrate to React-based alternatives before upgrade
- No workaround in v12 (can't re-enable Angular)
- Test in v11 first with Angular disabled

---

### Issue 4: Prometheus WAL Incompatibility

**Problem**: Native histogram WAL format changed in v2.42+.

**Detection**:
```bash
# Check if native histograms enabled
grep "native_histograms" /etc/prometheus/prometheus.yml
```

**Mitigation**:
- Remove WAL directory before upgrade: `rm -rf /prometheus/wal/*`
- Accept data loss for last ~2 hours of native histogram data

---

### Issue 5: Alertmanager API Version

**Problem**: Prometheus v3 requires Alertmanager 0.16.0+ with API v2.

**Detection**:
```bash
# Check Alertmanager version
podman exec alertmanager alertmanager --version
```

**Mitigation**:
- Upgrade Alertmanager to 0.16.0+ before Prometheus v3
- Update config: `api_version: v2` in prometheus.yml

---

## Version Compatibility Matrix

### StackWatch Component Versions

| StackWatch | Prometheus | Grafana | Alertmanager | Node Exporter |
|------------|------------|---------|--------------|---------------|
| 1.0.x | 2.45 - 2.53 | 10.0 - 10.4 | 0.25 - 0.27 | 1.6 - 1.7 |
| 1.1.x | 2.50 - 2.55 | 10.4 - 11.2 | 0.26 - 0.27 | 1.7 - 1.8 |
| 1.2.x | 2.53 - 3.0 | 11.0 - 11.4 | 0.27+ | 1.8+ |
| 2.0.x (planned) | 3.0+ | 12.0+ | 0.27+ | 1.8+ |

### Upgrade Path Summary

```
StackWatch 1.0.x ──► 1.1.x ──► 1.2.x ──► 2.0.x (planned)
                      │          │
                      │          └── Prometheus 3.0 support
                      └── Grafana 11 (Angular deprecated)
```

---

## Troubleshooting

### Common Issues

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| Prometheus won't start after upgrade | TSDB version mismatch | Check upgrade path; may need v2.55 first |
| Grafana dashboards empty | Plugin incompatibility | Update/replace plugins |
| Queries return no data | Label normalization | Update `le`/`quantile` queries |
| High disk usage after Grafana upgrade | Annotation migration | Run VACUUM after upgrade completes |
| Alerts not firing | Alertmanager API version | Upgrade Alertmanager; set api_version: v2 |

### Log Locations

```bash
# Prometheus logs
podman logs prometheus
journalctl -u stackwatch-prometheus

# Grafana logs
podman logs grafana
journalctl -u stackwatch-grafana

# Nginx logs
tail -f /var/log/nginx/error.log
journalctl -u stackwatch-nginx
```

### Support

For upgrade issues:
1. Check this guide for known issues
2. Review component logs
3. Consult official documentation (see References)
4. Create backup and attempt rollback if critical

---

## References

### Official Documentation

- **Prometheus Migration Guide**: https://prometheus.io/docs/prometheus/latest/migration/
- **Prometheus 3.0 Announcement**: https://prometheus.io/blog/2024/11/14/prometheus-3-0/
- **Grafana Upgrade Guide**: https://grafana.com/docs/grafana/latest/upgrade-guide/
- **Grafana Breaking Changes**: https://grafana.com/docs/grafana/latest/breaking-changes/

### Additional Resources

- **Prometheus CHANGELOG**: https://github.com/prometheus/prometheus/blob/main/CHANGELOG.md
- **Grafana AngularJS Removal**: https://grafana.com/blog/2024/03/11/removal-of-angularjs-support-in-grafana-what-you-need-to-know/
- **Podman Auto-Updates**: https://www.redhat.com/en/blog/podman-auto-updates-rollbacks

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2026-01-13 | Claude | Initial R&D document |

---

*This document is part of the StackWatch project. For the latest version, check the repository.*
