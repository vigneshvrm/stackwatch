#!/bin/bash
#
# STACKBILL: Grafana Deployment Script (Podman)
# Backend System Architect and Automation Engineer
#
# CRITICAL RULES:
# - Does NOT modify frontend
# - Backward compatible
# - Isolated container deployment

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

# Configuration
GRAFANA_CONTAINER_NAME="grafana"
GRAFANA_IMAGE="docker.io/grafana/grafana:latest"
GRAFANA_PORT="3000"
GRAFANA_DATA_DIR="/var/lib/grafana"
GRAFANA_CONFIG_DIR="/etc/grafana/config"
GRAFANA_CONFIG_FILE="${GRAFANA_CONFIG_DIR}/grafana.ini"
GRAFANA_PROVISIONING_DIR="/etc/grafana/provisioning"
GRAFANA_PROVISIONING_DASHBOARDS="${GRAFANA_PROVISIONING_DIR}/dashboards"
GRAFANA_PROVISIONING_DATASOURCES="${GRAFANA_PROVISIONING_DIR}/datasources"
GRAFANA_PROVISIONING_ALERTING="${GRAFANA_PROVISIONING_DIR}/alerting"

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
    
    # Set ownership to Grafana user (UID 472), recommended for volume mounts
    chown -R 472:472 "${GRAFANA_CONFIG_DIR}" || log_warn "Could not set ownership for config directory"
    chown -R 472:472 "${GRAFANA_DATA_DIR}" || log_warn "Could not set ownership for data directory"
    chown -R 472:472 "${GRAFANA_PROVISIONING_DIR}" || log_warn "Could not set ownership for provisioning directory"
    
    log_info "Permissions set (UID 472:472 for Grafana user)"
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
    
    # Create Grafana configuration
    cat > "${GRAFANA_CONFIG_FILE}" << 'GRAFANA_EOF'
# STACKBILL: Grafana Configuration
# Backend System Architect and Automation Engineer

[server]
http_port = 3000
root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana/
serve_from_sub_path = true

[database]
type = sqlite3
path = /var/lib/grafana/data/grafana.db

[security]
admin_user = admin
admin_password = admin
secret_key = CHANGE_THIS_SECRET_KEY_IN_PRODUCTION

[users]
allow_sign_up = false

[log]
mode = console
level = info
GRAFANA_EOF

    log_info "Grafana configuration created: ${GRAFANA_CONFIG_FILE}"
    log_warn "IMPORTANT: Change admin_password and secret_key in production!"
}

# Deploy Grafana container
deploy_grafana() {
    log_info "Deploying Grafana container..."
    
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
    
    # Pull latest image
    log_info "Pulling Grafana image: ${GRAFANA_IMAGE}..."
    podman pull "${GRAFANA_IMAGE}" || {
        log_error "Failed to pull Grafana image: ${GRAFANA_IMAGE}"
        log_error "Ensure you have internet connectivity and Podman can access Docker Hub"
        exit 1
    }
    log_info "Successfully pulled Grafana image: ${GRAFANA_IMAGE}"
    
    # Run Grafana container
    log_info "Starting Grafana container..."
    podman run -d \
        --name "${GRAFANA_CONTAINER_NAME}" \
        --dns 8.8.8.8 \
        --dns 1.1.1.1 \
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
    log_info "StackBill Grafana Deployment"
    log_info "=========================================="
    
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
    
    # Deploy container
    deploy_grafana
    
    # Create systemd service
    create_systemd_service
    
    # Verify
    verify_deployment
    
    log_info ""
    log_info "Grafana deployment complete"
    log_info "Access Grafana: http://localhost:${GRAFANA_PORT}"
    log_info "Access via Nginx: http://$(hostname -I | awk '{print $1}')/grafana"
    log_info ""
    log_warn "Default credentials: admin/admin - CHANGE IN PRODUCTION!"
}

main "$@"

