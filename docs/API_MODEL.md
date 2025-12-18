# STACKWATCH: API Model and Endpoint Documentation

**Document Version:** 1.0.0  
**Classification:** Internal Technical Documentation  
**Last Updated:** 2024  
**Architect:** Senior Cloud Infrastructure Architect and Automation Engineer

---

## 1. Endpoint Mapping Matrix

### 1.1 Complete Port and Endpoint Matrix

| Service | Internal Port | External Port | Protocol | Endpoint Pattern | Access Method | Authentication |
|---------|---------------|---------------|----------|------------------|---------------|----------------|
| **Nginx** | 80 | 80 | HTTP | `/*` | Direct | Public |
| **Nginx** | 443 | 443 | HTTPS | `/*` | Direct | Public (TLS-ready) |
| **StackWatch Frontend** | N/A | Via Nginx | HTTP/HTTPS | `/` | Via Nginx | None (static) |
| **Prometheus** | 9090 | Blocked | HTTP | `/prometheus/*` | Via Nginx proxy | TBD |
| **Grafana** | 3000 | Blocked | HTTP | `/grafana/*` | Via Nginx proxy | Required |
| **Node Exporter** | 9100 | Blocked | HTTP | `/metrics` | Prometheus scrape | None (internal) |
| **Windows Exporter** | 9182 | Blocked | HTTP | `/metrics` | Prometheus scrape | None (internal) |

### 1.2 Nginx Routing Endpoint Map

```
External Request: http://server-ip/<path>
│
├─ Path: /
│  └─→ Serves: /var/www/stackwatch/dist/index.html
│      └─→ Static React Application
│
├─ Path: /prometheus/*
│  └─→ Proxy: http://localhost:9090/*
│      └─→ Prometheus Web UI and API
│
└─ Path: /grafana/*
    └─→ Proxy: http://localhost:3000/*
        └─→ Grafana Web UI and API
```

---

## 2. StackWatch Frontend Endpoints

### 2.1 Frontend Routes

**Base URL:** `http://server-ip/` or `https://server-ip/`

| Route | Method | Description | Response Type |
|-------|--------|-------------|---------------|
| `/` | GET | Main dashboard page | HTML (React SPA) |
| `/prometheus` | GET | Redirect to Prometheus (via link) | HTML redirect |
| `/grafana` | GET | Redirect to Grafana (via link) | HTML redirect |

**Note:** Frontend is a Single Page Application (SPA). All routes are handled client-side via React Router (if implemented) or server-side via Nginx `try_files` directive.

### 2.2 Frontend API Contracts

**Service Registry:**
- Location: `constants.tsx`
- Format: TypeScript interface `ServiceConfig[]`
- Purpose: Defines available services and their paths

**Example Service Entry:**
```typescript
{
  id: 'svc-prom',
  name: 'Prometheus',
  description: 'Time-series event monitoring and alerting.',
  path: '/prometheus',
  icon: 'prometheus',
  status: 'active'
}
```

---

## 3. Prometheus API Endpoints

### 3.1 Prometheus Web UI Endpoints

**Base URL:** `http://server-ip/prometheus/` (via Nginx proxy)

| Endpoint | Method | Description | Authentication |
|----------|--------|-------------|----------------|
| `/` | GET | Prometheus web UI home | TBD |
| `/graph` | GET | PromQL query interface | TBD |
| `/alerts` | GET | Active alerts page | TBD |
| `/status` | GET | Prometheus status page | TBD |
| `/targets` | GET | Scrape targets status | TBD |
| `/config` | GET | Configuration view | TBD |

### 3.2 Prometheus HTTP API

**Base URL:** `http://server-ip/prometheus/api/v1/`

#### Query API

**Instant Query:**
```
GET /api/v1/query
POST /api/v1/query

Query Parameters:
  - query: PromQL expression (required)
  - time: RFC3339 timestamp (optional, defaults to now)

Response:
{
  "status": "success",
  "data": {
    "resultType": "vector" | "scalar" | "string" | "matrix",
    "result": [...]
  }
}
```

