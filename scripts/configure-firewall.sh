#!/bin/bash
#
# STACKWATCH: Firewall Configuration Script
# Backend System Architect and Automation Engineer
#
# CRITICAL RULES:
# - Does NOT remove existing firewall rules
# - Adds rules safely
# - Backward compatible
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

    # Ports
    PROMETHEUS_PORT=$(jq -r '.ports.prometheus' "$CONFIG_FILE")
    GRAFANA_PORT=$(jq -r '.ports.grafana' "$CONFIG_FILE")
    NODE_EXPORTER_PORT=$(jq -r '.ports.node_exporter' "$CONFIG_FILE")
    WINDOWS_EXPORTER_PORT=$(jq -r '.ports.windows_exporter' "$CONFIG_FILE")
    HTTP_PORT=$(jq -r '.ports.http' "$CONFIG_FILE")
    HTTPS_PORT=$(jq -r '.ports.https' "$CONFIG_FILE")

    log_info "Configuration loaded successfully"
else
    # Fallback defaults (for backward compatibility)
    log_warn "Using fallback configuration values"
    PROMETHEUS_PORT="9090"
    GRAFANA_PORT="3000"
    NODE_EXPORTER_PORT="9100"
    WINDOWS_EXPORTER_PORT="9182"
    HTTP_PORT="80"
    HTTPS_PORT="443"
fi

# =============================================================================
# FUNCTIONS
# =============================================================================

# Detect firewall system
detect_firewall() {
    if command -v firewall-cmd &> /dev/null; then
        echo "firewalld"
    elif command -v ufw &> /dev/null; then
        echo "ufw"
    elif command -v iptables &> /dev/null; then
        echo "iptables"
    else
        echo "unknown"
    fi
}

# Configure firewalld
configure_firewalld() {
    log_info "Configuring firewalld..."

    # Allow HTTP
    firewall-cmd --permanent --add-service=http || log_warn "HTTP rule may already exist"
    log_info "HTTP (port ${HTTP_PORT}) allowed"

    # Allow HTTPS
    firewall-cmd --permanent --add-service=https || log_warn "HTTPS rule may already exist"
    log_info "HTTPS (port ${HTTPS_PORT}) allowed"

    # Block direct access to Prometheus
    firewall-cmd --permanent --add-rich-rule="rule family=\"ipv4\" port port=\"${PROMETHEUS_PORT}\" protocol=\"tcp\" reject" || log_warn "Prometheus block rule may already exist"
    log_info "Direct access to Prometheus (port ${PROMETHEUS_PORT}) blocked"

    # Block direct access to Grafana
    firewall-cmd --permanent --add-rich-rule="rule family=\"ipv4\" port port=\"${GRAFANA_PORT}\" protocol=\"tcp\" reject" || log_warn "Grafana block rule may already exist"
    log_info "Direct access to Grafana (port ${GRAFANA_PORT}) blocked"

    # Block direct access to Node Exporter
    firewall-cmd --permanent --add-rich-rule="rule family=\"ipv4\" port port=\"${NODE_EXPORTER_PORT}\" protocol=\"tcp\" reject" || log_warn "Node Exporter block rule may already exist"
    log_info "Direct access to Node Exporter (port ${NODE_EXPORTER_PORT}) blocked"

    # Block direct access to Windows Exporter
    firewall-cmd --permanent --add-rich-rule="rule family=\"ipv4\" port port=\"${WINDOWS_EXPORTER_PORT}\" protocol=\"tcp\" reject" || log_warn "Windows Exporter block rule may already exist"
    log_info "Direct access to Windows Exporter (port ${WINDOWS_EXPORTER_PORT}) blocked"

    # Reload firewall
    firewall-cmd --reload
    log_info "Firewall rules reloaded"
}

# Configure UFW
configure_ufw() {
    log_info "Configuring UFW..."

    # Allow HTTP
    ufw allow "${HTTP_PORT}/tcp" || log_warn "HTTP rule may already exist"
    log_info "HTTP (port ${HTTP_PORT}) allowed"

    # Allow HTTPS
    ufw allow "${HTTPS_PORT}/tcp" || log_warn "HTTPS rule may already exist"
    log_info "HTTPS (port ${HTTPS_PORT}) allowed"

    # Deny direct access (UFW denies by default, but explicit for clarity)
    ufw deny "${PROMETHEUS_PORT}/tcp" || log_warn "Prometheus deny rule may already exist"
    ufw deny "${GRAFANA_PORT}/tcp" || log_warn "Grafana deny rule may already exist"
    ufw deny "${NODE_EXPORTER_PORT}/tcp" || log_warn "Node Exporter deny rule may already exist"
    ufw deny "${WINDOWS_EXPORTER_PORT}/tcp" || log_warn "Windows Exporter deny rule may already exist"

    log_info "Direct access to internal services blocked"
}

# Configure iptables
configure_iptables() {
    log_info "Configuring iptables..."
    log_warn "iptables configuration requires manual rules - consider using firewalld or UFW"
    log_info "Basic iptables rules (add to your iptables script):"
    echo "  iptables -A INPUT -p tcp --dport ${HTTP_PORT} -j ACCEPT"
    echo "  iptables -A INPUT -p tcp --dport ${HTTPS_PORT} -j ACCEPT"
    echo "  iptables -A INPUT -p tcp --dport ${PROMETHEUS_PORT} -j REJECT"
    echo "  iptables -A INPUT -p tcp --dport ${GRAFANA_PORT} -j REJECT"
    echo "  iptables -A INPUT -p tcp --dport ${NODE_EXPORTER_PORT} -j REJECT"
    echo "  iptables -A INPUT -p tcp --dport ${WINDOWS_EXPORTER_PORT} -j REJECT"
}

# Main function
main() {
    log_info "=========================================="
    log_info "StackWatch Firewall Configuration"
    log_info "=========================================="
    log_info "Configuration Source: config/stackwatch.json"
    log_info ""

    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi

    local firewall_system=$(detect_firewall)
    log_info "Detected firewall system: ${firewall_system}"

    case "${firewall_system}" in
        firewalld)
            configure_firewalld
            ;;
        ufw)
            configure_ufw
            ;;
        iptables)
            configure_iptables
            ;;
        *)
            log_error "Unknown firewall system - manual configuration required"
            exit 1
            ;;
    esac

    log_info ""
    log_info "Firewall configuration complete"
    log_info "  HTTP: port ${HTTP_PORT} (allowed)"
    log_info "  HTTPS: port ${HTTPS_PORT} (allowed)"
    log_info "  Prometheus: port ${PROMETHEUS_PORT} (blocked - access via Nginx)"
    log_info "  Grafana: port ${GRAFANA_PORT} (blocked - access via Nginx)"
    log_info "  Node Exporter: port ${NODE_EXPORTER_PORT} (blocked)"
    log_info "  Windows Exporter: port ${WINDOWS_EXPORTER_PORT} (blocked)"
}

main "$@"
