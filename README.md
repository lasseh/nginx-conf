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

```bash
# Install nginx
sudo apt install nginx  # Ubuntu/Debian
sudo yum install nginx  # CentOS/RHEL

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