**Range Query:**
```
GET /api/v1/query_range
POST /api/v1/query_range

Query Parameters:
  - query: PromQL expression (required)
  - start: RFC3339 start timestamp (required)
  - end: RFC3339 end timestamp (required)
  - step: Duration string (e.g., "15s") (required)

Response:
{
  "status": "success",
  "data": {
    "resultType": "matrix",
    "result": [...]
  }
}
```

**Series Query:**
```
GET /api/v1/series
POST /api/v1/series

Query Parameters:
  - match[]: Series selector (required, repeatable)
  - start: RFC3339 start timestamp (optional)
  - end: RFC3339 end timestamp (optional)

Response:
{
  "status": "success",
  "data": [...]
}
```

**Label Query:**
```
GET /api/v1/labels
POST /api/v1/labels

Query Parameters:
  - match[]: Series selector (optional, repeatable)
  - start: RFC3339 start timestamp (optional)
  - end: RFC3339 end timestamp (optional)

Response:
{
  "status": "success",
  "data": ["label1", "label2", ...]
}
```

**Label Values Query:**
```
GET /api/v1/label/<label_name>/values
POST /api/v1/label/<label_name>/values

Query Parameters:
  - match[]: Series selector (optional, repeatable)
  - start: RFC3339 start timestamp (optional)
  - end: RFC3339 end timestamp (optional)

Response:
{
  "status": "success",
  "data": ["value1", "value2", ...]
}
```

#### Metadata API

**Targets:**
```
GET /api/v1/targets

Response:
{
  "status": "success",
  "data": {
    "activeTargets": [...],
    "droppedTargets": [...]
  }
}
```

**Rules:**
```
GET /api/v1/rules

Response:
{
  "status": "success",
  "data": {
    "groups": [...]
  }
}
```

**Alerts:**
```
GET /api/v1/alerts

Response:
{
  "status": "success",
  "data": {
    "alerts": [...]
  }
}
```

**Status:**
```
GET /api/v1/status/config
GET /api/v1/status/flags
GET /api/v1/status/runtimeinfo
GET /api/v1/status/buildinfo
GET /api/v1/status/tsdb
```

### 3.3 Prometheus Metrics Endpoint

**Internal Only (Not Proxied):**
```
GET http://localhost:9090/metrics

Response: Prometheus internal metrics in exposition format
```

---

## 4. Grafana API Endpoints

### 4.1 Grafana Web UI Endpoints

**Base URL:** `http://server-ip/grafana/` (via Nginx proxy)

| Endpoint | Method | Description | Authentication |
|----------|--------|-------------|----------------|
| `/` | GET | Grafana home/login | Required |
| `/login` | GET/POST | Login page | None (for login) |
| `/d/<dashboard-id>` | GET | Dashboard view | Required |
| `/d/<dashboard-uid>/<dashboard-name>` | GET | Dashboard by UID | Required |
| `/dashboard/new` | GET | Create new dashboard | Required |
| `/datasources` | GET | Data sources management | Required (Admin) |
| `/org` | GET | Organization settings | Required |
| `/admin` | GET | Administration panel | Required (Admin) |

### 4.2 Grafana HTTP API

**Base URL:** `http://server-ip/grafana/api/`

#### Authentication API

**Login:**
```
POST /api/login

Request Body:
{
  "user": "admin",
  "password": "password"
}

Response:
{
  "message": "Logged in"
}
```

**Logout:**
```
POST /api/logout
```

#### Dashboard API

**List Dashboards:**
```
GET /api/search?type=dash-db

Response:
[
  {
    "id": 1,
    "uid": "dashboard-uid",
    "title": "Dashboard Title",
    "url": "/d/dashboard-uid/dashboard-title",
    ...
  }
]
```

**Get Dashboard:**
```
GET /api/dashboards/uid/<dashboard-uid>

Response:
{
  "dashboard": {...},
  "meta": {...}
}
```

