#!/bin/bash
#
# STACKWATCH: Prometheus Deployment Script (Podman)
# Backend System Architect and Automation Engineer
#
# CRITICAL RULES:
# - Does NOT modify frontend
# - Backward compatible
# - Isolated container deployment
# - Reads ALL configuration from config/stackwatch.json (Single Source of Truth)

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# CONFIGURATION FROM SINGLE SOURCE OF TRUTH
# =============================================================================

# Script directory and config file path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/stackwatch.json"

# Check if jq is available and config file exists
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warn "Config file not found: $CONFIG_FILE"
        log_warn "Using fallback defaults"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        log_warn "jq is not installed - using fallback defaults"
        log_warn "Install jq for Single Source of Truth configuration"
        return 1
    fi

    return 0
}

# Load configuration from stackwatch.json or use fallback defaults
if load_config; then
    log_info "Loading configuration from: $CONFIG_FILE"

    # Versions and Images
    PROMETHEUS_VERSION=$(jq -r '.versions.prometheus' "$CONFIG_FILE")
    PROMETHEUS_IMAGE_BASE=$(jq -r '.images.prometheus' "$CONFIG_FILE")
    PROMETHEUS_IMAGE="${PROMETHEUS_IMAGE_BASE}:${PROMETHEUS_VERSION}"

    # Ports
    PROMETHEUS_PORT=$(jq -r '.ports.prometheus' "$CONFIG_FILE")

    # Paths
    PROMETHEUS_CONFIG_DIR=$(jq -r '.paths.prometheus_config' "$CONFIG_FILE")
    PROMETHEUS_DATA_DIR=$(jq -r '.paths.prometheus_data' "$CONFIG_FILE")

    # Resources
    PROMETHEUS_MEMORY=$(jq -r '.resources.prometheus.memory' "$CONFIG_FILE")
    PROMETHEUS_CPUS=$(jq -r '.resources.prometheus.cpus' "$CONFIG_FILE")

    # Retention
    PROMETHEUS_RETENTION_DAYS=$(jq -r '.retention.prometheus_data_days' "$CONFIG_FILE")
    PROMETHEUS_STORAGE_LIMIT=$(jq -r '.retention.prometheus_storage_limit' "$CONFIG_FILE")

    # Prometheus settings
    SCRAPE_INTERVAL=$(jq -r '.prometheus.scrape_interval' "$CONFIG_FILE")
    EVALUATION_INTERVAL=$(jq -r '.prometheus.evaluation_interval' "$CONFIG_FILE")

    # Health check settings
    HEALTH_CHECK_INTERVAL=$(jq -r '.health_check.interval' "$CONFIG_FILE")
    HEALTH_CHECK_RETRIES=$(jq -r '.health_check.retries' "$CONFIG_FILE")
    HEALTH_CHECK_TIMEOUT=$(jq -r '.health_check.timeout' "$CONFIG_FILE")

    log_info "Configuration loaded successfully"
else
    # Fallback defaults (for backward compatibility)
    log_warn "Using fallback configuration values"
    PROMETHEUS_VERSION="latest"
    PROMETHEUS_IMAGE="docker.io/prom/prometheus:latest"
    PROMETHEUS_PORT="9090"
    PROMETHEUS_CONFIG_DIR="/etc/prometheus"
    PROMETHEUS_DATA_DIR="/var/lib/prometheus"
    PROMETHEUS_MEMORY="4g"
    PROMETHEUS_CPUS="2"
    PROMETHEUS_RETENTION_DAYS="90"
    PROMETHEUS_STORAGE_LIMIT="50GB"
    SCRAPE_INTERVAL="15s"
    EVALUATION_INTERVAL="15s"
    HEALTH_CHECK_INTERVAL="30s"
    HEALTH_CHECK_RETRIES="3"
    HEALTH_CHECK_TIMEOUT="60"
fi

# Static configuration
PROMETHEUS_CONTAINER_NAME="prometheus"
PROMETHEUS_CONFIG_FILE="${PROMETHEUS_CONFIG_DIR}/prometheus.yml"

# =============================================================================
# FUNCTIONS
# =============================================================================

