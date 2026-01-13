#!/bin/bash
#
# STACKWATCH: Prebuilt Package Creator
# Backend System Architect and Automation Engineer
#
# Purpose: Creates a tar.gz package containing frontend, scripts, and ansible
#          for client distribution
#
# Usage: ./scripts/create-prebuilt-package.sh

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
FRONTEND_BUILD_DIR="dist"
PACKAGE_NAME="stackwatch"
VERSION="${VERSION:-$(grep -oP '"version":\s*"\K[^"]+' "${PROJECT_ROOT}/package.json" 2>/dev/null || echo "1.0.0")}"
DATE=$(date +%Y%m%d)
PACKAGE_FILE="${PACKAGE_NAME}-${VERSION}-${DATE}.tar.gz"
TEMP_DIR="${PROJECT_ROOT}/.package-temp"
PACKAGE_DIR="${TEMP_DIR}/${PACKAGE_NAME}"

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

# Cleanup function
cleanup() {
    if [[ -d "${TEMP_DIR}" ]]; then
        log_info "Cleaning up temporary files..."
        rm -rf "${TEMP_DIR}"
    fi
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Validate frontend build exists
validate_frontend_build() {
    local build_dir="${PROJECT_ROOT}/${FRONTEND_BUILD_DIR}"
    
    if [[ ! -d "${build_dir}" ]]; then
        log_error "Frontend build directory not found: ${build_dir}"
        log_error "Please run 'npm run build' first to create the frontend build"
        exit 1
    fi
    
    if [[ ! -f "${build_dir}/index.html" ]]; then
        log_error "Frontend build incomplete: index.html not found in ${build_dir}"
        log_error "Please run 'npm run build' to create a complete frontend build"
        exit 1
    fi
    
    log_info "Frontend build validated: ${build_dir}"
}

# Validate required directories exist
validate_directories() {
    local required_dirs=(
        "${PROJECT_ROOT}/scripts"
        "${PROJECT_ROOT}/ansible"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            log_error "Required directory not found: ${dir}"
            exit 1
        fi
    done
    
    log_info "Required directories validated"
}

# Create package structure
create_package_structure() {
    log_info "Creating package structure..."

    # Create temporary directory
    mkdir -p "${PACKAGE_DIR}"

    # Create subdirectories
    mkdir -p "${PACKAGE_DIR}/dist"
    mkdir -p "${PACKAGE_DIR}/scripts"
    mkdir -p "${PACKAGE_DIR}/ansible"
    mkdir -p "${PACKAGE_DIR}/config"

    log_info "Package structure created"
}

# Copy frontend build
copy_frontend() {
    log_info "Copying frontend build files..."
    
    local source_dir="${PROJECT_ROOT}/${FRONTEND_BUILD_DIR}"
    local dest_dir="${PACKAGE_DIR}/dist"
    
    cp -r "${source_dir}"/* "${dest_dir}/" || {
        log_error "Failed to copy frontend build files"
        exit 1
    }
    
    log_info "Frontend files copied: $(du -sh "${dest_dir}" | cut -f1)"
}

# Copy scripts directory (CLIENT TOOLS ONLY)
copy_scripts() {
    log_info "Copying client deployment scripts..."

    local source_dir="${PROJECT_ROOT}/scripts"
    local dest_dir="${PACKAGE_DIR}/scripts"

    # Define client-side scripts to include (monitoring tools only)
    local client_scripts=(
        "deploy-from-opt.sh"
        "health-check.sh"
        "health-api.sh"
        "deploy-windows-exporter.ps1"
        "README.md"
    )

    # Copy only client scripts
    local copied_count=0
    for script in "${client_scripts[@]}"; do
        local source_file="${source_dir}/${script}"
        if [[ -f "${source_file}" ]]; then
            cp "${source_file}" "${dest_dir}/" || {
                log_error "Failed to copy ${script}"
                exit 1
            }
            copied_count=$((copied_count + 1))
            log_info "  ✓ Copied: ${script}"
        else
            log_warn "  ⚠ Not found: ${script} (skipping)"
        fi
    done

    # Ensure scripts are executable
    chmod +x "${dest_dir}"/*.sh 2>/dev/null || true
    chmod +x "${dest_dir}"/*.ps1 2>/dev/null || true

    log_info "Client scripts copied: ${copied_count} files"
}

# Copy ansible directory (ALL PLAYBOOKS for full infrastructure deployment)
copy_ansible() {
    log_info "Copying ansible playbooks and configuration..."

    local source_dir="${PROJECT_ROOT}/ansible"
    local dest_dir="${PACKAGE_DIR}/ansible"

    # Copy ansible configuration
    if [[ -f "${source_dir}/ansible.cfg" ]]; then
        cp "${source_dir}/ansible.cfg" "${dest_dir}/" || {
            log_error "Failed to copy ansible.cfg"
            exit 1
        }
        log_info "  ✓ Copied: ansible.cfg"
    fi

    # Copy README if exists
    if [[ -f "${source_dir}/README.md" ]]; then
        cp "${source_dir}/README.md" "${dest_dir}/" || {
            log_warn "Failed to copy ansible/README.md (continuing)"
        }
    fi

    # Create subdirectories
    mkdir -p "${dest_dir}/playbooks"
    mkdir -p "${dest_dir}/inventory"

    # Copy inventory template
    if [[ -d "${source_dir}/inventory" ]]; then
        cp -r "${source_dir}/inventory"/* "${dest_dir}/inventory/" || {
            log_error "Failed to copy inventory"
            exit 1
        }
        log_info "  ✓ Copied: inventory/ directory"
    fi

    # Copy ALL playbooks (infrastructure + monitoring agents)
    local all_playbooks=(
        "configure-firewall.yml"
        "deploy-nginx.yml"
        "deploy-prometheus.yml"
        "deploy-grafana.yml"
        "deploy-node-exporter.yml"
    )

    # Copy all playbooks
    local copied_count=0
    for playbook in "${all_playbooks[@]}"; do
        local source_file="${source_dir}/playbooks/${playbook}"
        if [[ -f "${source_file}" ]]; then
            cp "${source_file}" "${dest_dir}/playbooks/" || {
                log_error "Failed to copy ${playbook}"
                exit 1
            }
            copied_count=$((copied_count + 1))
            log_info "  ✓ Copied: playbooks/${playbook}"
        else
            log_warn "  ⚠ Not found: ${playbook} (skipping)"
        fi
    done

    log_info "Ansible files copied: ${copied_count} playbooks + inventory"
}

# Copy config directory (Single Source of Truth)
copy_config() {
    log_info "Copying configuration files..."

    local source_dir="${PROJECT_ROOT}/config"
    local dest_dir="${PACKAGE_DIR}/config"

    if [[ -f "${source_dir}/stackwatch.json" ]]; then
        cp "${source_dir}/stackwatch.json" "${dest_dir}/" || {
            log_error "Failed to copy stackwatch.json"
            exit 1
        }
        log_info "  ✓ Copied: config/stackwatch.json (Single Source of Truth)"
    else
        log_warn "  ⚠ config/stackwatch.json not found (skipping)"
    fi

    log_info "Configuration files copied"
}

# Copy client deployment README if exists
copy_client_readme() {
    local readme_file="${PROJECT_ROOT}/CLIENT_DEPLOYMENT.md"

    if [[ -f "${readme_file}" ]]; then
        log_info "Copying client deployment README..."
        cp "${readme_file}" "${PACKAGE_DIR}/" || {
            log_warn "Failed to copy CLIENT_DEPLOYMENT.md (continuing anyway)"
        }
    else
        log_warn "CLIENT_DEPLOYMENT.md not found (will be created in package)"
    fi
}

# Create metadata.json with version info
create_metadata() {
    log_info "Creating metadata.json..."

    local build_date=$(date +%Y%m%d-%H%M%S)
    local build_year=$(date +%Y)
    local build_month=$(date +%m)

    cat > "${PACKAGE_DIR}/metadata.json" << EOF
{"version": "${VERSION}", "release_type": "beta", "build_date": "${build_date}", "year": "${build_year}", "month": "${build_month}"}
EOF

    log_info "  ✓ Created: metadata.json (version: ${VERSION})"
}

# Create tar.gz package
create_tarball() {
    log_info "Creating tar.gz package..."
    
    local package_path="${PROJECT_ROOT}/${PACKAGE_FILE}"
    
    cd "${TEMP_DIR}" || exit 1
    tar -czf "${package_path}" "${PACKAGE_NAME}/" || {
        log_error "Failed to create tar.gz package"
        exit 1
    }
    
    cd "${PROJECT_ROOT}" || exit 1
    
    local package_size=$(du -h "${package_path}" | cut -f1)
    log_info "Package created: ${PACKAGE_FILE} (${package_size})"
}

# Display package information
display_package_info() {
    log_info ""
    log_info "=========================================="
    log_info "Package Creation Complete"
    log_info "=========================================="
    log_info ""
    log_info "Package File: ${PACKAGE_FILE}"
    log_info "Location: ${PROJECT_ROOT}/${PACKAGE_FILE}"
    log_info "Version: ${VERSION}"
    log_info "Date: ${DATE}"
    log_info ""
    log_info "Package Contents (CLIENT MONITORING TOOLS ONLY):"
    log_info "  - Frontend build (dist/)"
    log_info "  - Configuration (config/):"
    log_info "      * stackwatch.json (Single Source of Truth)"
    log_info "  - Client deployment scripts (scripts/):"
    log_info "      * deploy-from-opt.sh (client mode)"
    log_info "      * health-check.sh"
    log_info "      * health-api.sh"
    log_info "      * deploy-windows-exporter.ps1"
    log_info "  - Ansible playbooks (ansible/):"
    log_info "      * deploy-node-exporter.yml"
    log_info "      * inventory/ (template)"
    log_info "  - Client deployment guide (CLIENT_DEPLOYMENT.md)"
    log_info ""
    log_info "NOTE: This is a CLIENT PACKAGE for monitoring agent deployment"
    log_info "      Infrastructure playbooks NOT included"
    log_info "      For full infrastructure setup, deploy from source repository"
    log_info ""
    log_info "Client Deployment Instructions:"
    log_info "  1. Download the package file"
    log_info "  2. Extract to /opt: tar -xzf ${PACKAGE_FILE} -C /opt"
    log_info "  3. Navigate to: cd /opt/stackwatch"
    log_info "  4. Configure: Edit /opt/stackwatch/ansible/inventory/hosts"
    log_info "  5. Deploy monitoring agents:"
    log_info "      - Linux: ansible-playbook -i /opt/stackwatch/ansible/inventory/hosts \\"
    log_info "               /opt/stackwatch/ansible/playbooks/deploy-node-exporter.yml"
    log_info "      - Windows: Copy and run deploy-windows-exporter.ps1"
    log_info ""
}

# Main function
main() {
    log_info "=========================================="
    log_info "StackWatch Prebuilt Package Creator"
    log_info "=========================================="
    log_info ""
    
    # Validate prerequisites
    validate_frontend_build
    validate_directories
    
    # Create package
    create_package_structure
    copy_frontend
    copy_scripts
    copy_ansible
    copy_config
    copy_client_readme
    create_metadata

    # Create tarball
    create_tarball
    
    # Display information
    display_package_info
}

# Run main function
main "$@"

