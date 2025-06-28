# Best Practice Site Configuration Guide

This guide explains how to use the `sites-available/example-site.com.conf` configuration for hosting modern websites with nginx best practices.

## 📋 Overview

The best practice site configuration demonstrates a complete setup for hosting a modern website with:

- **Main Website**: Static content with optional backend proxy
- **API Subdomain**: Dedicated API server with rate limiting and CORS
- **Admin Subdomain**: Secure admin panel with enhanced security
- **Comprehensive Security**: Modern headers, CSP, and file protection
- **Performance Optimization**: HTTP/3, caching, and compression

## 🏗 Architecture

```
example-site.com (Main Site)
├── Static files (HTML, CSS, JS, images)
├── /api/* → Proxy to backend application
├── /health → Health check endpoint
└── Security headers and caching

api.example-site.com (API Server)
├── /auth/* → Authentication endpoints
├── /users/* → User management
├── /upload/* → File upload (50MB limit)
├── /ws/* → WebSocket connections
├── /docs → API documentation
└── Rate limiting and CORS

admin.example-site.com (Admin Panel)
├── Enhanced security headers
├── Optional IP whitelisting
├── Stricter rate limiting
├── /api/* → Admin API endpoints
└── Optional basic authentication
```

## 🚀 Quick Setup

### 1. Copy and Customize Configuration

```bash
# Copy the example configuration
sudo cp /etc/nginx/sites-available/example-site.com.conf /etc/nginx/sites-available/yourdomain.com.conf

# Copy the security configuration
sudo cp /etc/nginx/sites-security/example-site.com.conf /etc/nginx/sites-security/yourdomain.com.conf

# Edit configurations for your domain
sudo nano /etc/nginx/sites-available/yourdomain.com.conf
sudo nano /etc/nginx/sites-security/yourdomain.com.conf
```

### 2. Update Domain Names

Use sed to replace all instances of the example domain:

```bash
# Replace domain in main configuration
sudo sed -i 's/example-site\.com/yourdomain.com/g' /etc/nginx/sites-available/yourdomain.com.conf

# Replace domain in security configuration
sudo sed -i 's/example-site\.com/yourdomain.com/g' /etc/nginx/sites-security/yourdomain.com.conf
```

### 3. Configure Backend Services

Update the upstream definitions for your backend applications:

```nginx
# Main application backend
upstream backend_app {
    server 127.0.0.1:3000;    # Your main app
    # server 127.0.0.1:3001 backup;
    keepalive 32;
}

# Admin application backend
upstream admin_app {
    server 127.0.0.1:3100;    # Your admin app
    # server 127.0.0.1:3101 backup;
    keepalive 16;
}
```

### 4. Create Directory Structure

```bash
# Create web directories
sudo mkdir -p /var/www/yourdomain.com
sudo mkdir -p /var/www/api-docs

# Set proper ownership
sudo chown -R nginx:nginx /var/www/yourdomain.com
sudo chown -R nginx:nginx /var/www/api-docs

# Create log directories
sudo mkdir -p /var/log/nginx
```

### 5. Obtain SSL Certificates

```bash
# Get SSL certificate for all subdomains
certbot certonly --webroot \
  -d yourdomain.com \
  -d www.yourdomain.com \
  -d api.yourdomain.com \
  -d admin.yourdomain.com \
  --email your-email@domain.com \
  -w /var/www/_letsencrypt \
  -n --agree-tos
```

### 6. Enable Site and Test

```bash
# Create symlink to enable site
sudo ln -s /etc/nginx/sites-available/yourdomain.com.conf /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload nginx
sudo nginx -s reload
```

## ⚙️ Configuration Details

### Main Website Features

#### Static File Optimization
```nginx
# Aggressive caching for static assets
location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot|webp|avif)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    add_header Vary "Accept-Encoding";
    access_log off;
}
```

#### SPA Support
```nginx
# Single Page Application support
location / {
    try_files $uri $uri/ /index.html;
}
```

#### API Proxy
```nginx
# Proxy API calls to backend
location /api/ {
    limit_req zone=general burst=20 nodelay;
    rewrite ^/api/(.*)$ /$1 break;
    proxy_pass http://backend_app;
    include conf.d/proxy.conf;
}
```

### API Subdomain Features

