# Modern Nginx Configuration

Production-ready, modular nginx configuration for secure and performant web hosting. Battle-tested architecture suitable for single sites, multi-domain hosting, microservices, and API gateways.

## ✨ Features

### Security First
- **Modern TLS** - TLS 1.2/1.3 only, Mozilla Intermediate profile
- **Security Headers** - HSTS, CSP, X-Frame-Options, X-Content-Type-Options
- **Rate Limiting** - Per-endpoint DDoS protection
- **Secure Defaults** - Server tokens off, deny dangerous files, HTTPS-only

### Performance Optimized
- **HTTP/2** - Multiplexed connections for faster load times
- **Gzip Compression** - Optimized static asset delivery
- **Connection Pooling** - Keepalive and upstream connection optimization
- **Smart Caching** - Configurable cache strategies for static and dynamic content

### Modular Architecture
- **Reusable Snippets** - DRY configuration with include files
- **Separation of Concerns** - Global configs, site configs, security headers
- **Template Library** - 11 production-ready site templates
- **Easy Customization** - Clear documentation and examples

## 📁 Directory Structure

```
/etc/nginx/
├── nginx.conf                  # Main configuration file
│
├── conf.d/                     # Global HTTP-level configurations
│   ├── logformat.conf          # Custom log formats
│   ├── maps.conf               # WebSocket upgrade mapping
│   ├── mime.types              # MIME type definitions
│   ├── performance.conf        # Performance tuning
│   ├── proxy.conf              # Proxy timeout and buffering defaults
│   ├── security.conf           # Global security settings
│   └── tls-intermediate.conf   # SSL/TLS configuration
│
├── snippets/                   # Reusable configuration blocks
│   ├── deny-files.conf         # Block access to sensitive files
│   ├── error-pages.conf        # Custom error pages (502, 503, 504)
│   ├── gzip.conf               # Compression settings
│   ├── letsencrypt.conf        # ACME challenge support
│   ├── proxy-headers.conf      # Standard proxy headers
│   ├── rate-limiting.conf      # Rate limit configurations
│   ├── security-headers.conf   # Common security headers
│   ├── static-files.conf       # Static asset caching
│   └── stub-status.conf        # Nginx status endpoint
│
├── sites-available/            # Site configuration templates
│   ├── api-gateway.example.com.conf    # Microservices API gateway
│   ├── development.conf                 # Local development
│   ├── docker-compose.conf             # Container routing
│   ├── example-site.com.conf           # Full-featured multi-subdomain
│   ├── grafana.example.com.conf        # Grafana monitoring
│   ├── librenms.example.com.conf       # LibreNMS network monitoring
│   ├── load-balancer.conf              # Multi-server load balancing
│   ├── netbox.example.com.conf         # NetBox IPAM
│   ├── reverse-proxy.conf              # Simple reverse proxy
│   ├── static-site.conf                # Static HTML/SPA
│   └── wordpress.conf                  # WordPress with PHP-FPM
│
├── sites-enabled/              # Active site configurations (symlinks)
│   ├── defaults-80.conf        # HTTP default server (HTTPS redirect)
│   └── defaults-443.conf       # HTTPS default server (close invalid requests)
│
├── sites-security/             # Per-site security headers (CSP, etc)
│   ├── example-site.com.conf
│   └── whynoipv6.com.conf
│
├── html/errors/                # Custom error pages
│   ├── 502.html                # Bad Gateway (backend down)
│   ├── 503.html                # Service Unavailable (maintenance)
│   └── 504.html                # Gateway Timeout (backend slow)
│
└── examples/                   # Reference configurations
    ├── sse-example.conf        # Server-Sent Events
    └── websocket-example.conf  # WebSocket support
```

## 🚀 Quick Start

### 1. Installation

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install nginx
```

**CentOS/RHEL:**
```bash
sudo yum install nginx
```

### 2. Deploy Configuration

```bash
# Clone repository
git clone https://github.com/lasseh/nginx-conf.git
cd nginx-conf

# Backup existing nginx config
sudo mv /etc/nginx /etc/nginx.backup

# Deploy this configuration
sudo cp -r . /etc/nginx/

# Test configuration
sudo nginx -t

# Start nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 3. Create Your First Site

