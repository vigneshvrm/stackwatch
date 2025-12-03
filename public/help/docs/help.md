# StackWatch - Installation, Setup & Grafana Walkthrough

<div align="center">

**Version:** 1.0.0  
**Last Updated:** 2024

</div>

---

## Document Overview

This comprehensive guide provides step-by-step instructions for the complete StackWatch observability platform setup, covering:

| Topic | Description |
|:------|:------------|
| **Frontend Access** | Accessing the StackWatch dashboard interface |
| **Grafana Configuration** | Initial login and authentication setup |
| **Data Source Setup** | Configuring Prometheus as a data source |
| **Dashboard Import** | Importing pre-configured monitoring dashboards |

---

## Quick Reference: Service Endpoints

Before beginning the setup process, familiarize yourself with the following service endpoints and credentials:

| Service | Endpoint URL | Authentication | Purpose |
|:--------|:-------------|:--------------|:--------|
| **StackWatch Dashboard** | `http://<ServerIP>/` | None required | Main observability gateway interface |
| **Prometheus** | `http://<ServerIP>/prometheus` | None required | Metrics collection and query interface |
| **Grafana** | `http://<ServerIP>/grafana` | Username: `admin`<br>Password: `admin` | Data visualization and dashboards |
| **Help Documentation** | `http://<ServerIP>/help` | None required | This documentation portal |

> **Security Note:** Default Grafana credentials should be changed immediately after first login.

### Recommended Dashboard IDs

| Platform | Dashboard ID | Dashboard Name | Description |
|:---------|:-------------|:---------------|:------------|
| **Linux** | `1860` | Node Exporter Full | Comprehensive Linux system metrics including CPU, memory, disk, and network |
| **Windows** | `19269` | Windows Exporter | Complete Windows system monitoring including services, performance counters, and hardware metrics |

---

## Step-by-Step Configuration Guide

### Step A: Access the StackWatch Dashboard

**Objective:** Verify frontend accessibility and interface functionality.

1. **Open your web browser** and navigate to the StackWatch frontend URL:
   ```
   http://<ServerIP>/
   ```

2. **Verify the dashboard** renders correctly with the following elements visible:
   - StackWatch branding and header
   - Service cards for Prometheus and Grafana
   - Help & Documentation link
   - System status indicator

3. **Confirm service links** are functional and properly displayed.

![StackWatch Dashboard](/help/docs/images/Picture1.png)

---

### Step B: Grafana Initial Login

**Objective:** Access Grafana and complete initial authentication setup.

#### Procedure

1. **Navigate to Grafana** using one of the following methods:
   - Click the **Grafana** service card on the StackWatch dashboard
   - Direct URL access: `http://<ServerIP>/grafana`

2. **Enter default credentials:**
   | Field | Value |
   |:------|:------|
   | **Username** | `admin` |
   | **Password** | `admin` |

3. **Change default password** (mandatory on first login):
   - You will be prompted to change the password immediately
   - **Security Requirement:** Set a strong password following your organization's password policy
   - Minimum recommended: 12 characters with mixed case, numbers, and special characters

![Grafana Login Page](/help/docs/images/Picture2.png)

---

### Step C: Configure Prometheus Data Source

**Objective:** Establish connection between Grafana and Prometheus for metrics collection.

#### Configuration Steps

##### 1. Navigate to Data Sources

| Action | Location |
|:-------|:---------|
| Click **Configuration** icon | Left sidebar (gear icon) |
| Select **Data Sources** | Configuration menu |
| Click **Add data source** | Top right button |
| Select **Prometheus** | Data source type list |

##### 2. Configure Prometheus Connection

Enter the following configuration parameters:

| Parameter | Value | Notes |
|:----------|:------|:------|
| **Name** | `Prometheus` | Display name for the data source |
| **URL** | `http://localhost:9090` | Internal Prometheus endpoint |
| **Access** | `Server (default)` | Recommended for security |

