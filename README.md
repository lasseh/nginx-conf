# Modern Nginx Configuration

A production-ready, security-hardened nginx configuration optimized for 2025 standards. This repository provides a modular, maintainable nginx setup with modern security headers, HTTP/3 support, rate limiting, and performance optimizations.

## 🚀 Features

### Security
- **Modern Security Headers**: HSTS, CSP, CORS, and anti-clickjacking protection
- **Rate Limiting**: Configurable zones for API and general traffic protection
- **SSL/TLS Hardening**: Mozilla Intermediate configuration with optimized session caching
- **Cloudflare Integration**: Real IP detection with updated IP ranges
- **Input Validation**: Protection against common web vulnerabilities

### Performance
- **HTTP/3 Support**: Latest protocol with QUIC for improved performance
- **Advanced Compression**: gzip and Brotli compression ready
- **Static Asset Optimization**: Long-term caching with proper headers
- **Connection Optimization**: Keepalive tuning and worker process optimization
- **Proxy Buffering**: Optimized upstream communication

### Architecture
- **Modular Design**: Separated configuration files for maintainability
- **Environment Flexibility**: Easy adaptation for different deployment scenarios
- **API Gateway Ready**: Complete example for microservices routing
- **Monitoring Ready**: Structured logging and performance metrics
- **Documentation**: Comprehensive inline comments and external docs

## 📁 Repository Structure

```
nginx-new/
├── nginx.conf                 # Main configuration file
├── nginx.d/                   # Core configuration modules
│   ├── security.conf          # Security headers and policies
│   ├── general.conf           # General settings and compression
│   ├── performance.conf       # Performance optimizations
│   ├── tls-intermediate.conf  # SSL/TLS configuration
│   ├── proxy.conf             # Proxy settings and headers
│   ├── cloudflare.conf        # Cloudflare IP ranges
│   ├── logformat.conf         # Custom log formats
│   └── mime.types             # MIME type definitions
├── prefabs.d/                 # Reusable configuration blocks
│   ├── letsencrypt.conf       # Let's Encrypt ACME challenge
│   ├── websocket.conf         # WebSocket proxy configuration
│   └── stub-status.conf       # Nginx status endpoint
├── sites-available/           # Available site configurations
│   ├── api-gateway.example.com.conf  # API Gateway example
│   └── example-site.com.conf         # Best practice site example
├── sites-enabled/             # Virtual host configurations
│   ├── defaults-80.conf       # Default HTTP server
│   ├── whynoipv6.com.conf     # Example production site
│   └── ipv6.fail.conf         # IPv6 testing site
├── sites-security/            # Site-specific security configs
│   ├── whynoipv6.com.conf     # Security headers for main site
│   └── ipv6.fail.conf         # Security headers for test site
├── docs/                      # Documentation
│   ├── API-GATEWAY-SETUP.md   # API Gateway configuration guide
│   ├── API-GATEWAY-DIAGRAM.md # Architecture diagrams
│   └── BEST-PRACTICE-SITE-SETUP.md # Best practice site guide
├── IMPROVEMENTS.md            # Detailed changelog and improvements
└── README.md                  # This file
```

## 🛠 Installation & Setup

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install nginx

# CentOS/RHEL
sudo yum install nginx
# or
sudo dnf install nginx

# Verify nginx installation
nginx -v
```

### Required Nginx Modules

For full functionality, ensure nginx is compiled with:

```bash
# Check current modules
nginx -V 2>&1 | grep -o with-http_v3_module
nginx -V 2>&1 | grep -o with-http_ssl_module
nginx -V 2>&1 | grep -o with-http_v2_module

# For HTTP/3 support (if not available, see compilation notes below)
--with-http_v3_module

