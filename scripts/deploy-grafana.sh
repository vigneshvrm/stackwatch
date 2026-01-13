#!/bin/bash
#
# STACKWATCH: Grafana Deployment Script (Podman)
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
    GRAFANA_VERSION=$(jq -r '.versions.grafana' "$CONFIG_FILE")
    GRAFANA_IMAGE_BASE=$(jq -r '.images.grafana' "$CONFIG_FILE")
    GRAFANA_IMAGE="${GRAFANA_IMAGE_BASE}:${GRAFANA_VERSION}"

    # Ports
    GRAFANA_PORT=$(jq -r '.ports.grafana' "$CONFIG_FILE")

    # Paths
    GRAFANA_DATA_DIR=$(jq -r '.paths.grafana_data' "$CONFIG_FILE")
    GRAFANA_CONFIG_BASE=$(jq -r '.paths.grafana_config' "$CONFIG_FILE")
    GRAFANA_CONFIG_DIR="${GRAFANA_CONFIG_BASE}/config"
    GRAFANA_PROVISIONING_DIR=$(jq -r '.paths.grafana_provisioning' "$CONFIG_FILE")

    # Resources
    GRAFANA_MEMORY=$(jq -r '.resources.grafana.memory' "$CONFIG_FILE")
    GRAFANA_CPUS=$(jq -r '.resources.grafana.cpus' "$CONFIG_FILE")

    # Grafana settings
    GRAFANA_ADMIN_USER=$(jq -r '.grafana.admin_user' "$CONFIG_FILE")
    GRAFANA_DB_TYPE=$(jq -r '.grafana.database_type' "$CONFIG_FILE")
    GRAFANA_DB_PATH=$(jq -r '.grafana.database_path' "$CONFIG_FILE")
    GRAFANA_UID=$(jq -r '.grafana.uid' "$CONFIG_FILE")

    # DNS settings
    DNS_PRIMARY=$(jq -r '.dns.primary' "$CONFIG_FILE")
    DNS_SECONDARY=$(jq -r '.dns.secondary' "$CONFIG_FILE")

    # Health check settings
    HEALTH_CHECK_INTERVAL=$(jq -r '.health_check.interval' "$CONFIG_FILE")
    HEALTH_CHECK_RETRIES=$(jq -r '.health_check.retries' "$CONFIG_FILE")
    HEALTH_CHECK_TIMEOUT=$(jq -r '.health_check.timeout' "$CONFIG_FILE")

    log_info "Configuration loaded successfully"
else
    # Fallback defaults (for backward compatibility)
    log_warn "Using fallback configuration values"
    GRAFANA_VERSION="latest"
    GRAFANA_IMAGE="docker.io/grafana/grafana:latest"
    GRAFANA_PORT="3000"
    GRAFANA_DATA_DIR="/var/lib/grafana"
    GRAFANA_CONFIG_BASE="/etc/grafana"
    GRAFANA_CONFIG_DIR="/etc/grafana/config"
    GRAFANA_PROVISIONING_DIR="/etc/grafana/provisioning"
    GRAFANA_MEMORY="2g"
    GRAFANA_CPUS="2"
    GRAFANA_ADMIN_USER="admin"
    GRAFANA_DB_TYPE="sqlite3"
    GRAFANA_DB_PATH="/var/lib/grafana/data/grafana.db"
    GRAFANA_UID="472"
    DNS_PRIMARY="8.8.8.8"
    DNS_SECONDARY="1.1.1.1"
    HEALTH_CHECK_INTERVAL="30s"
    HEALTH_CHECK_RETRIES="3"
    HEALTH_CHECK_TIMEOUT="60"
fi

# Static configuration
GRAFANA_CONTAINER_NAME="grafana"
GRAFANA_CONFIG_FILE="${GRAFANA_CONFIG_DIR}/grafana.ini"
GRAFANA_PROVISIONING_DASHBOARDS="${GRAFANA_PROVISIONING_DIR}/dashboards"
GRAFANA_PROVISIONING_DATASOURCES="${GRAFANA_PROVISIONING_DIR}/datasources"
GRAFANA_PROVISIONING_ALERTING="${GRAFANA_PROVISIONING_DIR}/alerting"

