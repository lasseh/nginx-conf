# Nginx Monitoring Integration

Complete monitoring setup for nginx using Prometheus and Grafana.

## Overview

This monitoring stack provides:
- **Metrics collection** via nginx-prometheus-exporter
- **Visualization** via Grafana dashboards
- **Alerting** via Prometheus alerts
- **Real-time monitoring** of nginx performance and health

## Architecture

```
┌─────────┐     scrapes      ┌──────────────┐     queries    ┌─────────┐
│  Nginx  │ ────────────────>│  Prometheus  │ ──────────────>│ Grafana │
│         │  /nginx-status   │   Exporter   │   metrics      │         │
└─────────┘                  └──────────────┘                └─────────┘
                                     │
                                     ▼
                             ┌──────────────┐
                             │  Prometheus  │
                             │    Server    │
                             └──────────────┘
                                     │
                                     ▼
                             ┌──────────────┐
                             │ Alertmanager │
                             │  (optional)  │
                             └──────────────┘
```

## Quick Start

### 1. Enable Nginx Stub Status

The nginx stub_status endpoint should already be configured in your nginx setup. Verify:

```bash
# Test stub_status endpoint
curl http://localhost/nginx-status

# Expected output:
# Active connections: 2
# server accepts handled requests
#  12 12 34
# Reading: 0 Writing: 1 Waiting: 1
```

If not working, add to your nginx configuration:

```nginx
location = /nginx-status {
    stub_status;
    allow 127.0.0.1;
    allow ::1;
    deny all;
}
```

### 2. Start Nginx Prometheus Exporter

**Option A: Docker Compose (Recommended)**

```bash
cd monitoring/prometheus
docker-compose -f nginx-exporter.yml up -d

# Verify it's running
curl http://localhost:9113/metrics
```

**Option B: Native Binary**

```bash
# Download and install
wget https://github.com/nginxinc/nginx-prometheus-exporter/releases/latest/download/nginx-prometheus-exporter-linux-amd64.tar.gz
tar xzf nginx-prometheus-exporter-linux-amd64.tar.gz
sudo mv nginx-prometheus-exporter /usr/local/bin/

# Run exporter
nginx-prometheus-exporter -nginx.scrape-uri=http://localhost/nginx-status
```

### 3. Configure Prometheus

Add nginx scrape config to your Prometheus:

```yaml
# Add to prometheus.yml
scrape_configs:
  - job_name: 'nginx'
    static_configs:
      - targets: ['localhost:9113']
```

Reload Prometheus:

```bash
# Reload configuration
curl -X POST http://localhost:9090/-/reload

# Or restart
systemctl restart prometheus
```

### 4. Import Grafana Dashboard

1. Open Grafana (http://localhost:3000)
2. Go to Dashboards → Import
3. Upload `monitoring/grafana/nginx-dashboard.json`
4. Select your Prometheus datasource
5. Click Import

## Metrics Available

### Connection Metrics

- `nginx_connections_active` - Current active connections
- `nginx_connections_reading` - Connections reading request
- `nginx_connections_writing` - Connections writing response
- `nginx_connections_waiting` - Idle keepalive connections
- `nginx_connections_accepted` - Total accepted connections
- `nginx_connections_handled` - Total handled connections

### Request Metrics

- `nginx_http_requests_total` - Total HTTP requests
- `nginx_http_request_duration_seconds` - Request processing time

### Upstream Metrics (if configured)

- `nginx_upstream_server_up` - Upstream server status
- `nginx_upstream_server_connections` - Upstream connections
- `nginx_upstream_server_response_time` - Backend response time

## Alerting

### Setup Alerts

1. Copy alert rules to Prometheus:

```bash
sudo cp monitoring/prometheus/alerts/nginx-alerts.yml /etc/prometheus/rules/
```

2. Add to `prometheus.yml`:

```yaml
rule_files:
  - 'rules/nginx-alerts.yml'
```

3. Reload Prometheus:

```bash
curl -X POST http://localhost:9090/-/reload
```

### Available Alerts

- `NginxDown` - Nginx is not responding
- `NginxHighConnections` - Too many active connections
- `NginxHigh4xxRate` - High client error rate
- `NginxHigh5xxRate` - High server error rate
- `NginxDroppedConnections` - Connections being dropped
- `NginxBackendDown` - Backend server unavailable

### Configure Alertmanager (Optional)

For notifications (email, Slack, PagerDuty):

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'instance']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'slack'

receivers:
  - name: 'slack'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## Dashboards

### Included Dashboard

`monitoring/grafana/nginx-dashboard.json` provides:

**Overview Section:**
- Nginx status (up/down)
- Request rate (req/s)
- Active connections
- Connection states (reading/writing/waiting)

