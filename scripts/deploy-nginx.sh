#!/bin/bash
#
# STACKWATCH: Nginx Deployment Script
# Backend System Architect and Automation Engineer
#
# CRITICAL RULES:
# - Serves frontend UI (does NOT modify it)
# - Backward compatible routing
# - Does NOT break existing frontend behavior
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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
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

    # Paths
    NGINX_CONFIG=$(jq -r '.paths.nginx_config' "$CONFIG_FILE")
    NGINX_ENABLED=$(jq -r '.paths.nginx_enabled' "$CONFIG_FILE")
    WEB_ROOT=$(jq -r '.paths.web_root' "$CONFIG_FILE")
    INSTALL_DIR=$(jq -r '.paths.install_dir' "$CONFIG_FILE")

    # Ports
    PROMETHEUS_PORT=$(jq -r '.ports.prometheus' "$CONFIG_FILE")
    GRAFANA_PORT=$(jq -r '.ports.grafana' "$CONFIG_FILE")
    HEALTH_API_PORT=$(jq -r '.ports.health_api' "$CONFIG_FILE")

    # Nginx settings
    PROXY_CONNECT_TIMEOUT=$(jq -r '.nginx.proxy_connect_timeout' "$CONFIG_FILE")
    PROXY_READ_TIMEOUT=$(jq -r '.nginx.proxy_read_timeout' "$CONFIG_FILE")

    log_info "Configuration loaded successfully"
else
    # Fallback defaults (for backward compatibility)
    log_warn "Using fallback configuration values"
    NGINX_CONFIG="/etc/nginx/sites-available/stackwatch"
    NGINX_ENABLED="/etc/nginx/sites-enabled/stackwatch"
    WEB_ROOT="/var/www/stackwatch/dist"
    INSTALL_DIR="/opt/stackwatch"
    PROMETHEUS_PORT="9090"
    GRAFANA_PORT="3000"
    HEALTH_API_PORT="8888"
    PROXY_CONNECT_TIMEOUT="5s"
    PROXY_READ_TIMEOUT="10s"
fi

# Static configuration
FRONTEND_BUILD_DIR="dist"

# =============================================================================
# FUNCTIONS
# =============================================================================