# =============================================================================
# FUNCTIONS
# =============================================================================

# Prepare host volumes and directories
prepare_grafana_directories() {
    log_info "Preparing Grafana host volumes and directories..."

    # Data directory (DB files, plugins, uploads, etc.)
    mkdir -p "${GRAFANA_DATA_DIR}" || {
        log_error "Failed to create Grafana data directory: ${GRAFANA_DATA_DIR}"
        exit 1
    }

    # Main Grafana config directory
    mkdir -p "${GRAFANA_CONFIG_DIR}" || {
        log_error "Failed to create Grafana config directory: ${GRAFANA_CONFIG_DIR}"
        exit 1
    }

    # Provisioning subdirectories
    mkdir -p "${GRAFANA_PROVISIONING_DASHBOARDS}" || {
        log_error "Failed to create dashboards provisioning directory"
        exit 1
    }
    mkdir -p "${GRAFANA_PROVISIONING_DATASOURCES}" || {
        log_error "Failed to create datasources provisioning directory"
        exit 1
    }
    mkdir -p "${GRAFANA_PROVISIONING_ALERTING}" || {
        log_error "Failed to create alerting provisioning directory"
        exit 1
    }

    log_info "Grafana directories created successfully"
    log_info "  Data: ${GRAFANA_DATA_DIR}"
    log_info "  Config: ${GRAFANA_CONFIG_DIR}"
    log_info "  Provisioning: ${GRAFANA_PROVISIONING_DIR}"
}

# Set permissions (SELinux/Ownership)
set_grafana_permissions() {
    log_info "Setting Grafana directory permissions..."

    # Set ownership to Grafana user (from config), recommended for volume mounts
    chown -R "${GRAFANA_UID}:${GRAFANA_UID}" "${GRAFANA_CONFIG_DIR}" || log_warn "Could not set ownership for config directory"
    chown -R "${GRAFANA_UID}:${GRAFANA_UID}" "${GRAFANA_DATA_DIR}" || log_warn "Could not set ownership for data directory"
    chown -R "${GRAFANA_UID}:${GRAFANA_UID}" "${GRAFANA_PROVISIONING_DIR}" || log_warn "Could not set ownership for provisioning directory"

    log_info "Permissions set (UID ${GRAFANA_UID}:${GRAFANA_UID} for Grafana user)"
    log_info "Note: :Z flag in Podman volumes will handle SELinux context"
}