# Prepare host volumes and directories
prepare_prometheus_directories() {
    log_info "Preparing Prometheus host volumes and directories..."

    # Create Prometheus configuration directory
    mkdir -p "${PROMETHEUS_CONFIG_DIR}" || {
        log_error "Failed to create Prometheus config directory: ${PROMETHEUS_CONFIG_DIR}"
        exit 1
    }

    # Create Prometheus data directory
    mkdir -p "${PROMETHEUS_DATA_DIR}" || {
        log_error "Failed to create Prometheus data directory: ${PROMETHEUS_DATA_DIR}"
        exit 1
    }

    log_info "Prometheus directories created successfully"
    log_info "  Config: ${PROMETHEUS_CONFIG_DIR}"
    log_info "  Data: ${PROMETHEUS_DATA_DIR}"
}

# Create Prometheus configuration
create_prometheus_config() {
    log_info "Creating Prometheus configuration..."

    # Backup existing config if it exists
    if [[ -f "${PROMETHEUS_CONFIG_FILE}" ]]; then
        log_warn "Backing up existing Prometheus configuration..."
        cp "${PROMETHEUS_CONFIG_FILE}" "${PROMETHEUS_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)" || {
            log_warn "Could not backup existing config, continuing..."
        }
    fi

    # Create Prometheus configuration (using values from Single Source of Truth)
    cat > "${PROMETHEUS_CONFIG_FILE}" << PROMETHEUS_EOF
# STACKWATCH: Prometheus Configuration
# Backend System Architect and Automation Engineer
# Version: ${PROMETHEUS_VERSION}
# Generated from: config/stackwatch.json (Single Source of Truth)

global:
  scrape_interval: ${SCRAPE_INTERVAL}
  evaluation_interval: ${EVALUATION_INTERVAL}

# Alertmanager configuration (if needed)
# alerting:
#   alertmanagers:
#     - static_configs:
#         - targets: []

# Load rules (if needed)
# rule_files:
#   - "alerts/*.yml"

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:${PROMETHEUS_PORT}']

  # Node Exporter (Linux) - targets added via Ansible
  - job_name: 'node-exporter'
    static_configs:
      - targets: []
        # Example: ['server1:9100', 'server2:9100']
        # Configure via Ansible or manually

  # Windows Exporter - targets added manually or via service discovery
  - job_name: 'windows-exporter'
    static_configs:
      - targets: []
        # Example: ['win-server1:9182', 'win-server2:9182']
PROMETHEUS_EOF

    log_info "Prometheus configuration created: ${PROMETHEUS_CONFIG_FILE}"
    log_warn "Update scrape_configs with actual target servers"
}

# Deploy Prometheus container
deploy_prometheus() {
    log_info "Deploying Prometheus container..."
    log_info "  Version: ${PROMETHEUS_VERSION}"
    log_info "  Memory: ${PROMETHEUS_MEMORY}"
    log_info "  CPUs: ${PROMETHEUS_CPUS}"
    log_info "  Retention: ${PROMETHEUS_RETENTION_DAYS} days"
    log_info "  Storage Limit: ${PROMETHEUS_STORAGE_LIMIT}"

    # Check if Podman is installed
    if ! command -v podman &> /dev/null; then
        log_error "Podman is not installed"
        log_info "Install Podman: yum install podman (RHEL/CentOS) or apt install podman (Debian/Ubuntu)"
        exit 1
    fi

    # Stop and remove existing container if it exists
    if podman ps -a --format "{{.Names}}" | grep -q "^${PROMETHEUS_CONTAINER_NAME}$"; then
        log_warn "Stopping existing Prometheus container..."
        podman stop "${PROMETHEUS_CONTAINER_NAME}" || true
        podman rm "${PROMETHEUS_CONTAINER_NAME}" || true
    fi

    # Pull image
    log_info "Pulling Prometheus image: ${PROMETHEUS_IMAGE}..."
    podman pull "${PROMETHEUS_IMAGE}" || {
        log_error "Failed to pull Prometheus image: ${PROMETHEUS_IMAGE}"
        log_error "Ensure you have internet connectivity and Podman can access Docker Hub"
        exit 1
    }
    log_info "Successfully pulled Prometheus image: ${PROMETHEUS_IMAGE}"

    # Run Prometheus container (Production-Grade with all settings from config)
    log_info "Starting Prometheus container..."
    podman run -d \
        --name "${PROMETHEUS_CONTAINER_NAME}" \
        --memory="${PROMETHEUS_MEMORY}" \
        --cpus="${PROMETHEUS_CPUS}" \
        --health-cmd="wget -q --spider http://localhost:${PROMETHEUS_PORT}/-/healthy || exit 1" \
        --health-interval="${HEALTH_CHECK_INTERVAL}" \
        --health-retries="${HEALTH_CHECK_RETRIES}" \
        -v /etc/hosts:/etc/hosts:Z \
        -v "${PROMETHEUS_CONFIG_DIR}:/etc/prometheus:Z" \
        -v "${PROMETHEUS_DATA_DIR}:/prometheus:Z" \
        -p "${PROMETHEUS_PORT}:9090" \
        "${PROMETHEUS_IMAGE}" \
        --config.file=/etc/prometheus/prometheus.yml \
        --web.external-url=/prometheus/ \
        --web.route-prefix=/ \
        --storage.tsdb.retention.time="${PROMETHEUS_RETENTION_DAYS}d" \
        --storage.tsdb.retention.size="${PROMETHEUS_STORAGE_LIMIT}" \
        --storage.tsdb.path=/prometheus \
        --web.enable-lifecycle || {
        log_error "Failed to start Prometheus container"
        exit 1
    }

    log_info "Prometheus container started"
}

