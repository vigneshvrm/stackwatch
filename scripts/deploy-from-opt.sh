#!/bin/bash
#
# STACKWATCH: Client Deployment Script (from /opt/stackwatch)
# Backend System Architect and Automation Engineer
#
# Purpose: Deploys StackWatch from /opt/stackwatch installation
#          Copies frontend to /var/www/stackwatch/dist/ and runs deployment
#
# Usage: sudo /opt/stackwatch/scripts/deploy-from-opt.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/stackwatch"
WEB_ROOT="/var/www/stackwatch/dist"
FRONTEND_SOURCE="${INSTALL_DIR}/dist"
SCRIPTS_DIR="${INSTALL_DIR}/scripts"
ANSIBLE_DIR="${INSTALL_DIR}/ansible"
ANSIBLE_INVENTORY="${ANSIBLE_DIR}/inventory/hosts"
LOG_DIR="/var/log/stackwatch"
LOG_FILE="${LOG_DIR}/deploy.log"

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

# Create log directory
setup_logging() {
    mkdir -p "${LOG_DIR}"
    touch "${LOG_FILE}"
    chmod 644 "${LOG_FILE}"
}

# Run Ansible playbook with structured output
run_playbook() {
    local phase=$1
    local description=$2
    local playbook=$3
    
    log_info "[Phase ${phase}] ${description}"
    
    # Run playbook, redirect all output to log, filter INFO/ERROR to console
    if ansible-playbook -i "${ANSIBLE_INVENTORY}" "${ANSIBLE_DIR}/playbooks/${playbook}" --connection=local >> "${LOG_FILE}" 2>&1; then
        log_info "[Phase ${phase}] ✓ ${description} - Completed successfully"
        return 0
    else
        log_error "[Phase ${phase}] ✗ ${description} - Failed (check ${LOG_FILE} for details)"
        return 1
    fi
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
        log_error "Please extract the package to /opt/stackwatch first"
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
    
    # Check Ansible directory exists
    if [[ ! -d "${ANSIBLE_DIR}" ]]; then
        log_error "Ansible directory not found: ${ANSIBLE_DIR}"
        exit 1
    fi
    
    # Check required playbooks exist
    local required_playbooks=(
        "configure-firewall.yml"
        "deploy-nginx.yml"
        "deploy-prometheus.yml"
        "deploy-grafana.yml"
    )
    
    for playbook in "${required_playbooks[@]}"; do
        if [[ ! -f "${ANSIBLE_DIR}/playbooks/${playbook}" ]]; then
            log_error "Required playbook not found: ${ANSIBLE_DIR}/playbooks/${playbook}"
            exit 1
        fi
    done
    
    log_info "Pre-flight checks passed"
}

# Install required packages directly (before Ansible is available)
install_required_packages() {
    log_info "[Phase 0] Installing required packages directly..."
    
    # Required packages list
    local required_packages=(
        "ansible"
        "podman"
        "nginx"
        "python3"
        "sshpass"
    )
    
    # Update package cache
    log_info "Updating apt package cache..."
    if ! apt-get update >> "${LOG_FILE}" 2>&1; then
        log_error "Failed to update package cache"
        exit 1
    fi
    
    # Install packages
    log_info "Installing packages: ${required_packages[*]}..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "${required_packages[@]}" >> "${LOG_FILE}" 2>&1; then
        log_error "Failed to install required packages"
        log_error "Check ${LOG_FILE} for details"
        exit 1
    fi
    
    # Verify installations
    log_info "Verifying package installations..."
    local failed_checks=0
    
    for package in "${required_packages[@]}"; do
        if command -v "${package}" >/dev/null 2>&1 || dpkg -l | grep -q "^ii.*${package}"; then
            log_info "  ✓ ${package} installed"
        else
            log_error "  ✗ ${package} not found"
            failed_checks=$((failed_checks + 1))
        fi
    done
    
    if [[ ${failed_checks} -gt 0 ]]; then
        log_error "Some packages failed verification"
        exit 1
    fi
    
    # Display versions
    log_info "Installed package versions:"
    for package in ansible podman nginx python3; do
        if command -v "${package}" >/dev/null 2>&1; then
            local version_output
            version_output=$("${package}" --version 2>&1 | head -n 1 || echo "version check failed")
            log_info "  ${package}: ${version_output}"
        fi
    done
    
    log_info "[Phase 0] ✓ All required packages installed successfully"
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
    run_playbook "1" "Configuring firewall" "configure-firewall.yml" || exit 1
}