# For Brotli compression (optional)
--add-module=ngx_brotli
```

### Deployment

1. **Backup existing configuration:**
   ```bash
   sudo cp -r /etc/nginx /etc/nginx.backup.$(date +%Y%m%d)
   ```

2. **Clone and deploy this configuration:**
   ```bash
   git clone https://github.com/lasseh/nginx-new.git
   cd nginx-new
   
   # Copy configuration files
   sudo cp nginx.conf /etc/nginx/
   sudo cp -r nginx.d/ /etc/nginx/
   sudo cp -r prefabs.d/ /etc/nginx/
   sudo cp -r sites-enabled/ /etc/nginx/
   sudo cp -r sites-security/ /etc/nginx/
   sudo cp -r docs/ /etc/nginx/
   ```

3. **Customize for your environment:**
   ```bash
   # Edit main configuration
   sudo nano /etc/nginx/nginx.conf
   
   # Configure your sites
   sudo nano /etc/nginx/sites-enabled/your-site.conf
   ```

4. **Test and reload:**
   ```bash
   # Test configuration syntax
   sudo nginx -t
   
   # Reload if test passes
   sudo nginx -s reload
   ```

## ⚙️ Configuration Guide

### Setting Up a New Site

1. **Create site configuration:**
   ```bash
   sudo cp /etc/nginx/sites-enabled/whynoipv6.com.conf /etc/nginx/sites-enabled/yoursite.com.conf
   ```

2. **Edit the configuration:**
   ```nginx
   server {
       listen                  443 ssl;
       listen                  [::]:443 ssl;
       listen                  443 quic reuseport;
       listen                  [::]:443 quic reuseport;
       http2                   on;
       http3                   on;
       server_name             yoursite.com www.yoursite.com;
       
       # SSL certificates
       ssl_certificate         /etc/letsencrypt/live/yoursite.com/fullchain.pem;
       ssl_certificate_key     /etc/letsencrypt/live/yoursite.com/privkey.pem;
       ssl_trusted_certificate /etc/letsencrypt/live/yoursite.com/chain.pem;
       
       # Include security and performance configs
       include                 nginx.d/tls-intermediate.conf;
       include                 sites-security/yoursite.com.conf;
       include                 nginx.d/general.conf;
       include                 nginx.d/performance.conf;
       include                 nginx.d/cloudflare.conf;
       
       # Your application configuration
       location / {
           # Static files
           root /var/www/yoursite.com;
           try_files $uri $uri/ =404;
           
           # Or proxy to application
           # proxy_pass http://localhost:3000;
           # include nginx.d/proxy.conf;
       }
   }
   ```

3. **Create security configuration:**
   ```bash
   sudo cp /etc/nginx/sites-security/whynoipv6.com.conf /etc/nginx/sites-security/yoursite.com.conf
   ```

### Setting Up an API Gateway

For microservices architecture, use the included API gateway example:

1. **Copy the API gateway configuration:**
   ```bash
   sudo cp /etc/nginx/sites-available/api-gateway.example.com.conf /etc/nginx/sites-available/api.yourdomain.com.conf
   ```

2. **Customize for your services:**
   ```bash
   # Edit the configuration
   sudo nano /etc/nginx/sites-available/api.yourdomain.com.conf
   
   # Update domain name
   sudo sed -i 's/api\.example\.com/api.yourdomain.com/g' /etc/nginx/sites-available/api.yourdomain.com.conf
   ```

3. **Configure your backend services:**
   ```nginx
   upstream auth_service {
       server 127.0.0.1:3001;    # Your authentication service
       keepalive 32;
   }
   
   upstream user_service {
       server 127.0.0.1:8001;    # Your user management service
       keepalive 32;
   }
   ```

4. **Enable the API gateway:**
   ```bash
   sudo ln -s /etc/nginx/sites-available/api.yourdomain.com.conf /etc/nginx/sites-enabled/
   sudo nginx -t && sudo nginx -s reload
   ```

**📖 For detailed API gateway setup, see [docs/API-GATEWAY-SETUP.md](docs/API-GATEWAY-SETUP.md)**

### Setting Up a Best Practice Website

For modern website hosting with multiple subdomains:

1. **Copy the best practice configuration:**
   ```bash
   sudo cp /etc/nginx/sites-available/example-site.com.conf /etc/nginx/sites-available/yourdomain.com.conf
   sudo cp /etc/nginx/sites-security/example-site.com.conf /etc/nginx/sites-security/yourdomain.com.conf
   ```

2. **Update domain names:**
   ```bash
   # Replace domain in both files
   sudo sed -i 's/example-site\.com/yourdomain.com/g' /etc/nginx/sites-available/yourdomain.com.conf
   sudo sed -i 's/example-site\.com/yourdomain.com/g' /etc/nginx/sites-security/yourdomain.com.conf
   ```

3. **Configure backend services:**
   ```nginx
   upstream backend_app {
       server 127.0.0.1:3000;    # Your main application
       keepalive 32;
   }
   
   upstream admin_app {
       server 127.0.0.1:3100;    # Your admin application
       keepalive 16;
   }
   ```

4. **Enable the site:**
   ```bash
   sudo ln -s /etc/nginx/sites-available/yourdomain.com.conf /etc/nginx/sites-enabled/
   sudo nginx -t && sudo nginx -s reload
   ```

**📖 For detailed best practice setup, see [docs/BEST-PRACTICE-SITE-SETUP.md](docs/BEST-PRACTICE-SITE-SETUP.md)**

### Rate Limiting Configuration

Adjust rate limits in `/etc/nginx/nginx.conf`:

```nginx
# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;      # API endpoints
limit_req_zone $binary_remote_addr zone=general:10m rate=1r/s;   # General traffic
limit_req_zone $binary_remote_addr zone=strict:10m rate=1r/m;    # Very strict endpoints
```

Apply in location blocks:
```nginx
location /api/ {
    limit_req zone=api burst=20 nodelay;
    # ... rest of configuration
}
```

### Security Headers Customization

Edit `/etc/nginx/nginx.d/security.conf` for your needs:

```nginx
# Customize CSP for your application
add_header Content-Security-Policy "
    default-src 'self';
    script-src 'self' 'unsafe-inline' your-cdn.com;
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https:;
    connect-src 'self' wss: your-api.com;
