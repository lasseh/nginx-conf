# Sites Available Guide

Complete reference for all nginx site configuration templates in `sites-available/`. Choose the right template for your use case, customize it, and deploy.

---

## 📑 Table of Contents

1. [Quick Reference](#quick-reference)
2. [Beginner's Guide](#beginners-guide)
3. [Template Details](#template-details)
   - [static-site.conf](#1-static-siteconf) - Static HTML/SPA (React, Vue, Angular)
   - [reverse-proxy.conf](#2-reverse-proxyconf) - Simple backend proxy
   - [example-site.com.conf](#3-example-sitecomconf) - Full-featured multi-subdomain
   - [api-gateway.example.com.conf](#4-api-gatewayexamplecomconf) - Microservices routing
   - [wordpress.conf](#5-wordpressconf) - WordPress with PHP-FPM
   - [docker-compose.conf](#6-docker-composeconf) - Container services
   - [load-balancer.conf](#7-load-balancerconf) - Multi-server load balancing
   - [development.conf](#8-developmentconf) - Local development
   - [grafana.example.com.conf](#9-grafanaexamplecomconf) - Grafana monitoring
   - [librenms.example.com.conf](#10-librenmsexamplecomconf) - LibreNMS network monitoring
   - [netbox.example.com.conf](#11-netboxexamplecomconf) - NetBox IPAM/DCIM
4. [Common Patterns](#common-patterns)
5. [Customization Tips](#customization-tips)

---

## Quick Reference

| Template | Use Case | Backend | Complexity | Best For |
|----------|----------|---------|------------|----------|
| `static-site.conf` | Static HTML/SPA | None | ⭐ Beginner | React, Vue, Angular, HTML sites |
| `reverse-proxy.conf` | Single backend app | HTTP | ⭐ Beginner | Node.js, Python, Go applications |
| `wordpress.conf` | WordPress/PHP | PHP-FPM | ⭐⭐ Intermediate | WordPress, PHP applications |
| `docker-compose.conf` | Container routing | Docker | ⭐⭐ Intermediate | Docker services, containers |
| `development.conf` | Local dev server | HTTP | ⭐ Beginner | Development environments |
| `example-site.com.conf` | Multi-subdomain | HTTP | ⭐⭐⭐ Advanced | Complex multi-service sites |
| `api-gateway.example.com.conf` | API gateway | HTTP | ⭐⭐⭐ Advanced | Microservices, API routing |
| `load-balancer.conf` | Load balancing | HTTP | ⭐⭐⭐ Advanced | High availability, scaling |
| `grafana.example.com.conf` | Grafana proxy | Grafana | ⭐⭐ Intermediate | Monitoring dashboards |
| `librenms.example.com.conf` | LibreNMS proxy | LibreNMS | ⭐⭐ Intermediate | Network monitoring |
| `netbox.example.com.conf` | NetBox proxy | NetBox | ⭐⭐ Intermediate | IPAM/DCIM systems |

---

## Beginner's Guide

### First Time Using Nginx?

**Step 1: Choose Your Template**
- **Static website?** → Use `static-site.conf`
- **Backend API/app?** → Use `reverse-proxy.conf`
- **WordPress?** → Use `wordpress.conf`
- **Docker containers?** → Use `docker-compose.conf`

**Step 2: Copy and Customize**
```bash
# Copy template
sudo cp /etc/nginx/sites-available/static-site.conf /etc/nginx/sites-available/mysite.com.conf

# Edit with your favorite editor
sudo nano /etc/nginx/sites-available/mysite.com.conf
```

**Step 3: What to Change**
Every template requires these changes:
1. **`server_name`** - Change to your actual domain
2. **SSL certificate paths** - Update `/etc/letsencrypt/live/YOUR-DOMAIN/`
3. **Backend addresses** (if applicable) - Update `proxy_pass` or `upstream` blocks
4. **Root directory** (for static sites) - Update `root` directive

**Step 4: Get SSL Certificate**
```bash
sudo certbot certonly --webroot \
  -d mysite.com -d www.mysite.com \
  -w /var/www/_letsencrypt \
  --email your@email.com -n --agree-tos
```

**Step 5: Enable and Test**
```bash
# Create symlink to enable
sudo ln -s /etc/nginx/sites-available/mysite.com.conf /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload nginx
sudo nginx -s reload
```

---

## Template Details

### 1. `static-site.conf`
**→ Static HTML, React, Vue, Angular, SPA**

#### What It Does
Serves static files with aggressive caching, SPA routing support, and HTTPS redirect.

#### Use This When
- You have pre-built HTML/CSS/JS files
- React/Vue/Angular production builds
- No backend server needed
- Just serving static content

#### Key Features
```nginx
# SPA routing support (all routes → index.html)
try_files $uri $uri/ /index.html;

# Aggressive caching for assets
location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}

# Security headers included
include snippets/security-headers.conf;
```

#### What to Customize
```nginx
# 1. Domain name
server_name mysite.com www.mysite.com;

# 2. SSL certificate paths
ssl_certificate     /etc/letsencrypt/live/mysite.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/mysite.com/privkey.pem;

# 3. Root directory
root /var/www/mysite;

# 4. (Optional) Add rate limiting
limit_req zone=general burst=20 nodelay;
```

#### Quick Setup
```bash
# Create web directory
sudo mkdir -p /var/www/mysite
sudo chown -R nginx:nginx /var/www/mysite

# Copy your built files
sudo cp -r dist/* /var/www/mysite/
# or
sudo cp -r build/* /var/www/mysite/

# Deploy configuration
sudo cp sites-available/static-site.conf sites-available/mysite.com.conf
sudo nano sites-available/mysite.com.conf  # Edit domains and paths
sudo ln -s ../sites-available/mysite.com.conf sites-enabled/
sudo nginx -t && sudo nginx -s reload
```

---

### 2. `reverse-proxy.conf`
**→ Single Backend Application (Node.js, Python, Go)**

#### What It Does
Proxies requests to a single backend application with health checks, failover, and WebSocket support.

#### Use This When
- You have one backend service (Express, Flask, FastAPI, Go)
- Running on localhost:3000 or similar
- Need HTTPS termination
- Want connection pooling

#### Key Features
```nginx
# Backend definition with keepalive
upstream backend_app {
    server 127.0.0.1:3000;
    keepalive 32;
}

# Standard proxy headers
include snippets/proxy-headers.conf;

# Error handling and failover
proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;

# Custom error pages
include snippets/error-pages.conf;
```

#### What to Customize
```nginx
# 1. Backend server address
upstream backend_app {
    server 127.0.0.1:3000;    # Change port if needed
}

# 2. Domain and SSL
server_name mysite.com www.mysite.com;
ssl_certificate /etc/letsencrypt/live/mysite.com/fullchain.pem;

# 3. (Optional) File upload size
client_max_body_size 100M;

# 4. (Optional) Timeouts for slow backends
proxy_read_timeout 60s;
```

#### WebSocket Support
Uncomment this block if your app uses WebSockets:
```nginx
location /ws {
    proxy_pass http://backend_app;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_read_timeout 3600s;
}
```

#### Quick Setup
```bash
# Start your backend
node server.js  # or python app.py, ./myapp, etc.
# Make sure it's running on localhost:3000

# Deploy nginx config
sudo cp sites-available/reverse-proxy.conf sites-available/mysite.com.conf
sudo nano sites-available/mysite.com.conf  # Update domain and backend port
sudo ln -s ../sites-available/mysite.com.conf sites-enabled/
sudo nginx -t && sudo nginx -s reload
```

---

### 3. `example-site.com.conf`
**→ Full-Featured Multi-Subdomain Site**

#### What It Does
Comprehensive example showing main site, API subdomain, and admin subdomain with different security and rate limiting per subdomain.

#### Use This When
- You have multiple subdomains (www, api, admin)
- Different services on different subdomains
- Need fine-grained rate limiting
- Want comprehensive security setup

#### Architecture
```
mysite.com          → Static frontend
api.mysite.com      → Backend API with CORS, rate limiting
admin.mysite.com    → Admin panel with strict security
```

#### Key Features
```nginx
# Different upstreams per service
upstream backend_app { server 127.0.0.1:3000; }
upstream admin_app { server 127.0.0.1:3100; }

# Per-endpoint rate limiting
location /auth/ { limit_req zone=api burst=10; }
location /upload/ { client_max_body_size 50M; }

# CORS for API
add_header Access-Control-Allow-Origin "$http_origin";

# Enhanced admin security
# IP whitelist, stricter CSP, etc.
```

#### What to Customize
```nginx
# 1. All domain names
server_name mysite.com www.mysite.com;
server_name api.mysite.com;
server_name admin.mysite.com;

# 2. Backend ports
upstream backend_app { server 127.0.0.1:3000; }
upstream admin_app { server 127.0.0.1:3100; }

# 3. Rate limits (adjust per your traffic)
limit_req zone=api burst=20;      # API calls
limit_req zone=general burst=50;  # Admin area

# 4. (Optional) IP whitelist for admin
allow 192.168.1.0/24;  # Your network
deny all;
```

#### When to Use This Template
- Starting point for complex applications
- Need to understand all nginx features
- Want to see best practices in one place
- Building production-grade infrastructure

---

### 4. `api-gateway.example.com.conf`
**→ Microservices API Gateway**

#### What It Does
Routes different API endpoints to different backend services with per-service rate limiting and monitoring.

#### Use This When
- You have multiple backend services/microservices
- Each service should have different rate limits
- Need centralized API management
- Want service-specific routing

#### Architecture
```
api.mysite.com/auth/*      → Authentication Service (:3001)
api.mysite.com/users/*     → User Service (:8001)
api.mysite.com/orders/*    → Order Service (:8002)
api.mysite.com/payments/*  → Payment Service (:8003)
```

#### Key Features
```nginx
# Multiple upstreams
upstream auth_service { server 127.0.0.1:3001; }
upstream user_service { server 127.0.0.1:8001; }
upstream order_service { server 127.0.0.1:8002; }

# Per-service rate limiting
limit_req_zone $binary_remote_addr zone=auth_api:10m rate=5r/s;
limit_req_zone $binary_remote_addr zone=payment_api:10m rate=3r/s;

# Service routing with path rewriting
location /auth/ {
    rewrite ^/auth/(.*)$ /$1 break;  # Remove /auth prefix
    proxy_pass http://auth_service;
}
```

#### What to Customize
```nginx
# 1. Add your services
upstream myservice {
    server 127.0.0.1:PORT;
    keepalive 32;
}

# 2. Add rate limiting zone (in http block, usually nginx.conf)
limit_req_zone $binary_remote_addr zone=myservice_api:10m rate=10r/s;

# 3. Add routing
location /myservice/ {
    limit_req zone=myservice_api burst=20 nodelay;
    rewrite ^/myservice/(.*)$ /$1 break;
    proxy_pass http://myservice;
    include snippets/proxy-headers.conf;
}

# 4. Adjust rate limits based on service criticality
# Auth: strict (5 req/s)
# Payment: very strict (3 req/s)
# Analytics: permissive (50 req/s)
```

#### Advanced Features
```nginx
# Health check endpoints
location /status/auth {
    proxy_pass http://auth_service/health;
}

# JSON error responses
error_page 500 502 503 504 /50x.json;
location = /50x.json {
    return 500 '{"error":"Internal server error"}';
}

# CORS for web apps
add_header Access-Control-Allow-Origin "$http_origin";
```

---

### 5. `wordpress.conf`
**→ WordPress with PHP-FPM**

#### What It Does
Optimized WordPress configuration with security hardening, PHP-FPM integration, and caching.

#### Use This When
- Running WordPress
- Any PHP application
- Using PHP-FPM

#### Key Features
```nginx
# WordPress-specific security
location ~ /\.(htaccess|htpasswd|env) { deny all; }
location ~ /wp-config.php { deny all; }
location ~ /readme.html { deny all; }

# PHP-FPM processing
location ~ \.php$ {
    fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    fastcgi_index index.php;
    include fastcgi_params;
}

# WordPress permalinks
try_files $uri $uri/ /index.php?$args;

# Static file caching
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
}
```

#### What to Customize
```nginx
# 1. Domain and SSL
server_name mywordpress.com www.mywordpress.com;
ssl_certificate /etc/letsencrypt/live/mywordpress.com/fullchain.pem;

# 2. WordPress directory
root /var/www/mywordpress;

# 3. PHP-FPM version/socket
fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;  # Update PHP version

# 4. Upload size (for media uploads)
client_max_body_size 100M;

# 5. (Optional) Restrict wp-admin by IP
location /wp-admin/ {
    allow YOUR_IP;
    deny all;
    # ... php handling
}
```

#### Quick Setup
```bash
# Install WordPress
sudo mkdir -p /var/www/mywordpress
cd /var/www/mywordpress
sudo wget https://wordpress.org/latest.tar.gz
sudo tar -xzvf latest.tar.gz --strip-components=1
sudo chown -R nginx:nginx /var/www/mywordpress

# Install PHP-FPM
sudo apt install php8.2-fpm php8.2-mysql php8.2-curl php8.2-gd php8.2-xml

# Deploy nginx config
sudo cp sites-available/wordpress.conf sites-available/mywordpress.com.conf
sudo nano sites-available/mywordpress.com.conf  # Update domain and paths
sudo ln -s ../sites-available/mywordpress.com.conf sites-enabled/
sudo nginx -t && sudo nginx -s reload
```

---

### 6. `docker-compose.conf`
**→ Docker Container Services**

#### What It Does
Routes traffic to multiple Docker containers, each accessible via different paths or subdomains.

#### Use This When
- Running services in Docker containers
- Using docker-compose
- Need to expose multiple containers on one domain

#### Architecture
```
mysite.com/app1       → Container 1 (localhost:8001)
mysite.com/app2       → Container 2 (localhost:8002)
app1.mysite.com       → Container 1 subdomain
app2.mysite.com       → Container 2 subdomain
```

#### Key Features
```nginx
# Container upstreams
upstream app1_container { server 127.0.0.1:8001; }
upstream app2_container { server 127.0.0.1:8002; }

# Path-based routing
location /app1/ {
    rewrite ^/app1/(.*)$ /$1 break;
    proxy_pass http://app1_container;
}

# Subdomain routing
server {
    server_name app1.mysite.com;
    proxy_pass http://app1_container;
}
```

#### What to Customize
```nginx
# 1. Add your container upstreams
upstream mycontainer {
    server 127.0.0.1:PORT;  # Docker published port
    keepalive 16;
}

# 2. Add routing (path-based or subdomain)
# Path-based:
location /myapp/ {
    rewrite ^/myapp/(.*)$ /$1 break;
    proxy_pass http://mycontainer;
    include snippets/proxy-headers.conf;
}

# Subdomain:
server {
    listen 443 ssl;
    http2 on;
    server_name myapp.mysite.com;
    # SSL config...
    location / {
        proxy_pass http://mycontainer;
        include snippets/proxy-headers.conf;
    }
}
```

#### Docker Compose Example
```yaml
# docker-compose.yml
services:
  app1:
    image: myapp:latest
    ports:
      - "8001:3000"

  app2:
    image: otherapp:latest
    ports:
      - "8002:8080"
```

---

### 7. `load-balancer.conf`
**→ Multi-Server Load Balancing**

#### What It Does
Distributes traffic across multiple backend servers with health checks and failover.

#### Use This When
- You have multiple backend servers
- Need high availability
- Want automatic failover
- Scaling horizontally

#### Key Features
```nginx
# Multiple backend servers with weights
upstream backend_cluster {
    server 192.168.1.10:8080 weight=3;    # Primary (75% traffic)
    server 192.168.1.11:8080 weight=1;    # Secondary (25% traffic)
    server 192.168.1.12:8080 backup;      # Only used if others fail

    keepalive 32;
    keepalive_requests 1000;
}

# Load balancing algorithms
# least_conn;  # Route to server with least connections
# ip_hash;     # Same client always goes to same server
# hash $request_uri consistent;  # URL-based routing
```

#### What to Customize
```nginx
# 1. Add your backend servers
upstream backend_cluster {
    server 10.0.1.10:3000 weight=3;
    server 10.0.1.11:3000 weight=2;
    server 10.0.1.12:3000 weight=1;
    server 10.0.1.13:3000 backup;

    # Choose load balancing method
    least_conn;  # or ip_hash, or hash $variable

    keepalive 32;
}

# 2. Health checks (requires nginx Plus or external tool)
# For open source nginx, use external health checker

# 3. Session persistence (if needed)
ip_hash;  # Same client → same server
```

#### Load Balancing Strategies
```nginx
# Round Robin (default)
upstream backend { server 10.0.1.10; server 10.0.1.11; }

# Least Connections (good for long requests)
upstream backend {
    least_conn;
    server 10.0.1.10;
    server 10.0.1.11;
}

# IP Hash (session persistence)
upstream backend {
    ip_hash;
    server 10.0.1.10;
    server 10.0.1.11;
}

# Weighted Round Robin (different server capacities)
upstream backend {
    server 10.0.1.10 weight=3;  # Gets 3x more traffic
    server 10.0.1.11 weight=1;
}
```

---

### 8. `development.conf`
**→ Local Development Environment**

#### What It Does
Simplified configuration for local development with relaxed security and proxy caching disabled.

#### Use This When
- Running nginx locally for development
- Using `localhost` or `dev.local`
- Need hot-reload support
- Testing configurations

#### Key Features
```nginx
# Listen on localhost only
server_name localhost dev.local;

# Disable proxy caching for development
proxy_buffering off;
proxy_cache off;

# Allow CORS from anywhere (dev only!)
add_header Access-Control-Allow-Origin "*";

# Relaxed rate limiting
limit_req zone=general burst=100 nodelay;
```

#### What to Customize
```nginx
# 1. Development domain
server_name localhost myapp.local;

# 2. Backend port (your dev server)
upstream dev_backend {
    server 127.0.0.1:3000;  # npm run dev, flask run, etc.
}

# 3. (Optional) Add self-signed cert for HTTPS testing
# Generate with:
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
#   -keyout /etc/nginx/ssl/dev.key \
#   -out /etc/nginx/ssl/dev.crt
```

#### /etc/hosts Setup
```bash
# Add to /etc/hosts for custom domain
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts
```

---

### 9. `grafana.example.com.conf`
**→ Grafana Monitoring Dashboard**

#### What It Does
Proxies Grafana with WebSocket support for live updates and proper security headers.

#### Use This When
- Running Grafana monitoring
- Default Grafana port 3000

#### Key Features
```nginx
# Grafana upstream
upstream grafana {
    server 127.0.0.1:3000;
    keepalive 16;
}

# WebSocket support for live dashboards
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;

# Grafana-specific headers
proxy_set_header Host $host;
```

#### What to Customize
```nginx
# 1. Grafana port (if changed from default)
upstream grafana {
    server 127.0.0.1:3000;  # Default Grafana port
}

# 2. Domain and SSL
server_name grafana.mysite.com;
ssl_certificate /etc/letsencrypt/live/grafana.mysite.com/fullchain.pem;

# 3. (Optional) Basic auth for extra security
location / {
    auth_basic "Grafana Login";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://grafana;
}
```

---

### 10. `librenms.example.com.conf`
**→ LibreNMS Network Monitoring**

#### What It Does
Proxies LibreNMS with PHP-FPM support and proper security for network monitoring.

#### Use This When
- Running LibreNMS
- Network device monitoring

#### Key Features
```nginx
# PHP-FPM for LibreNMS
location ~ \.php$ {
    fastcgi_pass unix:/var/run/php/php-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
}

# LibreNMS security
location ~ /\.ht { deny all; }
location ~ /\.git { deny all; }
```

---

### 11. `netbox.example.com.conf`
**→ NetBox IPAM/DCIM**

#### What It Does
Proxies NetBox with WebSocket support for real-time updates.

#### Use This When
- Running NetBox
- IP Address Management (IPAM)
- Data Center Infrastructure Management (DCIM)

#### Key Features
```nginx
# NetBox upstream
upstream netbox {
    server 127.0.0.1:8001;
    keepalive 16;
}

# WebSocket for live updates
location /ws/ {
    proxy_pass http://netbox;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
}

# Static files
location /static/ {
    alias /opt/netbox/netbox/static/;
    expires 1y;
}
```

---

## Common Patterns

### Pattern 1: Adding Rate Limiting

```nginx
# In your server or location block
location /api/ {
    limit_req zone=api burst=20 nodelay;
    proxy_pass http://backend;
}
```

### Pattern 2: IP Whitelisting

```nginx
location /admin/ {
    allow 192.168.1.0/24;  # Office network
    allow 10.0.0.0/8;       # VPN
    deny all;

    proxy_pass http://admin_backend;
}
```

### Pattern 3: Basic Authentication

```bash
# Create password file
sudo htpasswd -c /etc/nginx/.htpasswd admin
```

```nginx
location / {
    auth_basic "Restricted Area";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://backend;
}
```

### Pattern 4: CORS Headers

```nginx
# Simple CORS (API)
add_header Access-Control-Allow-Origin "$http_origin" always;
add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE" always;
add_header Access-Control-Allow-Credentials "true" always;

# Handle preflight
if ($request_method = OPTIONS) {
    add_header Access-Control-Allow-Origin "$http_origin";
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE";
    add_header Access-Control-Allow-Headers "Authorization, Content-Type";
    add_header Access-Control-Max-Age 86400;
    return 204;
}
```

### Pattern 5: Custom Error Pages

```nginx
# Include custom error pages
include snippets/error-pages.conf;

# Or define custom ones
error_page 404 /404.html;
location = /404.html {
    root /var/www/errors;
    internal;
}
```

### Pattern 6: Maintenance Mode

```nginx
set $maintenance off;

if (-f /var/www/maintenance.flag) {
    set $maintenance on;
}

if ($maintenance = on) {
    return 503;
}

error_page 503 @maintenance;
location @maintenance {
    root /var/www;
    rewrite ^(.*)$ /maintenance.html break;
}
```

---

## Customization Tips

### Choosing the Right Template

1. **Start simple** - Use `static-site.conf` or `reverse-proxy.conf` first
2. **Build up complexity** - Add features as needed
3. **Learn from examples** - `example-site.com.conf` shows all features
4. **Copy patterns** - Reuse configurations from existing templates

### Essential Customizations

Every template needs:
1. ✅ `server_name` updated to your domain
2. ✅ SSL certificate paths updated
3. ✅ Backend ports/addresses updated
4. ✅ Root directory set (for static sites)

### Optional Enhancements

Consider adding:
- Rate limiting for protection
- IP whitelisting for admin areas
- Custom error pages
- CORS headers for APIs
- WebSocket support for real-time apps
- Basic auth for extra security
- Custom log formats
- Caching strategies

### Testing Your Configuration

```bash
# 1. Test syntax
sudo nginx -t

# 2. Check configuration details
sudo nginx -T | grep -A 10 "server_name"

# 3. Test HTTP → HTTPS redirect
curl -I http://yoursite.com

# 4. Test HTTPS
curl -I https://yoursite.com

# 5. Test backend connectivity
curl -I http://127.0.0.1:3000

# 6. Monitor logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Common Mistakes to Avoid

❌ **Don't:**
- Forget to update SSL certificate paths
- Leave example.com in server_name
- Skip `nginx -t` before reloading
- Edit files in `sites-enabled/` (edit in `sites-available/`)
- Use `proxy_pass` without backend running
- Mix HTTP and HTTPS in proxy_pass (use http://)

✅ **Do:**
- Always test configuration with `nginx -t`
- Update all domain references
- Verify backend is running before configuring proxy
- Use symlinks for sites-enabled
- Include appropriate snippets (proxy-headers, security-headers)
- Set appropriate timeouts for your application

---

## Need More Help?

- 📚 [Main README](../README.md) - Repository overview
- 🔒 [Security Checklist](SECURITY-CHECKLIST.md) - Security hardening
- 📊 [Monitoring Setup](MONITORING-SETUP.md) - Logging and metrics
- 🏗️ [API Gateway Setup](API-GATEWAY-SETUP.md) - Microservices guide
- 🎯 [Best Practice Site Setup](BEST-PRACTICE-SITE-SETUP.md) - Multi-subdomain guide

**Still stuck?** Open an issue on GitHub with your configuration and error logs.