```bash
# Copy template
sudo cp /etc/nginx/sites-available/static-site.conf /etc/nginx/sites-available/mysite.com.conf

# Edit configuration
sudo nano /etc/nginx/sites-available/mysite.com.conf
# Update: server_name, ssl_certificate paths, root directory

# Obtain SSL certificate
sudo certbot certonly --webroot \
  -d mysite.com -d www.mysite.com \
  -w /var/www/_letsencrypt \
  --email your@email.com -n --agree-tos

# Enable site
sudo ln -s /etc/nginx/sites-available/mysite.com.conf /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t && sudo nginx -s reload
```

## 📚 Documentation

### Core Guides
- **[Sites Available Guide](docs/SITES-AVAILABLE-GUIDE.md)** - Complete reference for all 11 site templates
- **[Security Checklist](docs/SECURITY-CHECKLIST.md)** - Security hardening guide

### Specific Use Cases
- **[API Gateway Setup](docs/API-GATEWAY-SETUP.md)** - Microservices routing configuration
- **[API Gateway Diagram](docs/API-GATEWAY-DIAGRAM.md)** - Architecture visualization
- **[Best Practice Site Setup](docs/BEST-PRACTICE-SITE-SETUP.md)** - Multi-subdomain configuration
- **[Monitoring Setup](docs/MONITORING-SETUP.md)** - Logging and health checks

## 🎯 Common Use Cases

### Static Website or SPA (React, Vue, Angular)
```bash
sudo cp sites-available/static-site.conf sites-available/yoursite.com.conf
# Edit configuration, enable site, reload nginx
```

### Reverse Proxy (Node.js, Python, Go Backend)
```bash
sudo cp sites-available/reverse-proxy.conf sites-available/yoursite.com.conf
# Update upstream backend, enable site, reload nginx
```

### API Gateway (Microservices)
```bash
sudo cp sites-available/api-gateway.example.com.conf sites-available/api.yoursite.com.conf
# Configure service routing, enable site, reload nginx
```

### WordPress Site
```bash
sudo cp sites-available/wordpress.conf sites-available/yoursite.com.conf
# Update database and PHP-FPM settings, enable site, reload nginx
```

### Docker Compose Services
```bash
sudo cp sites-available/docker-compose.conf sites-available/yoursite.com.conf
# Configure container routing, enable site, reload nginx
```

## 🔒 Security Features

### Built-in Protection
- ✅ HTTPS-only (automatic HTTP→HTTPS redirect)
- ✅ HSTS with 2-year max-age
- ✅ Modern TLS configuration (Mozilla Intermediate)
- ✅ Security headers (X-Frame-Options, CSP, etc)
- ✅ Rate limiting zones (API, general)
- ✅ Dangerous file blocking (.git, .env, .htaccess)
- ✅ Default servers catch invalid requests

### Optional Enhancements
- IP whitelisting for admin areas
- Basic authentication
- Client certificate authentication
- ModSecurity WAF integration
- Fail2ban integration

## ⚡ Performance Features

### Optimizations Included
- ✅ HTTP/2 enabled
- ✅ Gzip compression
- ✅ Static file caching with immutable headers
- ✅ Connection keepalive and pooling
- ✅ Upstream keepalive connections
- ✅ Sendfile and tcp_nopush enabled
- ✅ Worker process tuning

### Additional Optimizations
- Proxy caching for dynamic content
- FastCGI caching for PHP
- Microcaching strategies
- CDN integration

## 🧪 Testing

### Configuration Syntax
```bash
# Test nginx configuration
sudo nginx -t
```

### Site Functionality
```bash
# Test HTTP to HTTPS redirect
curl -I http://yoursite.com

# Test HTTPS
curl -I https://yoursite.com

# Test security headers
curl -I https://yoursite.com | grep -E "(Strict-Transport|X-Frame|X-Content)"

# Test compression
curl -H "Accept-Encoding: gzip" -I https://yoursite.com
```

### Load Testing
```bash
# Apache Bench
ab -n 1000 -c 10 https://yoursite.com/

# wrk
wrk -t4 -c100 -d30s https://yoursite.com/
```

## 🛠 Customization