#### Service-Specific Routing
```nginx
# Authentication with strict rate limiting
location /auth/ {
    limit_req zone=api burst=10 nodelay;
    proxy_pass http://backend_app;
    proxy_set_header X-Service "auth";
}

# File uploads with larger body size
location /upload/ {
    limit_req zone=api burst=5 nodelay;
    client_max_body_size 50M;
    client_body_timeout 300s;
    proxy_pass http://backend_app;
}
```

#### CORS Configuration
```nginx
# Comprehensive CORS setup
add_header Access-Control-Allow-Origin "$http_origin" always;
add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, PATCH, OPTIONS" always;
add_header Access-Control-Allow-Headers "Authorization, Content-Type, Accept, X-Requested-With" always;
add_header Access-Control-Allow-Credentials "true" always;
```

### Admin Subdomain Security

#### Enhanced Security Headers
```nginx
# Strict security for admin area
add_header X-Frame-Options "DENY" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; object-src 'none'; frame-ancestors 'none';" always;
```

#### Optional IP Whitelisting
```nginx
# Restrict admin access to specific IPs
allow 192.168.1.0/24;    # Local network
allow YOUR_OFFICE_IP;    # Office IP
deny all;
```

## 🔧 Customization Examples

### Adding a Blog Subdomain

1. **Add to HTTP redirect server:**
```nginx
server_name example-site.com www.example-site.com api.example-site.com admin.example-site.com blog.example-site.com;
```

2. **Create new server block:**
```nginx
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name blog.example-site.com;
    
    # SSL and includes...
    
    # WordPress or static blog
    root /var/www/blog;
    index index.php index.html;
    
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
```

### Adding CDN Integration

```nginx
# CDN for static assets
location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg)$ {
    # Try local file first, then CDN
    try_files $uri @cdn;
    expires 1y;
}

location @cdn {
    proxy_pass https://cdn.yourdomain.com;
    proxy_set_header Host cdn.yourdomain.com;
    expires 1y;
}
```

### Adding Maintenance Mode

```nginx
# Maintenance mode
set $maintenance off;

if (-f /var/www/maintenance.html) {
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

### Adding Basic Authentication

```nginx
# Protect admin area with basic auth
location / {
    auth_basic "Admin Area";
    auth_basic_user_file /etc/nginx/.htpasswd;
    
    proxy_pass http://admin_app;
    include conf.d/proxy.conf;
}
```

Create password file:
```bash
# Install htpasswd utility
sudo apt install apache2-utils

# Create password file
sudo htpasswd -c /etc/nginx/.htpasswd admin
sudo htpasswd /etc/nginx/.htpasswd user2
```

## 🔒 Security Considerations

### Content Security Policy

The included CSP is balanced for common use cases. Customize for your needs:

```nginx
# Strict CSP for high-security sites
add_header Content-Security-Policy "
    default-src 'self';
    script-src 'self';
    style-src 'self';
    img-src 'self' data:;
    font-src 'self';
    connect-src 'self';
    object-src 'none';
    frame-ancestors 'none';
    base-uri 'self';
    form-action 'self';
" always;
```

### File Upload Security

```nginx
# Secure file upload location
location /upload/ {
    # Limit file types
    location ~ \.(php|php3|php4|php5|phtml|pl|py|jsp|asp|sh|cgi)$ {
        deny all;
    }
    
    # Limit file size
    client_max_body_size 10M;
    
    # Disable script execution
    location ~* \.(jpg|jpeg|png|gif|pdf|doc|docx)$ {
        add_header X-Content-Type-Options nosniff;
        add_header Content-Disposition "attachment";
    }
}
```

### Rate Limiting Strategies

```nginx
# Different rate limits for different endpoints
location /api/auth/ {
    limit_req zone=auth_strict burst=3 nodelay;  # Very strict for auth
}

location /api/search/ {
    limit_req zone=api burst=50 nodelay;         # More permissive for search
}

location /api/upload/ {
    limit_req zone=upload burst=1 nodelay;      # Very strict for uploads
}
```

## 📊 Monitoring & Logging

### Custom Log Formats

Add to `conf.d/logformat.conf`:

```nginx
# Detailed logging for main site
log_format main_site '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

# API-specific logging
log_format api_access '$remote_addr - $remote_user [$time_local] '
                     '"$request" $status $body_bytes_sent '
                     '"$http_referer" "$http_user_agent" '
                     'api_key="$http_x_api_key" '
                     'request_id="$request_id"';
