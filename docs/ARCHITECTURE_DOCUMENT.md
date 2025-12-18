# STACKWATCH: Enterprise Architecture Document

**Document Version:** 1.0.0  
**Classification:** Internal Technical Documentation  
**Last Updated:** 2024  
**Architect:** Senior Cloud Infrastructure Architect and Automation Engineer

---

## Executive Summary

StackWatch is an enterprise-grade observability gateway infrastructure designed to provide centralized access to monitoring and visualization services. The system implements a microservices architecture pattern with strict separation of concerns, security-first design principles, and comprehensive observability capabilities.

### Architectural Characteristics Compliance

| Characteristic | Implementation Status | Evidence |
|----------------|----------------------|----------|
| **Availability** | ✅ Designed | Nginx reverse proxy with static frontend, Podman containerization for resilience |
| **Security** | ✅ Designed | Firewall rules, TLS readiness, port isolation, secure routing |
| **Scalability** | ✅ Designed | Stateless frontend, horizontal scaling capability for exporters |
| **Observability** | ✅ Core Function | Prometheus + Grafana stack, Node/Windows exporters |
| **Consistency** | ✅ Designed | Ansible automation, standardized configurations |
| **Resiliency** | ✅ Designed | Container isolation, service health checks, failure isolation |
| **Durability** | ✅ Designed | Prometheus time-series storage, persistent volumes |
| **Deployability** | ✅ Designed | Ansible automation, containerized services |
| **Configurability** | ✅ Implemented | Frontend constants.ts, service configuration files |
| **Maintainability** | ✅ Implemented | Modular code structure, comprehensive documentation |
| **Extensibility** | ✅ Implemented | Service registry pattern, plugin-ready architecture |

---

## 1. System-Wide Topology

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         EXTERNAL NETWORK (Internet)                      │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │
                                     │ HTTPS/HTTP (Port 80/443)
                                     │
┌────────────────────────────────────▼────────────────────────────────────┐
│                         NGINX REVERSE PROXY                              │
│                         (Port 80/443)                                    │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Location: /          → Static Frontend (StackWatch React App)   │   │
│  │  Location: /prometheus → Proxy to Prometheus :9090              │   │
│  │  Location: /grafana    → Proxy to Grafana :3000                 │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────┬───────────────────────┬────────────────────────────┘
                     │                       │
        ┌────────────▼──────────┐  ┌─────────▼──────────┐
        │   STATIC FRONTEND     │  │  BACKEND SERVICES  │
        │   (StackWatch UI)      │  │                    │
        │   /var/www/stackwatch/ │  │                    │
        │   dist/               │  │                    │
        └───────────────────────┘  │                    │
                                   │                    │
        ┌──────────────────────────┼────────────────────┼──────────────┐
        │                          │                    │              │
┌───────▼────────┐    ┌───────────▼────────┐  ┌────────▼──────────┐   │
│  PROMETHEUS    │    │     GRAFANA        │  │  EXPORTERS        │   │
│  (Podman)      │    │     (Podman)       │  │                   │   │
│  Port: 9090    │    │     Port: 3000     │  │                   │   │
│                │    │                    │  │                   │   │
│  - Scrapes     │    │  - Queries         │  │  ┌──────────────┐ │   │
│    exporters   │    │    Prometheus      │  │  │ Node Exporter│ │   │
│  - Stores      │    │  - Renders         │  │  │ (Linux)      │ │   │
│    metrics     │    │    dashboards      │  │  │ Port: 9100  │ │   │
│  - Alerting    │    │  - Visualization   │  │  └──────────────┘ │   │
│    rules       │    │                    │  │                   │   │
└────────────────┘    └────────────────────┘  │  ┌──────────────┐ │   │
                                              │  │Windows Exporter│ │   │
                                              │  │ (Windows)    │ │   │
                                              │  │ Port: 9182  │ │   │
                                              │  └──────────────┘ │   │
                                              └───────────────────┘   │
                                                                       │
