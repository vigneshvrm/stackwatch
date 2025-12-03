#!/bin/bash
#
# STACKWATCH: Firewall Configuration Script
# Backend System Architect and Automation Engineer
#
# CRITICAL RULES:
# - Does NOT remove existing firewall rules
# - Adds rules safely
# - Backward compatible

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
    log_info "HTTP (port 80) allowed"
    
    # Allow HTTPS
    firewall-cmd --permanent --add-service=https || log_warn "HTTPS rule may already exist"
    log_info "HTTPS (port 443) allowed"
    
    # Block direct access to Prometheus
    firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port port="9090" protocol="tcp" reject' || log_warn "Prometheus block rule may already exist"
    log_info "Direct access to Prometheus (port 9090) blocked"
    
    # Block direct access to Grafana
    firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port port="3000" protocol="tcp" reject' || log_warn "Grafana block rule may already exist"
    log_info "Direct access to Grafana (port 3000) blocked"
    
    # Block direct access to Node Exporter
    firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port port="9100" protocol="tcp" reject' || log_warn "Node Exporter block rule may already exist"
    log_info "Direct access to Node Exporter (port 9100) blocked"
    
    # Block direct access to Windows Exporter
    firewall-cmd --permanent --add-rich-rule='rule family="ipv4" port port="9182" protocol="tcp" reject' || log_warn "Windows Exporter block rule may already exist"
    log_info "Direct access to Windows Exporter (port 9182) blocked"
    
    # Reload firewall
    firewall-cmd --reload
    log_info "Firewall rules reloaded"
}

# Configure UFW
configure_ufw() {
    log_info "Configuring UFW..."
    
    # Allow HTTP
    ufw allow 80/tcp || log_warn "HTTP rule may already exist"
    log_info "HTTP (port 80) allowed"
    
    # Allow HTTPS
    ufw allow 443/tcp || log_warn "HTTPS rule may already exist"
    log_info "HTTPS (port 443) allowed"
    
    # Deny direct access (UFW denies by default, but explicit for clarity)
    ufw deny 9090/tcp || log_warn "Prometheus deny rule may already exist"
    ufw deny 3000/tcp || log_warn "Grafana deny rule may already exist"
    ufw deny 9100/tcp || log_warn "Node Exporter deny rule may already exist"
    ufw deny 9182/tcp || log_warn "Windows Exporter deny rule may already exist"
    
    log_info "Direct access to internal services blocked"
}

# Configure iptables
configure_iptables() {
    log_info "Configuring iptables..."
    log_warn "iptables configuration requires manual rules - consider using firewalld or UFW"
    log_info "Basic iptables rules (add to your iptables script):"
    echo "  iptables -A INPUT -p tcp --dport 80 -j ACCEPT"
    echo "  iptables -A INPUT -p tcp --dport 443 -j ACCEPT"
    echo "  iptables -A INPUT -p tcp --dport 9090 -j REJECT"
    echo "  iptables -A INPUT -p tcp --dport 3000 -j REJECT"
    echo "  iptables -A INPUT -p tcp --dport 9100 -j REJECT"
    echo "  iptables -A INPUT -p tcp --dport 9182 -j REJECT"
}

# Main function
main() {
    log_info "=========================================="
    log_info "StackWatch Firewall Configuration"
    log_info "=========================================="
    
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
}

main "$@"

