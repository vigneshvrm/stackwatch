# Claude Memory & Project Reference

> **Purpose**: This document serves as Claude's memory reference for the StackWatch project. Check this file whenever context is unclear or forgotten.

---

## My Role

I am acting as your **Coder Expert & UI/UX Designer**. You (the user) have the ideas, and I write all the code. You don't need to know coding - just tell me what you want, and I'll build it.

### My Responsibilities:
1. **Write all code** - Frontend (React), Backend (Scripts), Infrastructure (Ansible)
2. **Design UI/UX** - Create beautiful, user-friendly interfaces
3. **Never hallucinate** - Only write proper, working code
4. **Check this document** - When memory is unclear, refer here first
5. **Update this document** - Keep track of progress and plans

---

## Architecture Rules (CRITICAL - MUST FOLLOW)

### Single Source of Truth - `config/stackwatch.json`

**ALL configuration lives in ONE file**: `config/stackwatch.json`

| Category | What's Stored |
|----------|---------------|
| versions | Prometheus, Grafana, Node Exporter, Windows Exporter |
| images | Container image URLs |
| resources | Memory, CPU limits for each service |
| retention | Data retention days, storage limits, backup days |
| paths | Data directories, backup directories |
| ports | Service ports |

**Rules:**
- **Policy**: Manual updates only - you (user) control all changes
- **NEVER hardcode values** in playbooks, scripts, Jenkinsfile, or frontend
- **All consumers MUST read from this file**:
  - Ansible playbooks (`deploy-prometheus.yml`, `deploy-grafana.yml`)
  - Jenkins build
  - Backup/upgrade scripts
  - Frontend (if needed for display)

**Why**: Single file = easy to maintain, no version drift, consistent deployments

### Current Configuration (as of 2026-01-13)
```json
{
  "versions": {
    "prometheus": "v2.53.0",
    "grafana": "11.2.0",
    "node_exporter": "1.8.0",
    "windows_exporter": "0.25.1"
  },
  "resources": {
    "prometheus": { "memory": "4g", "cpus": "2" },
    "grafana": { "memory": "2g", "cpus": "2" }
  },
  "retention": {
    "prometheus_data_days": 90,
    "prometheus_storage_limit": "50GB",
    "backup_days": 7
  }
}
```

### Production Settings
| Setting | Value | Purpose |
|---------|-------|---------|
| Prometheus retention | 90 days | Keep metrics for 3 months |
| Storage limit | 50GB | Prevent disk overflow |
| Prometheus memory | 4GB | Handle ~1000 samples/sec |
| Grafana memory | 2GB | Multiple concurrent dashboards |
| Backups | Daily at 2-3 AM | 7-day retention |
| Image versions | Pinned | No `:latest` for stability |

---

## Project: StackWatch

### What Is It?
**StackWatch** is a centralized observability gateway - a single dashboard to monitor your entire infrastructure through Prometheus and Grafana.

Think of it as: **One door to see all your servers' health and performance.**

### Why Does It Exist?
- Instead of remembering multiple URLs and ports (Prometheus:9090, Grafana:3000, etc.)
- You access everything through ONE clean interface
- Security: Internal ports are blocked; everything goes through the gateway

---

## Deployment Architecture (CRITICAL TO UNDERSTAND)

### Three-Tier Architecture
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DEPLOYMENT FLOW                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐         ┌──────────────────────┐         ┌─────────────┐  │
│  │  StackWatch  │ builds  │   Artifact Server    │ serves  │  Monitoring │  │
│  │   (GitLab/   │ ──────► │ artifact.stackwatch  │ ──────► │   Server    │  │
│  │   Jenkins)   │         │       .io            │         │  (Client)   │  │
│  └──────────────┘         └──────────────────────┘         └──────┬──────┘  │
│                                                                    │         │
│                                                                    │ deploys │
│                                                                    │ agents  │
│                                                                    ▼         │
│                                                            ┌─────────────┐   │
│                                                            │  End User   │   │
│                                                            │  Machines   │   │
│                                                            │ (monitored) │   │
│                                                            └─────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Understanding Each Component:

#### 1. StackWatch (Source Code Repository)
- **Location**: GitLab repository
- **Purpose**: Contains all source code, scripts, and configurations
- **Built by**: Jenkins CI/CD pipeline

#### 2. Artifact Server (artifact.stackwatch.io)
- **Purpose**: Hosts downloadable builds (tarballs)
- **URL**: `https://artifact.stackwatch.io/`
- **Contains**:
  - Download website (index.html with version selector)
  - Build artifacts (stackwatch-beta.tar.gz, stackwatch-latest.tar.gz)
  - Installation script (install.sh)