# Create systemd service (optional)
create_systemd_service() {
    log_info "Creating systemd service for Prometheus..."

    # Generate systemd service file in /etc/systemd/system/
    SERVICE_FILE="/etc/systemd/system/container-${PROMETHEUS_CONTAINER_NAME}.service"

    podman generate systemd --name "${PROMETHEUS_CONTAINER_NAME}" --new > "${SERVICE_FILE}" || {
        log_warn "Failed to generate systemd service - container will not auto-start on boot"
        return 0
    }

    # Reload systemd daemon to recognize new service
    systemctl daemon-reload || {
        log_warn "Failed to reload systemd daemon"
        return 0
    }

    # Enable service
    systemctl enable "container-${PROMETHEUS_CONTAINER_NAME}.service" || {
        log_warn "Failed to enable systemd service"
        return 0
    }

    log_info "Systemd service created and enabled: ${SERVICE_FILE}"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying Prometheus deployment..."

    # Wait for container to start
    sleep 3

    # Check container status
    if podman ps --format "{{.Names}}" | grep -q "^${PROMETHEUS_CONTAINER_NAME}$"; then
        log_info "Prometheus container is running"
    else
        log_error "Prometheus container is not running"
        return 1
    fi

    # Check health endpoint
    if curl -s -f "http://localhost:${PROMETHEUS_PORT}/-/healthy" > /dev/null; then
        log_info "Prometheus health check passed"
    else
        log_warn "Prometheus health check failed - container may still be starting"
    fi
}

# Main function
main() {
    log_info "=========================================="
    log_info "StackWatch Prometheus Deployment"
    log_info "=========================================="
    log_info "Configuration Source: config/stackwatch.json"
    log_info ""

    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi

    # Prepare directories
    prepare_prometheus_directories

    # Create configuration
    create_prometheus_config

    # Deploy container
    deploy_prometheus

    # Create systemd service
    create_systemd_service

    # Verify
    verify_deployment

    log_info ""
    log_info "Prometheus deployment complete"
    log_info "  Version: ${PROMETHEUS_VERSION}"
    log_info "  Memory: ${PROMETHEUS_MEMORY}"
    log_info "  CPUs: ${PROMETHEUS_CPUS}"
    log_info "  Retention: ${PROMETHEUS_RETENTION_DAYS} days"
    log_info "  Storage Limit: ${PROMETHEUS_STORAGE_LIMIT}"
    log_info ""
    log_info "Access Prometheus: http://localhost:${PROMETHEUS_PORT}"
    log_info "Access via Nginx: http://$(hostname -I | awk '{print $1}')/prometheus"
}

main "$@"