**Create/Update Dashboard:**
```
POST /api/dashboards/db

Request Body:
{
  "dashboard": {...},
  "overwrite": false
}

Response:
{
  "id": 1,
  "uid": "dashboard-uid",
  "url": "/d/dashboard-uid/dashboard-title",
  "status": "success",
  "version": 1
}
```

**Delete Dashboard:**
```
DELETE /api/dashboards/uid/<dashboard-uid>
```

#### Data Source API

**List Data Sources:**
```
GET /api/datasources

Response:
[
  {
    "id": 1,
    "uid": "prometheus",
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://localhost:9090",
    ...
  }
]
```

**Get Data Source:**
```
GET /api/datasources/<id>
GET /api/datasources/uid/<uid>
GET /api/datasources/name/<name>
```

**Create Data Source:**
```
POST /api/datasources

Request Body:
{
  "name": "Prometheus",
  "type": "prometheus",
  "url": "http://localhost:9090",
  "access": "proxy",
  ...
}
```

**Update Data Source:**
```
PUT /api/datasources/<id>
```

**Delete Data Source:**
```
DELETE /api/datasources/<id>
```

#### Query API

**Query Data Source:**
```
POST /api/ds/query

Request Body:
{
  "queries": [
    {
      "refId": "A",
      "datasource": {
        "uid": "prometheus"
      },
      "expr": "node_cpu_seconds_total",
      "range": true,
      "format": "time_series"
    }
  ],
  "from": "now-1h",
  "to": "now"
}

Response:
{
  "results": {
    "A": {
      "frames": [...]
    }
  }
}
```

### 4.3 Grafana Health Endpoint

**Health Check:**
```
GET /api/health

Response:
{
  "commit": "commit-hash",
  "database": "ok",
  "version": "10.0.0"
}
```

---

## 5. Exporter Endpoints

### 5.1 Node Exporter (Linux) Endpoints

**Base URL:** `http://target-server:9100/` (Internal only, not proxied)

| Endpoint | Method | Description | Access |
|----------|--------|-------------|--------|
| `/metrics` | GET | Prometheus metrics in exposition format | Prometheus scraper |
| `/` | GET | Basic HTML page with links | Internal diagnostics |

**Metrics Endpoint Details:**
```
GET /metrics

Response Format: Prometheus Exposition Format
Content-Type: text/plain; version=0.0.4

Example Response:
# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 12345.67
node_cpu_seconds_total{cpu="0",mode="user"} 1234.56
...
```

**Key Metrics Exported:**
- `node_cpu_seconds_total`: CPU time by mode
- `node_memory_MemTotal_bytes`: Total memory
- `node_memory_MemFree_bytes`: Free memory
- `node_filesystem_size_bytes`: Filesystem size
- `node_filesystem_avail_bytes`: Filesystem available space
- `node_network_receive_bytes_total`: Network receive bytes
- `node_network_transmit_bytes_total`: Network transmit bytes
- `node_disk_io_time_seconds_total`: Disk I/O time
- `node_load1`, `node_load5`, `node_load15`: System load averages

### 5.2 Windows Exporter Endpoints

**Base URL:** `http://target-server:9182/` (Internal only, not proxied)

| Endpoint | Method | Description | Access |
|----------|--------|-------------|--------|
| `/metrics` | GET | Prometheus metrics in exposition format | Prometheus scraper |
| `/` | GET | Basic HTML page with links | Internal diagnostics |

**Metrics Endpoint Details:**
```
GET /metrics

Response Format: Prometheus Exposition Format
Content-Type: text/plain; version=0.0.4

Example Response:
# HELP windows_cpu_time_total Seconds the CPU spent in each mode.
# TYPE windows_cpu_time_total counter
windows_cpu_time_total{core="0",mode="idle"} 12345.67
...
```

**Key Metrics Exported:**
- `windows_cpu_time_total`: CPU time by mode and core
- `windows_cs_physical_memory_bytes`: Total physical memory
- `windows_cs_processes`: Number of processes
- `windows_logical_disk_size_bytes`: Logical disk size
- `windows_logical_disk_free_bytes`: Logical disk free space
- `windows_net_bytes_received_total`: Network bytes received
- `windows_net_bytes_sent_total`: Network bytes sent
- `windows_service_state`: Windows service states
- `windows_os_info`: Operating system information

