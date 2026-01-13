#!/bin/bash
#
# STACKWATCH: Health Check Script
# Backend System Architect and Automation Engineer
#
# CRITICAL RULES:
# - Read-only health validation
# - Does NOT modify services
# - Backward compatible
# - Reads ALL configuration from config/stackwatch.json (Single Source of Truth)

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Health check results
HEALTHY=0
UNHEALTHY=0
WARNINGS=0

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((UNHEALTHY++))
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
    ((HEALTHY++))
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
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        return 1
    fi

    return 0
}

# Load configuration from stackwatch.json or use fallback defaults
if load_config; then
    # Ports
    PROMETHEUS_PORT=$(jq -r '.ports.prometheus' "$CONFIG_FILE")
    GRAFANA_PORT=$(jq -r '.ports.grafana' "$CONFIG_FILE")
    NODE_EXPORTER_PORT=$(jq -r '.ports.node_exporter' "$CONFIG_FILE")
else
    # Fallback defaults (for backward compatibility)
    PROMETHEUS_PORT="9090"
    GRAFANA_PORT="3000"
    NODE_EXPORTER_PORT="9100"
fi

# =============================================================================
# FUNCTIONS
# =============================================================================

# Check service health
check_service() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}

    if curl -s -f -o /dev/null -w "%{http_code}" --max-time 5 "${url}" | grep -q "${expected_status}"; then
        log_success "${name}: OK"
        return 0
    else
        log_error "${name}: FAILED (${url})"
        return 1
    fi
}

# Check container status
check_container() {
    local name=$1

    if podman ps --format "{{.Names}}" | grep -q "^${name}$"; then
        log_success "${name} container: Running"
        return 0
    else
        log_error "${name} container: Not running"
        return 1
    fi
}

# Main health check
main() {
    echo "=========================================="
    echo "StackWatch Health Check Report"
    echo "Date: $(date)"
    echo "Configuration: config/stackwatch.json"
    echo "=========================================="
    echo ""

    # Check Nginx
    log_info "Checking Nginx..."
    if systemctl is-active --quiet nginx; then
        check_service "Nginx" "http://localhost/" "200" || true
    else
        log_error "Nginx service: Not running"
    fi

    # Check StackWatch Frontend
    log_info "Checking StackWatch Frontend..."
    check_service "StackWatch Frontend" "http://localhost/" "200" || true

    # Check Prometheus
    log_info "Checking Prometheus..."
    check_container "prometheus"
    check_service "Prometheus Health" "http://localhost:${PROMETHEUS_PORT}/-/healthy" "200" || true
    check_service "Prometheus via Nginx" "http://localhost/prometheus/-/healthy" "200" || true

    # Check Grafana
    log_info "Checking Grafana..."
    check_container "grafana"
    check_service "Grafana Health" "http://localhost:${GRAFANA_PORT}/api/health" "200" || true
    check_service "Grafana via Nginx" "http://localhost/grafana/api/health" "200" || true

    # Check Node Exporter (if accessible)
    log_info "Checking Node Exporter targets..."
    if command -v ansible &> /dev/null; then
        log_info "Node Exporter targets should be checked via Prometheus /api/v1/targets"
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Health Check Summary"
    echo "=========================================="
    echo "Healthy: ${HEALTHY}"
    echo "Unhealthy: ${UNHEALTHY}"
    echo "Warnings: ${WARNINGS}"
    echo ""
    echo "Ports Configuration:"
    echo "  Prometheus: ${PROMETHEUS_PORT}"
    echo "  Grafana: ${GRAFANA_PORT}"
    echo "  Node Exporter: ${NODE_EXPORTER_PORT}"
    echo ""

    if [[ ${UNHEALTHY} -eq 0 ]]; then
        log_info "Overall Status: HEALTHY"
        exit 0
    else
        log_error "Overall Status: UNHEALTHY"
        exit 1
    fi
}

main "$@"
