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
GRAFANA_CONFIG_DIR="/etc/grafana"
GRAFANA_DATA_DIR="/var/lib/grafana/data"
GRAFANA_CONFIG_FILE="${GRAFANA_CONFIG_DIR}/grafana.ini"

# Create Grafana configuration
create_grafana_config() {
    log_info "Creating Grafana configuration..."
    
    # Create directories
    mkdir -p "${GRAFANA_CONFIG_DIR}"
    mkdir -p "${GRAFANA_DATA_DIR}"
    
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
    log_info "Pulling Grafana image..."
    podman pull "${GRAFANA_IMAGE}" || {
        log_error "Failed to pull Grafana image"
        exit 1
    }
    
    # Run Grafana container
    log_info "Starting Grafana container..."
    podman run -d \
        --name "${GRAFANA_CONTAINER_NAME}" \
        -p "${GRAFANA_PORT}:3000" \
        -v "${GRAFANA_CONFIG_DIR}:/etc/grafana:ro" \
        -v "${GRAFANA_DATA_DIR}:/var/lib/grafana" \
        --restart=unless-stopped \
        "${GRAFANA_IMAGE}" || {
        log_error "Failed to start Grafana container"
        exit 1
    }
    
    log_info "Grafana container started"
}

# Create systemd service (optional)
create_systemd_service() {
    log_info "Creating systemd service for Grafana..."
    
    # Generate systemd service file
    podman generate systemd --name "${GRAFANA_CONTAINER_NAME}" --files --new || {
        log_warn "Failed to generate systemd service - container will not auto-start on boot"
        return 0
    }
    
    # Enable service
    systemctl enable "container-${GRAFANA_CONTAINER_NAME}.service" || {
        log_warn "Failed to enable systemd service"
        return 0
    }
    
    log_info "Systemd service created and enabled"
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