" always;
```

## 🔧 Advanced Configuration

### HTTP/3 Setup

If your nginx doesn't support HTTP/3:

1. **Compile nginx with HTTP/3:**
   ```bash
   # Install dependencies
   sudo apt install build-essential libpcre3-dev zlib1g-dev libssl-dev
   
   # Download and compile
   wget http://nginx.org/download/nginx-1.25.3.tar.gz
   tar -xzf nginx-1.25.3.tar.gz
   cd nginx-1.25.3
   
   ./configure --with-http_v3_module --with-http_ssl_module --with-http_v2_module
   make && sudo make install
   ```

2. **Verify HTTP/3 support:**
   ```bash
   nginx -V 2>&1 | grep -o with-http_v3_module
   ```

### Brotli Compression

1. **Install ngx_brotli module:**
   ```bash
   git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli.git
   cd ngx_brotli/deps/brotli
   mkdir out && cd out
   cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF ..
   cmake --build . --config Release --target brotlienc
   ```

2. **Enable in configuration:**
   ```nginx
   # Uncomment in /etc/nginx/nginx.d/general.conf
   brotli          on;
   brotli_comp_level 6;
   brotli_types    text/plain text/css application/json application/javascript;
   ```

### SSL/TLS Setup

1. **Generate Diffie-Hellman parameters:**
   ```bash
   openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
   ```

2. **Create ACME challenge directory:**
   ```bash
   mkdir -p /var/www/_letsencrypt
   chown nginx /var/www/_letsencrypt
   ```

3. **Obtain SSL certificates with Certbot:**
   ```bash
   # Install certbot
   sudo apt install certbot
   
   # Obtain certificate
   certbot certonly --webroot \
     -d yoursite.com -d www.yoursite.com \
     --email your-email@example.com \
     -w /var/www/_letsencrypt \
     -n --agree-tos
   ```

4. **Configure auto-renewal:**
   ```bash
   echo -e '#!/bin/bash\nnginx -t && systemctl reload nginx' | \
     sudo tee /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh
   sudo chmod a+x /etc/letsencrypt/renewal-hooks/post/nginx-reload.sh
   ```

### Monitoring & Logging

1. **Enable status endpoint:**
   ```nginx
   # Include in server block
   include prefabs.d/stub-status.conf;
   ```

2. **Custom log formats:**
   ```nginx
   # Already configured in nginx.d/logformat.conf
   access_log /var/log/nginx/access.log prettycloud;
   ```

3. **Log analysis with GoAccess:**
   ```bash
   sudo apt install goaccess
   goaccess /var/log/nginx/access.log -c
   ```

## 🔍 Testing & Validation

### Configuration Testing
```bash
# Syntax check
sudo nginx -t