# Create Nginx configuration
create_nginx_config() {
    log_info "Creating Nginx configuration..."

    # Backup existing config if it exists
    if [[ -f "${NGINX_CONFIG}" ]]; then
        log_warn "Backing up existing Nginx configuration..."
        cp "${NGINX_CONFIG}" "${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    # Create Nginx configuration (using values from Single Source of Truth)
    cat > "${NGINX_CONFIG}" << NGINX_EOF
# STACKWATCH: Nginx Configuration
# Backend System Architect and Automation Engineer
# Generated from: config/stackwatch.json (Single Source of Truth)
#
# CRITICAL: Serves frontend UI - does NOT modify frontend code
# Backward compatible routing

server {
    listen 80;
    server_name _;
    root ${WEB_ROOT};
    index index.html;

    # Serve StackWatch Frontend (SPA routing support)
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Health API endpoint (proxy to health-api.sh service)
    location /api/health {
        proxy_pass http://127.0.0.1:${HEALTH_API_PORT}/api/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout ${PROXY_CONNECT_TIMEOUT};
        proxy_read_timeout ${PROXY_READ_TIMEOUT};
    }

    # Route to Prometheus (backend service)
    location /prometheus/ {
        proxy_pass http://localhost:${PROMETHEUS_PORT}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;

        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Rewrite redirects to include /prometheus prefix
        proxy_redirect http://localhost:${PROMETHEUS_PORT}/ /prometheus/;
        proxy_redirect http://\$host:${PROMETHEUS_PORT}/ /prometheus/;
        proxy_redirect default;
    }

    # Handle Prometheus API endpoints without trailing slash
    location /prometheus {
        return 301 /prometheus/;
    }

    # Route to Grafana (backend service)
    # CRITICAL: Use 127.0.0.1 (not localhost) and NO trailing slash in proxy_pass
    # root_url in Grafana must be hardcoded with NO trailing slash
    location /grafana/ {
        proxy_pass http://127.0.0.1:${GRAFANA_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # WebSocket support (if needed)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Handle Grafana without trailing slash
    location /grafana {
        return 301 /grafana/;
    }

    # Serve Help Documentation Manifest (JSON)
    location ~ ^/help/docs/manifest\.json\$ {
        alias ${WEB_ROOT}/help/docs/manifest.json;
        add_header Content-Type "application/json; charset=utf-8";
        add_header Access-Control-Allow-Origin "*";
    }

    # Serve Help Documentation (Markdown files)
    location /help/docs/ {
        alias ${WEB_ROOT}/help/docs/;
        default_type text/plain;
        add_header Content-Type "text/markdown; charset=utf-8";
        add_header Access-Control-Allow-Origin "*";
        # Disable directory listing for security
        autoindex off;
    }

    # Serve Help Documentation Images
    location /help/docs/images/ {
        alias ${WEB_ROOT}/help/docs/images/;
        add_header Access-Control-Allow-Origin "*";
        expires 30d;
        add_header Cache-Control "public, immutable";
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

    # Priority order for frontend source locations
    local opt_dist="${INSTALL_DIR}/dist"
    local build_dir="${PROJECT_ROOT}/${FRONTEND_BUILD_DIR}"
    local prebuilt_dir="${PROJECT_ROOT}/prebuilt/dist"

    local frontend_source=""
    local source_type=""

    # Priority 1: Client installation in /opt/stackwatch
    if [[ -d "${opt_dist}" ]] && [[ -f "${opt_dist}/index.html" ]]; then
        frontend_source="${opt_dist}"
        source_type="client installation (${INSTALL_DIR}/dist)"
    # Priority 2: Developer build directory
    elif [[ -d "${build_dir}" ]] && [[ -f "${build_dir}/index.html" ]]; then
        frontend_source="${build_dir}"
        source_type="developer build (dist/)"
    # Priority 3: Prebuilt directory
    elif [[ -d "${prebuilt_dir}" ]] && [[ -f "${prebuilt_dir}/index.html" ]]; then
        frontend_source="${prebuilt_dir}"
        source_type="prebuilt directory (prebuilt/dist/)"
    fi

    if [[ -n "${frontend_source}" ]]; then
        log_info "Frontend build found - deploying from ${source_type}..."

        # Create web root directory
        mkdir -p "${WEB_ROOT}"

        # Copy frontend build (preserves existing if deployment fails)
        cp -r "${frontend_source}"/* "${WEB_ROOT}/" || {
            log_error "Failed to copy frontend build"
            return 1
        }

        # Set permissions
        chown -R nginx:nginx "${WEB_ROOT}" || chown -R www-data:www-data "${WEB_ROOT}" || log_warn "Could not set ownership"
        chmod -R 755 "${WEB_ROOT}"

        log_info "Frontend deployed to: ${WEB_ROOT}"
    else
        log_warn "Frontend build not found in any of the following locations:"
        log_warn "  1. ${opt_dist} (client installation)"
        log_warn "  2. ${build_dir} (developer build)"
        log_warn "  3. ${prebuilt_dir} (prebuilt directory)"
        log_warn "Skipping frontend deployment - Nginx will serve existing files or 404"
        log_warn ""
        log_warn "To deploy frontend:"
        log_warn "  - For clients: Extract package to ${INSTALL_DIR} and run deploy-from-opt.sh"
        log_warn "  - For developers: Run 'npm run build' in project root"
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
    log_info "StackWatch Nginx Deployment"
    log_info "=========================================="
    log_info "Configuration Source: config/stackwatch.json"
    log_info ""

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
        log_info "Frontend files found at: ${WEB_ROOT}"
    else
        log_warn "Frontend files NOT found at: ${WEB_ROOT}"
        log_warn "  Run 'npm run build' in project root, then re-run this script"
    fi

    if [[ -L "${NGINX_ENABLED}" ]]; then
        log_info "StackWatch Nginx site is enabled"
    else
        log_warn "StackWatch Nginx site is NOT enabled"
    fi

    if [[ -L "/etc/nginx/sites-enabled/default" ]] || [[ -f "/etc/nginx/sites-enabled/default" ]]; then
        log_warn "Default Nginx site is still enabled - this may cause issues"
    else
        log_info "Default Nginx site is disabled"
    fi

    log_info ""
    log_info "Nginx deployment complete"
    log_info "Frontend served from: ${WEB_ROOT}"
    log_info "Backend routes: /prometheus (port ${PROMETHEUS_PORT}), /grafana (port ${GRAFANA_PORT})"
    log_info ""
    log_info "If you see 'Welcome to nginx!' instead of StackWatch UI:"
    log_info "  1. Verify frontend files exist: ls -la ${WEB_ROOT}/"
    log_info "  2. Check enabled sites: ls -la /etc/nginx/sites-enabled/"
    log_info "  3. Ensure default site is disabled: rm -f /etc/nginx/sites-enabled/default"
    log_info "  4. Reload Nginx: systemctl reload nginx"
}

main "$@"
