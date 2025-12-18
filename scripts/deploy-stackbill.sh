#!/bin/bash
#
# STACKWATCH: Main Deployment Orchestrator
# Backend System Architect and Automation Engineer
#
# CRITICAL RULES:
# - Does NOT modify frontend UI
# - Does NOT break existing behavior
# - Backward compatible
# - Orchestrates backend services only

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
ENVIRONMENT="${ENVIRONMENT:-production}"
ANSIBLE_INVENTORY="${ANSIBLE_INVENTORY:-${PROJECT_ROOT}/ansible/inventory/hosts}"

# Logging
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
    
    # Check required commands
    local required_commands=("podman" "nginx" "ansible-playbook")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    # Check Ansible inventory exists
    if [[ ! -f "${ANSIBLE_INVENTORY}" ]]; then
        log_error "Ansible inventory not found: ${ANSIBLE_INVENTORY}"
        log_info "Expected location: ${PROJECT_ROOT}/ansible/inventory/hosts"
        exit 1
    fi
    
    log_info "Pre-flight checks passed"
}

# Main deployment function
main() {
    log_info "=========================================="
    log_info "StackWatch Backend Deployment"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "=========================================="
    log_info ""
    log_info "CRITICAL: Backend services only - Frontend UI not modified"
    log_info ""
    
    # Pre-flight checks
    preflight_checks
    
    # Phase 1: Firewall Configuration
    log_info "Phase 1: Configuring firewall..."
    "${SCRIPT_DIR}/configure-firewall.sh" || {
        log_error "Firewall configuration failed"
        exit 1
    }
    
    # Phase 2: Nginx Deployment
    log_info "Phase 2: Deploying Nginx..."
    "${SCRIPT_DIR}/deploy-nginx.sh" || {
        log_error "Nginx deployment failed"
        exit 1
    }
    
    # Phase 3: Prometheus Deployment
    log_info "Phase 3: Deploying Prometheus..."
    "${SCRIPT_DIR}/deploy-prometheus.sh" || {
        log_error "Prometheus deployment failed"
        exit 1
    }
    
    # Phase 4: Grafana Deployment
    log_info "Phase 4: Deploying Grafana..."
    "${SCRIPT_DIR}/deploy-grafana.sh" || {
        log_error "Grafana deployment failed"
        exit 1
    }
    
    # Phase 5: Node Exporter Deployment (Ansible - Linux)
    log_info "Phase 5: Deploying Node Exporter (Linux) via Ansible..."
    ansible-playbook -i "${ANSIBLE_INVENTORY}" \
        "${PROJECT_ROOT}/ansible/playbooks/deploy-node-exporter.yml" || {
        log_error "Node Exporter deployment failed"
        exit 1
    }
    
    # Phase 5b: Windows Exporter Deployment (PowerShell Script - Windows)
    log_info "Phase 5b: Windows Exporter deployment..."
    log_warn "Windows Exporter MUST be deployed using PowerShell script on Windows servers"
    log_warn "Run: powershell -ExecutionPolicy Bypass -File scripts/deploy-windows-exporter.ps1"
    log_warn "This must be executed directly on each Windows server (NO Ansible, NO WinRM)"
    
    # Phase 6: Health Check
    log_info "Phase 6: Running health checks..."
    "${SCRIPT_DIR}/health-check.sh" || {
        log_warn "Health check reported issues - review output"
    }
    
    log_info ""
    log_info "=========================================="
    log_info "StackWatch Backend Deployment Complete"
    log_info "=========================================="
    log_info ""
    log_info "Backend services deployed successfully"
    log_info "Frontend UI unchanged (served via Nginx)"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Verify services: ./scripts/health-check.sh"
    log_info "  2. Access StackWatch: http://$(hostname -I | awk '{print $1}')/"
    log_info "  3. Access Prometheus: http://$(hostname -I | awk '{print $1}')/prometheus"
    log_info "  4. Access Grafana: http://$(hostname -I | awk '{print $1}')/grafana"
}

# Run main function
main "$@"

