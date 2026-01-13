#!/bin/bash
# STACKWATCH: Prometheus Backup Script
# Backend System Architect and Automation Engineer
#
# Purpose: Create backup of Prometheus TSDB data and configuration
# Schedule: Daily at 2:00 AM via cron
# Retention: 7 days (configurable via stackwatch.json)
#
# Usage: ./backup-prometheus.sh
# Requirements: Prometheus must be running with --web.enable-lifecycle

set -e

# =============================================================================
# CONFIGURATION
# =============================================================================

# Try to load from stackwatch.json if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/stackwatch.json"

if [[ -f "$CONFIG_FILE" ]] && command -v jq &> /dev/null; then
    BACKUP_DIR=$(jq -r '.paths.backup_dir' "$CONFIG_FILE")/prometheus
    RETENTION_DAYS=$(jq -r '.retention.backup_days' "$CONFIG_FILE")
    PROMETHEUS_CONFIG_DIR=$(jq -r '.paths.prometheus_config' "$CONFIG_FILE")
else
    # Fallback defaults
    BACKUP_DIR="/opt/stackwatch/backup/prometheus"
    RETENTION_DAYS=7
    PROMETHEUS_CONFIG_DIR="/etc/prometheus"
fi

DATE=$(date +%Y%m%d_%H%M%S)
LOG_PREFIX="[$(date '+%Y-%m-%d %H:%M:%S')]"

# =============================================================================
# FUNCTIONS
# =============================================================================

log_info() {
    echo "${LOG_PREFIX} [INFO] $1"
}

log_warn() {
    echo "${LOG_PREFIX} [WARN] $1" >&2
}

log_error() {
    echo "${LOG_PREFIX} [ERROR] $1" >&2
}

check_prometheus_running() {
    if ! podman ps --format '{{.Names}}' | grep -q '^prometheus$'; then
        log_error "Prometheus container is not running"
        exit 1
    fi
}

create_tsdb_snapshot() {
    log_info "Creating TSDB snapshot..."

    # Trigger snapshot via API (requires --web.enable-lifecycle)
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)

    if [[ "$HTTP_CODE" != "200" ]]; then
        log_error "Failed to create TSDB snapshot. HTTP code: $HTTP_CODE"
        log_error "Response: $BODY"
        log_warn "Make sure Prometheus is started with --web.enable-lifecycle flag"
        return 1
    fi

    # Extract snapshot name from response
    SNAPSHOT_NAME=$(echo "$BODY" | jq -r '.data.name' 2>/dev/null)
    if [[ -z "$SNAPSHOT_NAME" || "$SNAPSHOT_NAME" == "null" ]]; then
        log_error "Could not parse snapshot name from response"
        return 1
    fi

    log_info "Snapshot created: $SNAPSHOT_NAME"
    echo "$SNAPSHOT_NAME"
}

copy_snapshot() {
    local SNAPSHOT_NAME=$1
    local DEST_DIR="${BACKUP_DIR}/tsdb-${DATE}"

    log_info "Copying snapshot to: $DEST_DIR"

    mkdir -p "$DEST_DIR"
    podman cp "prometheus:/prometheus/snapshots/${SNAPSHOT_NAME}" "$DEST_DIR/"

    if [[ $? -eq 0 ]]; then
        log_info "Snapshot copied successfully"

        # Cleanup snapshot inside container
        log_info "Cleaning up snapshot inside container..."
        podman exec prometheus rm -rf "/prometheus/snapshots/${SNAPSHOT_NAME}"
    else
        log_error "Failed to copy snapshot"
        return 1
    fi
}

backup_config() {
    local CONFIG_BACKUP_DIR="${BACKUP_DIR}/config-${DATE}"

    log_info "Backing up Prometheus configuration..."

    if [[ -d "$PROMETHEUS_CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_BACKUP_DIR"
        cp -r "$PROMETHEUS_CONFIG_DIR"/* "$CONFIG_BACKUP_DIR/"
        log_info "Configuration backed up to: $CONFIG_BACKUP_DIR"
    else
        log_warn "Configuration directory not found: $PROMETHEUS_CONFIG_DIR"
    fi
}

cleanup_old_backups() {
    log_info "Cleaning up backups older than $RETENTION_DAYS days..."

    # Remove old TSDB backups
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "tsdb-*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true

    # Remove old config backups
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "config-*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true

    log_info "Cleanup complete"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_info "=========================================="
    log_info "Starting Prometheus Backup"
    log_info "=========================================="
    log_info "Backup directory: $BACKUP_DIR"
    log_info "Retention: $RETENTION_DAYS days"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Check Prometheus is running
    check_prometheus_running

    # Create TSDB snapshot
    SNAPSHOT_NAME=$(create_tsdb_snapshot)
    if [[ $? -ne 0 || -z "$SNAPSHOT_NAME" ]]; then
        log_error "Failed to create snapshot"
        exit 1
    fi

    # Copy snapshot to backup location
    copy_snapshot "$SNAPSHOT_NAME"

    # Backup configuration
    backup_config

    # Cleanup old backups
    cleanup_old_backups

    log_info "=========================================="
    log_info "Prometheus Backup Complete"
    log_info "TSDB: ${BACKUP_DIR}/tsdb-${DATE}"
    log_info "Config: ${BACKUP_DIR}/config-${DATE}"
    log_info "=========================================="
}

# Run main function
main "$@"