# Create Grafana configuration
create_grafana_config() {
    log_info "Creating Grafana configuration..."

    # Backup existing config if it exists
    if [[ -f "${GRAFANA_CONFIG_FILE}" ]]; then
        log_warn "Backing up existing Grafana configuration..."
        cp "${GRAFANA_CONFIG_FILE}" "${GRAFANA_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # Detect server's IP address (prefer public over private)
    SERVER_IP=""

    # Function to check if IP is private
    is_private_ip() {
        local ip="$1"
        if [[ "$ip" =~ ^10\. ]] || \
           [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || \
           [[ "$ip" =~ ^192\.168\. ]] || \
           [[ "$ip" =~ ^127\. ]] || \
           [[ "$ip" =~ ^169\.254\. ]]; then
            return 0  # Is private
        fi
        return 1  # Is public
    }

    # Collect all IPs from all interfaces
    ALL_IPS=""
    if command -v hostname &> /dev/null; then
        ALL_IPS=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^127\.' || true)
    fi

    if command -v ip &> /dev/null; then
        INTERFACE_IPS=$(ip addr show 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | grep -v '^127\.' || true)
        if [[ -n "${INTERFACE_IPS}" ]]; then
            ALL_IPS="${ALL_IPS}"$'\n'"${INTERFACE_IPS}"
        fi
    fi

    # Filter and prioritize: public IPs first, then private IPs
    PUBLIC_IP=""
    PRIVATE_IP=""

    while IFS= read -r ip; do
        [[ -z "$ip" ]] && continue
        if is_private_ip "$ip"; then
            [[ -z "$PRIVATE_IP" ]] && PRIVATE_IP="$ip"
        else
            [[ -z "$PUBLIC_IP" ]] && PUBLIC_IP="$ip"
        fi
    done <<< "$ALL_IPS"

    # Prefer public IP, fallback to private IP
    if [[ -n "$PUBLIC_IP" ]]; then
        SERVER_IP="$PUBLIC_IP"
        log_info "Detected public IP: ${SERVER_IP}"
    elif [[ -n "$PRIVATE_IP" ]]; then
        SERVER_IP="$PRIVATE_IP"
        log_info "Detected private IP: ${SERVER_IP} (typical for direct private IP deployments)"
    fi

    # Allow environment variable override
    if [[ -n "${GRAFANA_DOMAIN:-}" ]]; then
        SERVER_IP="${GRAFANA_DOMAIN}"
        log_info "Using GRAFANA_DOMAIN environment variable override: ${SERVER_IP}"
    fi

    if [[ -z "${SERVER_IP}" ]]; then
        log_warn "Could not detect server IP address. Grafana will use Host header from requests."
        SERVER_DOMAIN=""
    else
        SERVER_DOMAIN="${SERVER_IP}"
    fi

    # Create Grafana configuration (using values from Single Source of Truth)
    cat > "${GRAFANA_CONFIG_FILE}" << EOF
# STACKWATCH: Grafana Configuration
# Backend System Architect and Automation Engineer
# Version: ${GRAFANA_VERSION}
# Generated from: config/stackwatch.json (Single Source of Truth)

[server]
http_port = ${GRAFANA_PORT}
domain = ${SERVER_DOMAIN}
protocol = http
serve_from_sub_path = true
# CRITICAL: root_url must be hardcoded (no variables) and NO trailing slash
root_url = http://${SERVER_DOMAIN}/grafana
enforce_domain = false

[database]
type = ${GRAFANA_DB_TYPE}
path = ${GRAFANA_DB_PATH}

[security]
admin_user = ${GRAFANA_ADMIN_USER}
cookie_samesite = lax
admin_password = admin
secret_key = CHANGE_THIS_SECRET_KEY_IN_PRODUCTION

[users]
allow_sign_up = false

[log]
mode = console
level = info
EOF

    log_info "Grafana configuration created: ${GRAFANA_CONFIG_FILE}"
    if [[ -n "${SERVER_DOMAIN}" ]]; then
        log_info "Grafana domain set to: ${SERVER_DOMAIN}"
    else
        log_warn "Grafana domain is empty - will use Host header from requests"
    fi
    log_warn "IMPORTANT: Change admin_password and secret_key in production!"
}

# Deploy Grafana container
deploy_grafana() {
    log_info "Deploying Grafana container..."
    log_info "  Version: ${GRAFANA_VERSION}"
    log_info "  Memory: ${GRAFANA_MEMORY}"
    log_info "  CPUs: ${GRAFANA_CPUS}"

    # Check if Podman is installed
    if ! command -v podman &> /dev/null; then
        log_error "Podman is not installed"
        log_info "Install Podman: yum install podman (RHEL/CentOS) or apt install podman (Debian/Ubuntu)"
        exit 1
    fi

    # Stop and remove existing container if it exists
    if podman ps -a --format "{{.Names}}" | grep -q "^${GRAFANA_CONTAINER_NAME}$"; then
        log_warn "Stopping existing Grafana container..."
        podman stop "${GRAFANA_CONTAINER_NAME}" || true
        podman rm "${GRAFANA_CONTAINER_NAME}" || true
    fi

    # Pull image
    log_info "Pulling Grafana image: ${GRAFANA_IMAGE}..."
    podman pull "${GRAFANA_IMAGE}" || {
        log_error "Failed to pull Grafana image: ${GRAFANA_IMAGE}"
        log_error "Ensure you have internet connectivity and Podman can access Docker Hub"
        exit 1
    }
    log_info "Successfully pulled Grafana image: ${GRAFANA_IMAGE}"

    # Run Grafana container (Production-Grade with all settings from config)
    log_info "Starting Grafana container..."
    podman run -d \
        --name "${GRAFANA_CONTAINER_NAME}" \
        --memory="${GRAFANA_MEMORY}" \
        --cpus="${GRAFANA_CPUS}" \
        --health-cmd="wget -q --spider http://localhost:${GRAFANA_PORT}/api/health || exit 1" \
        --health-interval="${HEALTH_CHECK_INTERVAL}" \
        --health-retries="${HEALTH_CHECK_RETRIES}" \
        --dns "${DNS_PRIMARY}" \
        --dns "${DNS_SECONDARY}" \
        -p "${GRAFANA_PORT}:3000" \
        -v /etc/hosts:/etc/hosts:Z \
        -v "${GRAFANA_DATA_DIR}:/var/lib/grafana:Z" \
        -v "${GRAFANA_CONFIG_FILE}:/etc/grafana/grafana.ini:Z" \
        -v "${GRAFANA_PROVISIONING_ALERTING}:/etc/grafana/provisioning/alerting:Z" \
        -v "${GRAFANA_PROVISIONING_DATASOURCES}:/etc/grafana/provisioning/datasources:Z" \
        -v "${GRAFANA_PROVISIONING_DASHBOARDS}:/etc/grafana/provisioning/dashboards:Z" \
        "${GRAFANA_IMAGE}" || {
        log_error "Failed to start Grafana container"
        exit 1
    }

    log_info "Grafana container started"
}

# Create systemd service (optional)
create_systemd_service() {
    log_info "Creating systemd service for Grafana..."

    # Generate systemd service file in /etc/systemd/system/
    SERVICE_FILE="/etc/systemd/system/container-${GRAFANA_CONTAINER_NAME}.service"

    podman generate systemd --name "${GRAFANA_CONTAINER_NAME}" --new > "${SERVICE_FILE}" || {
        log_warn "Failed to generate systemd service - container will not auto-start on boot"
        return 0
    }

    # Reload systemd daemon to recognize new service
    systemctl daemon-reload || {
        log_warn "Failed to reload systemd daemon"
        return 0
    }

    # Enable service
    systemctl enable "container-${GRAFANA_CONTAINER_NAME}.service" || {
        log_warn "Failed to enable systemd service"
        return 0
    }

    log_info "Systemd service created and enabled: ${SERVICE_FILE}"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying Grafana deployment..."

    # Wait for container to start
    sleep 5

    # Check container status
    if podman ps --format "{{.Names}}" | grep -q "^${GRAFANA_CONTAINER_NAME}$"; then
        log_info "Grafana container is running"
    else
        log_error "Grafana container is not running"
        return 1
    fi

    # Check health endpoint
    if curl -s -f "http://localhost:${GRAFANA_PORT}/api/health" > /dev/null; then
        log_info "Grafana health check passed"
    else
        log_warn "Grafana health check failed - container may still be starting"
    fi
}

# Main function
main() {
    log_info "=========================================="
    log_info "StackWatch Grafana Deployment"
    log_info "=========================================="
    log_info "Configuration Source: config/stackwatch.json"
    log_info ""

    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi

    # Prepare directories
    prepare_grafana_directories

    # Set permissions
    set_grafana_permissions

    # Create configuration
    create_grafana_config

    # Check if container already exists
    local container_exists=false
    if podman ps -a --format "{{.Names}}" | grep -q "^${GRAFANA_CONTAINER_NAME}$"; then
        container_exists=true
    fi

    # Deploy container
    deploy_grafana

    # If container existed, restart it to apply config changes
    if [[ "$container_exists" == "true" ]]; then
        log_info "Restarting Grafana container to apply configuration changes..."
        podman restart "${GRAFANA_CONTAINER_NAME}" || {
            log_warn "Could not restart Grafana container - configuration may not be applied"
        }
        log_info "Waiting for Grafana to start..."
        sleep 5
    fi

    # Create systemd service
    create_systemd_service

    # Verify
    verify_deployment

    log_info ""
    log_info "Grafana deployment complete"
    log_info "  Version: ${GRAFANA_VERSION}"
    log_info "  Memory: ${GRAFANA_MEMORY}"
    log_info "  CPUs: ${GRAFANA_CPUS}"
    log_info ""
    log_info "Access Grafana: http://localhost:${GRAFANA_PORT}"
    log_info "Access via Nginx: http://$(hostname -I | awk '{print $1}')/grafana"
    log_info ""
    log_warn "Default credentials: ${GRAFANA_ADMIN_USER}/admin - CHANGE IN PRODUCTION!"
}

main "$@"
