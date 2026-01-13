#!/bin/bash
#
# StackWatch One-Line Installer
# Usage: curl -fsSL https://artifact.stackwatch.io/install.sh | sudo bash
#        or
#        curl -fsSL https://artifact.stackwatch.io/install.sh | sudo bash -s -- --version beta
#
# Options:
#   --version <latest|beta|X.X.X>  Specify version to install (default: latest)
#   --install-dir <path>           Installation directory (default: /opt/stackwatch)
#   --help                         Show this help message
#

set -euo pipefail

# Configuration
ARTIFACT_URL="https://artifact.stackwatch.io"
DEFAULT_VERSION="latest"
DEFAULT_INSTALL_DIR="/opt/stackwatch"
TEMP_DIR="/tmp/stackwatch-install-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Print banner
print_banner() {
    echo -e "${CYAN}"
    echo "  ____  _             _   __        __    _       _     "
    echo " / ___|| |_ __ _  ___| | _\\ \\      / /_ _| |_ ___| |__  "
    echo " \\___ \\| __/ _\` |/ __| |/ /\\ \\ /\\ / / _\` | __/ __| '_ \\ "
    echo "  ___) | || (_| | (__|   <  \\ V  V / (_| | || (__| | | |"
    echo " |____/ \\__\\__,_|\\___|_|\\_\\  \\_/\\_/ \\__,_|\\__\\___|_| |_|"
    echo ""
    echo -e "${NC}${BOLD}         Infrastructure Monitoring Solution${NC}"
    echo ""
}

# Show help
show_help() {
    echo "StackWatch Installer"
    echo ""
    echo "Usage: curl -fsSL ${ARTIFACT_URL}/install.sh | sudo bash"
    echo "       curl -fsSL ${ARTIFACT_URL}/install.sh | sudo bash -s -- [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version <version>    Version to install: latest, beta, or specific version (default: latest)"
    echo "  --install-dir <path>   Installation directory (default: /opt/stackwatch)"
    echo "  --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Install latest version"
    echo "  curl -fsSL ${ARTIFACT_URL}/install.sh | sudo bash"
    echo ""
    echo "  # Install beta version"
    echo "  curl -fsSL ${ARTIFACT_URL}/install.sh | sudo bash -s -- --version beta"
    echo ""
    echo "  # Install specific version"
    echo "  curl -fsSL ${ARTIFACT_URL}/install.sh | sudo bash -s -- --version 2025.01.55"
    echo ""
    echo "  # Install to custom directory"
    echo "  curl -fsSL ${ARTIFACT_URL}/install.sh | sudo bash -s -- --install-dir /usr/local/stackwatch"
    echo ""
}

# Parse arguments
# Note: Using STACKWATCH_VERSION to avoid conflict with VERSION from /etc/os-release
STACKWATCH_VERSION="${DEFAULT_VERSION}"
INSTALL_DIR="${DEFAULT_INSTALL_DIR}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            STACKWATCH_VERSION="$2"
            shift 2
            ;;
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Cleanup function
cleanup() {
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
}
trap cleanup EXIT

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        echo ""
        echo "Usage: curl -fsSL ${ARTIFACT_URL}/install.sh | sudo bash"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    log_step "Checking system requirements..."

    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS. This installer supports Debian/Ubuntu-based systems."
        exit 1
    fi

    source /etc/os-release
    log_info "Detected OS: ${PRETTY_NAME:-$ID}"

    # Check required commands
    local required_cmds=("curl" "tar")
    local missing_cmds=()

    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_cmds+=("$cmd")
        fi
    done

    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
        log_warn "Missing required commands: ${missing_cmds[*]}"
        log_info "Installing missing dependencies..."
        apt-get update -qq && apt-get install -y -qq "${missing_cmds[@]}"
    fi

    log_info "System requirements satisfied"
}

# Get download URL based on version
get_download_url() {
    local version="$1"
    local download_url=""

    # Get current year and month for the path
    local current_year=$(date +%Y)
    local current_month=$(date +%m)
    local base_path="${ARTIFACT_URL}/stackwatch/build/${current_year}/${current_month}"

    case "${version}" in
        latest)
            download_url="${base_path}/latest/stackwatch-latest.tar.gz"
            ;;
        beta)
            download_url="${base_path}/beta/stackwatch-beta.tar.gz"
            ;;
        *)
            # Specific version - check in archive
            download_url="${base_path}/archive/stackwatch-${version}.tar.gz"
            ;;
    esac

    echo "${download_url}"
}

