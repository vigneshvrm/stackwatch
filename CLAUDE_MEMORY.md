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

## Project: StackWatch

### What Is It?
**StackWatch** is a centralized observability gateway - a single dashboard to monitor your entire infrastructure through Prometheus and Grafana.

Think of it as: **One door to see all your servers' health and performance.**

### Why Does It Exist?
- Instead of remembering multiple URLs and ports (Prometheus:9090, Grafana:3000, etc.)
- You access everything through ONE clean interface
- Security: Internal ports are blocked; everything goes through the gateway

---

## CI/CD Pipeline (NEW)

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
| `artifact-server/promote-beta-to-latest.sh` | Promote tested beta to latest |
| `CICD_SETUP_GUIDE.md` | Complete setup instructions |

---

## What Has Been Built (Completed)

### Frontend (React Web App)
| Feature | Status | Description |
|---------|--------|-------------|
| Main Dashboard | Done | Shows service cards (Prometheus, Grafana, Help) |
| Dark/Light Theme | Done | Toggle with system preference detection |
| Health Status | Done | Real-time system health indicator |
| Help Documentation | Done | Built-in docs viewer with sidebar |
| Responsive Design | Done | Works on mobile, tablet, desktop |

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

### CI/CD Pipeline (NEW - Done)
| Feature | Status | Description |
|---------|--------|-------------|
| Jenkinsfile | Done | Pipeline with beta/latest options |
| Artifact Server Config | Done | Nginx + setup scripts |
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
- **Tailwind CSS** - Styling
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
│   ├── App.tsx                   # Main app with routing
│   ├── index.tsx                 # Entry point
│   ├── constants.tsx             # App config
│   ├── types.ts                  # TypeScript types
│   ├── components/               # UI components
│   │   ├── Dashboard.tsx
│   │   ├── HelpPage.tsx
│   │   ├── ServiceCard.tsx
│   │   └── ...
│   └── contexts/                 # React contexts
│       └── ThemeContext.tsx
│
├── docs/                         # Documentation
│   ├── architecture/             # System design docs
│   │   ├── API_MODEL.md
│   │   ├── ARCHITECTURE_OVERVIEW.md
│   │   ├── ARCHITECTURE_DIAGRAM.md
│   │   ├── SECURITY_DESIGN.md
│   │   └── WORKFLOW_DIAGRAMS.md
│   ├── deployment/               # Deployment guides
│   │   ├── CICD_SETUP_GUIDE.md
│   │   ├── CLIENT_DEPLOYMENT_GUIDE.md
│   │   ├── BACKEND_DEPLOYMENT_FLOW.md
│   │   └── ...
│   └── operations/               # Operational docs
│       ├── OPERATIONAL_RUNBOOK.md
│       ├── OPERATIONS_GUIDE.md
│       ├── GAP_ANALYSIS.md
│       └── ...
│
├── scripts/                      # Backend Scripts
│   ├── deploy-stackbill.sh
│   ├── create-prebuilt-package.sh
│   └── (other scripts)
│
├── artifact-server/              # CI/CD Artifact Server
│   ├── index.html                # Download website
│   ├── nginx-artifact.conf
│   ├── setup-artifact-server.sh
│   └── promote-beta-to-latest.sh
│
├── ansible/                      # Ansible Automation
│
├── Jenkinsfile                   # CI/CD Pipeline config
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

### Promote Beta to Latest
```bash
# On artifact server
./promote-beta-to-latest.sh 2025 01
```

---

## Future Plans / Roadmap

> Update this section as we plan new features

### Planned Features
1. [ ] (Add your next feature idea here)
2. [ ] (Add more ideas as we discuss)

### Known Issues
- (Document any bugs or issues here)

### Improvements Needed
- (Document enhancement ideas here)

---

## Session Notes

> Use this section to track our conversation progress

### Current Session
- **Date**: 2026-01-12
- **Status**: Project structure reorganization completed
- **What Was Done**:
  - Reorganized project structure for better maintainability
  - Moved all frontend source files to `src/` folder
  - Organized documentation into `docs/architecture/`, `docs/deployment/`, `docs/operations/`
  - Updated vite.config.ts, tsconfig.json, index.html for new paths
  - Cleaned up unnecessary files from root
- **Next Steps**: Verify build works, commit changes

### Previous Sessions
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

# Download latest build
curl -LO https://artifact.stackwatch.io/stackwatch/build/YYYY/MM/latest/stackwatch-latest.tar.gz
```

---

## Remember

1. **Check this file first** when context is unclear
2. **Update this file** after major changes
3. **Never guess** - always refer to actual code
4. **Write working code** - no placeholders or pseudo-code
5. **No pre-built files in git** - .gitignore excludes dist/, *.tar.gz

---

*Last Updated: 2026-01-12*
