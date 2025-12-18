# Installation & Prerequisites

This section outlines all system requirements, network prerequisites, and installation steps needed before deploying Stackwatch. These prerequisites ensure compatibility, performance, and reliable metrics ingestion.

---

## System Requirements

### **Minimum Hardware Requirements**

| Component | Minimum Specification | Recommended |
|----------|------------------------|-------------|
| CPU | 2 vCPU | 4+ vCPU |
| RAM | 4 GB | 8–16 GB |
| Disk | 20 GB | 50 GB+ SSD |
| Network | 1 Gbps | 10 Gbps |

---

## Supported Operating Systems

### **Linux**
- Ubuntu 20.04 / 22.04  
- RHEL 7 / 8  
- CentOS 7  
- Rocky Linux / AlmaLinux  

### **Windows**
- Windows Server 2016 / 2019 / 2022  

---

## Network & Firewall Requirements

Prometheus & exporters require open ports for scraping.

| Component | Port | Protocol |
|----------|------|----------|
| Prometheus | 9090 | TCP |
| Node Exporter (Linux) | 9100 | TCP |
| Windows Exporter | 9182 | TCP |
| Grafana UI | 3000 | TCP |
| Stackwatch API | Custom (default 8080) | TCP |

Ensure that the Prometheus server can reach all VM exporters.

---

## Required Software

- Prometheus (latest stable)  
- Grafana (latest stable)  
- Node Exporter (for Linux VMs)  
- Windows Exporter (for Windows servers)  
- cURL / wget  
- Systemd (for service management)  

---

## Installation Checklist

Before proceeding, verify:

- [x] Prometheus installed  
- [x] Grafana installed  
- [x] Linux/Windows exporters deployed  
- [x] Scrape targets reachable  
- [x] Firewall configured  
- [x] DNS or IP access configured  

---

## Prerequisites for Prometheus Setup

Prometheus should be installed and configured as described in the **Prometheus Configuration** section. This includes:

- Target declarations  
- Job configurations  
- Retention settings  

---

## Prerequisites for Grafana Setup

Grafana must be configured with:

- Prometheus data source  
- Stackwatch dashboards imported  
- Alerting enabled  

---

## Next Steps

Proceed to the **Environment Configuration** section to configure Prometheus, exporters, and Grafana dashboards for monitoring.

