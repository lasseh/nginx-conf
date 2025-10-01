# Nginx Performance Tuning Guide

Comprehensive guide to optimizing nginx performance for production workloads.

## Table of Contents

1. [Quick Wins](#quick-wins)
2. [Worker Process Tuning](#worker-process-tuning)
3. [Connection Optimization](#connection-optimization)
4. [Caching Strategies](#caching-strategies)
5. [Compression](#compression)
6. [Static File Optimization](#static-file-optimization)
7. [Proxy Optimization](#proxy-optimization)
8. [Operating System Tuning](#operating-system-tuning)
9. [Benchmarking](#benchmarking)
10. [Troubleshooting](#troubleshooting)

---

## Quick Wins

These settings provide immediate performance improvements with minimal risk:

```nginx
# nginx.conf

# Enable sendfile for efficient file transfers
sendfile on;

# Optimize packet sending
tcp_nopush on;      # Send headers in one packet
tcp_nodelay on;     # Disable Nagle's algorithm for real-time

# Connection optimization
keepalive_timeout 65;
keepalive_requests 1000;

# Increase hash table sizes (prevents hash collisions)
types_hash_max_size 2048;
server_names_hash_bucket_size 64;
```

**Expected Impact:** 10-20% improvement in static file serving, reduced latency

---

## Worker Process Tuning

### 1. Worker Processes

```nginx
# Automatic (recommended) - one worker per CPU core
worker_processes auto;

# Or manual based on your CPU count
worker_processes 4;  # For 4-core CPU

# Check CPU count
# nproc
```

**Rule of Thumb:**
- **< 10k req/s:** `worker_processes auto` is perfect
- **> 10k req/s:** Consider manual tuning based on workload

### 2. Worker Connections

```nginx
# Maximum connections per worker
events {
    worker_connections 4096;  # Increase from default 768
}
```

**Total connections = worker_processes × worker_connections**

Example:
- 4 workers × 4096 connections = 16,384 total connections

**Calculation:**
```bash
# Check current limits
ulimit -n

# Each connection uses 2 file descriptors (client + upstream)
# Max connections = (ulimit -n) / 2 / worker_processes
```

### 3. Worker Priority

```nginx
# Give nginx workers higher priority (-5 to -20)
worker_priority -5;  # Range: -20 (highest) to 19 (lowest)
```

**Use Case:** When nginx competes with other processes for CPU

### 4. Worker CPU Affinity

```nginx
# Bind each worker to specific CPU core
worker_cpu_affinity auto;

# Manual (4 workers on 4-core CPU)
worker_cpu_affinity 0001 0010 0100 1000;
```

**Benefit:** Reduces context switching, improves cache hit rates

### 5. Worker File Limits

```nginx
# Increase open file descriptor limit per worker
worker_rlimit_nofile 65535;
```

Also set system limits:
```bash
# /etc/security/limits.conf
nginx soft nofile 65535
nginx hard nofile 65535
```

---

## Connection Optimization

### 1. Keepalive Connections

**Client Keepalive:**
```nginx
http {
    # How long to keep client connections open
    keepalive_timeout 65;

    # Maximum requests per connection
    keepalive_requests 1000;

    # Maximum keepalive time
    keepalive_time 1h;
}
```

**Upstream Keepalive:**
```nginx
upstream backend {
    server 127.0.0.1:3000;

    # Keep 32 idle connections to backend
    keepalive 32;

    # Reuse connections for 100 requests
    keepalive_requests 100;

    # Keep connections alive for 60s
    keepalive_timeout 60s;
}
```

**Impact:** Reduces connection overhead by ~50-70%

### 2. Multi-Accept

```nginx
events {
    # Accept multiple connections at once
    multi_accept on;
}
```

**Use Case:** High-traffic servers (> 1000 req/s)
**Warning:** May increase latency under low traffic

### 3. Connection Queue

```nginx
events {
    worker_connections 4096;
    use epoll;  # Linux (default on Linux)
    # use kqueue;  # FreeBSD/macOS
}
```

Nginx automatically selects best method, but verify:
```bash
nginx -V 2>&1 | grep -o with-[a-z_]*
```

---

## Caching Strategies

### 1. Proxy Cache (Backend Responses)

```nginx
# Define cache zone
http {
    proxy_cache_path /var/cache/nginx/proxy
        levels=1:2
        keys_zone=backend_cache:10m
        max_size=1g
        inactive=60m
        use_temp_path=off;
}

server {
    location /api/ {
        proxy_pass http://backend;

        # Enable caching
        proxy_cache backend_cache;

        # Cache 200 responses for 5 minutes
        proxy_cache_valid 200 5m;

        # Cache 404 for 1 minute
        proxy_cache_valid 404 1m;

        # Use stale cache if backend is down
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;

        # Add cache status to response header
        add_header X-Cache-Status $upstream_cache_status;

        # Bypass cache for certain conditions
        proxy_cache_bypass $http_cache_control;

        # Cache lock (prevent thundering herd)
        proxy_cache_lock on;
        proxy_cache_lock_timeout 5s;
    }
}
```

**Monitoring:**
```bash
# Check cache stats
cat /var/cache/nginx/proxy/.cache_stats  # If configured

# Monitor cache hits
tail -f /var/log/nginx/access.log | grep "X-Cache-Status"
```

### 2. FastCGI Cache (PHP)

```nginx
http {
    fastcgi_cache_path /var/cache/nginx/fastcgi
        levels=1:2
        keys_zone=php_cache:10m
        max_size=1g
        inactive=60m;
}

server {
    location ~ \.php$ {
        fastcgi_cache php_cache;
        fastcgi_cache_valid 200 5m;
        fastcgi_cache_key "$scheme$request_method$host$request_uri";

        # Skip cache for certain conditions
        set $skip_cache 0;

        if ($request_method = POST) {
            set $skip_cache 1;
        }

        if ($query_string != "") {
            set $skip_cache 1;
        }

        fastcgi_cache_bypass $skip_cache;
        fastcgi_no_cache $skip_cache;

        # Headers
        add_header X-FastCGI-Cache $upstream_cache_status;
    }
}
```

### 3. Microcaching (Short-Term Caching)

```nginx
# Cache for just 1 second - still huge performance boost
location / {
    proxy_cache backend_cache;
    proxy_cache_valid 200 1s;  # 1 second cache
    proxy_cache_use_stale updating;
}
```

**Benefit:** Absorbs traffic spikes, protects backends

---

## Compression

### 1. Gzip Configuration (Already Configured)

```nginx
http {
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;  # 1-9 (6 is good balance)
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/rss+xml
        application/atom+xml
        image/svg+xml;
}
```

**Performance Impact of gzip_comp_level:**
- Level 1: Fastest, ~70% compression
- Level 6: Balanced, ~80% compression (recommended)
- Level 9: Slowest, ~85% compression (not worth it)

### 2. Pre-Compressed Files

```nginx
# Serve .gz files directly if they exist
location ~* \.(css|js)$ {
    gzip_static on;  # Requires ngx_http_gzip_static_module
}
```

**Setup:**
```bash
# Pre-compress files
find /var/www -type f \( -name '*.css' -o -name '*.js' \) -exec gzip -k9 {} \;

# Result:
# style.css
# style.css.gz  ← nginx serves this
```

**Benefit:** No runtime compression overhead

---

## Static File Optimization

### 1. Aggressive Caching

```nginx
location ~* \.(jpg|jpeg|png|gif|ico|svg|webp|avif)$ {
    # Cache for 1 year
    expires 1y;
    add_header Cache-Control "public, immutable";

    # Don't log static files
    access_log off;

    # Disable last modified time checks
    if_modified_since off;

    # Add Vary header
    add_header Vary Accept-Encoding;
}
```

### 2. Open File Cache

```nginx
http {
    # Cache file metadata (not content)
    open_file_cache max=10000 inactive=30s;
    open_file_cache_valid 60s;
    open_file_cache_min_uses 2;
    open_file_cache_errors on;
}
```

**What it caches:**
- File descriptors
- File existence/size
- Directory lookups

**Impact:** 20-30% improvement for static file serving

### 3. Sendfile and Direct I/O

```nginx
http {
    # Efficient file transfers
    sendfile on;

    # For files > 1MB, use direct I/O (bypass cache)
    directio 4m;

    # Output buffer size
    output_buffers 1 32k;
}
```

### 4. Buffer Sizes

```nginx
http {
    client_body_buffer_size 16k;    # Default 8k or 16k
    client_header_buffer_size 1k;
    client_max_body_size 8m;
    large_client_header_buffers 2 1k;
}
```

---

## Proxy Optimization

### 1. Proxy Buffering

```nginx
http {
    # Enable buffering (already in conf.d/proxy.conf)
    proxy_buffering on;

    # Buffer size (should match backend response header size)
    proxy_buffer_size 4k;

    # Number and size of buffers
    proxy_buffers 8 4k;  # 32k total

    # Buffer size for busy connections
    proxy_busy_buffers_size 8k;
}
```

**When to disable buffering:**
- Server-Sent Events (SSE)
- Large file uploads/downloads
- Real-time streaming

### 2. Proxy Timeouts

```nginx
location / {
    proxy_pass http://backend;

    # Tuned timeouts
    proxy_connect_timeout 5s;   # Time to connect to backend
    proxy_send_timeout 60s;     # Time to send request
    proxy_read_timeout 60s;     # Time to read response

    # For long-running requests
    # proxy_read_timeout 300s;
}
```

### 3. Proxy Connection Pooling

```nginx
upstream backend {
    server 127.0.0.1:3000;

    # Keep 32 connections open
    keepalive 32;

    # HTTP/1.1 for keepalive
    keepalive_requests 100;
    keepalive_timeout 60s;
}

location / {
    proxy_pass http://backend;

    # Required for keepalive
    proxy_http_version 1.1;
    proxy_set_header Connection "";
}
```

**Impact:** 50-70% reduction in backend connection overhead

---

## Operating System Tuning

### 1. File Descriptor Limits

```bash
# /etc/security/limits.conf
nginx soft nofile 65535
nginx hard nofile 65535

# Or systemd override
# /etc/systemd/system/nginx.service.d/limits.conf
[Service]
LimitNOFILE=65535
```

Verify:
```bash
# Check current limits
cat /proc/$(cat /var/run/nginx.pid)/limits | grep "Max open files"
```

### 2. TCP/IP Tuning

```bash
# /etc/sysctl.conf

# Increase connection backlog
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192

# Reuse TIME_WAIT sockets
net.ipv4.tcp_tw_reuse = 1

# Increase local port range
net.ipv4.ip_local_port_range = 1024 65535

# Increase TCP buffer sizes
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Enable TCP Fast Open
net.ipv4.tcp_fastopen = 3

# BBR congestion control (Linux 4.9+)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
```

Apply changes:
```bash
sudo sysctl -p
```

### 3. Disable Transparent Huge Pages (THP)

```bash
# Check if THP is enabled
cat /sys/kernel/mm/transparent_hugepage/enabled

# Disable THP (for better latency)
echo never > /sys/kernel/mm/transparent_hugepage/enabled

# Make persistent
# Add to /etc/rc.local or create systemd service
```

### 4. CPU Governor

```bash
# Use performance governor for low latency
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Or install cpufrequtils
sudo apt install cpufrequtils
sudo cpufreq-set -r -g performance
```

---

## Benchmarking

### 1. Apache Bench (ab)

```bash
# Simple test
ab -n 1000 -c 10 https://yoursite.com/

# Keepalive enabled
ab -n 10000 -c 100 -k https://yoursite.com/

# POST request
ab -n 1000 -c 10 -p data.json -T application/json https://yoursite.com/api/
```

### 2. wrk (Better than ab)

```bash
# Install wrk
sudo apt install wrk

# Basic test
wrk -t4 -c100 -d30s https://yoursite.com/

# With Lua script for POST
wrk -t4 -c100 -d30s -s post.lua https://yoursite.com/api/
```

### 3. siege

```bash
# Install
sudo apt install siege

# Test with multiple URLs
siege -c 50 -t 1M -f urls.txt

# Benchmark mode
siege -c 100 -r 10 https://yoursite.com/
```

### 4. Monitoring During Load Tests

```bash
# Watch nginx status
watch -n 1 'curl -s http://localhost/nginx-status'

# System resources
htop

# Network connections
watch -n 1 'ss -s'

# Disk I/O
iostat -x 1

# Check for errors
tail -f /var/log/nginx/error.log
```

### 5. Realistic Load Testing

Use k6, Locust, or Gatling for:
- Realistic user behavior
- Gradual ramp-up
- Complex scenarios
- Detailed metrics

---

## Troubleshooting

### High CPU Usage

**Symptoms:**
- CPU consistently > 80%
- Slow response times

**Diagnosis:**
```bash
# Check nginx worker CPU usage
top -p $(pgrep nginx | tr '\n' ',' | sed 's/,$//')

# Enable debug logging temporarily
nginx -s stop
nginx -g 'error_log /var/log/nginx/debug.log debug;'
```

**Common Causes:**
1. **Compression overhead** - Reduce gzip_comp_level
2. **Regex in location blocks** - Use exact matches
3. **SSL/TLS overhead** - Enable session caching
4. **Too many workers** - Reduce worker_processes

### High Memory Usage

**Diagnosis:**
```bash
# Check nginx memory
ps aux | grep nginx

# Check cache usage
du -sh /var/cache/nginx/*
```

**Common Causes:**
1. **Proxy buffering** - Reduce buffer sizes
2. **Large caches** - Reduce max_size
3. **Open file cache** - Reduce max parameter
4. **Connection backlog** - Reduce worker_connections

### Connection Timeouts

**Check timeouts:**
```bash
# Backend connection timeout
grep "upstream timed out" /var/log/nginx/error.log

# Client timeout
grep "client timed out" /var/log/nginx/error.log
```

**Fix:**
1. Increase `proxy_read_timeout`
2. Optimize backend performance
3. Enable proxy caching
4. Add more backend servers

### Dropped Connections

**Check:**
```bash
# Compare accepted vs handled
curl http://localhost/nginx-status
```

If `accepted` > `handled`, you're dropping connections.

**Fix:**
1. Increase `worker_connections`
2. Increase `worker_rlimit_nofile`
3. Check system file descriptor limits
4. Increase `net.core.somaxconn`

---

## Performance Checklist

### Before Production

- [ ] Worker processes set to auto or CPU count
- [ ] Worker connections increased (4096+)
- [ ] Keepalive enabled (client and upstream)
- [ ] Sendfile enabled
- [ ] TCP optimization (nopush, nodelay)
- [ ] Gzip compression enabled
- [ ] Open file cache enabled
- [ ] Static file caching configured (1 year)
- [ ] Access logging disabled for static files
- [ ] System file descriptor limits increased
- [ ] TCP/IP kernel parameters tuned

### After Deployment

- [ ] Load tested under realistic traffic
- [ ] Monitored for 24 hours
- [ ] Benchmark results documented
- [ ] Alerts configured for high load
- [ ] Runbook created for common issues

### Regular Maintenance

- [ ] Review access logs for slow requests
- [ ] Monitor cache hit rates
- [ ] Check for connection drops
- [ ] Review error logs weekly
- [ ] Update benchmarks quarterly

---

## Performance Targets

### Good Performance

- **Static files:** < 10ms response time
- **API endpoints:** < 100ms response time
- **Proxy requests:** < 200ms response time
- **Cache hit rate:** > 80%
- **CPU usage:** < 70% average
- **Connection drops:** 0

### Excellent Performance

- **Static files:** < 5ms response time
- **API endpoints:** < 50ms response time
- **Proxy requests:** < 100ms response time
- **Cache hit rate:** > 90%
- **CPU usage:** < 50% average
- **Connection drops:** 0

---

## Additional Resources

- [Nginx Performance Tuning](https://www.nginx.com/blog/tuning-nginx/)
- [Linux Performance](http://www.brendangregg.com/linuxperf.html)
- [TCP Tuning Guide](https://fasterdata.es.net/host-tuning/linux/)

---

**Remember:** Always benchmark before and after changes. Performance tuning is iterative!
