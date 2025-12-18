# STACKWATCH: Security Design and Firewall Documentation

**Document Version:** 1.0.0  
**Classification:** Internal Technical Documentation - Security Sensitive  
**Last Updated:** 2024  
**Architect:** Senior Cloud Infrastructure Architect and Automation Engineer

---

## Executive Summary

This document defines the security architecture, firewall rules, TLS/SSL configuration, and exposure justification for the StackWatch observability infrastructure. All security controls are designed to minimize attack surface while maintaining operational functionality.

---

## 1. Security Architecture Overview

### 1.1 Defense in Depth Strategy

StackWatch implements a multi-layered security approach:

```
Layer 1: Network Perimeter (Firewall)
    ↓
Layer 2: Reverse Proxy (Nginx)
    ↓
Layer 3: Application Authentication (Grafana)
    ↓
Layer 4: Service Isolation (Podman containers)
    ↓
Layer 5: Data Protection (Encryption at rest, TLS in transit)
```

### 1.2 Security Principles Applied

| Principle | Implementation | Status |
|-----------|----------------|--------|
| **Least Privilege** | Services run with minimal required permissions | ✅ Designed |
| **Defense in Depth** | Multiple security layers | ✅ Designed |
| **Network Segmentation** | Internal services not directly exposed | ✅ Designed |
| **Principle of Fail-Safe Defaults** | Firewall denies by default | ✅ Designed |
| **Separation of Duties** | Different access levels for different roles | ⚠️ Partial (Grafana only) |
| **Secure by Default** | Services configured with security in mind | ✅ Designed |

---

## 2. Firewall Rules and Network Security

### 2.1 Firewall Rule Matrix

**Firewall System:** firewalld or iptables (implementation TBD)

| Rule ID | Direction | Source | Destination | Port | Protocol | Action | Justification |
|---------|-----------|--------|-------------|------|----------|--------|---------------|
| **FW-001** | Inbound | Any | Nginx | 80 | TCP | ALLOW | Public web access (HTTP) |
| **FW-002** | Inbound | Any | Nginx | 443 | TCP | ALLOW | Secure web access (HTTPS/TLS) |
| **FW-003** | Inbound | Any | Prometheus | 9090 | TCP | DENY | Internal service, access via Nginx only |
| **FW-004** | Inbound | Any | Grafana | 3000 | TCP | DENY | Internal service, access via Nginx only |
| **FW-005** | Inbound | Any | Node Exporter | 9100 | TCP | DENY | Metrics endpoint, Prometheus scrape only |
| **FW-006** | Inbound | Any | Windows Exporter | 9182 | TCP | DENY | Metrics endpoint, Prometheus scrape only |
| **FW-007** | Inbound | Management Network | Server | 22 | TCP | ALLOW | SSH for server management (restricted) |
| **FW-008** | Outbound | Prometheus | Node Exporter | 9100 | TCP | ALLOW | Metrics scraping |
| **FW-009** | Outbound | Prometheus | Windows Exporter | 9182 | TCP | ALLOW | Metrics scraping |
| **FW-010** | Outbound | Grafana | Prometheus | 9090 | TCP | ALLOW | Prometheus queries |
| **FW-011** | Outbound | Nginx | Prometheus | 9090 | TCP | ALLOW | Reverse proxy connection |
| **FW-012** | Outbound | Nginx | Grafana | 3000 | TCP | ALLOW | Reverse proxy connection |

### 2.2 Firewall Configuration Specification

#### firewalld Configuration (Recommended)

**Zone Configuration:**
```bash
# Public zone (external interface)
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --zone=public --remove-service=ssh  # If SSH not needed publicly

# Internal zone (for internal network)
firewall-cmd --zone=internal --add-source=10.0.0.0/8 --permanent
firewall-cmd --zone=internal --add-service=ssh --permanent
```

**Rich Rules (Explicit Denials):**
```bash
# Deny direct access to Prometheus
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" port port="9090" protocol="tcp" reject' --permanent

# Deny direct access to Grafana
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" port port="3000" protocol="tcp" reject' --permanent

# Deny direct access to Node Exporter
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" port port="9100" protocol="tcp" reject' --permanent

# Deny direct access to Windows Exporter
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" port port="9182" protocol="tcp" reject' --permanent
```

**Reload:**
```bash
firewall-cmd --reload
```

#### iptables Configuration (Alternative)

