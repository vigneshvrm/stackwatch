#!/bin/bash
#
# StackWatch Artifact Server Setup Script
# Run this on your artifact server (artifact.stackwatch.io)
#
# Usage: sudo ./setup-artifact-server.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
ARTIFACT_ROOT="/var/www/artifacts"
STACKWATCH_ROOT="${ARTIFACT_ROOT}/stackwatch/build"
DEPLOY_USER="deploy"
NGINX_CONF="/etc/nginx/sites-available/artifact.stackwatch.io"
DOMAIN="artifact.stackwatch.io"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

log_info "=========================================="
log_info "StackWatch Artifact Server Setup"
log_info "=========================================="

# Step 1: Install Nginx if not present
log_info "Step 1: Checking Nginx installation..."
if ! command -v nginx &> /dev/null; then
    log_info "Installing Nginx..."
    apt-get update
    apt-get install -y nginx
else
    log_info "Nginx already installed"
fi

# Step 2: Create deploy user
log_info "Step 2: Setting up deploy user..."
if ! id "${DEPLOY_USER}" &>/dev/null; then
    useradd -m -s /bin/bash "${DEPLOY_USER}"
    log_info "Created user: ${DEPLOY_USER}"
else
    log_info "User ${DEPLOY_USER} already exists"
fi

# Step 3: Create directory structure
log_info "Step 3: Creating directory structure..."
CURRENT_YEAR=$(date +%Y)
CURRENT_MONTH=$(date +%m)

mkdir -p "${STACKWATCH_ROOT}/${CURRENT_YEAR}/${CURRENT_MONTH}/beta"
mkdir -p "${STACKWATCH_ROOT}/${CURRENT_YEAR}/${CURRENT_MONTH}/latest"
mkdir -p "${STACKWATCH_ROOT}/${CURRENT_YEAR}/${CURRENT_MONTH}/archive"

# Set permissions
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${ARTIFACT_ROOT}"
chmod -R 755 "${ARTIFACT_ROOT}"

log_info "Directory structure created:"
log_info "  ${STACKWATCH_ROOT}/${CURRENT_YEAR}/${CURRENT_MONTH}/beta/"
log_info "  ${STACKWATCH_ROOT}/${CURRENT_YEAR}/${CURRENT_MONTH}/latest/"
log_info "  ${STACKWATCH_ROOT}/${CURRENT_YEAR}/${CURRENT_MONTH}/archive/"

# Step 4: Setup SSH for deploy user
log_info "Step 4: Setting up SSH access for deploy user..."
DEPLOY_HOME=$(eval echo "~${DEPLOY_USER}")
SSH_DIR="${DEPLOY_HOME}/.ssh"

mkdir -p "${SSH_DIR}"
touch "${SSH_DIR}/authorized_keys"
chmod 700 "${SSH_DIR}"
chmod 600 "${SSH_DIR}/authorized_keys"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${SSH_DIR}"

log_warn "IMPORTANT: Add Jenkins public key to ${SSH_DIR}/authorized_keys"

# Step 5: Install Nginx configuration
log_info "Step 5: Installing Nginx configuration..."

# Check if config file exists in current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/nginx-artifact.conf" ]]; then
    cp "${SCRIPT_DIR}/nginx-artifact.conf" "${NGINX_CONF}"
    log_info "Copied nginx configuration to ${NGINX_CONF}"
else
    log_warn "nginx-artifact.conf not found in ${SCRIPT_DIR}"
    log_warn "Please copy the nginx configuration manually"
fi

# Enable site
if [[ -f "${NGINX_CONF}" ]]; then
    ln -sf "${NGINX_CONF}" /etc/nginx/sites-enabled/
    log_info "Enabled Nginx site"
fi

# Step 6: Setup SSL with Let's Encrypt (optional)
log_info "Step 6: SSL Setup..."
if command -v certbot &> /dev/null; then
    log_info "Certbot is available. To setup SSL run:"
    log_info "  certbot --nginx -d ${DOMAIN}"
else
    log_warn "Certbot not installed. Install with:"
    log_warn "  apt-get install certbot python3-certbot-nginx"
fi

# Step 7: Test and reload Nginx
log_info "Step 7: Testing Nginx configuration..."
if nginx -t; then
    systemctl reload nginx
    log_info "Nginx configuration valid and reloaded"
else
    log_error "Nginx configuration test failed"
    exit 1
fi

# Step 8: Create helper scripts
log_info "Step 8: Creating helper scripts..."

