# API Gateway Setup Guide

This guide explains how to set up and use the nginx API gateway configuration for routing requests to multiple backend services.

## 📋 Overview

The API gateway configuration (`sites-available/api-gateway.example.com.conf`) demonstrates how to:

- Route different API endpoints to various backend services
- Implement rate limiting per service
- Handle CORS for web applications
- Provide health checks and monitoring
- Support WebSocket connections
- Implement API versioning
- Handle file uploads with appropriate timeouts

## 🏗 Architecture

```
Internet → nginx API Gateway → Backend Services
                ├── /auth/*      → Authentication Service (Node.js :3001)
                ├── /users/*     → User Management (Python :8001)
                ├── /orders/*    → Order Processing (Go :8002)
                ├── /payments/*  → Payment Service (Java :8003)
                ├── /files/*     → File Upload (Node.js :3002)
                ├── /analytics/* → Analytics (Python :8004)
                ├── /ws/*        → WebSocket connections
                └── /v1/, /v2/*  → API versioning
```

## 🚀 Quick Setup

### 1. Copy Configuration

```bash
# Copy the example configuration
sudo cp /etc/nginx/sites-available/api-gateway.example.com.conf /etc/nginx/sites-available/api.yourdomain.com.conf

# Edit for your domain and services
sudo nano /etc/nginx/sites-available/api.yourdomain.com.conf
```

### 2. Update Domain and SSL

Replace `api.example.com` with your actual domain:

```bash
# Use sed to replace the domain
sudo sed -i 's/api\.example\.com/api.yourdomain.com/g' /etc/nginx/sites-available/api.yourdomain.com.conf
```

### 3. Configure Backend Services

Update the upstream blocks to match your actual backend services:

```nginx
upstream auth_service {
    server 127.0.0.1:3001;    # Your auth service
    # server 10.0.1.10:3001;  # Additional servers for load balancing
    keepalive 32;
}

upstream user_service {
    server 127.0.0.1:8001;    # Your user service
    keepalive 32;
}
```

### 4. Obtain SSL Certificate

```bash
# Get SSL certificate with certbot
certbot certonly --webroot \
  -d api.yourdomain.com \
  --email your-email@domain.com \
  -w /var/www/_letsencrypt \
  -n --agree-tos
```

### 5. Enable Site

```bash
# Create symlink to enable site
sudo ln -s /etc/nginx/sites-available/api.yourdomain.com.conf /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload nginx
sudo nginx -s reload
```

## ⚙️ Configuration Details

### Rate Limiting

Each service has its own rate limiting zone:

```nginx
# Different rate limits per service type
limit_req_zone $binary_remote_addr zone=auth_api:10m rate=5r/s;      # Authentication - stricter
limit_req_zone $binary_remote_addr zone=payment_api:10m rate=3r/s;   # Payment - very strict
limit_req_zone $binary_remote_addr zone=analytics_api:10m rate=50r/s; # Analytics - permissive
```

### Service Routing

Each service gets its own location block with specific configurations:

```nginx
# Authentication service with strict rate limiting
location /auth/ {
    limit_req               zone=auth_api burst=10 nodelay;
    rewrite                 ^/auth/(.*)$ /$1 break;  # Remove /auth prefix
    proxy_pass              http://auth_service;
    # ... additional config
}
```


Pre-configured CORS headers for web application access:

```nginx
# CORS headers for API access
add_header Access-Control-Allow-Origin "$http_origin" always;
add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, PATCH, OPTIONS" always;
add_header Access-Control-Allow-Credentials "true" always;
```

### Error Handling

JSON error responses for API consistency:

```nginx
# Custom error pages return JSON
error_page 500 502 503 504 /50x.json;
location = /50x.json {
    internal;
    add_header Content-Type "application/json" always;
    return 500 '{"error":"Internal server error","timestamp":"$time_iso8601"}';
}
```

## 🔧 Customization Examples

### Adding a New Service

```nginx
upstream notification_service {
    server 127.0.0.1:8005;
    keepalive 32;
}
```

```nginx
limit_req_zone $binary_remote_addr zone=notification_api:10m rate=15r/s;
```

```nginx
location /notifications/ {
    limit_req               zone=notification_api burst=25 nodelay;
    rewrite                 ^/notifications/(.*)$ /$1 break;
    proxy_pass              http://notification_service;
    include                 snippets/proxy-headers.conf;
    proxy_set_header        X-Service "notifications";
}
```

### Load Balancing Multiple Servers

```nginx
upstream user_service {
    server 127.0.0.1:8001 weight=3;
    server 127.0.0.1:8011 weight=2;
    server 127.0.0.1:8021 weight=1 backup;
    
    # Health checks (nginx plus)
    # health_check;
    
    keepalive 32;
}
```

### Service-Specific Caching

```nginx
location /users/profile {
    # Cache user profiles for 5 minutes
    if ($request_method = GET) {
        expires 5m;
        add_header Cache-Control "public, must-revalidate";
    }

    proxy_pass http://user_service;
    include snippets/proxy-headers.conf;
}
```

