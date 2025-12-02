#!/bin/bash
#
# STACKBILL: Client Deployment Script (from /opt/stackbill)
# Backend System Architect and Automation Engineer
#
# Purpose: Deploys StackBill from /opt/stackbill installation
#          Copies frontend to /var/www/stackbill/dist/ and runs deployment
#
# Usage: sudo /opt/stackbill/scripts/deploy-from-opt.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/stackbill"
WEB_ROOT="/var/www/stackbill/dist"
FRONTEND_SOURCE="${INSTALL_DIR}/dist"
SCRIPTS_DIR="${INSTALL_DIR}/scripts"
ANSIBLE_DIR="${INSTALL_DIR}/ansible"
ANSIBLE_INVENTORY="${ANSIBLE_DIR}/inventory/hosts"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Pre-flight checks
preflight_checks() {
    log_info "Running pre-flight checks..."
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Check installation directory exists
    if [[ ! -d "${INSTALL_DIR}" ]]; then
        log_error "Installation directory not found: ${INSTALL_DIR}"
        log_error "Please extract the package to /opt/stackbill first"
        exit 1
    fi
    
    # Check frontend source exists
    if [[ ! -d "${FRONTEND_SOURCE}" ]]; then
        log_error "Frontend source not found: ${FRONTEND_SOURCE}"
        log_error "Package may be incomplete"
        exit 1
    fi
    
    if [[ ! -f "${FRONTEND_SOURCE}/index.html" ]]; then
        log_error "Frontend index.html not found in ${FRONTEND_SOURCE}"
        log_error "Package may be incomplete"
        exit 1
    fi
    
    # Check scripts directory exists
    if [[ ! -d "${SCRIPTS_DIR}" ]]; then
        log_error "Scripts directory not found: ${SCRIPTS_DIR}"
        exit 1
    fi
    
    # Check required scripts exist
    local required_scripts=(
        "${SCRIPTS_DIR}/configure-firewall.sh"
        "${SCRIPTS_DIR}/deploy-nginx.sh"
        "${SCRIPTS_DIR}/deploy-prometheus.sh"
        "${SCRIPTS_DIR}/deploy-grafana.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "${script}" ]]; then
            log_error "Required script not found: ${script}"
            exit 1
        fi
        # Ensure script is executable
        chmod +x "${script}"
    done
    
    log_info "Pre-flight checks passed"
}

# Deploy frontend files
deploy_frontend() {
    log_info "Deploying frontend files..."
    
    # Create web root directory
    mkdir -p "${WEB_ROOT}"
    
    # Copy frontend files
    log_info "Copying frontend from ${FRONTEND_SOURCE} to ${WEB_ROOT}..."
    cp -r "${FRONTEND_SOURCE}"/* "${WEB_ROOT}/" || {
        log_error "Failed to copy frontend files"
        exit 1
    }
    
    # Set permissions
    chown -R nginx:nginx "${WEB_ROOT}" 2>/dev/null || \
    chown -R www-data:www-data "${WEB_ROOT}" 2>/dev/null || \
    log_warn "Could not set ownership (may need manual fix)"
    
    chmod -R 755 "${WEB_ROOT}"
    
    log_info "Frontend deployed to: ${WEB_ROOT}"
    log_info "Frontend size: $(du -sh "${WEB_ROOT}" | cut -f1)"
}

# Deploy firewall configuration
deploy_firewall() {
    log_info "Phase 1: Configuring firewall..."
    "${SCRIPTS_DIR}/configure-firewall.sh" || {
        log_error "Firewall configuration failed"
        exit 1
    }
}

# Deploy Nginx
deploy_nginx() {
    log_info "Phase 2: Deploying Nginx..."
    "${SCRIPTS_DIR}/deploy-nginx.sh" || {
        log_error "Nginx deployment failed"
        exit 1
    }
}

# Deploy Prometheus
deploy_prometheus() {
    log_info "Phase 3: Deploying Prometheus..."
    "${SCRIPTS_DIR}/deploy-prometheus.sh" || {
        log_error "Prometheus deployment failed"
        exit 1
    }
}

# Deploy Grafana
deploy_grafana() {
    log_info "Phase 4: Deploying Grafana..."
    "${SCRIPTS_DIR}/deploy-grafana.sh" || {
        log_error "Grafana deployment failed"
        exit 1
    }
}

# Deploy Node Exporter (Ansible)
deploy_node_exporter() {
    log_info "Phase 5: Deploying Node Exporter (Linux) via Ansible..."
    
    if [[ ! -f "${ANSIBLE_INVENTORY}" ]]; then
        log_warn "Ansible inventory not found: ${ANSIBLE_INVENTORY}"
        log_warn "Skipping Node Exporter deployment"
        log_warn "Please configure ansible/inventory/hosts and run manually:"
        log_warn "  ansible-playbook -i ${ANSIBLE_INVENTORY} ${ANSIBLE_DIR}/playbooks/deploy-node-exporter.yml"
        return 0
    fi
    
    if ! command -v ansible-playbook &> /dev/null; then
        log_warn "ansible-playbook not found - skipping Node Exporter deployment"
        log_warn "Install Ansible and run manually:"
        log_warn "  ansible-playbook -i ${ANSIBLE_INVENTORY} ${ANSIBLE_DIR}/playbooks/deploy-node-exporter.yml"
        return 0
    fi
    
    ansible-playbook -i "${ANSIBLE_INVENTORY}" \
        "${ANSIBLE_DIR}/playbooks/deploy-node-exporter.yml" || {
        log_warn "Node Exporter deployment failed (continuing anyway)"
    }
}

# Health check
run_health_check() {
    log_info "Phase 6: Running health checks..."
    
    if [[ -f "${SCRIPTS_DIR}/health-check.sh" ]]; then
        "${SCRIPTS_DIR}/health-check.sh" || {
            log_warn "Health check reported issues - review output"
        }
    else
        log_warn "Health check script not found - skipping"
    fi
}

# Display deployment summary
display_summary() {
    local server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    log_info ""
    log_info "=========================================="
    log_info "StackBill Deployment Complete"
    log_info "=========================================="
    log_info ""
    log_info "Installation Directory: ${INSTALL_DIR}"
    log_info "Web Root: ${WEB_ROOT}"
    log_info ""
    log_info "Access URLs:"
    log_info "  - StackBill Dashboard: http://${server_ip}/"
    log_info "  - Prometheus: http://${server_ip}/prometheus/"
    log_info "  - Grafana: http://${server_ip}/grafana/"
    log_info "  - Help Documentation: http://${server_ip}/help"
    log_info ""
    log_info "Next Steps:"
    log_info "  1. Verify services: ${SCRIPTS_DIR}/health-check.sh"
    log_info "  2. Configure Grafana (default: admin/admin)"
    log_info "  3. Configure Ansible inventory for Node Exporter deployment"
    log_info "  4. Deploy Windows Exporter on Windows servers using PowerShell script"
    log_info ""
}

# Main function
main() {
    log_info "=========================================="
    log_info "StackBill Client Deployment"
    log_info "Installation: ${INSTALL_DIR}"
    log_info "=========================================="
    log_info ""
    
    # Pre-flight checks
    preflight_checks
    
    # Deploy frontend first
    deploy_frontend
    
    # Deploy backend services
    deploy_firewall
    deploy_nginx
    deploy_prometheus
    deploy_grafana
    deploy_node_exporter
    
    # Health check
    run_health_check
    
    # Display summary
    display_summary
}

# Run main function
main "$@"

