#!/bin/bash
# STACKWATCH: Grafana Backup Script
# Backend System Architect and Automation Engineer
#
# Purpose: Create backup of Grafana SQLite database and configuration
# Schedule: Daily at 3:00 AM via cron
# Retention: 7 days (configurable via stackwatch.json)
#
# Usage: ./backup-grafana.sh
# Requirements: Grafana container must be running

set -e

# =============================================================================
# CONFIGURATION
# =============================================================================

# Try to load from stackwatch.json if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/stackwatch.json"

if [[ -f "$CONFIG_FILE" ]] && command -v jq &> /dev/null; then
    BACKUP_DIR=$(jq -r '.paths.backup_dir' "$CONFIG_FILE")/grafana
    RETENTION_DAYS=$(jq -r '.retention.backup_days' "$CONFIG_FILE")
    GRAFANA_CONFIG_DIR=$(jq -r '.paths.grafana_config' "$CONFIG_FILE")
else
    # Fallback defaults
    BACKUP_DIR="/opt/stackwatch/backup/grafana"
    RETENTION_DAYS=7
    GRAFANA_CONFIG_DIR="/etc/grafana"
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

check_grafana_running() {
    if ! podman ps --format '{{.Names}}' | grep -q '^grafana$'; then
        log_error "Grafana container is not running"
        exit 1
    fi
}

backup_sqlite_database() {
    local DB_BACKUP_FILE="${BACKUP_DIR}/grafana.db.${DATE}"

    log_info "Backing up Grafana SQLite database..."

    # Use sqlite3 inside container to create a consistent backup
    # This ensures the database is not corrupted during backup
    podman exec grafana sqlite3 /var/lib/grafana/grafana.db ".backup '/tmp/grafana.db.bak'"

    if [[ $? -ne 0 ]]; then
        log_warn "sqlite3 backup command failed, trying direct copy..."
        # Fallback: direct copy (less safe but works if sqlite3 not available)
        podman cp grafana:/var/lib/grafana/grafana.db "$DB_BACKUP_FILE"
    else
        # Copy the backup file out of the container
        podman cp grafana:/tmp/grafana.db.bak "$DB_BACKUP_FILE"

        # Cleanup temp file in container
        podman exec grafana rm -f /tmp/grafana.db.bak
    fi

    if [[ -f "$DB_BACKUP_FILE" ]]; then
        local SIZE=$(du -h "$DB_BACKUP_FILE" | cut -f1)
        log_info "Database backed up: $DB_BACKUP_FILE ($SIZE)"
    else
        log_error "Database backup failed"
        return 1
    fi
}

backup_config() {
    local CONFIG_BACKUP_DIR="${BACKUP_DIR}/config-${DATE}"

    log_info "Backing up Grafana configuration..."

    if [[ -d "$GRAFANA_CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_BACKUP_DIR"
        cp -r "$GRAFANA_CONFIG_DIR"/* "$CONFIG_BACKUP_DIR/"
        log_info "Configuration backed up to: $CONFIG_BACKUP_DIR"
    else
        log_warn "Configuration directory not found: $GRAFANA_CONFIG_DIR"
    fi
}

backup_provisioning() {
    local PROV_BACKUP_DIR="${BACKUP_DIR}/provisioning-${DATE}"

    log_info "Backing up Grafana provisioning..."

    # Copy provisioning from container (dashboards, datasources, etc.)
    podman cp grafana:/etc/grafana/provisioning "$PROV_BACKUP_DIR" 2>/dev/null || true

    if [[ -d "$PROV_BACKUP_DIR" ]]; then
        log_info "Provisioning backed up to: $PROV_BACKUP_DIR"
    else
        log_warn "No provisioning data found in container"
    fi
}

cleanup_old_backups() {
    log_info "Cleaning up backups older than $RETENTION_DAYS days..."

    # Remove old database backups
    find "$BACKUP_DIR" -maxdepth 1 -type f -name "grafana.db.*" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true

    # Remove old config backups
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "config-*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true

    # Remove old provisioning backups
    find "$BACKUP_DIR" -maxdepth 1 -type d -name "provisioning-*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true

    log_info "Cleanup complete"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    log_info "=========================================="
    log_info "Starting Grafana Backup"
    log_info "=========================================="
    log_info "Backup directory: $BACKUP_DIR"
    log_info "Retention: $RETENTION_DAYS days"

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Check Grafana is running
    check_grafana_running

    # Backup SQLite database
    backup_sqlite_database

    # Backup configuration
    backup_config

    # Backup provisioning (dashboards, datasources)
    backup_provisioning

    # Cleanup old backups
    cleanup_old_backups

    log_info "=========================================="
    log_info "Grafana Backup Complete"
    log_info "Database: ${BACKUP_DIR}/grafana.db.${DATE}"
    log_info "Config: ${BACKUP_DIR}/config-${DATE}"
    log_info "=========================================="
}

# Run main function
main "$@"
