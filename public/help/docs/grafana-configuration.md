# STACKBILL - Installation, Setup & Grafana Walkthrough

**Version:** 1.0.0

**Prepared from:** Uploaded STACKBILL operations guide and provided endpoints

---

## Document Overview

This document provides a complete walkthrough for the Frontend-to-Grafana workflow, covering:

- Grafana initial login
- Adding Prometheus data source
- Importing dashboards for Linux and Windows

---

## Frontend to Grafana: GUI Walkthrough

This guide walks you through the steps from accessing the frontend URL through Grafana initial login, configuring the Prometheus data source, and importing dashboards.

### Endpoints and Credentials

Before you begin, note the following endpoints and credentials:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Frontend** | `http://IPAddress/` | - |
| **Prometheus** | `http://IPAddress/prometheus` | - |
| **Help** | `http://IPAddress/help` | - |
| **Grafana** | `http://IPAddress/grafana` | Username: `admin`<br>Password: `admin` |

**Recommended Dashboard IDs:**
- **Linux:** Dashboard ID `1860` (Node Exporter Full)
- **Windows:** Dashboard ID `19269` (Windows Exporter)

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