#### 3. Monitoring Server (StackWatch Client)
- **What it is**: A server where user runs the curl installer
- **What gets installed**:
  - Full infrastructure: Nginx, Prometheus, Grafana (via Podman)
  - StackWatch React dashboard
  - ALL Ansible playbooks for infrastructure management
- **Purpose**: Central monitoring hub that collects metrics from end-user machines

#### 4. End User Machines (Monitored Servers)
- **What they are**: Linux/Windows servers to be monitored
- **What gets deployed to them**: Node Exporter (Linux) or Windows Exporter
- **Deployed by**: Monitoring Server runs Ansible playbooks against these machines
- **Purpose**: Export metrics to Prometheus on the Monitoring Server

### Installation Flow:
```bash
# On Monitoring Server:
curl -sSL https://artifact.stackwatch.io/install.sh | sudo bash -s -- --version beta

# This installs:
# 1. StackWatch React UI
# 2. Nginx (reverse proxy)
# 3. Prometheus (metrics collection)
# 4. Grafana (visualization)
# 5. Ansible playbooks to deploy exporters to end-user machines
```

### Key Insight:
The tarball must contain ALL infrastructure playbooks because the **Monitoring Server** needs to:
1. Set up its own monitoring stack (Nginx, Prometheus, Grafana)
2. Deploy Node Exporter to Linux end-user machines
3. Deploy Windows Exporter to Windows end-user machines

---

## CI/CD Pipeline

### Overview
```
┌─────────────┐      ┌─────────────┐      ┌─────────────────────────────────┐
│   GitLab    │ ──►  │   Jenkins   │ ──►  │   artifact.stackwatch.io        │
│  (Source)   │      │   (Build)   │      │   (Download Server)             │
└─────────────┘      └─────────────┘      └─────────────────────────────────┘
```

### Build Flow
1. **Code in GitLab** - Source repository
2. **Jenkins builds** - With RELEASE_TYPE option (beta/latest)
3. **Artifacts deployed** - To artifact server for client download

### Artifact Server Structure
```
artifact.stackwatch.io/stackwatch/build/
└── YYYY/              # Year (2025)
    └── MM/            # Month (01, 02, etc.)
        ├── beta/      # New untested builds
        ├── latest/    # Tested stable builds
        └── archive/   # Old versions (auto-moved)
```

### Jenkins Options
| Option | Description |
|--------|-------------|
| `RELEASE_TYPE: beta` | New build, not tested yet |
| `RELEASE_TYPE: latest` | Tested, stable build (auto-archives old latest) |
| `VERSION_TAG` | Optional custom version name |

### Download URLs
- **Beta**: `https://artifact.stackwatch.io/stackwatch/build/YYYY/MM/beta/stackwatch-beta.tar.gz`
- **Latest**: `https://artifact.stackwatch.io/stackwatch/build/YYYY/MM/latest/stackwatch-latest.tar.gz`

### Key Files
| File | Purpose |
|------|---------|
| `Jenkinsfile` | Pipeline with beta/latest options |
| `artifact-server/nginx-artifact.conf` | Nginx config for artifact server |
| `artifact-server/setup-artifact-server.sh` | Server setup script |
| `artifact-server/install.sh` | Client installation script |
| `artifact-server/promote-beta-to-latest.sh` | Promote tested beta to latest |

---

## Recent Bug Fixes (2026-01-13)

### 1. Jenkinsfile - Metadata JSON Quote Issue
**Problem**: `metadata.json` had invalid JSON after Jenkins build (missing quotes)
```json
// BAD - quotes stripped by shell
{version: 1.0.0-beta, release_type: beta}

// GOOD - proper JSON
{"version": "1.0.0-beta", "release_type": "beta"}
```

**Cause**: Using `echo` with escaped quotes inside Jenkins `'''` block strips the quotes

**Fix**: Use heredoc instead of echo:
```groovy
# OLD (broken):
echo "{\"version\": \"${FINAL_VERSION}\"}" > metadata.json

# NEW (working):
cat > metadata.json << METADATA_EOF
{"version": "${FINAL_VERSION}", "release_type": "beta"}
METADATA_EOF
```

### 2. Install.sh - VERSION Variable Conflict
**Problem**: URLs contained OS version like "22.04.1 LTS (Jammy Jellyfish)" instead of StackWatch version

**Cause**: `source /etc/os-release` overwrites the `VERSION` variable (Ubuntu sets VERSION="22.04.1 LTS")