```bash
# Allow HTTP/HTTPS
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Deny direct access to internal services
iptables -A INPUT -p tcp --dport 9090 -j REJECT  # Prometheus
iptables -A INPUT -p tcp --dport 3000 -j REJECT  # Grafana
iptables -A INPUT -p tcp --dport 9100 -j REJECT  # Node Exporter
iptables -A INPUT -p tcp --dport 9182 -j REJECT  # Windows Exporter

# Allow localhost connections (for Nginx proxy)
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Default deny
iptables -P INPUT DROP
```

### 2.3 Network Segmentation

**Network Zones:**

1. **Public Zone (Internet)**
   - Access: Port 80, 443 only
   - Services: Nginx reverse proxy
   - Security: TLS/HTTPS recommended

2. **Internal Zone (Localhost/Private Network)**
   - Access: Services on localhost or private network
   - Services: Prometheus, Grafana, Exporters
   - Security: No direct external access

3. **Management Zone (SSH)**
   - Access: Port 22 (restricted to management network)
   - Services: SSH for server administration
   - Security: Key-based authentication recommended

### 2.4 Port Exposure Justification

| Port | Service | External Access | Justification | Risk Level |
|------|---------|-----------------|---------------|------------|
| **80** | Nginx (HTTP) | ✅ Yes | Public web access required for StackWatch gateway | **Medium** (mitigated by TLS) |
| **443** | Nginx (HTTPS) | ✅ Yes | Secure web access, TLS encryption | **Low** (with proper TLS config) |
| **9090** | Prometheus | ❌ No | Internal metrics service, proxied via Nginx | **N/A** (blocked) |
| **3000** | Grafana | ❌ No | Internal visualization service, proxied via Nginx | **N/A** (blocked) |
| **9100** | Node Exporter | ❌ No | Metrics endpoint, Prometheus scrape only | **N/A** (blocked) |
| **9182** | Windows Exporter | ❌ No | Metrics endpoint, Prometheus scrape only | **N/A** (blocked) |
| **22** | SSH | ⚠️ Restricted | Server management, restricted to management network | **Low** (with key auth) |

**Risk Mitigation:**
- Port 80/443: Implement TLS/HTTPS, rate limiting, DDoS protection
- Port 22: Use key-based authentication, disable password auth, restrict source IPs

---

## 3. TLS/SSL Configuration

### 3.1 TLS Readiness Assessment

**Current Status:** TLS-ready design, configuration not implemented

**TLS Requirements:**
- ✅ Nginx supports TLS/SSL (port 443)
- ✅ Certificate management capability
- ⚠️ Certificate not configured (gap)
- ⚠️ HTTP to HTTPS redirect not configured (gap)

### 3.2 TLS Configuration Specification

#### Certificate Options

**Option 1: Let's Encrypt (Recommended for Public)**
```nginx
# Nginx SSL configuration
server {
    listen 443 ssl http2;
    server_name stackwatch.example.com;
    
    ssl_certificate /etc/letsencrypt/live/stackwatch.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/stackwatch.example.com/privkey.pem;
    
    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # ... rest of configuration
}
```

**Option 2: Self-Signed Certificate (Development/Internal)**
```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/stackwatch.key \
  -out /etc/nginx/ssl/stackwatch.crt
```

**Option 3: Enterprise CA Certificate (Enterprise)**
- Use organization's internal CA
- Follow enterprise certificate management procedures

#### HTTP to HTTPS Redirect

```nginx
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name stackwatch.example.com;
    return 301 https://$server_name$request_uri;
}
```

### 3.3 TLS Security Best Practices

**TLS Configuration Checklist:**
- [ ] TLS 1.2 minimum (TLS 1.3 preferred)
- [ ] Strong cipher suites only
- [ ] Perfect Forward Secrecy (PFS) enabled
- [ ] HSTS header configured
- [ ] Certificate valid and not expired
- [ ] Certificate chain complete
- [ ] OCSP stapling enabled (if supported)
- [ ] HTTP to HTTPS redirect configured

