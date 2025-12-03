# STACKBILL - Installation, Setup & Grafana Walkthrough

_Version: 1.0.0_

Prepared from: Uploaded STACKBILL operations guide and provided endpoints

## Document Overview

This document contains two parts:

Part 2 - Frontend-to-Grafana workflow: Grafana initial login, add Prometheus data source and import dashboards for Linux and Windows.

## Frontend to Grafana: GUI Walkthrough

**Scope:** Steps from the frontend URL through Grafana initial login, configuring the Prometheus data source, and importing dashboards.

### Endpoints and Credentials

- **Frontend URL:** `http://IPAddress/`
- **Prometheus URL:** `http://IPAddress/prometheus`
- **Help URL:** `http://IPAddress/help`
- **Grafana URL:** `http://IPAddress/grafana`
- **Grafana login:** Username: `admin` | Password: `admin`
- **Recommended dashboard IDs from Grafana.com:** Linux: `1860` | Windows: `19269`

### Step A - Access the frontend

1. Open a browser and navigate to the frontend URL. Confirm the home page renders and links to Grafana and Prometheus are visible.

![frontend](/help/docs/images/Picture1.png)

### Step B - Grafana: Initial login

1. Open Grafana at the Grafana URL and login using provided credentials. On first login, change the default password.

![frontend](/help/docs/images/Picture2.png)

*Figure 2: Grafana login page (placeholder).*

### Step C - Add Prometheus data source

**Procedure:**

1. **In Grafana:**
   - Configuration (gear) → Data Sources → Add data source → Prometheus

2. **Configure:**
   - **Name:** Prometheus
   - **URL:** `http://localhost:9090` (use host IP or container network alias if required)
   - **Access:** Server (default)

3. Click **Save & Test** - expected: Data source is working (green confirmation).

![Grafana](/help/docs/images/Picture3.png)

*Figure 3: Data source configuration (placeholder).*

### Step D - Import dashboards

**Recommended community dashboards and IDs:**
- Linux (Node Exporter Full) - Dashboard ID: `1860`
- Windows (Windows Exporter) - Dashboard ID: `19269`

**Import steps:**

1. In Grafana: Click **+** → **Import**.
2. Enter dashboard ID (e.g., 1860) and click **Load**.
3. When prompted, select the Prometheus data source and click **Import**.
4. Repeat for Windows dashboard if Windows targets are in use.

![Grafana Import](/help/docs/images/Picture4.png)

*Figure 4: Import dashboard dialog (placeholder).*

## Verification - Dashboard data

- Open the imported dashboard and confirm panels show data.
- If panels show no data, confirm:
  - Prometheus targets show UP (Prometheus UI → Status → Targets).
  - Node exporter / Windows exporter metrics are reachable and being scraped.
  - Grafana data source is configured correctly and queries return results (Explore).

## Appendix - Troubleshooting & Notes

**Quick checks and useful commands:**

- Verify Grafana container/process: `sudo podman ps | grep grafana`
- Verify Prometheus targets: `http://IPAddress/prometheus` → Status → Targets
- Test metrics endpoint: `curl http://IPAddress:9100/metrics`
- Grafana: Configuration → Data Sources → Save & Test