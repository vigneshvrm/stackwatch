#!/bin/bash
#
# STACKBILL: Prometheus Deployment Script (Podman)
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
PROMETHEUS_CONTAINER_NAME="prometheus"
PROMETHEUS_IMAGE="docker.io/prom/prometheus:latest"
PROMETHEUS_PORT="9090"
PROMETHEUS_CONFIG_DIR="/etc/prometheus"
PROMETHEUS_DATA_DIR="/var/lib/prometheus/data"
PROMETHEUS_CONFIG_FILE="${PROMETHEUS_CONFIG_DIR}/prometheus.yml"

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
    
    # Create Prometheus configuration
    cat > "${PROMETHEUS_CONFIG_FILE}" << 'PROMETHEUS_EOF'
# STACKBILL: Prometheus Configuration
# Backend System Architect and Automation Engineer

global:
  scrape_interval: 15s
  evaluation_interval: 15s

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
      - targets: ['localhost:9090']

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
    
    # Pull latest image
    log_info "Pulling Prometheus image: ${PROMETHEUS_IMAGE}..."
    podman pull "${PROMETHEUS_IMAGE}" || {
        log_error "Failed to pull Prometheus image: ${PROMETHEUS_IMAGE}"
        log_error "Ensure you have internet connectivity and Podman can access Docker Hub"
        exit 1
    }
    log_info "Successfully pulled Prometheus image: ${PROMETHEUS_IMAGE}"
    
    # Run Prometheus container
    log_info "Starting Prometheus container..."
    podman run -d \
        --name "${PROMETHEUS_CONTAINER_NAME}" \
        -v /etc/hosts:/etc/hosts:Z \
        -v "${PROMETHEUS_CONFIG_DIR}:/etc/prometheus:Z" \
        -p "${PROMETHEUS_PORT}:9090" \
        "${PROMETHEUS_IMAGE}" \
        --config.file=/etc/prometheus/prometheus.yml || {
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
    log_info "StackBill Prometheus Deployment"
    log_info "=========================================="
    
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
    log_info "Access Prometheus: http://localhost:${PROMETHEUS_PORT}"
    log_info "Access via Nginx: http://$(hostname -I | awk '{print $1}')/prometheus"
}

main "$@"