> **Note:** The URL `http://localhost:9090` works because Grafana runs on the same host as Prometheus. For distributed deployments, use the actual Prometheus server IP address.

##### 3. Save and Test Connection

1. Click **Save & Test** button at the bottom of the configuration page
2. **Expected Result:** Green success message displaying **"Data source is working"**
3. If connection fails, verify:
   - Prometheus container is running: `sudo podman ps | grep prometheus`
   - Prometheus is accessible: `curl http://localhost:9090/-/healthy`

![Prometheus Data Source Configuration](/help/docs/images/Picture3.png)

---

### Step D: Import Monitoring Dashboards

**Objective:** Import pre-configured Grafana dashboards for Linux and Windows system monitoring.

#### Dashboard Overview

Grafana community dashboards provide production-ready visualizations that require minimal configuration.

| Dashboard | Platform | ID | Features |
|:----------|:---------|:---|:---------|
| **Node Exporter Full** | Linux | `1860` | CPU, memory, disk I/O, network, system load, process monitoring |
| **Windows Exporter** | Windows | `19269` | CPU, memory, disk usage, network interfaces, Windows services, performance counters |

#### Import Procedure

Follow these steps for each dashboard:

| Step | Action | Details |
|:-----|:------|:--------|
| **1** | Open Import Dialog | Click **+** icon → Select **Import** |
| **2** | Enter Dashboard ID | Type dashboard ID (e.g., `1860` for Linux) |
| **3** | Load Dashboard | Click **Load** button |
| **4** | Select Data Source | Choose **Prometheus** from dropdown |
| **5** | Import Dashboard | Click **Import** to complete |

**Repeat Steps 1-5** for the Windows dashboard (`19269`) if you have Windows monitoring targets.

![Import Dashboard Dialog](/help/docs/images/Picture4.png)

---

## Verification and Troubleshooting

### Dashboard Data Verification

After importing dashboards, perform the following verification steps:

#### 1. Visual Verification

- **Open the imported dashboard** and confirm panels display data
- **Check time range** is set appropriately (default: Last 6 hours)
- **Verify metric names** appear in panel titles and legends

#### 2. Data Availability Checklist

If panels show **"No data"**, verify the following:

| Check | Command / Location | Expected Result |
|:------|:-------------------|:----------------|
| **Prometheus Targets** | Prometheus UI → Status → Targets | All targets show status: **UP** |
| **Exporter Reachability** | `curl http://<TargetIP>:9100/metrics` | Returns metrics in Prometheus format |
| **Grafana Data Source** | Configuration → Data Sources → Prometheus → **Save & Test** | Green success message |
| **Query Testing** | Grafana → Explore → Enter query: `up` | Returns time series data |

#### 3. Common Issues and Solutions

| Issue | Symptom | Solution |
|:------|:--------|:---------|
| **No data in dashboards** | Panels show "No data" message | Verify Prometheus targets are UP and exporters are running |
| **Data source connection failed** | Red error message in Grafana | Check Prometheus URL and network connectivity |
| **Dashboard not loading** | Import fails or dashboard blank | Verify correct dashboard ID and Prometheus data source selection |
| **Incorrect time range** | Data appears outdated | Adjust time range selector in dashboard |

---

## Quick Reference Commands

### Service Verification

```bash
# Check Grafana container status
sudo podman ps | grep grafana

# Check Prometheus container status
sudo podman ps | grep prometheus

# Test Prometheus health endpoint
curl http://localhost:9090/-/healthy

# Test Node Exporter metrics endpoint
curl http://<TargetIP>:9100/metrics

# Test Grafana health endpoint
curl http://localhost:3000/api/health
```

### Useful Links

| Resource | URL | Purpose |
|:---------|:-----|:--------|
| **Prometheus Targets** | `http://<ServerIP>/prometheus` → Status → Targets | View all monitoring targets and their health status |
| **Grafana Data Sources** | `http://<ServerIP>/grafana` → Configuration → Data Sources | Manage and test data source connections |
| **Grafana Explore** | `http://<ServerIP>/grafana` → Explore | Test PromQL queries and verify data collection |