# Create promote script on server
cat > "${ARTIFACT_ROOT}/promote-to-latest.sh" << 'EOF'
#!/bin/bash
# Promote beta to latest
# Usage: ./promote-to-latest.sh [YEAR] [MONTH]

YEAR=${1:-$(date +%Y)}
MONTH=${2:-$(date +%m)}
BASE_PATH="/var/www/artifacts/stackwatch/build/${YEAR}/${MONTH}"

if [[ ! -f "${BASE_PATH}/beta/stackwatch-beta.tar.gz" ]]; then
    echo "ERROR: No beta version found at ${BASE_PATH}/beta/"
    exit 1
fi

# Get beta version
BETA_VERSION=$(cat "${BASE_PATH}/beta/version.txt" 2>/dev/null || echo "unknown")
echo "Promoting beta version: ${BETA_VERSION}"

# Archive current latest
if [[ -f "${BASE_PATH}/latest/stackwatch-latest.tar.gz" ]]; then
    OLD_VERSION=$(cat "${BASE_PATH}/latest/version.txt" 2>/dev/null || echo "unknown")
    mv "${BASE_PATH}/latest/stackwatch-latest.tar.gz" "${BASE_PATH}/archive/stackwatch-${OLD_VERSION}.tar.gz"
    echo "Archived previous latest: ${OLD_VERSION}"
fi

# Copy beta to latest
cp "${BASE_PATH}/beta/stackwatch-beta.tar.gz" "${BASE_PATH}/latest/stackwatch-latest.tar.gz"
cp "${BASE_PATH}/beta/version.txt" "${BASE_PATH}/latest/version.txt"
cp "${BASE_PATH}/beta/metadata.json" "${BASE_PATH}/latest/metadata.json"

# Update metadata
sed -i 's/"release_type": "beta"/"release_type": "latest"/g' "${BASE_PATH}/latest/metadata.json"

echo "SUCCESS: Beta ${BETA_VERSION} promoted to latest"
echo "Download URL: https://artifact.stackwatch.io/stackwatch/build/${YEAR}/${MONTH}/latest/stackwatch-latest.tar.gz"
EOF

chmod +x "${ARTIFACT_ROOT}/promote-to-latest.sh"
chown "${DEPLOY_USER}:${DEPLOY_USER}" "${ARTIFACT_ROOT}/promote-to-latest.sh"

# Create index HTML for better browsing
cat > "${ARTIFACT_ROOT}/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>StackWatch Artifacts</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        h1 { color: #333; }
        a { color: #0066cc; text-decoration: none; }
        a:hover { text-decoration: underline; }
        .info { background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0; }
        code { background: #eee; padding: 2px 6px; border-radius: 3px; }
    </style>
</head>
<body>
    <h1>StackWatch Artifact Server</h1>
    <div class="info">
        <h3>Quick Links</h3>
        <ul>
            <li><a href="/stackwatch/build/">Browse all builds</a></li>
        </ul>
    </div>
    <div class="info">
        <h3>Download Commands</h3>
        <p><strong>Latest (stable):</strong></p>
        <code>curl -LO https://artifact.stackwatch.io/stackwatch/build/YYYY/MM/latest/stackwatch-latest.tar.gz</code>
        <p><strong>Beta (testing):</strong></p>
        <code>curl -LO https://artifact.stackwatch.io/stackwatch/build/YYYY/MM/beta/stackwatch-beta.tar.gz</code>
    </div>
</body>
</html>
EOF

log_info ""
log_info "=========================================="
log_info "Setup Complete!"
log_info "=========================================="
log_info ""
log_info "Directory Structure:"
log_info "  ${STACKWATCH_ROOT}/"
log_info "    └── YYYY/"
log_info "        └── MM/"
log_info "            ├── beta/       <- New untested builds"
log_info "            ├── latest/     <- Tested stable builds"
log_info "            └── archive/    <- Old versions"
log_info ""
log_info "Next Steps:"
log_info "  1. Add Jenkins SSH public key to: ${SSH_DIR}/authorized_keys"
log_info "  2. Setup SSL: certbot --nginx -d ${DOMAIN}"
log_info "  3. Configure Jenkins with 'stackwatch-deploy' credentials"
log_info ""
log_info "Test URLs (after first build):"
log_info "  https://${DOMAIN}/stackwatch/build/${CURRENT_YEAR}/${CURRENT_MONTH}/beta/"
log_info "  https://${DOMAIN}/stackwatch/build/${CURRENT_YEAR}/${CURRENT_MONTH}/latest/"
log_info ""
