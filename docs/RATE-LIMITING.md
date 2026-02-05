# Rate Limiting Configuration Guide

This guide provides comprehensive documentation for implementing rate limiting in nginx. Rate limiting is disabled by default in this configuration to allow flexibility during development and testing.

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Understanding Rate Limiting](#understanding-rate-limiting)
4. [Configuration Reference](#configuration-reference)
5. [Application-Specific Defaults](#application-specific-defaults)
6. [Advanced Configurations](#advanced-configurations)
7. [Testing and Debugging](#testing-and-debugging)
8. [Best Practices](#best-practices)

---

## Overview

### What is Rate Limiting?

Rate limiting controls the number of requests a client can make to your server within a specified time period. It helps:

- **Prevent DDoS attacks** - Limit damage from malicious traffic
- **Protect against brute force** - Slow down password guessing attempts
- **Ensure fair usage** - Prevent single users from monopolizing resources
- **Reduce server load** - Protect backend services from overload
- **API quota enforcement** - Implement usage tiers for APIs

### Why is it Disabled by Default?

Rate limiting is disabled in this configuration because:

1. **Development flexibility** - Avoid false positives during testing
2. **Application-specific needs** - Different apps need different limits
3. **Infrastructure variety** - CDNs and load balancers may already rate limit
4. **Debugging ease** - Rate limiting can mask other issues

---

## Quick Start

### Step 1: Enable Rate Limit Zones

Edit `nginx.conf` and uncomment the rate limit zones:

```nginx
# In nginx.conf, find and uncomment:
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=general:10m rate=1r/s;
```

### Step 2: Apply to Location Blocks

Add `limit_req` directives to your location blocks:

```nginx
location /api/ {
    limit_req zone=api burst=20 nodelay;
    # ... rest of configuration
}

location / {
    limit_req zone=general burst=10 nodelay;
    # ... rest of configuration
}
```

### Step 3: Test and Reload

```bash
# Test configuration
sudo nginx -t

# Reload nginx
sudo nginx -s reload

# Test rate limiting
for i in {1..20}; do curl -s -o /dev/null -w "%{http_code}\n" https://yoursite.com/api/; done
```

---

## Understanding Rate Limiting

### The Leaky Bucket Algorithm

nginx uses the "leaky bucket" algorithm:

```
Request Flow:
                    ┌─────────────┐
    Requests ──────►│   Bucket    │──────► Processed
    (incoming)      │  (burst)    │        (at rate limit)
                    └─────────────┘
                          │
                          ▼
                    Overflow (503)
```

- **Rate** (`rate=10r/s`): How fast the bucket drains (requests processed per second)
- **Burst** (`burst=20`): How many requests can queue in the bucket
- **Nodelay**: Process burst requests immediately instead of queuing

### Key Directives

#### limit_req_zone

Defines a shared memory zone for tracking request rates:

```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
#              └─────────┬───────┘      └──┬──┘     └──┬──┘
#                   Key variable      Zone name    Requests/second
#                   (client IP)       & size
```

| Parameter | Description |
|-----------|-------------|
| `$binary_remote_addr` | Client IP address (16 bytes for IPv4, 64 for IPv6) |
| `zone=name:size` | Shared memory zone name and size (1MB ≈ 16,000 IPs) |
| `rate=Xr/s` or `rate=Xr/m` | Allowed requests per second/minute |

#### limit_req

Applies rate limiting to a location:

```nginx
limit_req zone=api burst=20 nodelay;
#         └──┬──┘   └──┬──┘  └──┬──┘
#        Zone name   Queue    Immediate
#                    size     processing
```

| Parameter | Description |
|-----------|-------------|
| `zone=name` | Which zone to use |
| `burst=N` | Allow N extra requests to queue |
| `nodelay` | Process burst immediately (don't queue) |
| `delay=N` | Process first N burst requests immediately, queue rest |

### Response Codes

| Code | Meaning | When |
|------|---------|------|
| 200 | Success | Request processed normally |
| 503 | Service Unavailable | Rate limit exceeded (default) |
| 429 | Too Many Requests | Rate limit exceeded (if configured) |

To return 429 instead of 503:

```nginx
limit_req_status 429;
```

---

## Configuration Reference

### Recommended Zone Definitions

Add these to `nginx.conf` in the `http` block:

```nginx
# =============================================================================
# RATE LIMITING ZONES
# =============================================================================

# General web traffic - moderate limits
limit_req_zone $binary_remote_addr zone=general:10m rate=1r/s;

# API endpoints - higher limits for legitimate usage
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

# Authentication endpoints - strict limits to prevent brute force
limit_req_zone $binary_remote_addr zone=auth:10m rate=1r/m;

# Login pages - very strict
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

# Search/expensive operations - moderate limits
limit_req_zone $binary_remote_addr zone=search:10m rate=5r/s;

# File uploads - strict limits
limit_req_zone $binary_remote_addr zone=upload:10m rate=1r/s;

# Static assets - permissive (usually not needed)
limit_req_zone $binary_remote_addr zone=static:10m rate=50r/s;

# WebSocket connections - per-connection limit
limit_req_zone $binary_remote_addr zone=websocket:10m rate=2r/s;
```

### Zone Sizing Guide

| Zone Size | Approximate IPs | Use Case |
|-----------|-----------------|----------|
| 1m | ~16,000 | Small sites |
| 10m | ~160,000 | Medium sites |
| 32m | ~500,000 | Large sites |
| 64m | ~1,000,000 | Very large sites |

---

## Application-Specific Defaults

### Static Website / Blog

```nginx
# Zone definition
limit_req_zone $binary_remote_addr zone=web:10m rate=2r/s;

# Application
location / {
    limit_req zone=web burst=10 nodelay;
}

# Contact forms
location /contact {
    limit_req zone=web burst=3 nodelay;
}
```

### WordPress

```nginx
# Zone definitions
limit_req_zone $binary_remote_addr zone=wp_general:10m rate=2r/s;
limit_req_zone $binary_remote_addr zone=wp_admin:10m rate=1r/s;
limit_req_zone $binary_remote_addr zone=wp_login:10m rate=5r/m;

# Main site
location / {
    limit_req zone=wp_general burst=20 nodelay;
}

# Admin area
location /wp-admin {
    limit_req zone=wp_admin burst=10 nodelay;
}

# Login page (strict)
location = /wp-login.php {
    limit_req zone=wp_login burst=3 nodelay;
}

# XML-RPC (very strict - often abused)
location = /xmlrpc.php {
    limit_req zone=wp_login burst=1 nodelay;
}
```

### REST API

```nginx
# Zone definitions
limit_req_zone $binary_remote_addr zone=api_general:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=api_auth:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=api_write:10m rate=5r/s;

# Read operations (GET)
location /api/ {
    limit_req zone=api_general burst=30 nodelay;
}

# Authentication
location /api/auth/ {
    limit_req zone=api_auth burst=5 nodelay;
}

# Write operations (POST, PUT, DELETE)
location /api/ {
    if ($request_method !~ ^(GET|HEAD|OPTIONS)$) {
        set $limit_write 1;
    }
    limit_req zone=api_write burst=10 nodelay;
}
```

### E-Commerce (WooCommerce, Shopify-like)

```nginx
# Zone definitions
limit_req_zone $binary_remote_addr zone=shop:10m rate=5r/s;
limit_req_zone $binary_remote_addr zone=cart:10m rate=2r/s;
limit_req_zone $binary_remote_addr zone=checkout:10m rate=1r/s;
limit_req_zone $binary_remote_addr zone=payment:10m rate=10r/m;

# Product pages
location / {
    limit_req zone=shop burst=30 nodelay;
}

# Cart operations
location ~ ^/(cart|add-to-cart) {
    limit_req zone=cart burst=10 nodelay;
}

# Checkout
location /checkout {
    limit_req zone=checkout burst=5 nodelay;
}

# Payment processing (very strict)
location ~ ^/(payment|pay|process-payment) {
    limit_req zone=payment burst=2 nodelay;
}
```

### SaaS Application

```nginx
# Zone definitions
limit_req_zone $binary_remote_addr zone=app:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=app_api:10m rate=20r/s;
limit_req_zone $binary_remote_addr zone=app_auth:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=app_export:10m rate=1r/m;

# Web application
location / {
    limit_req zone=app burst=30 nodelay;
}

# API endpoints
location /api/ {
    limit_req zone=app_api burst=50 nodelay;
}

# Authentication
location ~ ^/(login|signup|forgot-password) {
    limit_req zone=app_auth burst=3 nodelay;
}

# Data exports (expensive operations)
location ~ ^/(export|download|report) {
    limit_req zone=app_export burst=2 nodelay;
}
```

### Monitoring Dashboard (Grafana, LibreNMS)

```nginx
# Zone definitions - dashboards are request-heavy
limit_req_zone $binary_remote_addr zone=monitor:10m rate=20r/s;
limit_req_zone $binary_remote_addr zone=monitor_api:10m rate=50r/s;
limit_req_zone $binary_remote_addr zone=monitor_login:10m rate=5r/m;

# Dashboard
location / {
    limit_req zone=monitor burst=50 nodelay;
}

# API (graphs, data queries)
location /api/ {
    limit_req zone=monitor_api burst=100 nodelay;
}

# Login
location /login {
    limit_req zone=monitor_login burst=3 nodelay;
}
```

### API Gateway / Microservices

```nginx
# Per-service zone definitions
limit_req_zone $binary_remote_addr zone=gw_auth:10m rate=5r/s;
limit_req_zone $binary_remote_addr zone=gw_users:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=gw_orders:10m rate=20r/s;
limit_req_zone $binary_remote_addr zone=gw_payments:10m rate=3r/s;
limit_req_zone $binary_remote_addr zone=gw_search:10m rate=5r/s;
limit_req_zone $binary_remote_addr zone=gw_uploads:10m rate=1r/s;

# Authentication service
location /auth/ {
    limit_req zone=gw_auth burst=10 nodelay;
}

# User service
location /users/ {
    limit_req zone=gw_users burst=20 nodelay;
}

# Order service
location /orders/ {
    limit_req zone=gw_orders burst=30 nodelay;
}

# Payment service (strict)
location /payments/ {
    limit_req zone=gw_payments burst=5 nodelay;
}

# Search service
location /search/ {
    limit_req zone=gw_search burst=10 nodelay;
}

# File uploads
location /uploads/ {
    limit_req zone=gw_uploads burst=3 nodelay;
}
```

---

## Advanced Configurations

### Rate Limiting by API Key

```nginx
# Map API key to rate limit key
map $http_x_api_key $limit_key {
    default         $binary_remote_addr;
    "~^premium_"    "";  # No limit for premium keys
    "~^basic_"      $http_x_api_key;  # Limit by key
}

limit_req_zone $limit_key zone=api_keyed:10m rate=100r/s;

location /api/ {
    limit_req zone=api_keyed burst=50 nodelay;
}
```

### Different Limits for Authenticated Users

```nginx
# Map authentication status
map $http_authorization $is_authenticated {
    default 0;
    "~Bearer" 1;
}

map $is_authenticated $limit_key_auth {
    0 $binary_remote_addr;
    1 "";  # No limit for authenticated
}

limit_req_zone $limit_key_auth zone=api_auth:10m rate=10r/s;
```

### Graduated Rate Limiting (Delay)

```nginx
# First 10 requests immediate, next 40 delayed, then reject
limit_req zone=api burst=50 delay=10;
```

### Whitelist Specific IPs

```nginx
geo $rate_limit {
    default 1;
    10.0.0.0/8 0;      # Internal network
    192.168.0.0/16 0;  # Private network
    203.0.113.50 0;    # Specific IP
}

map $rate_limit $limit_key_geo {
    0 "";
    1 $binary_remote_addr;
}

limit_req_zone $limit_key_geo zone=api_geo:10m rate=10r/s;
```

### Per-Server Rate Limiting

```nginx
# Limit total requests to server (not per-client)
limit_req_zone $server_name zone=server_limit:1m rate=1000r/s;

server {
    limit_req zone=server_limit burst=2000 nodelay;
}
```

### Connection Limiting (Complement to Rate Limiting)

```nginx
# Limit concurrent connections
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

location /download/ {
    limit_conn conn_limit 5;  # Max 5 concurrent connections per IP
    limit_rate 1m;            # 1MB/s per connection
}
```

---

## Testing and Debugging

### Testing Rate Limits

```bash
# Quick test with curl
for i in {1..30}; do
    curl -s -o /dev/null -w "%{http_code} " https://yoursite.com/api/
done
echo

# With timing
for i in {1..30}; do
    curl -s -o /dev/null -w "%{http_code}:%{time_total}s " https://yoursite.com/api/
done
echo

# Using Apache Bench
ab -n 100 -c 10 https://yoursite.com/api/

# Using wrk
wrk -t12 -c400 -d30s https://yoursite.com/api/
```

### Debugging Configuration

```nginx
# Add to location block for debugging
add_header X-RateLimit-Limit "10r/s" always;
add_header X-RateLimit-Remaining "$limit_req_status" always;

# Detailed error logging
error_log /var/log/nginx/error.log info;

# Log rate limited requests
log_format ratelimit '$remote_addr - $remote_user [$time_local] '
                     '"$request" $status $body_bytes_sent '
                     '"$http_referer" "$http_user_agent" '
                     'limit_req_status=$limit_req_status';

access_log /var/log/nginx/ratelimit.log ratelimit if=$limit_req_status;
```

### Monitoring Rate Limits

```bash
# Watch rate limit hits in real-time
tail -f /var/log/nginx/error.log | grep "limiting requests"

# Count 503 responses
grep " 503 " /var/log/nginx/access.log | wc -l

# Group by IP
grep "limiting requests" /var/log/nginx/error.log | \
    awk '{print $NF}' | sort | uniq -c | sort -rn | head -20
```

---

## Best Practices

### 1. Start Permissive, Tighten Gradually

```nginx
# Week 1: Monitor only (high limits)
limit_req zone=api burst=1000 nodelay;

# Week 2: Moderate limits
limit_req zone=api burst=100 nodelay;

# Week 3: Production limits
limit_req zone=api burst=30 nodelay;
```

### 2. Use Different Zones for Different Endpoints

```nginx
# Don't do this:
limit_req zone=general burst=10 nodelay;  # Everywhere

# Do this:
location /api/ { limit_req zone=api burst=30 nodelay; }
location /login { limit_req zone=auth burst=3 nodelay; }
location / { limit_req zone=general burst=10 nodelay; }
```

### 3. Return Proper Status Codes

```nginx
limit_req_status 429;

error_page 429 /429.html;
location = /429.html {
    internal;
    default_type application/json;
    return 429 '{"error":"Too Many Requests","retry_after":60}';
}
```

### 4. Add Retry-After Header

```nginx
location /api/ {
    limit_req zone=api burst=20 nodelay;

    error_page 429 = @rate_limited;
}

location @rate_limited {
    add_header Retry-After 60 always;
    add_header Content-Type application/json always;
    return 429 '{"error":"Rate limit exceeded","retry_after":60}';
}
```

### 5. Consider Your Infrastructure

- **Behind CDN**: CDN may already rate limit; coordinate limits
- **Behind Load Balancer**: Use `$http_x_forwarded_for` or real IP module
- **Multiple nginx instances**: Use shared memory (redis) or sticky sessions

### 6. Document Your Limits

```nginx
# API Rate Limits:
# - General API: 10 req/s, burst 30
# - Authentication: 5 req/min, burst 3
# - File uploads: 1 req/s, burst 5
# - Search: 5 req/s, burst 10
```

---

## Quick Reference Card

| Application Type | Endpoint | Rate | Burst |
|-----------------|----------|------|-------|
| Static site | General | 2r/s | 10 |
| WordPress | General | 2r/s | 20 |
| WordPress | Admin | 1r/s | 10 |
| WordPress | Login | 5r/m | 3 |
| REST API | Read | 10r/s | 30 |
| REST API | Write | 5r/s | 10 |
| REST API | Auth | 5r/m | 5 |
| E-commerce | General | 5r/s | 30 |
| E-commerce | Checkout | 1r/s | 5 |
| E-commerce | Payment | 10r/m | 2 |
| Dashboard | General | 20r/s | 50 |
| Dashboard | API | 50r/s | 100 |
| File uploads | Any | 1r/s | 3-5 |

---

## See Also

- [nginx limit_req_module documentation](https://nginx.org/en/docs/http/ngx_http_limit_req_module.html)
- [nginx limit_conn_module documentation](https://nginx.org/en/docs/http/ngx_http_limit_conn_module.html)
- [OWASP Rate Limiting Guidelines](https://owasp.org/www-community/controls/Blocking_Brute_Force_Attacks)
