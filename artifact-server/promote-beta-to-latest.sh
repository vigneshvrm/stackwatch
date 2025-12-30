#!/bin/bash
#
# StackWatch: Promote Beta to Latest
# Run this on the artifact server after testing a beta build
#
# Usage: ./promote-beta-to-latest.sh [YEAR] [MONTH]
# Example: ./promote-beta-to-latest.sh 2025 01
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Configuration
ARTIFACT_ROOT="/var/www/artifacts"
STACKWATCH_ROOT="${ARTIFACT_ROOT}/stackwatch/build"
DOMAIN="artifact.stackbill.com"

# Get year and month (default to current)
YEAR=${1:-$(date +%Y)}
MONTH=${2:-$(date +%m)}

BASE_PATH="${STACKWATCH_ROOT}/${YEAR}/${MONTH}"
BETA_PATH="${BASE_PATH}/beta"
LATEST_PATH="${BASE_PATH}/latest"
ARCHIVE_PATH="${BASE_PATH}/archive"

log_info "=========================================="
log_info "StackWatch: Promote Beta to Latest"
log_info "=========================================="
log_info "Year/Month: ${YEAR}/${MONTH}"
log_info ""

# Step 1: Verify beta exists
log_step "1. Checking beta version..."
if [[ ! -f "${BETA_PATH}/stackwatch-beta.tar.gz" ]]; then
    log_error "No beta version found!"
    log_error "Path: ${BETA_PATH}/stackwatch-beta.tar.gz"
    exit 1
fi

BETA_VERSION=$(cat "${BETA_PATH}/version.txt" 2>/dev/null || echo "unknown")
BETA_DATE=$(cat "${BETA_PATH}/build-date.txt" 2>/dev/null || echo "unknown")
log_info "Beta version found: ${BETA_VERSION}"
log_info "Beta build date: ${BETA_DATE}"

# Step 2: Archive current latest (if exists)
log_step "2. Archiving current latest..."
if [[ -f "${LATEST_PATH}/stackwatch-latest.tar.gz" ]]; then
    OLD_VERSION=$(cat "${LATEST_PATH}/version.txt" 2>/dev/null || echo "unknown-$(date +%Y%m%d)")

    mkdir -p "${ARCHIVE_PATH}"

    # Move latest to archive with version name
    mv "${LATEST_PATH}/stackwatch-latest.tar.gz" "${ARCHIVE_PATH}/stackwatch-${OLD_VERSION}.tar.gz"

    # Also archive metadata
    if [[ -f "${LATEST_PATH}/metadata.json" ]]; then
        mv "${LATEST_PATH}/metadata.json" "${ARCHIVE_PATH}/metadata-${OLD_VERSION}.json"
    fi

    log_info "Archived previous latest: ${OLD_VERSION}"
    log_info "Archive location: ${ARCHIVE_PATH}/stackwatch-${OLD_VERSION}.tar.gz"
else
    log_info "No existing latest to archive (first promotion)"
fi

# Step 3: Promote beta to latest
log_step "3. Promoting beta to latest..."
mkdir -p "${LATEST_PATH}"

# Copy the actual versioned file
cp "${BETA_PATH}/stackwatch-${BETA_VERSION}.tar.gz" "${LATEST_PATH}/" 2>/dev/null || \
    cp "${BETA_PATH}/stackwatch-beta.tar.gz" "${LATEST_PATH}/stackwatch-${BETA_VERSION}.tar.gz"

# Create the latest symlink
cd "${LATEST_PATH}"
rm -f stackwatch-latest.tar.gz
ln -sf "stackwatch-${BETA_VERSION}.tar.gz" stackwatch-latest.tar.gz

# Copy version info
cp "${BETA_PATH}/version.txt" "${LATEST_PATH}/"
cp "${BETA_PATH}/build-date.txt" "${LATEST_PATH}/" 2>/dev/null || true

# Update metadata
if [[ -f "${BETA_PATH}/metadata.json" ]]; then
    cp "${BETA_PATH}/metadata.json" "${LATEST_PATH}/"
    # Update release_type in metadata
    sed -i 's/"release_type": "beta"/"release_type": "latest"/g' "${LATEST_PATH}/metadata.json"
fi

log_info "Beta promoted to latest successfully!"

# Step 4: Display summary
log_info ""
log_info "=========================================="
log_info "Promotion Complete!"
log_info "=========================================="
log_info ""
log_info "Promoted Version: ${BETA_VERSION}"
log_info ""
log_info "Download URLs:"
log_info "  Latest: https://${DOMAIN}/stackwatch/build/${YEAR}/${MONTH}/latest/stackwatch-latest.tar.gz"
log_info "  Direct: https://${DOMAIN}/stackwatch/build/${YEAR}/${MONTH}/latest/stackwatch-${BETA_VERSION}.tar.gz"
log_info ""
log_info "Archive Contents:"
ls -la "${ARCHIVE_PATH}/" 2>/dev/null || log_info "  (empty)"
log_info ""