### Authentication Middleware

```nginx
# Protect certain endpoints with auth subrequest
location /orders/ {
    # Authenticate request first
    auth_request /auth/verify;

    limit_req zone=order_api burst=30 nodelay;
    proxy_pass http://order_service;
    include snippets/proxy-headers.conf;
}

# Internal auth verification endpoint
location = /auth/verify {
    internal;
    proxy_pass http://auth_service/verify;
    proxy_pass_request_body off;
    proxy_set_header Content-Length "";
    proxy_set_header X-Original-URI $request_uri;
}
```

## 📊 Monitoring & Logging

### Custom Log Format

Add to `conf.d/logformat.conf`:

```nginx
log_format api_gateway '$remote_addr - $remote_user [$time_local] '
                      '"$request" $status $body_bytes_sent '
                      '"$http_referer" "$http_user_agent" '
                      'rt=$request_time uct="$upstream_connect_time" '
                      'uht="$upstream_header_time" urt="$upstream_response_time" '
                      'sid="$upstream_addr" rid="$request_id"';
```

Use in your API gateway:

```nginx
access_log /var/log/nginx/api-gateway.access.log api_gateway;
```

### Health Check Endpoint

The configuration includes a health check endpoint:

```bash
# Check API gateway health
curl https://api.yourdomain.com/health

# Response:
{
  "status": "healthy",
  "timestamp": "2025-01-27T10:30:00+00:00",
  "server": "web-server-01"
}
```

### Monitoring Backend Services

Add status endpoints for each service:

```nginx
location /status/auth {
    access_log off;
    proxy_pass http://auth_service/health;
    proxy_set_header Host $host;
}
```

## 🔒 Security Considerations


```nginx
# Require API key for certain endpoints
location /admin/ {
    if ($http_x_api_key != "your-secret-api-key") {
        return 401 '{"error":"Invalid API key"}';
    }

    proxy_pass http://admin_service;
    include snippets/proxy-headers.conf;
}
```


```nginx
# Restrict admin endpoints to specific IPs
location /admin/ {
    allow 192.168.1.0/24;
    allow 10.0.0.0/8;
    deny all;

    proxy_pass http://admin_service;
    include snippets/proxy-headers.conf;
}
```

### Request Size Limits

```nginx
# Different limits per service
location /files/ {
    client_max_body_size 100M;  # Large files
    # ... rest of config
}

location /api/ {
    client_max_body_size 1M;    # Regular API calls
    # ... rest of config
}
```

## 🧪 Testing

### Test Rate Limiting

```bash
# Test auth endpoint rate limiting (5 req/s)
for i in {1..10}; do
  curl -w "%{http_code}\n" -o /dev/null -s https://api.yourdomain.com/auth/test
  sleep 0.1
done
```

### Test Service Routing

```bash
# Test different services
curl https://api.yourdomain.com/auth/status
curl https://api.yourdomain.com/users/profile
curl https://api.yourdomain.com/orders/list
```

### Test CORS

```bash
# Test preflight request
curl -X OPTIONS \
  -H "Origin: https://yourapp.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  https://api.yourdomain.com/auth/login
```

## 🚨 Troubleshooting

### Common Issues

   - Check if backend services are running
   - Verify upstream server addresses and ports
   - Check firewall rules

   - Adjust burst values: `burst=20 nodelay`
   - Increase rate limits: `rate=20r/s`

   - Verify Origin header handling
   - Check preflight OPTIONS handling
   - Review Access-Control headers

   - Verify certificate paths
   - Check certificate expiry
   - Ensure proper certificate chain

### Debug Commands

```bash
# Check nginx configuration
sudo nginx -t

# Check backend connectivity
curl -I http://127.0.0.1:3001/health

# Monitor nginx logs
sudo tail -f /var/log/nginx/api-gateway.error.log

# Check rate limiting
sudo tail -f /var/log/nginx/error.log | grep "limiting requests"
```

## 📈 Performance Optimization

### Connection Pooling

```nginx
upstream backend_service {
    server 127.0.0.1:8001;
    keepalive 32;           # Keep 32 connections open
    keepalive_requests 100; # Reuse connections for 100 requests
    keepalive_timeout 60s;  # Keep connections open for 60s
}
```

### Caching Strategies

```nginx
# Cache static API responses
location ~* ^/api/static/.*\.(json|xml)$ {
    expires 1h;
    add_header Cache-Control "public, immutable";
    proxy_pass http://backend_service;
}

# Cache with conditional headers
location /api/data/ {
    proxy_cache api_cache;
    proxy_cache_valid 200 5m;
    proxy_cache_use_stale error timeout updating;
    proxy_pass http://backend_service;
}
```

This API gateway configuration provides a robust, scalable foundation for routing requests to multiple backend services with proper security, monitoring, and performance optimizations.