```

Use in your configuration:
```nginx
access_log /var/log/nginx/yourdomain.com.access.log main_site;
access_log /var/log/nginx/api.yourdomain.com.access.log api_access;
```

### Health Check Monitoring

```bash
# Monitor all health endpoints
curl -s https://yourdomain.com/health | jq
curl -s https://api.yourdomain.com/health | jq
curl -s https://admin.yourdomain.com/health | jq

# Create monitoring script
cat > /usr/local/bin/site-health-check.sh << 'EOF'
#!/bin/bash
SITES=("yourdomain.com" "api.yourdomain.com" "admin.yourdomain.com")

for site in "${SITES[@]}"; do
    status=$(curl -s -o /dev/null -w "%{http_code}" "https://$site/health")
    if [ "$status" = "200" ]; then
        echo "✅ $site is healthy"
    else
        echo "❌ $site is down (HTTP $status)"
    fi
done
EOF

chmod +x /usr/local/bin/site-health-check.sh
```

## 🧪 Testing

### Test All Subdomains

```bash
# Test main site
curl -I https://yourdomain.com
curl -I https://www.yourdomain.com

# Test API
curl -I https://api.yourdomain.com/health
curl -X POST https://api.yourdomain.com/auth/test

# Test admin (may require auth)
curl -I https://admin.yourdomain.com/health
```

### Test Security Headers

```bash
# Check security headers
curl -I https://yourdomain.com | grep -E "(X-|Content-Security|Strict-Transport)"

# Test CSP
curl -s -I https://yourdomain.com | grep "Content-Security-Policy"
```

### Test Rate Limiting

```bash
# Test API rate limiting
for i in {1..15}; do
    curl -w "%{http_code}\n" -o /dev/null -s https://api.yourdomain.com/auth/test
    sleep 0.1
done
```

### Test CORS

```bash
# Test CORS preflight
curl -X OPTIONS \
  -H "Origin: https://yourapp.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" \
  https://api.yourdomain.com/auth/login
```

## 🚨 Troubleshooting

### Common Issues

1. **SSL Certificate Issues**
   ```bash
   # Check certificate
   openssl x509 -in /etc/letsencrypt/live/yourdomain.com/cert.pem -noout -dates
   
   # Test SSL
   openssl s_client -connect yourdomain.com:443 -servername yourdomain.com
   ```

2. **Backend Connection Issues**
   ```bash
   # Test backend connectivity
   curl -I http://127.0.0.1:3000/health
   
   # Check nginx error logs
   sudo tail -f /var/log/nginx/error.log
   ```

3. **Rate Limiting Too Aggressive**
   ```bash
   # Check rate limit logs
   sudo grep "limiting requests" /var/log/nginx/error.log
   
   # Adjust burst values in configuration
   limit_req zone=api burst=30 nodelay;  # Increase burst
   ```

4. **CORS Issues**
   ```bash
   # Check CORS headers
   curl -H "Origin: https://yourapp.com" -I https://api.yourdomain.com/
   
   # Verify preflight handling
   curl -X OPTIONS -H "Origin: https://yourapp.com" https://api.yourdomain.com/
   ```

### Debug Commands

```bash
# Test nginx configuration
sudo nginx -t

# Reload configuration
sudo nginx -s reload

# Check listening ports
sudo netstat -tlnp | grep nginx

# Monitor access logs
sudo tail -f /var/log/nginx/yourdomain.com.access.log

# Monitor error logs
sudo tail -f /var/log/nginx/error.log
```

## 📈 Performance Optimization

### Enable Caching

```nginx
# Proxy cache for API responses
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=1g inactive=60m;

location /api/data/ {
    proxy_cache api_cache;
    proxy_cache_valid 200 5m;
    proxy_cache_use_stale error timeout updating;
    proxy_pass http://backend_app;
}
```

### Optimize Static Files

```nginx
# Precompressed files
location ~* \.(css|js)$ {
    gzip_static on;
    expires 1y;
    add_header Cache-Control "public, immutable";
}

# WebP image support
location ~* \.(png|jpg|jpeg)$ {
    add_header Vary Accept;
    try_files $uri$webp_suffix $uri =404;
}
```

### Connection Optimization

```nginx
# Optimize upstream connections
upstream backend_app {
    server 127.0.0.1:3000;
    keepalive 32;
    keepalive_requests 100;
    keepalive_timeout 60s;
}
```

This configuration provides a solid foundation for hosting modern websites with nginx, incorporating security best practices, performance optimizations, and operational considerations.