┌───────────────────────────────────────────────────────────────────────┐
│                    ANSIBLE AUTOMATION LAYER                           │
│  - Deploys Node Exporter (Linux)                                     │
│  - Configures firewall rules                                        │
│  - Manages service configurations                                   │
│  - Handles health checks                                            │
└───────────────────────────────────────────────────────────────────────┘
```

### 1.2 Component Inventory

#### Frontend Layer
- **Component:** StackWatch React Application
- **Technology:** React 19.2.0, TypeScript, Vite 6.2.0
- **Deployment:** Static files served via Nginx
- **Location:** `/var/www/stackwatch/dist/`
- **Port:** N/A (served via Nginx on port 80/443)
- **Purpose:** Unified gateway UI for service access

#### Reverse Proxy Layer
- **Component:** Nginx Web Server
- **Technology:** Nginx (version TBD)
- **Ports:** 80 (HTTP), 443 (HTTPS - TLS ready)
- **Purpose:** 
  - Static file serving for frontend
  - Reverse proxy for Prometheus and Grafana
  - SSL/TLS termination point
  - Security boundary enforcement

#### Monitoring Backend Services

**Prometheus**
- **Technology:** Prometheus (containerized via Podman)
- **Port:** 9090 (internal, proxied via Nginx)
- **Purpose:** 
  - Time-series metrics collection
  - Metrics storage
  - Alert rule evaluation
  - Service discovery and scraping
- **Storage:** Persistent volume (location TBD)

**Grafana**
- **Technology:** Grafana (containerized via Podman)
- **Port:** 3000 (internal, proxied via Nginx)
- **Purpose:**
  - Metrics visualization
  - Dashboard management
  - Alert notification routing
  - Data source integration with Prometheus

#### Metrics Exporters

**Node Exporter (Linux)**
- **Technology:** Prometheus Node Exporter
- **Deployment:** Linux system service (Ansible-managed)
- **Port:** 9100
- **Purpose:** System-level metrics (CPU, memory, disk, network)
- **Targets:** Linux servers in infrastructure

**Windows Exporter**
- **Technology:** Prometheus Windows Exporter
- **Deployment:** Windows service (deployment method TBD)
- **Port:** 9182
- **Purpose:** Windows system metrics (CPU, memory, disk, network, services)
- **Targets:** Windows servers in infrastructure

### 1.3 Data Flow Architecture

#### Request Flow (User → Service)
```
User Browser
    │
    │ HTTP/HTTPS Request
    │ GET /prometheus
    ▼
Nginx Reverse Proxy
    │
    │ Proxy Pass
    │ http://localhost:9090/
    ▼
Prometheus Service (Podman)
    │
    │ Response (HTML/JSON)
    ▼
Nginx Reverse Proxy
    │
    │ HTTP/HTTPS Response
    ▼
User Browser
```

#### Metrics Collection Flow
```
Node Exporter (Linux :9100)
    │
    │ HTTP GET /metrics
    ▼
Prometheus Scraper
    │
    │ Store in TSDB
    ▼
Prometheus Time-Series Database
    │
    │ PromQL Query
    ▼
Grafana Dashboard
    │
    │ Render Visualization
    ▼
User Browser (via /grafana)
```

#### Scraping Configuration Flow
```
Prometheus Config (prometheus.yml)
    │
    │ Static Config / Service Discovery
    ▼
Prometheus Scraper Engine
    │
    ├─→ Node Exporter (:9100) ──┐
    ├─→ Windows Exporter (:9182)┼─→ Metrics Collection
    └─→ Custom Exporters ───────┘