---

## Additional Resources

### Documentation

- **StackWatch Operations Guide:** Available in `/docs` directory
- **Prometheus Documentation:** https://prometheus.io/docs/
- **Grafana Documentation:** https://grafana.com/docs/

### Support

For additional support or questions:
- Review the troubleshooting section above
- Check service logs: `sudo journalctl -u container-<service-name>`
- Contact your system administrator

---

<div align="center">

**StackWatch v1.0.0** | Infrastructure Observability Platform

</div>

---

### Step A - Access the Frontend

1. Open a web browser and navigate to the frontend URL: `http://IPAddress/`

2. Confirm the home page renders correctly and that links to Grafana and Prometheus are visible.

![Frontend Dashboard](/help/docs/images/Picture1.png)

---

### Step B - Grafana: Initial Login

1. Navigate to the Grafana URL: `http://IPAddress/grafana`

2. Log in using the provided credentials:
   - **Username:** `admin`
   - **Password:** `admin`

3. **Important:** On first login, you will be prompted to change the default password. Please set a strong password for security.

![Grafana Login Page](/help/docs/images/Picture2.png)

---

### Step C - Add Prometheus Data Source

Follow these steps to configure Prometheus as a data source in Grafana:

#### 1. Navigate to Data Sources

- Click the **Configuration** icon (gear) in the left sidebar
- Select **Data Sources**
- Click **Add data source**
- Select **Prometheus**

#### 2. Configure Prometheus Connection

Enter the following configuration:

- **Name:** `Prometheus`
- **URL:** `http://localhost:9090`
  - *Note: Use host IP or container network alias if required*
- **Access:** `Server (default)`

#### 3. Save and Test

- Click **Save & Test**
- You should see a green confirmation message: **"Data source is working"**

![Prometheus Data Source Configuration](/help/docs/images/Picture3.png)

---

### Step D - Import Dashboards

Grafana community dashboards provide pre-configured visualizations for monitoring.

#### Recommended Dashboards

| Dashboard | ID | Description |
|-----------|----|----|
| **Linux** | `1860` | Node Exporter Full - Complete Linux system metrics |
| **Windows** | `19269` | Windows Exporter - Complete Windows system metrics |

#### Import Steps

1. In Grafana, click the **+** icon in the left sidebar
2. Select **Import**
3. Enter the dashboard ID (e.g., `1860` for Linux)
4. Click **Load**
5. When prompted, select the **Prometheus** data source
6. Click **Import**
7. Repeat steps 1-6 for the Windows dashboard (`19269`) if you have Windows targets

![Import Dashboard Dialog](/help/docs/images/Picture4.png)

---

## Verification - Dashboard Data

After importing dashboards, verify that data is being displayed:

1. **Open the imported dashboard** and confirm panels show data

2. **If panels show no data**, verify the following:

   - **Prometheus targets are UP:**
     - Navigate to Prometheus UI → Status → Targets
     - Confirm all targets show as "UP"

   - **Exporters are reachable:**
     - Node exporter / Windows exporter metrics should be accessible
     - Test with: `curl http://IPAddress:9100/metrics`

   - **Grafana data source is working:**
     - Go to Configuration → Data Sources → Prometheus
     - Click **Save & Test** to verify connection
     - Use the **Explore** feature to test queries

---

## Appendix - Troubleshooting & Notes

### Quick Verification Commands

```bash
# Verify Grafana container/process
sudo podman ps | grep grafana

# Test metrics endpoint
curl http://IPAddress:9100/metrics
```

### Useful Links

- **Prometheus Targets:** `http://IPAddress/prometheus` → Status → Targets
- **Grafana Data Sources:** Configuration → Data Sources → Save & Test

### Common Issues

- **No data in dashboards:** Check Prometheus targets status and verify exporters are running
- **Data source connection failed:** Verify Prometheus URL and network connectivity
- **Dashboard not loading:** Ensure correct dashboard ID and Prometheus data source is selected