---

## 6. Health Check Endpoints

### 6.1 Service Health Check Matrix

| Service | Health Endpoint | Method | Expected Response | Check Interval |
|---------|----------------|--------|-------------------|----------------|
| **Nginx** | `http://server-ip/` | GET | HTTP 200, HTML content | 30s |
| **Prometheus** | `http://server-ip/prometheus/-/healthy` | GET | HTTP 200, "Prometheus is Healthy." | 30s |
| **Grafana** | `http://server-ip/grafana/api/health` | GET | HTTP 200, JSON with status | 30s |
| **Node Exporter** | `http://target:9100/metrics` | GET | HTTP 200, metrics content | 15s (scrape) |
| **Windows Exporter** | `http://target:9182/metrics` | GET | HTTP 200, metrics content | 15s (scrape) |

### 6.2 Health Check Implementation Details

#### Nginx Health Check

**Endpoint:** `GET /`
**Expected:** HTTP 200 OK with StackWatch frontend HTML
**Validation:**
```bash
curl -I http://server-ip/
# Expected: HTTP/1.1 200 OK
```

#### Prometheus Health Check

**Endpoint:** `GET /prometheus/-/healthy`
**Expected:** HTTP 200 OK with text "Prometheus is Healthy."
**Validation:**
```bash
curl http://server-ip/prometheus/-/healthy
# Expected: Prometheus is Healthy.
```

**Alternative:** Check Prometheus status API
```bash
curl http://server-ip/prometheus/api/v1/status/config
# Expected: JSON with status: "success"
```

#### Grafana Health Check

**Endpoint:** `GET /grafana/api/health`
**Expected:** HTTP 200 OK with JSON
**Response Format:**
```json
{
  "commit": "abc123",
  "database": "ok",
  "version": "10.0.0"
}
```

**Validation:**
```bash
curl http://server-ip/grafana/api/health
# Expected: JSON with database: "ok"
```

#### Node Exporter Health Check

**Endpoint:** `GET http://target:9100/metrics`
**Expected:** HTTP 200 OK with metrics in Prometheus format
**Validation:**
```bash
curl -I http://target-server:9100/metrics
# Expected: HTTP/1.1 200 OK
# Content-Type: text/plain; version=0.0.4
```

#### Windows Exporter Health Check

**Endpoint:** `GET http://target:9182/metrics`
**Expected:** HTTP 200 OK with metrics in Prometheus format
**Validation:**
```bash
curl -I http://windows-server:9182/metrics
# Expected: HTTP/1.1 200 OK
# Content-Type: text/plain; version=0.0.4
```

### 6.3 Comprehensive Health Check Script (Recommended)

**Purpose:** Validate all services are operational
**Location:** Not in repository (recommendation)
**Execution:** Manual or automated via monitoring system

**Check Sequence:**
1. Nginx responding on port 80/443
2. StackWatch frontend loads successfully
3. Prometheus accessible via `/prometheus/-/healthy`
4. Grafana accessible via `/grafana/api/health`
5. Node Exporter responding on target servers
6. Windows Exporter responding on target servers
7. Prometheus successfully scraping exporters

---

## 7. Port Matrix Summary

### 7.1 Complete Port Allocation

| Port | Service | Protocol | Direction | Firewall Rule | Justification |
|------|---------|----------|-----------|---------------|---------------|
| **80** | Nginx (HTTP) | TCP | Inbound | ALLOW | Public web access |
| **443** | Nginx (HTTPS) | TCP | Inbound | ALLOW | Secure web access (TLS-ready) |
| **9090** | Prometheus | TCP | Localhost only | DENY external | Internal service, proxied via Nginx |
| **3000** | Grafana | TCP | Localhost only | DENY external | Internal service, proxied via Nginx |
| **9100** | Node Exporter | TCP | Internal network | DENY external | Metrics collection, Prometheus scrape only |
| **9182** | Windows Exporter | TCP | Internal network | DENY external | Metrics collection, Prometheus scrape only |
| **22** | SSH | TCP | Inbound | ALLOW (restricted) | Server management (if applicable) |

