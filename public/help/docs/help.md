# StackBill Help & Documentation

Welcome to the StackBill Observability Platform help documentation.

## Getting Started

### Accessing Services

- **Prometheus**: Access the Prometheus monitoring interface to view metrics and run queries
- **Grafana**: Access Grafana dashboards for data visualization and analytics
- **Help**: You're here! This documentation provides guidance on using the platform

## Features

### Prometheus

Prometheus is a powerful time-series database and monitoring system.

#### Key Features:
- **Time-series Data Collection**: Automatically collects metrics from configured targets
- **PromQL Query Language**: Powerful query language for data analysis
- **Alert Management**: Configure and manage alerting rules
- **Target Monitoring**: Monitor the health of scrape targets

#### Common Tasks:

**Viewing Metrics:**
1. Navigate to the Prometheus interface
2. Use the Graph tab to visualize metrics
3. Enter PromQL queries in the query bar
4. View results in table or graph format

**Example Queries:**
```
# CPU usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))

# Disk usage
100 * (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes))
```

### Grafana

Grafana provides interactive dashboards and data visualization.

#### Key Features:
- **Interactive Dashboards**: Create and customize monitoring dashboards
- **Data Visualization**: Multiple visualization types (graphs, tables, gauges, etc.)
- **Alert Notifications**: Set up alerts based on metric thresholds
- **Data Source Management**: Connect to Prometheus and other data sources

#### Common Tasks:

**Accessing Dashboards:**
1. Navigate to the Grafana interface
2. Log in with your credentials (default: admin/admin)
3. Browse pre-configured dashboards or create new ones
4. Customize panels and visualizations as needed

**Creating a Dashboard:**
1. Click "Create" → "Dashboard"
2. Add a new panel
3. Select Prometheus as the data source
4. Enter a PromQL query
5. Choose visualization type
6. Save the dashboard

## Service Configuration

### Default Credentials

**Grafana:**
- Username: `admin`
- Password: `admin`
- **Important**: Change these credentials in production!

**Prometheus:**
- No authentication required (internal network only)
- Accessible via Nginx reverse proxy

### Network Access

All services are accessed through the Nginx reverse proxy:
- Prometheus: `http://your-server-ip/prometheus/`
- Grafana: `http://your-server-ip/grafana/`
- Help: `http://your-server-ip/help`

Direct access to service ports (9090, 3000) is disabled for security.

## Troubleshooting

### Service Not Accessible

1. **Check Service Status:**
   ```bash
   # Check Prometheus
   systemctl status container-prometheus
   
   # Check Grafana
   systemctl status container-grafana
   
   # Check Nginx
   systemctl status nginx
   ```

2. **Check Service Logs:**
   ```bash
   # Prometheus logs
   podman logs container-prometheus
   
   # Grafana logs
   podman logs container-grafana
   
   # Nginx logs
   tail -f /var/log/nginx/error.log
   ```

3. **Verify Ports:**
   ```bash
   # Check if services are listening
   netstat -tlnp | grep -E '9090|3000|80'
   ```

### Metrics Not Appearing

1. **Check Prometheus Targets:**
   - Navigate to Prometheus → Status → Targets
   - Verify all targets are "UP"
   - Check for scrape errors

2. **Verify Exporter Installation:**
   - Linux: Check if node_exporter service is running
   - Windows: Check if windows_exporter service is running

3. **Check Firewall Rules:**
   - Ensure exporter ports (9100, 9182) are accessible from Prometheus server

### Dashboard Issues

1. **Data Source Connection:**
   - Verify Prometheus data source is configured correctly
   - Test the connection in Grafana data source settings

2. **Query Errors:**
   - Check PromQL syntax
   - Verify metric names exist in Prometheus
   - Use Prometheus query interface to test queries

## Best Practices

### Security

- **Change Default Passwords**: Always change default Grafana credentials
- **Use HTTPS**: Configure SSL/TLS certificates for production
- **Network Isolation**: Keep monitoring services on internal networks
- **Access Control**: Implement proper authentication and authorization

### Performance

- **Query Optimization**: Use efficient PromQL queries
- **Dashboard Optimization**: Limit the number of panels per dashboard
- **Retention Policies**: Configure appropriate data retention periods
- **Resource Monitoring**: Monitor Prometheus and Grafana resource usage

### Maintenance

- **Regular Backups**: Backup Grafana dashboards and Prometheus data
- **Update Services**: Keep services updated with security patches
- **Monitor Logs**: Regularly review service logs for errors
- **Capacity Planning**: Monitor disk usage and plan for growth

## Additional Resources

- **Prometheus Documentation**: https://prometheus.io/docs/
- **Grafana Documentation**: https://grafana.com/docs/
- **PromQL Guide**: https://prometheus.io/docs/prometheus/latest/querying/basics/

## Support

For additional support or questions:
- Contact your system administrator
- Review service logs for error details
- Check the troubleshooting section above

---

*Last updated: ${new Date().toLocaleDateString()}*