# Download package
download_package() {
    local download_url="$1"
    local output_file="$2"

    log_step "Downloading StackWatch package..."
    log_info "URL: ${download_url}"

    local http_code
    http_code=$(curl -fsSL -w "%{http_code}" -o "${output_file}" "${download_url}" 2>/dev/null || echo "000")

    if [[ "${http_code}" != "200" ]] || [[ ! -s "${output_file}" ]]; then
        log_error "Failed to download package (HTTP ${http_code})"

        if [[ "${STACKWATCH_VERSION}" != "latest" ]] && [[ "${STACKWATCH_VERSION}" != "beta" ]]; then
            log_info "Checking available versions in archive..."
            echo ""
            local current_year=$(date +%Y)
            local current_month=$(date +%m)
            local archive_url="${ARTIFACT_URL}/stackwatch/build/${current_year}/${current_month}/archive/"
            log_info "Try one of these versions:"
            curl -fsSL "${archive_url}" 2>/dev/null | grep -oP 'stackwatch-\K[0-9.-]+(?=\.tar\.gz)' | sort -V | tail -10 || true
        fi
        exit 1
    fi

    local file_size
    file_size=$(du -h "${output_file}" | cut -f1)
    log_info "Downloaded: ${file_size}"
}

# Extract package
extract_package() {
    local archive="$1"
    local dest_dir="$2"

    log_step "Extracting package to ${dest_dir}..."

    # Create parent directory if needed
    mkdir -p "$(dirname "${dest_dir}")"

    # Backup existing installation if present
    if [[ -d "${dest_dir}" ]]; then
        local backup_dir="${dest_dir}.backup.$(date +%Y%m%d%H%M%S)"
        log_warn "Existing installation found. Backing up to ${backup_dir}"
        mv "${dest_dir}" "${backup_dir}"
    fi

    # Create temp extraction directory
    local extract_dir="${TEMP_DIR}/extract"
    mkdir -p "${extract_dir}"

    # Extract archive
    tar -xzf "${archive}" -C "${extract_dir}"

    # Find the extracted directory (handles different naming)
    local extracted_name
    extracted_name=$(ls "${extract_dir}" | head -1)

    if [[ -z "${extracted_name}" ]]; then
        log_error "Failed to extract package - archive appears to be empty"
        exit 1
    fi

    # Move to final location
    mv "${extract_dir}/${extracted_name}" "${dest_dir}"

    log_info "Extracted to: ${dest_dir}"
}

# Get version info
get_version_info() {
    local install_dir="$1"

    if [[ -f "${install_dir}/metadata.json" ]]; then
        local version build_date
        version=$(grep -oP '"version":\s*"\K[^"]+' "${install_dir}/metadata.json" 2>/dev/null || echo "unknown")
        build_date=$(grep -oP '"build_date":\s*"\K[^"]+' "${install_dir}/metadata.json" 2>/dev/null || echo "unknown")
        echo "${version} (built: ${build_date})"
    else
        echo "unknown"
    fi
}

# Run deployment
run_deployment() {
    local install_dir="$1"
    local deploy_script="${install_dir}/scripts/deploy-from-opt.sh"

    log_step "Running StackWatch deployment..."
    echo ""

    if [[ -f "${deploy_script}" ]]; then
        chmod +x "${deploy_script}"

        # Export install directory for the deploy script
        export INSTALL_DIR="${install_dir}"

        # Run deployment
        if ! "${deploy_script}"; then
            log_error "Deployment script failed"
            exit 1
        fi
    else
        log_error "Deployment script not found: ${deploy_script}"
        log_info "Package may be incomplete. Please check the download."
        exit 1
    fi
}

# Print completion message
print_completion() {
    local install_dir="$1"
    local version_info
    version_info=$(get_version_info "${install_dir}")

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}           ${BOLD}StackWatch Installation Complete!${NC}              ${GREEN}║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Version:${NC}    ${version_info}"
    echo -e "  ${BOLD}Location:${NC}   ${install_dir}"
    echo ""
    echo -e "  ${BOLD}Quick Commands:${NC}"
    echo "    Health check:  ${install_dir}/scripts/health-check.sh"
    echo "    View logs:     /var/log/stackwatch/deploy.log"
    echo ""
}

# Main installation function
main() {
    print_banner

    log_info "StackWatch Installer v1.0"
    log_info "Version to install: ${STACKWATCH_VERSION}"
    log_info "Install directory: ${INSTALL_DIR}"
    echo ""

    # Pre-flight checks
    check_root
    check_requirements

    # Create temp directory
    mkdir -p "${TEMP_DIR}"

    # Get download URL
    local download_url
    download_url=$(get_download_url "${STACKWATCH_VERSION}")

    # Download package
    local archive_file="${TEMP_DIR}/stackwatch.tar.gz"
    download_package "${download_url}" "${archive_file}"

    # Extract package
    extract_package "${archive_file}" "${INSTALL_DIR}"

    # Run deployment
    run_deployment "${INSTALL_DIR}"

    # Print completion
    print_completion "${INSTALL_DIR}"
}

# Run main
main