**Fix**: Renamed `VERSION` to `STACKWATCH_VERSION` throughout install.sh:
```bash
# OLD (broken):
VERSION="${DEFAULT_VERSION}"
source /etc/os-release  # This overwrites VERSION!

# NEW (working):
STACKWATCH_VERSION="${DEFAULT_VERSION}"
source /etc/os-release  # Safe, doesn't conflict
```

### 3. Install.sh - Wrong URL Paths
**Problem**: Download URLs missing year/month structure

**Fix**: Added proper path construction:
```bash
get_download_url() {
    local version="$1"
    local current_year=$(date +%Y)
    local current_month=$(date +%m)
    local base_path="${ARTIFACT_URL}/stackwatch/build/${current_year}/${current_month}"
    # ... rest of function
}
```

### 4. Tarball Missing Infrastructure Playbooks
**Problem**: Tarball only contained `deploy-node-exporter.yml`, so Monitoring Server couldn't set up full infrastructure

**Fix**: Updated `create-prebuilt-package.sh` to include ALL playbooks:
```bash
local all_playbooks=(
    "configure-firewall.yml"
    "deploy-nginx.yml"
    "deploy-prometheus.yml"
    "deploy-grafana.yml"
    "deploy-node-exporter.yml"
)
```

### 5. Version Showing "unknown" After Installation
**Problem**: `metadata.json` not included in tarball

**Fix**: Added `create_metadata()` function to `create-prebuilt-package.sh`:
```bash
create_metadata() {
    cat > "${PACKAGE_DIR}/metadata.json" << EOF
{"version": "${VERSION}", "release_type": "beta", "build_date": "${build_date}"}
EOF
}
```

---

## UI/UX Revamp (2026-01-13)

### Design Philosophy
- **Modern Glassmorphism** - Frosted glass effect with backdrop blur
- **Blue Color Theme** - Professional, consistent with monitoring/tech aesthetic
- **Component-Based** - Modular, reusable React components
- **Clean & Simple** - Only essential components, no dummy data

### Current Dashboard (Simplified)
The dashboard now shows only:
1. **Sidebar** - Navigation with system status
2. **ServiceCards** - Quick access to Prometheus, Grafana, Help
3. **Footer** - Copyright and version info

### Components REMOVED (for future release with real API integration)
The following components were created but removed because they used dummy/hardcoded data:

#### QuickStats (`src/components/QuickStats.tsx`) - KEPT BUT NOT USED
- Four metric cards: Uptime, Active Servers, Active Alerts, Metrics/sec
- **Future**: Connect to Prometheus API for real data
- **Re-enable when**: Real API integration is implemented

#### ServerStatusGrid (`src/components/ServerStatusGrid.tsx`) - KEPT BUT NOT USED
- Server cards with status, CPU, memory
- **Future**: Connect to Prometheus targets API
- **Re-enable when**: Server inventory system is implemented

#### RecentAlerts (`src/components/RecentAlerts.tsx`) - KEPT BUT NOT USED
- Alert list with severity levels
- **Future**: Connect to Alertmanager API
- **Re-enable when**: Alertmanager integration is implemented

### Active Components

#### Sidebar (`src/components/Sidebar.tsx`)
- Navigation menu with icons
- System status indicator
- Mobile responsive (slides in/out)
- Glassmorphism styling

#### App.tsx (Dashboard)
- Clean, centered layout
- Welcome message
- ServiceCards grid only
- No dummy data sections
- Removed: Search bar, Notifications bell, "Last updated" (all were non-functional)

#### ServiceCard.tsx
- Service-specific color themes:
  - Prometheus: Orange/Red
  - Grafana: Amber/Orange
  - Help: Blue/Indigo
- Glassmorphism card styling
- Hover animations (scale, rotate icon)
- Status indicator dots

#### HelpPage.tsx
- Cleaner sidebar navigation
- Breadcrumb navigation
- Better markdown content styling
- Responsive layout

### Future Release Plan
When user requests, re-enable these features with real API integration:
1. **QuickStats** - Pull from Prometheus API (`/api/v1/query`)
2. **ServerStatusGrid** - Pull from Prometheus targets (`/api/v1/targets`)
3. **RecentAlerts** - Pull from Alertmanager (`/api/v1/alerts`)

---

## What Has Been Built (Completed)

