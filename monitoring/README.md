# Nginx Monitoring Integration

Complete monitoring setup for nginx using Prometheus, Grafana, and Grafana Alloy.

## Overview

This monitoring stack provides two layers:

**Layer 1: stub_status + Prometheus Exporter** (connection counts, total request rate)
- Basic health: is nginx up? how many active connections?
- No status code breakdown, no response times

**Layer 2: Grafana Alloy** (log-derived metrics + log search)
- 4xx/5xx error rates by status class
- Response time histograms (p50, p95, p99)
- Full log search via Loki in Grafana
- Per-path, per-server breakdowns

Both layers feed into Prometheus and Grafana.

## Architecture

```
┌─────────────┐  stub_status   ┌────────────────┐
│             │ ──────────────>│  Prometheus    │
│             │  :9113         │  Exporter      │──┐
│   Nginx     │                └────────────────┘  │  scrapes   ┌────────────┐
│             │                                    ├──────────>│ Prometheus │
│             │  access logs   ┌────────────────┐  │            └────────────┘
│             │ ──────────────>│  Grafana Alloy │──┘                 │
└─────────────┘  (file tail)   │                │               queries
                               │  → metrics     │                    │
                               │  → logs ──────────> Loki       ┌────▼───────┐
                               └────────────────┘               │  Grafana   │
                                                                └────────────┘
```

## Log Format Requirements

Alloy (Layer 2) parses nginx access logs to extract metrics. It expects the **`elk_json`** log format defined in `conf.d/logformat.conf`.

### Required: `elk_json` format

This is the recommended format for full monitoring support. It provides all the fields Alloy needs as structured JSON:

```nginx
access_log /var/log/nginx/access.log elk_json;
```

Output example:

```json
{
  "timestamp": "2025-06-28T10:30:45+00:00",
  "remote_addr": "192.168.1.100",
  "method": "GET",
  "uri": "/api/users",
  "status": 200,
  "bytes_sent": 1234,
  "response_time": 0.123,
  "server_name": "example.com",
  "upstream_addr": "127.0.0.1:3000",
  "user_agent": "Mozilla/5.0...",
  ...
}
```

Fields used by Alloy for metrics extraction:

| Field | Used for | Metric |
|-------|----------|--------|
| `status` | Status class labels (2xx/3xx/4xx/5xx) | `nginx_http_requests_by_status_total` |
| `method` | HTTP method labels (GET/POST/...) | `nginx_http_requests_by_status_total` |
| `response_time` | Latency histogram buckets | `nginx_http_request_duration_seconds` |
| `bytes_sent` | Response size counter | `nginx_http_response_bytes_total` |
| `server_name` | Per-vhost Loki labels | Loki log queries |

All other fields (`uri`, `remote_addr`, `upstream_addr`, `user_agent`, etc.) are available for ad-hoc log queries in Loki/Grafana but are not extracted as Prometheus metric labels to avoid cardinality explosion.

### Other formats in `conf.d/logformat.conf`

The repository provides several log formats. Here's how they relate to monitoring:

| Format | Works with Alloy? | Notes |
|--------|-------------------|-------|
| **`elk_json`** | Yes (recommended) | Full metric extraction + Loki log search |
| `elk_detailed` | Partial | Nested JSON structure; would need a different Alloy config |
| `standard` | With regex parser | See alternative config in `monitoring/alloy/config.alloy` |
| `enhanced` | With regex parser | Same as standard, extra fields ignored |
| `splunk` | No | Key-value format, not JSON |
| `cloudflare` | No | Custom text format |
| `pretty` | No | Minimal, missing required fields |

If your nginx uses the standard `combined` or `standard` text format instead of `elk_json`, a commented-out regex parser is included at the bottom of `monitoring/alloy/config.alloy`. It extracts fewer fields (no `server_name`, no `upstream_addr`, no `response_time` in the default combined format).

### Applying the log format

Set `elk_json` in each site config's `server` block:

```nginx
server {
    ...
    access_log /var/log/nginx/example.com.access.log elk_json;
    error_log  /var/log/nginx/example.com.error.log warn;
    ...
}
```

Alloy watches `/var/log/nginx/*.log` by default (configured in `monitoring/alloy/config.alloy`), so any `.log` file in that directory will be picked up automatically.

> **Note:** `error_log` does not support custom formats — it always uses nginx's built-in format. Only `access_log` needs to be changed.

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

### 4. Set Up Grafana Alloy (status codes + log search)

Alloy tails nginx access logs and gives you what stub_status can't:
4xx/5xx error rates, response time histograms, and full log search via Loki.

**Step 1: Switch nginx to JSON logging**

