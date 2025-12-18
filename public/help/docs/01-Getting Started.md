# Getting Started

Welcome to **Stackwatch**, the AI-powered VM & Network Monitoring platform designed to deliver real-time observability, predictive insights, cost optimization, and enterprise-grade governance. This guide introduces the core concepts, components, and architecture required to begin using Stackwatch effectively.

---

## What Is Stackwatch?

Stackwatch extends traditional monitoring systems such as Prometheus by combining:

- **Metrics, Logs & Traces** into unified observability  
- **AI-powered analysis** for anomaly detection & RCA  
- **FinOps & GreenOps intelligence** for cost & carbon optimization  
- **Self-healing automation** through rule-based and AI-assisted remediation  
- **Role-based multi-portal experience** (User & Admin Panels)

Stackwatch is designed for enterprises that require performance, cost visibility, automation, and compliance in a single platform.

---

## Key Features

### **AI-Assisted Observability**
- Natural-language query assistant  
- “Explain This Spike” root-cause explanations  
- Predictive anomaly detection  
- Automated corrective recommendations  

### **Unified Monitoring**
- Real-time metrics ingestion  
- Log and trace correlation  
- VM and network monitoring  
- Instance-level and tenant-level dashboards  

### **Enterprise Governance**
- Strong RBAC  
- Multi-tenancy isolation  
- Compliance-ready auditing  
- SLA/SLO tracking  

### **FinOps & GreenOps Insights**
- Cost monitoring per VM, tenant, or department  
- Carbon footprint estimation  
- Optimization recommendations  

---

## Architecture Overview

Stackwatch is composed of:

1. **Prometheus** – Metrics collection & scraping  
2. **Stackwatch API** – Data aggregation, enrichment, AI inference  
3. **Grafana** – Visualization layer for dashboards  
4. **Exporters** – Linux/Windows/node exporters for VM metrics  
5. **AI Engine** – Observability intelligence & NLP interface  
6. **User Portal** – Monitoring & visualization  
7. **Admin Portal** – Governance, RBAC, plan entitlements  

A simplified architecture:

Exporters → Prometheus → Stackwatch API → Grafana/UI


---

## Who Should Use This Guide?

This guide is intended for:

- **System Administrators**  
- **Cloud/VM Operators**  
- **Network Engineers**  
- **SRE Teams**  
- **DevOps Engineers**  
- **FinOps Practitioners**  

---

## Before You Begin

Ensure you have access to:

- Prometheus instance  
- Grafana instance  
- Linux/Windows VM environments  
- Network access for scraping endpoints  
- Root/admin credentials for installation  

Continue to the **Installation & Prerequisites** section to start setting up Stackwatch.