### Frontend (React Web App)
| Feature | Status | Description |
|---------|--------|-------------|
| Main Dashboard | Done | Clean, centered layout with ServiceCards only |
| Sidebar Navigation | Done | Collapsible navigation with icons |
| Service Cards | Done | Quick access to Prometheus/Grafana/Help |
| Dark/Light Theme | Done | Toggle with system preference detection |
| Help Documentation | Done | Built-in docs viewer with sidebar |
| Responsive Design | Done | Works on mobile, tablet, desktop |

### Frontend (Future - Components Ready, Need API Integration)
| Feature | Status | Description |
|---------|--------|-------------|
| Quick Stats | Ready | Needs Prometheus API connection |
| Server Status Grid | Ready | Needs Prometheus targets API |
| Recent Alerts | Ready | Needs Alertmanager API |

### Backend (Infrastructure Scripts)
| Feature | Status | Description |
|---------|--------|-------------|
| Nginx Deployment | Done | Reverse proxy setup |
| Prometheus Setup | Done | Metrics collection via Podman container |
| Grafana Setup | Done | Dashboard visualization via Podman |
| Firewall Config | Done | Security rules (blocks direct port access) |
| Health Checks | Done | Automated service validation |
| Node Exporter | Done | Linux server monitoring agent |
| Windows Exporter | Done | Windows server monitoring agent |

### CI/CD Pipeline
| Feature | Status | Description |
|---------|--------|-------------|
| Jenkinsfile | Done | Pipeline with beta/latest + heredoc fix |
| Artifact Server Config | Done | Nginx + setup scripts |
| Install Script | Done | Fixed VERSION conflict |
| Tarball Creation | Done | Includes all playbooks + metadata |
| Promote Script | Done | Move beta to latest |
| Auto-Archive | Done | Old latest moves to archive |

### Documentation
| Document | Status | Description |
|----------|--------|-------------|
| Architecture | Done | System design overview |
| Workflow Diagrams | Done | Data flow and processes |
| API Model | Done | Endpoint mapping |
| Security Design | Done | Security architecture |
| Operational Runbook | Done | Admin procedures |
| Gap Analysis | Done | Improvement roadmap |
| CI/CD Setup Guide | Done | Complete pipeline setup |

---

## Technology Stack

### Frontend
- **React 19** - UI framework
- **React Router** - Page navigation
- **Tailwind CSS** - Styling (with glassmorphism utilities)
- **Vite** - Build tool
- **TypeScript** - Type-safe JavaScript

### Backend
- **Bash/Shell** - Deployment scripts
- **Ansible** - Infrastructure automation
- **Podman** - Containers (like Docker)
- **Nginx** - Web server/reverse proxy
- **Prometheus** - Metrics collection
- **Grafana** - Visualization dashboards

### CI/CD
- **GitLab** - Source code repository
- **Jenkins** - Build automation
- **Nginx** - Artifact server

---

## Project Structure

```
stackwatch/
├── src/                          # Frontend Source Code
│   ├── App.tsx                   # Main app with Dashboard + routing
│   ├── index.tsx                 # Entry point
│   ├── constants.tsx             # App config (SERVICES, ICONS)
│   ├── types.ts                  # TypeScript types
│   ├── components/               # UI components
│   │   ├── Sidebar.tsx           # Navigation sidebar
│   │   ├── QuickStats.tsx        # Metric cards
│   │   ├── ServerStatusGrid.tsx  # Server monitoring grid
│   │   ├── RecentAlerts.tsx      # Alert list
│   │   ├── ServiceCard.tsx       # Service quick access cards
│   │   ├── HelpPage.tsx          # Documentation viewer
│   │   └── ThemeToggle.tsx       # Dark/light mode toggle
│   └── contexts/                 # React contexts
│       └── ThemeContext.tsx
│
├── docs/                         # Documentation
│   ├── architecture/             # System design docs
│   ├── deployment/               # Deployment guides
│   └── operations/               # Operational docs
│
├── scripts/                      # Backend Scripts
│   ├── deploy-stackbill.sh
│   ├── create-prebuilt-package.sh  # Creates tarball with ALL playbooks
│   └── (other scripts)
│
├── artifact-server/              # CI/CD Artifact Server
│   ├── index.html                # Download website with version selector
│   ├── install.sh                # Client installation script
│   ├── nginx-artifact.conf
│   ├── setup-artifact-server.sh
│   └── promote-beta-to-latest.sh
│
├── ansible/                      # Ansible Automation
│   ├── playbooks/
│   │   ├── configure-firewall.yml
│   │   ├── deploy-nginx.yml
│   │   ├── deploy-prometheus.yml
│   │   ├── deploy-grafana.yml
│   │   └── deploy-node-exporter.yml
│   └── ...
│
├── Jenkinsfile                   # CI/CD Pipeline config (heredoc fix)
├── README.md                     # Project readme
├── CLAUDE_MEMORY.md              # This file (Claude's memory)
│
└── Config Files
    ├── package.json
    ├── tsconfig.json
    ├── vite.config.ts
    └── .gitignore
```