**Security Headers:**
```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

---

## 4. Authentication and Access Control

### 4.1 Current Authentication Status

| Service | Authentication Method | Status | Risk Level |
|--------|----------------------|--------|------------|
| **StackWatch Frontend** | None | ⚠️ Gap | **High** (public access) |
| **Prometheus** | TBD | ⚠️ Gap | **High** (via Nginx, but no auth) |
| **Grafana** | User/Password (expected) | ✅ Expected | **Medium** (if configured) |
| **Node Exporter** | None | ✅ Acceptable | **Low** (internal only) |
| **Windows Exporter** | None | ✅ Acceptable | **Low** (internal only) |

### 4.2 Authentication Recommendations

#### Nginx-Level Authentication

**Option 1: HTTP Basic Authentication**
```nginx
# Basic auth for Prometheus
location /prometheus {
    auth_basic "Prometheus Access";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://localhost:9090;
}
```

**Option 2: OAuth2 Proxy (Recommended)**
- Integrate OAuth2 proxy for SSO
- Supports multiple identity providers (Google, GitHub, LDAP, etc.)
- More secure than basic auth

#### Prometheus Authentication

**Option 1: Nginx Basic Auth (Recommended)**
- Implement at Nginx level (see above)
- No Prometheus configuration changes needed

**Option 2: Prometheus Native Auth**
- Configure in Prometheus configuration
- Requires Prometheus configuration changes

#### Grafana Authentication

**Expected Configuration:**
- Default: Admin user/password (change default password)
- Recommended: LDAP/Active Directory integration
- Alternative: OAuth2/SAML for SSO

**Grafana Security Settings:**
```ini
# grafana.ini
[security]
admin_user = admin
admin_password = <strong-password>
secret_key = <random-secret-key>

[auth.ldap]
enabled = true
config_file = /etc/grafana/ldap.toml
```

### 4.3 Access Control Matrix

| User Role | StackWatch Frontend | Prometheus | Grafana | Exporters |
|-----------|-------------------|------------|---------|-----------|
| **Public User** | ✅ Read | ❌ No Access | ❌ No Access | ❌ No Access |
| **Authenticated User** | ✅ Read | ⚠️ TBD | ✅ Read (dashboards) | ❌ No Access |
| **Grafana Admin** | ✅ Read | ⚠️ TBD | ✅ Full Access | ❌ No Access |
| **System Admin** | ✅ Read | ✅ Full Access | ✅ Full Access | ✅ Read (metrics) |
| **Prometheus Scraper** | ❌ No Access | ❌ No Access | ❌ No Access | ✅ Read (metrics) |

---

## 5. Container Security (Podman)

### 5.1 Podman Security Features

**Rootless Containers:**
- ✅ Prometheus and Grafana run as rootless containers
- ✅ Reduced attack surface (no root privileges)
- ✅ User namespace isolation

**Security Configuration:**
```bash
# Run container as non-root user
podman run --user 1000:1000 prometheus

# Read-only root filesystem (if applicable)
podman run --read-only prometheus

# Resource limits
podman run --memory=2g --cpus=2 prometheus
```

### 5.2 Container Image Security

**Best Practices:**
- Use official images from trusted sources
- Regularly update container images (security patches)
- Scan images for vulnerabilities
- Use specific image tags (not `latest`)
- Verify image signatures (if available)

**Image Update Procedure:**
```bash
# Pull latest image
podman pull prom/prometheus:latest

# Stop and remove old container
podman stop prometheus
podman rm prometheus