# Deploy Nginx
deploy_nginx() {
    run_playbook "2" "Deploying Nginx" "deploy-nginx.yml" || exit 1
}

# Deploy Prometheus
deploy_prometheus() {
    run_playbook "3" "Deploying Prometheus" "deploy-prometheus.yml" || exit 1
}

# Deploy Grafana
deploy_grafana() {
    run_playbook "4" "Deploying Grafana" "deploy-grafana.yml" || exit 1
}

# Deploy Node Exporter (Ansible)
deploy_node_exporter() {
    log_info "[Phase 5] Node Exporter deployment (skipped on source node)"
    log_info "Node Exporter should be deployed on target monitoring servers, not the StackWatch server"
    log_info "To deploy Node Exporter on target servers:"
    log_info "  1. Configure ${ANSIBLE_INVENTORY} with target server IPs"
    log_info "  2. Run: ansible-playbook -i ${ANSIBLE_INVENTORY} ${ANSIBLE_DIR}/playbooks/deploy-node-exporter.yml"
    return 0
}

# Health check
run_health_check() {
    log_info "[Phase 6] Running health checks..."
    
    if [[ -f "${SCRIPTS_DIR}/health-check.sh" ]]; then
        "${SCRIPTS_DIR}/health-check.sh" >> "${LOG_FILE}" 2>&1 || {
            log_warn "Health check reported issues - check ${LOG_FILE} for details"
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
    log_info "StackWatch Deployment Complete"
    log_info "=========================================="
    log_info ""
    log_info "Installation Directory: ${INSTALL_DIR}"
    log_info "Web Root: ${WEB_ROOT}"
    log_info ""
    log_info "Access URLs:"
    log_info "  - StackWatch Dashboard: http://${server_ip}/"
    log_info "  - Prometheus: http://${server_ip}/prometheus/"
    log_info "  - Grafana: http://${server_ip}/grafana/"
    log_info "  - Help Documentation: http://${server_ip}/help"
    log_info ""
    log_info "Next Steps:"
    log_info "  1. Verify services: ${SCRIPTS_DIR}/health-check.sh"
    log_info "  2. Configure Grafana (default: admin/admin)"
    log_info "  3. Configure Ansible inventory for Node Exporter deployment"
    log_info "  4. Deploy Windows Exporter on Windows servers using PowerShell script"
    log_info "  5. Review deployment log: ${LOG_FILE}"
    log_info ""
}

# Main function
main() {
    # Check if running as root or with sudo (required for package installation)
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
    
    log_info "=========================================="
    log_info "StackWatch Client Deployment"
    log_info "Installation: ${INSTALL_DIR}"
    log_info "Log File: ${LOG_FILE}"
    log_info "=========================================="
    log_info ""
    
    # Setup logging
    setup_logging
    
    # Pre-flight checks
    preflight_checks
    
    # Install required packages first (before Ansible is available)
    install_required_packages
    
    # Deploy frontend
    deploy_frontend
    
    # Deploy backend services via Ansible playbooks (Ansible now available)
    # Note: deploy_packages() is skipped - packages already installed in Phase 0
    deploy_firewall
    deploy_nginx
    deploy_prometheus
    deploy_grafana
    deploy_node_exporter
    
    # Health check
    run_health_check
    
    # Display summary
    display_summary
    
    log_info ""
    log_info "Deployment log saved to: ${LOG_FILE}"
    log_info ""
}

# Run main function
main "$@"

