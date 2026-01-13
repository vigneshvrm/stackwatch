# StackWatch

A production-ready monitoring dashboard for infrastructure observability using Prometheus, Grafana, and Node Exporter.

## Features

- **Modern Dashboard**: React-based frontend with glassmorphism design
- **Prometheus Integration**: 90-day data retention with configurable storage limits
- **Grafana Dashboards**: Pre-configured visualizations with secure authentication
- **Node Exporter**: Automated deployment for Linux servers
- **Windows Exporter**: PowerShell deployment script for Windows servers
- **Single Source of Truth**: All configuration centralized in `config/stackwatch.json`

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    StackWatch Frontend                       │
│                 (React + Vite + TypeScript)                  │
└─────────────────────────────────────────────────────────────┘
                              │
                         Nginx Reverse Proxy
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   Prometheus    │  │     Grafana     │  │   Health API    │
│   (Port 9090)   │  │   (Port 3000)   │  │   (Port 8888)   │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │
         │ Scrapes metrics from
         ▼
┌─────────────────────────────────────────────────────────────┐
│              Node Exporter (Linux) - Port 9100              │
│           Windows Exporter (Windows) - Port 9182            │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Node.js 18+
- Podman or Docker
- Ansible (for infrastructure deployment)

### Development

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build
```

### Production Deployment

#### Option 1: One-Liner Install (Recommended)

```bash
curl -fsSL https://artifact.stackwatch.io/stackwatch/install.sh | sudo bash
```

#### Option 2: Manual Installation

```bash
# Download package
wget https://artifact.stackwatch.io/stackwatch/build/YYYY/MM/latest/stackwatch-latest.tar.gz

# Extract to /opt
sudo tar -xzf stackwatch-latest.tar.gz -C /opt

# Run deployment
sudo /opt/stackwatch/scripts/deploy-from-opt.sh
```

## Configuration

### Single Source of Truth

All configuration is centralized in `config/stackwatch.json`:

```json
{
  "versions": {
    "prometheus": "v2.53.0",
    "grafana": "11.2.0",
    "node_exporter": "1.8.0"
  },
  "resources": {
    "prometheus": { "memory": "4g", "cpus": "2" },
    "grafana": { "memory": "2g", "cpus": "2" }
  },
  "retention": {
    "prometheus_data_days": 90,
    "prometheus_storage_limit": "50GB"
  },
  "ports": {
    "prometheus": 9090,
    "grafana": 3000,
    "node_exporter": 9100,
    "health_api": 8888
  }
}
```

### Key Configuration Sections

| Section | Description |
|---------|-------------|
| `versions` | Pinned container image versions |
| `resources` | Memory and CPU limits for containers |
| `retention` | Data retention settings for Prometheus |
| `ports` | Service port mappings |
| `paths` | Installation and data directories |

## Project Structure

```
stackwatch/
├── config/
│   └── stackwatch.json      # Single Source of Truth
├── ansible/
│   ├── playbooks/
│   │   ├── deploy-prometheus.yml
│   │   ├── deploy-grafana.yml
│   │   ├── deploy-nginx.yml
│   │   └── deploy-node-exporter.yml
│   └── inventory/
├── scripts/
│   ├── deploy-from-opt.sh   # Main deployment script
│   ├── deploy-prometheus.sh
│   ├── deploy-grafana.sh
│   ├── deploy-nginx.sh
│   ├── health-check.sh
│   ├── health-api.sh
│   └── deploy-windows-exporter.ps1
├── src/                     # React frontend source
├── dist/                    # Built frontend (after npm run build)
├── Jenkinsfile              # CI/CD pipeline
└── package.json
```

## Ansible Playbooks

### Deploy Infrastructure

```bash
# Deploy Prometheus
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/deploy-prometheus.yml

# Deploy Grafana
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/deploy-grafana.yml

# Deploy Nginx
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/deploy-nginx.yml
```

### Deploy Monitoring Agents

```bash
# Deploy Node Exporter to Linux servers
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/deploy-node-exporter.yml

# Deploy Windows Exporter (run on Windows)
powershell -ExecutionPolicy Bypass -File scripts/deploy-windows-exporter.ps1
```

## CI/CD Pipeline

The project uses Jenkins for CI/CD with three release channels:

| Release Type | Description |
|--------------|-------------|
| `beta` | Build from source, deploy to beta folder |
| `latest` | Promote current beta to latest (no rebuild) |
| `archive` | Previous latest versions (auto-archived for rollback) |

### Build URLs

| Channel | URL |
|---------|-----|
| Beta | `https://artifact.stackwatch.io/stackwatch/build/YYYY/MM/beta/stackwatch-beta.tar.gz` |
| Latest | `https://artifact.stackwatch.io/stackwatch/build/YYYY/MM/latest/stackwatch-latest.tar.gz` |
| Archive | `https://artifact.stackwatch.io/stackwatch/build/YYYY/MM/archive/stackwatch-<version>.tar.gz` |

**Note:** When promoting beta to latest, the previous latest version is automatically archived for rollback purposes.

## Production Settings

### Prometheus

- **Retention**: 90 days
- **Storage Limit**: 50GB
- **Memory**: 4GB
- **CPUs**: 2
- **Health Check**: Enabled

### Grafana

- **Memory**: 2GB
- **CPUs**: 2
- **Database**: SQLite
- **Authentication**: Secure auto-generated password
- **Health Check**: Enabled

## Scripts

| Script | Purpose |
|--------|---------|
| `deploy-from-opt.sh` | Main deployment from /opt/stackwatch |
| `health-check.sh` | Check service health status |
| `health-api.sh` | HTTP API wrapper for health checks |
| `configure-firewall.sh` | Configure firewall rules |
| `create-prebuilt-package.sh` | Create distribution tarball |

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | StackWatch Dashboard |
| `/api/health` | Health status JSON |
| `/prometheus/` | Prometheus UI |
| `/grafana/` | Grafana UI |

## License

Proprietary - StackWatch

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branchArchive
5. Create a Pull Request