# Start new container with updated image
podman run ... prom/prometheus:latest
```

---

## 6. Data Protection and Encryption

### 6.1 Data in Transit

**Current Status:**
- ⚠️ HTTP only (no TLS configured)
- ✅ TLS-ready design

**Encryption Requirements:**
- All external traffic: TLS/HTTPS (port 443)
- Internal traffic: Localhost (no encryption needed) or TLS for private network

### 6.2 Data at Rest

**Current Status:**
- ⚠️ Not encrypted (gap identified)

**Data Storage:**
- Prometheus TSDB: `/var/lib/prometheus/data/` (or Podman volume)
- Grafana data: `/var/lib/grafana/` (or Podman volume)

**Encryption Recommendations:**
- Use encrypted filesystem (LUKS) for sensitive data
- Encrypt backup archives
- Secure credential storage (Ansible Vault, secrets management)

---

## 7. Security Monitoring and Logging

### 7.1 Security Event Logging

**Recommended Logging:**
- Nginx access logs: All HTTP requests
- Nginx error logs: Failed requests, errors
- Prometheus logs: Scrape failures, query errors
- Grafana logs: Authentication attempts, access logs
- System logs: Firewall denials, authentication failures

**Log Locations (Expected):**
- Nginx: `/var/log/nginx/access.log`, `/var/log/nginx/error.log`
- Prometheus: Container logs or systemd journal
- Grafana: Container logs or systemd journal
- System: `/var/log/auth.log`, `/var/log/syslog`

### 7.2 Security Monitoring

**Recommended Monitoring:**
- Failed authentication attempts
- Unusual access patterns
- Firewall rule violations
- Service availability
- Certificate expiration

**Alerting (Recommended):**
- Multiple failed login attempts
- Certificate expiring soon (< 30 days)
- Service downtime
- Unusual network traffic patterns

---

## 8. Vulnerability Management

### 8.1 Patch Management

**Update Schedule:**
- Critical security patches: Apply immediately
- High severity: Apply within 7 days
- Medium severity: Apply within 30 days
- Low severity: Apply in next maintenance window

**Components to Update:**
- Nginx: System package updates
- Prometheus: Container image updates
- Grafana: Container image updates
- Node Exporter: Binary updates (Ansible-managed)
- Windows Exporter: Binary updates
- Operating System: Security patches

### 8.2 Vulnerability Scanning

**Recommended Tools:**
- Container image scanning: Trivy, Clair, Snyk
- System vulnerability scanning: OpenVAS, Nessus
- Dependency scanning: npm audit (for frontend)

**Scanning Frequency:**
- Container images: Before deployment, monthly
- System: Monthly
- Dependencies: Before each deployment

---

## 9. Incident Response

### 9.1 Security Incident Classification

**Severity Levels:**
- **Critical:** Active exploitation, data breach, service compromise
- **High:** Successful unauthorized access, privilege escalation
- **Medium:** Failed attack, suspicious activity
- **Low:** Security misconfiguration, informational

### 9.2 Incident Response Procedures

**Immediate Actions:**
1. Isolate affected systems (if necessary)
2. Preserve logs and evidence
3. Assess scope of impact
4. Notify security team and management
5. Begin remediation

**Recovery Steps:**
1. Patch vulnerabilities
2. Reset compromised credentials
3. Review and update security controls
4. Conduct post-incident review
5. Update documentation and procedures

---

## 10. Compliance and Audit

### 10.1 Security Compliance

**Compliance Requirements (TBD):**
- Industry-specific regulations (if applicable)
- Organizational security policies
- Data protection regulations (GDPR, etc.)

### 10.2 Security Audit

**Audit Checklist:**
- [ ] Firewall rules reviewed and documented
- [ ] TLS/SSL configured and valid
- [ ] Authentication implemented for all services
- [ ] Access controls reviewed
- [ ] Logging and monitoring configured
- [ ] Backup and recovery procedures tested
- [ ] Incident response plan documented
- [ ] Security patches up to date
- [ ] Vulnerability scanning completed
- [ ] Security documentation current

**Audit Frequency:** Quarterly

---

## 11. Security Gaps and Recommendations

### 11.1 Critical Gaps

1. **No TLS/HTTPS Configuration**
   - Risk: Data transmitted in plaintext
   - Recommendation: Implement TLS with Let's Encrypt or enterprise CA
   - Priority: **High**

2. **No Authentication on StackWatch Frontend**
   - Risk: Public access to gateway
   - Recommendation: Implement Nginx basic auth or OAuth2 proxy
   - Priority: **Medium**

3. **No Authentication on Prometheus (via Nginx)**
   - Risk: Unauthorized access to metrics
   - Recommendation: Implement Nginx basic auth
   - Priority: **High**

4. **No Data Encryption at Rest**
   - Risk: Data exposure if disk compromised
   - Recommendation: Implement encrypted filesystem or volume encryption
   - Priority: **Medium**

### 11.2 Recommended Enhancements

1. **Rate Limiting**
   - Implement Nginx rate limiting to prevent DDoS
   - Limit API query rates

2. **WAF (Web Application Firewall)**
   - Consider ModSecurity or cloud WAF
   - Protect against common web attacks

3. **Intrusion Detection**
   - Implement IDS/IPS for network monitoring
   - Alert on suspicious activity

4. **Security Information and Event Management (SIEM)**
   - Centralize security logs
   - Correlate security events

---

## Document Control

**Version History:**
- 1.0.0 (2024): Initial security design document

**Classification:** Security Sensitive  
**Review Cycle:** Quarterly  
**Next Review Date:** TBD  
**Approval Required:** Security Team Lead, Infrastructure Team Lead

**Distribution:** Restricted to authorized personnel only

---

**END OF SECURITY DESIGN DOCUMENT**