---

## How To Run

### Development Mode
```bash
npm install    # Install dependencies
npm run dev    # Start dev server
```

### Production Build
```bash
npm run build  # Build to dist/
```

### Jenkins Build
1. Go to Jenkins > stackwatch
2. Click "Build with Parameters"
3. Select RELEASE_TYPE: `beta` or `latest`
4. Click Build

### Install on Monitoring Server
```bash
# Install beta version
curl -sSL https://artifact.stackwatch.io/install.sh | sudo bash -s -- --version beta

# Install latest version
curl -sSL https://artifact.stackwatch.io/install.sh | sudo bash -s -- --version latest
```

### Promote Beta to Latest
```bash
# On artifact server
./promote-beta-to-latest.sh 2025 01
```

---

## Session Notes

> Use this section to track our conversation progress

### Current Session
- **Date**: 2026-01-13
- **Status**: Upgrade System R&D + Documentation Complete
- **What Was Done**:
  1. Fixed Jenkinsfile metadata.json (heredoc for JSON quotes)
  2. Fixed install.sh VERSION conflict (renamed to STACKWATCH_VERSION)
  3. Fixed install.sh URL paths (added year/month structure)
  4. Fixed tarball to include ALL infrastructure playbooks
  5. Added metadata.json creation in create-prebuilt-package.sh
  6. Created modern glassmorphism UI (later simplified to ServiceCards only)
  7. Removed dummy components (QuickStats, ServerStatusGrid, RecentAlerts) - kept for future API integration
  8. Fixed HelpPage markdown rendering (added custom CSS styles)
  9. **Upgrade System R&D**:
     - Researched Prometheus upgrade (TSDB, breaking changes, v2→v3 path)
     - Researched Grafana upgrade (Angular removal, annotation table, plugins)
     - Researched auto-update patterns (Chrome/Electron model, Podman)
  10. Created `UPGRADE_GUIDE.md` with comprehensive documentation

### Upgrade System Plan (R&D Phase)
- **User Requirements**:
  - Security updates = Zero downtime (blue-green)
  - Feature updates = 2-5 min downtime OK
  - Update mode = Auto-download, manual apply
  - Rollback window = 7 days
- **Key Findings**:
  - Prometheus: Must go v2.x → v2.55 → v3.0 for safe rollback
  - Grafana: Angular plugins removed in v12, annotation table rewrite needs 3x disk
  - Both: Need comprehensive backup before any upgrade
- **Next Steps**: Implement version check, backup scripts, frontend notification

### Previous Sessions
- 2026-01-12: Project structure reorganization (src/, docs/ folders)
- 2026-01-11: Fixed Jenkins archive logic, metadata.json format, download page
- 2025-12-30: CI/CD pipeline setup, artifact server configuration
- 2025-12-30: Initial project review and documentation

---

## Quick Reference Commands

```bash
# Development
npm run dev           # Start dev server
npm run build         # Production build

# Jenkins (on Jenkins UI)
# Select RELEASE_TYPE: beta or latest

# Promote beta to latest (on artifact server)
./promote-beta-to-latest.sh YYYY MM

# Install StackWatch on Monitoring Server
curl -sSL https://artifact.stackwatch.io/install.sh | sudo bash -s -- --version beta

# Download tarball manually
curl -LO https://artifact.stackwatch.io/stackwatch/build/YYYY/MM/beta/stackwatch-beta.tar.gz
```

---

## Common Pitfalls to Avoid

1. **Shell Variable Expansion**: Use heredoc (`<< EOF`) for JSON in shell scripts, not echo with escaped quotes
2. **Variable Naming**: Avoid `VERSION` as variable name - conflicts with `/etc/os-release`
3. **Tarball Contents**: Must include ALL infrastructure playbooks, not just Node Exporter
4. **URL Structure**: Include year/month in artifact URLs: `/stackwatch/build/YYYY/MM/`

---

## Remember

1. **Check this file first** when context is unclear
2. **Update this file** after major changes
3. **Never guess** - always refer to actual code
4. **Write working code** - no placeholders or pseudo-code
5. **No pre-built files in git** - .gitignore excludes dist/, *.tar.gz
6. **Monitoring Server gets FULL infrastructure** - not just exporters

---

*Last Updated: 2026-01-13*