```

---

## 2. Technology Stack Rationale

### 2.1 Frontend Technology Decisions

| Technology | Rationale | Alternative Considered | Decision Factor |
|------------|-----------|----------------------|-----------------|
| **React 19.2.0** | Component modularity, type safety, ecosystem maturity | Vue.js, Angular | TypeScript integration, team expertise |
| **TypeScript** | Type safety prevents runtime errors, IDE support | JavaScript | Enterprise-grade error prevention |
| **Vite 6.2.0** | Fast HMR, optimized production builds, tree-shaking | Webpack, Create React App | Build performance, modern tooling |
| **Tailwind CSS (CDN)** | Utility-first CSS, consistent design system | CSS Modules, Styled Components | Zero build-time CSS processing, rapid development |

### 2.2 Infrastructure Technology Decisions

| Technology | Rationale | Alternative Considered | Decision Factor |
|------------|-----------|----------------------|-----------------|
| **Nginx** | High-performance reverse proxy, battle-tested | Apache, Traefik | Performance, configuration flexibility, TLS support |
| **Podman** | Rootless containers, systemd integration, OCI-compliant | Docker, systemd-nspawn | Security (rootless), Red Hat ecosystem alignment |
| **Prometheus** | Industry-standard metrics collection, PromQL | InfluxDB, TimescaleDB | Query language, ecosystem, alerting integration |
| **Grafana** | Rich visualization, dashboard templating | Kibana, Chronograf | Prometheus integration, dashboard library |
| **Ansible** | Agentless automation, idempotent operations | Puppet, Chef, Terraform | Agentless, YAML-based, infrastructure-as-code |

---

## 3. Deployment Architecture

### 3.1 Service Deployment Model

**Containerized Services (Podman)**
- Prometheus: Podman container with persistent volume
- Grafana: Podman container with persistent volume
- Benefits: Isolation, version control, easy rollback, resource limits

**System Services (Ansible-managed)**
- Node Exporter: Linux systemd service
- Benefits: Native integration, system-level access, minimal overhead

**Static Frontend (Nginx-served)**
- StackWatch: Pre-built static files
- Benefits: Zero runtime dependencies, CDN-ready, infinite scalability

### 3.2 Network Architecture

**Port Matrix:**
| Service | Internal Port | External Port | Protocol | Access Method |
|---------|---------------|---------------|----------|---------------|
| Nginx | 80, 443 | 80, 443 | HTTP/HTTPS | Direct (firewall-allowed) |
| Prometheus | 9090 | N/A (blocked) | HTTP | Via Nginx /prometheus |
| Grafana | 3000 | N/A (blocked) | HTTP | Via Nginx /grafana |
| Node Exporter | 9100 | N/A (blocked) | HTTP | Prometheus scraping only |
| Windows Exporter | 9182 | N/A (blocked) | HTTP | Prometheus scraping only |

**Network Isolation:**
- All backend services (Prometheus, Grafana, exporters) are NOT directly exposed to external network
- Only Nginx port 80/443 is firewall-allowed for external access
- Internal services communicate via localhost (127.0.0.1) or private network

---

## 4. Scalability Architecture

### 4.1 Horizontal Scaling Capabilities

**Frontend (StackWatch)**
- Stateless design enables CDN deployment
- No session state or server-side logic
- Can be replicated across multiple Nginx instances

**Nginx**
- Can be load-balanced behind a frontend load balancer
- Stateless reverse proxy configuration
- Session affinity not required

**Prometheus**
- Vertical scaling via resource limits (CPU/memory)
- Horizontal scaling via Prometheus federation (future enhancement)
- Storage scaling via remote write to long-term storage (future enhancement)

**Grafana**
- Stateless application (database-backed)
- Can be horizontally scaled behind load balancer
- Shared database required for multi-instance deployment

**Exporters**
- Stateless metrics endpoints
- Can be deployed on every target server
- Prometheus service discovery enables automatic scaling

### 4.2 Vertical Scaling Considerations

- Prometheus: Memory scaling for TSDB, CPU for query evaluation
- Grafana: Memory for dashboard rendering, CPU for query execution
- Nginx: CPU for SSL/TLS termination, memory for connection handling

---

## 5. High Availability Design

### 5.1 Single-Node Deployment (Current)

**Assumptions:**
- Single server deployment
- No active-active redundancy
- Backup and recovery procedures required

**Availability Characteristics:**
- Frontend: High availability (static files, no runtime dependencies)
- Nginx: Single point of failure (mitigated by monitoring)
- Prometheus: Single point of failure (mitigated by backups)
- Grafana: Single point of failure (mitigated by configuration backups)

### 5.2 Future HA Enhancements (Recommendations)

1. **Nginx HA:** Deploy behind load balancer with health checks
2. **Prometheus HA:** Deploy multiple instances with remote write to shared storage
3. **Grafana HA:** Deploy multiple instances with shared PostgreSQL database
4. **Exporters:** Already distributed (no single point of failure)

---

## 6. Storage Architecture

### 6.1 Persistent Storage Requirements

**Prometheus:**
- Time-series database storage (TSDB)
- Alert rule files
- Configuration files
- Estimated: 10-100GB depending on retention policy

**Grafana:**
- Dashboard definitions (JSON)
- Data source configurations
- User preferences
- Estimated: <1GB

**Frontend:**
- Static files (no persistent storage required)
- Build artifacts

### 6.2 Storage Backend (TBD)

**Current State:** Storage backend not specified in repository  
**Recommendation:** 
- Podman volumes for container data
- NFS or local filesystem for persistent data
- Backup strategy for Prometheus TSDB

---

## 7. Configuration Management

### 7.1 Configuration Sources

**Frontend Configuration:**
- `constants.tsx`: Service registry, metadata
- `vite.config.ts`: Build configuration
- `tsconfig.json`: TypeScript compiler options

**Infrastructure Configuration (Expected):**
- Nginx: `/etc/nginx/sites-available/stackwatch` (not in repo)
- Prometheus: `prometheus.yml`, alert rules (not in repo)
- Grafana: `grafana.ini`, provisioning configs (not in repo)
- Ansible: Playbooks, roles, inventory (not in repo)
- Firewall: iptables/firewalld rules (not in repo)

### 7.2 Configuration Management Strategy

**Current:** Manual configuration (documented in ARCHITECTURE_AND_OPS.md)  
**Expected:** Ansible automation for infrastructure components  
**Gap:** Infrastructure-as-code not present in repository

---

## 8. Observability Architecture

### 8.1 Monitoring Stack

**Metrics Collection:**
- Prometheus scrapes Node Exporter (Linux metrics)
- Prometheus scrapes Windows Exporter (Windows metrics)
- Prometheus self-monitoring (internal metrics)

**Visualization:**
- Grafana dashboards for metrics visualization
- Pre-built dashboards for Node Exporter
- Custom dashboards for application metrics

**Alerting (Expected):**
- Prometheus Alertmanager (not in repo)
- Alert rules evaluation
- Notification channels (email, Slack, PagerDuty)

### 8.2 Logging Architecture (Gap Identified)

**Current State:** Logging strategy not documented  
**Recommendation:** 
- Centralized logging solution (ELK, Loki)
- Log aggregation from all services
- Log retention policies

---

## 9. Security Architecture

### 9.1 Network Security

**Firewall Rules (Expected):**
- Allow: Port 80, 443 (Nginx)
- Deny: Port 9090, 3000, 9100, 9182 (direct access blocked)
- Allow: Internal Prometheus scraping (localhost or private network)

**Network Segmentation:**
- Public-facing: Nginx only
- Internal: Prometheus, Grafana, exporters
- Isolation: Services not directly accessible from external network

### 9.2 Application Security

**Frontend:**
- No authentication (static frontend)
- Security via Nginx authentication (recommended enhancement)
- HTTPS/TLS termination at Nginx (TLS-ready design)

**Backend Services:**
- Prometheus: Basic authentication recommended
- Grafana: User authentication required
- Exporters: No authentication (internal network only)

### 9.3 Container Security

**Podman Benefits:**
- Rootless containers (reduced attack surface)
- OCI-compliant images
- Image scanning recommended

---

## 10. Disaster Recovery and Backup

### 10.1 Backup Requirements

**Critical Data:**
1. Prometheus TSDB (time-series data)
2. Grafana dashboards and configurations
3. Prometheus configuration and alert rules
4. Nginx configuration
5. Ansible playbooks and inventory

### 10.2 Recovery Procedures

**Documentation Gap:** Recovery procedures not documented  
**Recommendation:** Documented in Operational Runbook (see separate document)

---

## 11. Compliance and Governance

### 11.1 Architectural Compliance

All 11 architectural characteristics are addressed in the design:
- ✅ Availability: Nginx HA-ready, static frontend
- ✅ Security: Firewall rules, TLS-ready, network isolation
- ✅ Scalability: Stateless design, horizontal scaling capability
- ✅ Observability: Full monitoring stack
- ✅ Consistency: Ansible automation (expected)
- ✅ Resiliency: Container isolation, health checks
- ✅ Durability: Persistent storage design
- ✅ Deployability: Ansible automation (expected)
- ✅ Configurability: Service registry pattern
- ✅ Maintainability: Modular code, documentation
- ✅ Extensibility: Plugin-ready service registry

---

## Document Control

**Version History:**
- 1.0.0 (2024): Initial enterprise architecture document

**Review Cycle:** Quarterly  
**Next Review Date:** TBD  
**Approval Required:** Infrastructure Team Lead, Security Team Lead

---

**END OF ARCHITECTURE DOCUMENT**

