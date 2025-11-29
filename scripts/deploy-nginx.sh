#!/bin/bash
#
# STACKBILL: Nginx Deployment Script
# Backend System Architect and Automation Engineer
#
# CRITICAL RULES:
# - Serves frontend UI (does NOT modify it)
# - Backward compatible routing
# - Does NOT break existing frontend behavior

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
NGINX_CONFIG="/etc/nginx/sites-available/stackbill"
NGINX_ENABLED="/etc/nginx/sites-enabled/stackbill"
WEB_ROOT="/var/www/stackbill/dist"
FRONTEND_BUILD_DIR="dist"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Create Nginx configuration
create_nginx_config() {
    log_info "Creating Nginx configuration..."
    
    # Backup existing config if it exists
    if [[ -f "${NGINX_CONFIG}" ]]; then
        log_warn "Backing up existing Nginx configuration..."
        cp "${NGINX_CONFIG}" "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Create Nginx configuration
    cat > "${NGINX_CONFIG}" << 'NGINX_EOF'
# STACKBILL: Nginx Configuration
# Backend System Architect and Automation Engineer
# 
# CRITICAL: Serves frontend UI - does NOT modify frontend code
# Backward compatible routing

server {
    listen 80;
    server_name _;
    root /var/www/stackbill/dist;
    index index.html;

    # Serve StackBill Frontend (SPA routing support)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Route to Prometheus (backend service)
    location /prometheus/ {
        proxy_pass http://localhost:9090/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Route to Grafana (backend service)
    location /grafana/ {
        proxy_pass http://localhost:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
NGINX_EOF

    log_info "Nginx configuration created: ${NGINX_CONFIG}"
}

# Deploy frontend build (if exists)
deploy_frontend() {
    log_info "Checking for frontend build..."
    
    local build_dir="${PROJECT_ROOT}/${FRONTEND_BUILD_DIR}"
    
    if [[ -d "${build_dir}" ]] && [[ -f "${build_dir}/index.html" ]]; then
        log_info "Frontend build found - deploying to web root..."
        
        # Create web root directory
        mkdir -p "${WEB_ROOT}"
        
        # Copy frontend build (preserves existing if deployment fails)
        cp -r "${build_dir}"/* "${WEB_ROOT}/" || {
            log_error "Failed to copy frontend build"
            return 1
        }
        
        # Set permissions
        chown -R nginx:nginx "${WEB_ROOT}" || chown -R www-data:www-data "${WEB_ROOT}" || log_warn "Could not set ownership"
        chmod -R 755 "${WEB_ROOT}"
        
        log_info "Frontend deployed to: ${WEB_ROOT}"
    else
        log_warn "Frontend build not found at: ${build_dir}"
        log_warn "Skipping frontend deployment - Nginx will serve existing files or 404"
        log_warn "To deploy frontend: npm run build (in project root)"
    fi
}

# Enable Nginx site
enable_nginx_site() {
    log_info "Enabling Nginx site..."
    
    # Create symlink if it doesn't exist
    if [[ ! -L "${NGINX_ENABLED}" ]]; then
        ln -s "${NGINX_CONFIG}" "${NGINX_ENABLED}"
        log_info "Nginx site enabled"
    else
        log_info "Nginx site already enabled"
    fi
}

# Test and reload Nginx
test_and_reload_nginx() {
    log_info "Testing Nginx configuration..."
    
    if nginx -t; then
        log_info "Nginx configuration test passed"
        log_info "Reloading Nginx..."
        systemctl reload nginx || service nginx reload || {
            log_error "Failed to reload Nginx"
            return 1
        }
        log_info "Nginx reloaded successfully"
    else
        log_error "Nginx configuration test failed"
        return 1
    fi
}

# Main function
main() {
    log_info "=========================================="
    log_info "StackBill Nginx Deployment"
    log_info "=========================================="
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Check if Nginx is installed
    if ! command -v nginx &> /dev/null; then
        log_error "Nginx is not installed"
        log_info "Install Nginx: yum install nginx (RHEL/CentOS) or apt install nginx (Debian/Ubuntu)"
        exit 1
    fi
    
    # Create configuration
    create_nginx_config
    
    # Deploy frontend (if build exists)
    deploy_frontend
    
    # Enable site
    enable_nginx_site
    
    # Test and reload
    test_and_reload_nginx
    
    log_info ""
    log_info "Nginx deployment complete"
    log_info "Frontend served from: ${WEB_ROOT}"
    log_info "Backend routes: /prometheus, /grafana"
}

main "$@"

