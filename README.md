# Modern Nginx Configuration

Production-ready nginx setup with HTTP/3, security hardening, and performance optimization.

## Features
- **Security**: HSTS, CSP, rate limiting, SSL/TLS hardening
- **Performance**: HTTP/3, Brotli compression, optimized caching
- **Architecture**: Modular design, API gateway ready, monitoring

## Structure
```
nginx-conf/
├── nginx.conf              # Main config
├── conf.d/                 # Core modules (security, performance, TLS)
├── snippets/               # Reusable blocks (WebSocket, Let's Encrypt)
├── sites-available/        # Site templates
├── sites-enabled/          # Active sites
├── sites-security/         # Security headers per site
└── docs/                   # Setup guides
```

## Documentation

- **[API Gateway Setup](docs/API-GATEWAY-SETUP.md)** - Microservices routing configuration
- **[API Gateway Diagram](docs/API-GATEWAY-DIAGRAM.md)** - Architecture diagrams and flow charts
- **[Best Practice Site Setup](docs/BEST-PRACTICE-SITE-SETUP.md)** - Multi-subdomain website configuration
- **[Catch-All Server Setup](docs/CATCH-ALL-SERVER-SETUP.md)** - Default server for unmatched requests

- **[Monitoring Setup](docs/MONITORING-SETUP.md)** - Logging, metrics, and health checks
- **[Security Checklist](docs/SECURITY-CHECKLIST.md)** - Security implementation guide


## Installation

### Install Latest Nginx (Recommended)

For HTTP/3 and latest features, install from nginx's official repository:

```bash
# Ubuntu - Add nginx repository
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
sudo apt update && sudo apt install nginx

# Debian - Add nginx repository
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/debian $(lsb_release -cs) nginx" | sudo tee /etc/apt/sources.list.d/nginx.list
sudo apt update && sudo apt install nginx

# CentOS/RHEL - Add nginx repository  
sudo yum install -y https://nginx.org/packages/centos/$(rpm -E '%{rhel}')/noarch/RPMS/nginx-release-centos-$(rpm -E '%{rhel}')-0.el$(rpm -E '%{rhel}').ngx.noarch.rpm
sudo yum install nginx

# Or use distribution packages (older versions, but easier)
sudo apt install nginx  # Ubuntu/Debian
sudo yum install nginx  # CentOS/RHEL
```

### Install Brotli Compression (Debian/Ubuntu)

For optimal performance, install Brotli compression modules:

```bash
# Debian/Ubuntu - Install Brotli modules
sudo apt install libnginx-mod-http-brotli-filter libnginx-mod-http-brotli-static

# Enable modules in nginx.conf (add before 'http' block)
echo 'load_module modules/ngx_http_brotli_filter_module.so;' | sudo tee -a /etc/nginx/nginx.conf
echo 'load_module modules/ngx_http_brotli_static_module.so;' | sudo tee -a /etc/nginx/nginx.conf
```

### Deploy Configuration

```bash
# Deploy configuration
git clone https://github.com/lasseh/nginx-conf.git
cd nginx-conf
sudo cp -r * /etc/nginx/
sudo nginx -t && sudo nginx -s reload
```

## Quick Setup

### New Site
```bash
# Copy template and customize
sudo cp sites-available/example-site.com.conf sites-available/yoursite.com.conf
# Edit domain names and SSL paths, then enable
sudo ln -s ../sites-available/yoursite.com.conf sites-enabled/
# Edit domain names and SSL paths
sudo nginx -t && sudo nginx -s reload
```

### API Gateway
```bash
# Copy and customize API gateway template
sudo cp sites-available/api-gateway.example.com.conf sites-available/api.yourdomain.com.conf
# Update domain and backend services
sudo ln -s ../sites-available/api.yourdomain.com.conf sites-enabled/
```

## Example Configurations

Available in `sites-available/`:

- **static-site.conf** - React/Vue/Angular SPA with aggressive caching
- **reverse-proxy.conf** - Single backend application proxy
- **wordpress.conf** - WordPress with PHP-FPM optimization
- **docker-compose.conf** - Container services routing
- **load-balancer.conf** - Multi-server load balancing
- **development.conf** - Local development with hot reload

## Testing

```bash
# Configuration test
sudo nginx -t

# HTTP/3 support
curl --http3 -I https://yoursite.com

# Compression test
curl -H "Accept-Encoding: gzip,br" -I https://yoursite.com

# Load test
ab -n 1000 -c 10 https://yoursite.com/
```

## License

MIT License - see LICENSE file for details.