In your site configs, use the `elk_json` format (defined in `conf.d/logformat.conf`).
See [Log Format Requirements](#log-format-requirements) above for details on which fields
are used and what alternative formats are supported.

```nginx
access_log /var/log/nginx/access.log elk_json;
```

**Step 2: Install Alloy**

```bash
# Debian/Ubuntu
sudo apt install grafana-alloy

# RHEL/CentOS
sudo yum install grafana-alloy

# Or via Docker
docker run -v ./monitoring/alloy:/etc/alloy grafana/alloy:latest run /etc/alloy/config.alloy
```

See https://grafana.com/docs/alloy/latest/get-started/install/ for all options.

**Step 3: Deploy the config**

```bash
sudo cp monitoring/alloy/config.alloy /etc/alloy/config.alloy
sudo systemctl restart alloy
```

**Step 4: Add Alloy as a Prometheus scrape target**

```yaml
# Add to prometheus.yml
scrape_configs:
  - job_name: 'alloy'
    static_configs:
      - targets: ['localhost:12345']
```

**Step 5: Add Loki as a Grafana datasource**

1. Grafana → Configuration → Data Sources → Add
2. Select Loki, URL: `http://localhost:3100`

**Metrics now available (from Alloy):**

- `nginx_http_requests_by_status_total` — request count by method + status class (2xx/3xx/4xx/5xx)
- `nginx_http_request_duration_seconds` — response time histogram (p50/p95/p99)
- `nginx_http_response_bytes_total` — total response bytes

**Example PromQL queries:**

```promql
# 5xx error rate as percentage
sum(rate(nginx_http_requests_by_status_total{status_class="5xx"}[5m]))
/ sum(rate(nginx_http_requests_by_status_total[5m])) * 100

# p95 response time
histogram_quantile(0.95, sum(rate(nginx_http_request_duration_seconds_bucket[5m])) by (le))
```

**Example Loki queries (LogQL) in Grafana Explore:**

```logql
# All 5xx errors
{job="nginx"} | json | status_class = "5xx"

# Slow requests (>1s)
{job="nginx"} | json | response_time > 1

# 404s on API paths
{job="nginx"} | json | status = "404" | uri =~ "/api/.*"
```

### 5. Import Grafana Dashboard

1. Open Grafana (http://localhost:3000)
2. Go to Dashboards → Import
3. Upload `monitoring/grafana/nginx-dashboard.json`
4. Select your Prometheus datasource
5. Click Import

## Metrics Available

These metrics come from nginx `stub_status` via the prometheus exporter.

### Connection Metrics

- `nginx_connections_active` - Current active connections
- `nginx_connections_reading` - Connections reading request
- `nginx_connections_writing` - Connections writing response
- `nginx_connections_waiting` - Idle keepalive connections
- `nginx_connections_accepted` - Total accepted connections (counter)
- `nginx_connections_handled` - Total handled connections (counter)

### Request Metrics

- `nginx_http_requests_total` - Total HTTP requests (counter, no status code breakdown)

### Not Available (requires NGINX Plus or VTS module)

- Per-status-code request counts (no 4xx/5xx breakdown)
- Request duration / response time histograms
- Upstream server health and response times
- Per-location or per-server metrics
- SSL certificate expiry

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
- `NginxHighRequestRate` - High request rate
- `NginxRequestRateDrop` - Sudden traffic drop
- `NginxHighWaitingConnections` - Many idle connections
- `NginxDroppedConnections` - Connections being dropped

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

`monitoring/grafana/nginx-dashboard.json` provides a comprehensive 16-panel dashboard:

**Sections:**
- **Overview** - Nginx status, request rate, error rate, active connections, p95 latency, bytes/s, uptime, dropped connections
- **Traffic & Errors** - Request rate with status breakdown, error rate percentage, 4xx/5xx rates
- **Response Times** - Percentile latencies (p50/p95/p99) and response time heatmap
- **Connections** - Connection states and acceptance/handled rates
- **Bandwidth** - Response bytes/s and request method distribution

### Custom Dashboards

Create custom Grafana dashboards with these queries:

**Request rate:**
```promql
rate(nginx_http_requests_total[5m])
```

**Active connections by state:**
```promql
nginx_connections_reading
nginx_connections_writing
nginx_connections_waiting
```

**Dropped connections per second:**
```promql
rate(nginx_connections_accepted[5m]) - rate(nginx_connections_handled[5m])
```

**Connection acceptance rate:**
```promql
rate(nginx_connections_accepted[5m])
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

# Connection acceptance rate
rate(nginx_connections_accepted[5m])

# Connections per state
nginx_connections_active
nginx_connections_waiting
nginx_connections_reading
nginx_connections_writing

# Dropped connections per second
rate(nginx_connections_accepted[5m]) - rate(nginx_connections_handled[5m])
```

> **Note:** The queries above use stub_status metrics (Layer 1). For per-status-code
> error rates and response time histograms, use the Alloy-derived metrics (Layer 2)
> described in the [Grafana Alloy](#4-set-up-grafana-alloy-status-codes--log-search) section.