### Adding a New Site
1. Choose appropriate template from `sites-available/`
2. Copy to new filename: `yoursite.com.conf`
3. Edit: `server_name`, SSL paths, backend upstreams
4. Create security headers: `sites-security/yoursite.com.conf` (if needed)
5. Obtain SSL certificate with certbot
6. Create symlink: `ln -s ../sites-available/yoursite.com.conf sites-enabled/`
7. Test: `nginx -t`
8. Reload: `nginx -s reload`

### Modifying Global Settings
- **Performance**: Edit `conf.d/performance.conf`
- **Security**: Edit `conf.d/security.conf`
- **TLS**: Edit `conf.d/tls-intermediate.conf`
- **Logging**: Edit `conf.d/logformat.conf`

Changes to `conf.d/` affect ALL sites.

### Creating Reusable Snippets
Place in `snippets/` and include in location blocks:
```nginx
location /api/ {
    include snippets/proxy-headers.conf;
    include snippets/rate-limiting.conf;
    proxy_pass http://backend;
}
```

## 📊 Monitoring

### Health Checks
```bash
# Nginx status (localhost only)
curl http://localhost/nginx-status

# Backend health
curl https://yoursite.com/health
```

### Log Analysis
```bash
# Watch access logs
sudo tail -f /var/log/nginx/access.log

# Watch error logs
sudo tail -f /var/log/nginx/error.log

# Check for errors
sudo grep -E "error|warn" /var/log/nginx/error.log
```

### Integration
- Prometheus + nginx-prometheus-exporter
- Grafana dashboards
- ELK stack (Elasticsearch, Logstash, Kibana)
- Custom monitoring scripts

## 🐛 Troubleshooting

### Configuration Errors
```bash
# Test syntax
sudo nginx -t

# Check error log
sudo tail -50 /var/log/nginx/error.log
```

### SSL/TLS Issues
```bash
# Verify certificate
sudo openssl x509 -in /etc/letsencrypt/live/yoursite.com/cert.pem -noout -dates

# Test SSL connection
openssl s_client -connect yoursite.com:443 -servername yoursite.com
```

### Permission Issues
```bash
# Check nginx user
ps aux | grep nginx

# Fix permissions
sudo chown -R nginx:nginx /var/www/yoursite
sudo chmod -R 755 /var/www/yoursite
```

### Backend Connection Issues
```bash
# Test backend directly
curl -I http://127.0.0.1:3000

# Check firewall
sudo ufw status

# Check SELinux (CentOS/RHEL)
sudo setsebool -P httpd_can_network_connect 1
```

## 🔄 Updates and Maintenance

### Reloading Configuration
```bash
# Graceful reload (no downtime)
sudo nginx -s reload

# Restart (brief downtime)
sudo systemctl restart nginx
```

### Renewing SSL Certificates
```bash
# Certbot automatic renewal (runs via cron/systemd timer)
sudo certbot renew

# Manual renewal
sudo certbot renew --force-renewal

# Test renewal process
sudo certbot renew --dry-run
```

### Updating Nginx
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade nginx

# CentOS/RHEL
sudo yum update nginx

# After update, test and reload
sudo nginx -t && sudo systemctl reload nginx
```

## 📖 Architecture Philosophy

This configuration follows these principles:

1. **Security by Default** - HTTPS everywhere, secure headers, rate limiting
2. **Separation of Concerns** - Global configs, site configs, security headers in separate files
3. **DRY (Don't Repeat Yourself)** - Reusable snippets for common patterns
4. **Explicit Over Implicit** - Clear configuration over magic defaults
5. **Performance Minded** - Optimized but not over-optimized
6. **Production Ready** - Tested patterns suitable for real-world use

### Configuration Hierarchy
```
nginx.conf (main)
  ↓
conf.d/* (global HTTP-level settings)
  ↓
sites-enabled/* (site-specific servers)
  ↓
snippets/* (reusable location blocks)
```

## 🤝 Contributing

Issues and pull requests welcome! Please ensure:
- Configuration tested with `nginx -t`
- Documentation updated
- Security best practices followed
- Comments explain "why" not just "what"

## 📄 License

MIT License - Use freely in personal and commercial projects

## 🙏 Credits

Built on nginx best practices from:
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)
- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [Nginx documentation](https://nginx.org/en/docs/)

---

**Need help?** Check the [documentation](docs/) or open an issue on GitHub.