**Performance Section:**
- Request duration
- Upstream response time
- Connection handling rate

**Error Tracking:**
- 4xx error rate
- 5xx error rate
- Failed connections

### Custom Dashboards

Create custom Grafana dashboards with these queries:

**Request rate by status code:**
```promql
sum(rate(nginx_http_requests_total[5m])) by (status)
```

**Connection usage percentage:**
```promql
nginx_connections_active / nginx_connections_accepted * 100
```

**Error rate percentage:**
```promql
sum(rate(nginx_http_requests_total{status=~"5.."}[5m])) / sum(rate(nginx_http_requests_total[5m])) * 100
```

**Request duration p95:**
```promql
histogram_quantile(0.95, sum(rate(nginx_http_request_duration_seconds_bucket[5m])) by (le))
```

## Advanced Configuration

### Multi-Instance Monitoring

Monitor multiple nginx servers:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'nginx-cluster'
    static_configs:
      - targets:
          - 'nginx-01:9113'
          - 'nginx-02:9113'
          - 'nginx-03:9113'
        labels:
          cluster: 'web-frontend'
```

### Custom Metrics

Add custom log parsing with nginx-vts-exporter for:
- Per-location metrics
- Upstream server details
- Cache hit rates
- Request body sizes

### High Availability Setup

For production HA monitoring:

```yaml
# prometheus.yml with remote write
remote_write:
  - url: "http://thanos-receiver:19291/api/v1/receive"

# Or use Prometheus federation
scrape_configs:
  - job_name: 'federate'
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job="nginx"}'
    static_configs:
      - targets:
          - 'prometheus-01:9090'
          - 'prometheus-02:9090'
```

## Troubleshooting

### Exporter Not Connecting to Nginx

**Check stub_status is accessible:**
```bash
curl http://localhost/nginx-status
```

**Check exporter logs:**
```bash
docker logs nginx-prometheus-exporter
# or
journalctl -u nginx-exporter
```

**Common issues:**
- Firewall blocking port 9113
- Wrong scrape URI in exporter command
- Nginx not allowing localhost access to stub_status

### No Metrics in Prometheus

**Check Prometheus targets:**
- Open http://localhost:9090/targets
- Verify nginx target is "UP"

**Test scrape manually:**
```bash
curl http://localhost:9113/metrics
```

**Check Prometheus logs:**
```bash
journalctl -u prometheus
```

### Grafana Shows No Data

**Verify Prometheus datasource:**
- Grafana → Configuration → Data Sources
- Test connection to Prometheus

**Check time range:**
- Ensure dashboard time range includes recent data
- Try "Last 5 minutes"

**Verify metrics exist:**
```bash
# Query Prometheus directly
curl 'http://localhost:9090/api/v1/query?query=nginx_connections_active'
```

## Performance Impact

Monitoring overhead:

- **Exporter:** <10MB RAM, <1% CPU
- **Scraping:** Negligible impact on nginx
- **stub_status:** Very lightweight, no performance impact

Best practices:
- Use 15-30s scrape intervals (not every second)
- Disable stub_status logging: `access_log off;`
- Use localhost-only access restrictions

## Security Considerations

🔒 **Restrict stub_status:**
```nginx
location = /nginx-status {
    stub_status;
    allow 127.0.0.1;
    allow ::1;
    deny all;
}
```

🔒 **Firewall exporter port:**
```bash
# Allow only Prometheus server
sudo ufw allow from PROMETHEUS_IP to any port 9113
```

🔒 **Use HTTPS for remote monitoring:**
```bash
nginx-prometheus-exporter \
  -nginx.scrape-uri=https://nginx.example.com/nginx-status \
  -nginx.ssl-verify=true \
  -nginx.ssl-ca-cert=/path/to/ca.crt
```

## Related Documentation

- [Nginx Prometheus Exporter](https://github.com/nginxinc/nginx-prometheus-exporter)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)

## Example Queries

Useful Prometheus queries for nginx:

```promql
# Requests per second
rate(nginx_http_requests_total[5m])

# 95th percentile response time
histogram_quantile(0.95, rate(nginx_http_request_duration_seconds_bucket[5m]))

# Error rate percentage
sum(rate(nginx_http_requests_total{status=~"5.."}[5m])) / sum(rate(nginx_http_requests_total[5m])) * 100

# Connection acceptance rate
rate(nginx_connections_accepted[5m])

# Connections per state
nginx_connections_active
nginx_connections_waiting
nginx_connections_reading
nginx_connections_writing

# Dropped connections
rate(nginx_connections_accepted[5m]) - rate(nginx_connections_handled[5m])
```