# Test specific configuration
sudo nginx -t -c /etc/nginx/nginx.conf
```

### Security Testing
```bash
# Test security headers
curl -I https://yoursite.com

# Test rate limiting
for i in {1..15}; do curl -I https://yoursite.com/api/endpoint; done

# SSL/TLS testing
openssl s_client -connect yoursite.com:443 -servername yoursite.com
```

### Performance Testing
```bash
# HTTP/3 testing
curl --http3 -I https://yoursite.com

# Compression testing
curl -H "Accept-Encoding: gzip,br" -I https://yoursite.com

# Load testing
ab -n 1000 -c 10 https://yoursite.com/
```

## 📊 Monitoring & Maintenance

### Regular Maintenance Tasks

1. **Update Cloudflare IP ranges:**
   ```bash
   # Automated script (run monthly)
   curl -s https://www.cloudflare.com/ips-v4 > /tmp/cf-ips-v4
   curl -s https://www.cloudflare.com/ips-v6 > /tmp/cf-ips-v6
   # Update nginx.d/cloudflare.conf with new ranges
   ```

2. **Monitor SSL certificate expiry:**
   ```bash
   # Check certificate expiry
   openssl x509 -in /etc/letsencrypt/live/yoursite.com/cert.pem -noout -dates
   ```

3. **Log rotation:**
   ```bash
   # Ensure logrotate is configured
   sudo nano /etc/logrotate.d/nginx
   ```

### Performance Monitoring

Monitor these metrics:
- **Response times**: Average and 95th percentile
- **Cache hit rates**: Static assets and proxy cache
- **SSL session reuse**: Monitor session cache effectiveness
- **HTTP/3 adoption**: Track Alt-Svc header usage
- **Rate limiting**: Monitor blocked requests

## 🎯 Why Use This Configuration?

### Security Benefits
- **Zero-day protection**: Modern security headers protect against emerging threats
- **DDoS mitigation**: Rate limiting and connection optimization
- **Data protection**: Strict CSP and CORS policies prevent data exfiltration
- **SSL/TLS hardening**: Future-proof encryption with perfect forward secrecy

### Performance Benefits
- **Faster page loads**: HTTP/3, compression, and caching optimizations
- **Reduced server load**: Efficient connection handling and proxy buffering
- **Better user experience**: Optimized for mobile and slow connections
- **Scalability**: Configuration designed for high-traffic scenarios

### Operational Benefits
- **Maintainability**: Modular design makes updates and changes easier
- **Monitoring**: Built-in logging and metrics for operational visibility
- **Flexibility**: Easy to adapt for different applications and environments
- **Documentation**: Comprehensive guides and inline comments

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/improvement`
3. Test your changes thoroughly
4. Submit a pull request with detailed description

## 📄 License

This configuration is provided under the MIT License. See LICENSE file for details.

## 🆘 Support & Troubleshooting

### Common Issues

1. **HTTP/3 not working:**
   - Verify nginx compiled with `--with-http_v3_module`
   - Check firewall allows UDP traffic on port 443
   - Ensure Alt-Svc header is present

2. **Rate limiting too aggressive:**
   - Adjust burst values in limit_req directives
   - Monitor nginx error logs for rate limit hits

3. **SSL/TLS issues:**
   - Verify certificate chain completeness
   - Check cipher compatibility with clients
   - Monitor SSL session cache hit rates

### Getting Help

- **Issues**: Open an issue on GitHub
- **Security concerns**: Email security issues privately
- **Performance questions**: Check IMPROVEMENTS.md for optimization details

---

**Note**: This configuration is production-tested but should be customized for your specific environment and requirements. Always test in a staging environment before deploying to production.