### 7.2 Network Access Matrix

| Source | Destination | Port | Allowed | Purpose |
|--------|-------------|------|---------|---------|
| Internet | Nginx | 80, 443 | ✅ Yes | Public web access |
| Internet | Prometheus | 9090 | ❌ No | Blocked, use /prometheus via Nginx |
| Internet | Grafana | 3000 | ❌ No | Blocked, use /grafana via Nginx |
| Internet | Node Exporter | 9100 | ❌ No | Internal metrics only |
| Internet | Windows Exporter | 9182 | ❌ No | Internal metrics only |
| Prometheus | Node Exporter | 9100 | ✅ Yes | Metrics scraping |
| Prometheus | Windows Exporter | 9182 | ✅ Yes | Metrics scraping |
| Localhost | Prometheus | 9090 | ✅ Yes | Nginx proxy connection |
| Localhost | Grafana | 3000 | ✅ Yes | Nginx proxy connection |

---

## 8. API Authentication and Security

### 8.1 Current Authentication Status

| Service | Authentication | Status | Recommendation |
|---------|----------------|--------|----------------|
| **StackWatch Frontend** | None | ✅ Current | Add Nginx basic auth or OAuth proxy |
| **Prometheus** | TBD | ⚠️ Gap | Implement basic auth or OAuth |
| **Grafana** | Required | ✅ Expected | User/password or LDAP/OAuth |
| **Node Exporter** | None | ✅ Acceptable | Internal network only |
| **Windows Exporter** | None | ✅ Acceptable | Internal network only |

### 8.2 Authentication Recommendations

**Nginx Level:**
- Implement HTTP Basic Authentication for `/prometheus` and `/grafana` paths
- Or implement OAuth2 proxy for SSO integration
- TLS/HTTPS required for production (port 443)

**Prometheus Level:**
- Basic authentication via Nginx or Prometheus native auth
- API key authentication for programmatic access

**Grafana Level:**
- User/password authentication (default)
- LDAP/Active Directory integration (recommended for enterprise)
- OAuth2/SAML integration (recommended for SSO)

---

## 9. API Rate Limiting and Throttling

### 9.1 Current Status

**Rate Limiting:** Not implemented (gap identified)
**Recommendation:** Implement Nginx rate limiting for:
- Prometheus API endpoints (prevent query abuse)
- Grafana API endpoints (prevent dashboard abuse)
- General Nginx requests (DDoS protection)

### 9.2 Recommended Rate Limits

| Endpoint Pattern | Rate Limit | Burst | Justification |
|-----------------|------------|-------|---------------|
| `/prometheus/api/v1/query*` | 10 req/s | 20 | Prevent query overload |
| `/grafana/api/*` | 30 req/s | 50 | Prevent API abuse |
| `/` (Frontend) | 100 req/s | 200 | General web traffic |
| `/metrics` (Exporters) | 1 req/15s | 2 | Scraping interval |

---

## 10. API Error Responses

### 10.1 Standard Error Response Format

**Prometheus API Errors:**
```json
{
  "status": "error",
  "errorType": "bad_data" | "timeout" | "internal" | "canceled",
  "error": "Error message description"
}
```

**Grafana API Errors:**
```json
{
  "message": "Error message description"
}
```

**HTTP Status Codes:**
- `200 OK`: Successful request
- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Access denied
- `404 Not Found`: Resource not found
- `500 Internal Server Error`: Server error
- `502 Bad Gateway`: Upstream service unavailable
- `503 Service Unavailable`: Service temporarily unavailable

---

## Document Control

**Version History:**
- 1.0.0 (2024): Initial API model document

**Review Cycle:** Quarterly  
**Next Review Date:** TBD  
**Approval Required:** Infrastructure Team Lead, Security Team Lead

---

**END OF API MODEL DOCUMENT**

