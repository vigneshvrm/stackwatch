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
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Rewrite redirects to include /prometheus prefix
        proxy_redirect http://localhost:9090/ /prometheus/;
        proxy_redirect http://$host:9090/ /prometheus/;
        proxy_redirect default;
    }
    
    # Handle Prometheus API endpoints without trailing slash
    location /prometheus {
        return 301 /prometheus/;
    }

    # Route to Grafana (backend service)
    location /grafana/ {
        proxy_pass http://localhost:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Rewrite redirects to include /grafana prefix
        # Handle both with and without trailing slash to prevent loops
        proxy_redirect http://localhost:3000/ /grafana/;
        proxy_redirect http://localhost:3000 /grafana/;
        proxy_redirect http://$host:3000/ /grafana/;
        proxy_redirect http://$host:3000 /grafana/;
        proxy_redirect https://localhost:3000/ /grafana/;
        proxy_redirect https://localhost:3000 /grafana/;
        proxy_redirect https://$host:3000/ /grafana/;
        proxy_redirect https://$host:3000 /grafana/;
        proxy_redirect default;
    }
    
    # Handle Grafana without trailing slash
    location /grafana {
        return 301 /grafana/;
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

# Disable default Nginx site
disable_default_site() {
    log_info "Checking for default Nginx site..."
    
    local default_site="/etc/nginx/sites-enabled/default"
    
    if [[ -L "${default_site}" ]] || [[ -f "${default_site}" ]]; then
        log_warn "Default Nginx site found - disabling it..."
        rm -f "${default_site}" || {
            log_warn "Could not remove default site, continuing..."
        }
        log_info "Default Nginx site disabled"
    else
        log_info "Default Nginx site not found (already disabled)"
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
    
    # Disable default site
    disable_default_site
    
    # Enable site
    enable_nginx_site
    
    # Test and reload
    test_and_reload_nginx
    
    # Verify deployment
    log_info ""
    log_info "Verifying deployment..."
    
    if [[ -f "${WEB_ROOT}/index.html" ]]; then
        log_info "✓ Frontend files found at: ${WEB_ROOT}"
    else
        log_warn "✗ Frontend files NOT found at: ${WEB_ROOT}"
        log_warn "  Run 'npm run build' in project root, then re-run this script"
    fi
    
    if [[ -L "${NGINX_ENABLED}" ]]; then
        log_info "✓ StackBill Nginx site is enabled"
    else
        log_warn "✗ StackBill Nginx site is NOT enabled"
    fi
    
    if [[ -L "/etc/nginx/sites-enabled/default" ]] || [[ -f "/etc/nginx/sites-enabled/default" ]]; then
        log_warn "✗ Default Nginx site is still enabled - this may cause issues"
    else
        log_info "✓ Default Nginx site is disabled"
    fi
    
    log_info ""
    log_info "Nginx deployment complete"
    log_info "Frontend served from: ${WEB_ROOT}"
    log_info "Backend routes: /prometheus, /grafana"
    log_info ""
    log_info "If you see 'Welcome to nginx!' instead of StackBill UI:"
    log_info "  1. Verify frontend files exist: ls -la ${WEB_ROOT}/"
    log_info "  2. Check enabled sites: ls -la /etc/nginx/sites-enabled/"
    log_info "  3. Ensure default site is disabled: rm -f /etc/nginx/sites-enabled/default"
    log_info "  4. Reload Nginx: systemctl reload nginx"
}

main "$@"

