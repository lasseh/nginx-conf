# Default Server Configuration

Default servers handle requests that don't match any specific server_name, providing security and operational benefits.

## Current Setup

### HTTP Default Server (`sites-enabled/defaults-80.conf`)
```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    # ACME challenge support
    include snippets/letsencrypt.conf;
    
    # Redirect everything else to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}
```

### HTTPS Default Server (`sites-enabled/defaults-443.conf`)
```nginx
server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;
    
    # Self-signed certificate for default server
    ssl_certificate /etc/nginx/ssl/default.crt;
    ssl_certificate_key /etc/nginx/ssl/default.key;
    
    # Minimal SSL config
    include conf.d/tls-intermediate.conf;
    
    # Return 444 (close connection) for unmatched domains
    return 444;
}
```

## Purpose

### Security Benefits
- **Prevents certificate errors** - Self-signed cert for unmatched domains
- **Blocks malicious requests** - Returns 444 for invalid hosts
- **Protects real sites** - Isolates legitimate traffic
- **ACME challenge support** - Allows Let's Encrypt validation

### Operational Benefits
- **Clean logs** - Separates legitimate from invalid requests
- **Performance** - Quick rejection of unwanted traffic
- **Monitoring** - Easy identification of scanning attempts

## Setup Instructions

### 1. Create Self-Signed Certificate
```bash
# Create SSL directory
sudo mkdir -p /etc/nginx/ssl

# Generate self-signed certificate for default server
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/default.key \
    -out /etc/nginx/ssl/default.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=default"

# Secure permissions
sudo chmod 600 /etc/nginx/ssl/default.key
sudo chmod 644 /etc/nginx/ssl/default.crt
```

### 2. Enable Default Servers
```bash
# Both files should already be in sites-enabled/
# Verify they're present
ls -la /etc/nginx/sites-enabled/defaults-*

# Test configuration
sudo nginx -t

# Reload if test passes
sudo nginx -s reload
```

### 3. Verify Setup
```bash
# Test HTTP default (should redirect to HTTPS)
curl -I http://invalid-domain.test

# Test HTTPS default (should return 444 or connection closed)
curl -I https://invalid-domain.test --insecure
```

## Monitoring

### Log Analysis
```bash
# Monitor requests to default servers
grep "default_server" /var/log/nginx/access.log

# Check for scanning attempts
grep "444" /var/log/nginx/access.log | head -10

# Monitor invalid host headers
grep -E "Host: [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" /var/log/nginx/access.log
```

### Common Patterns
- **IP-based requests** - Direct IP access attempts
- **Invalid hostnames** - Malformed or non-existent domains
- **Port scanning** - Automated security scans
- **Bot traffic** - Search engine crawlers with invalid hosts

## Customization

### Alternative Responses
```nginx
# Return custom error page instead of 444
location / {
    return 403 "Access Denied";
}

# Redirect to main site
location / {
    return 301 https://yourmainsite.com$request_uri;
}

# Serve static error page
location / {
    root /var/www/default;
    try_files /index.html =444;
}
```

### Enhanced Security
```nginx
# Rate limit default server requests
limit_req_zone $binary_remote_addr zone=default:1m rate=1r/s;

server {
    listen 443 ssl default_server;
    server_name _;
    
    # Apply rate limiting
    limit_req zone=default burst=5 nodelay;
    
    # Log to separate file
    access_log /var/log/nginx/default-access.log;
    error_log /var/log/nginx/default-error.log;
    
    return 444;
}
```

## Troubleshooting

### Common Issues
- **Certificate warnings** - Expected for self-signed cert on default server
- **Connection refused** - Normal behavior when returning 444
- **ACME challenges failing** - Ensure letsencrypt.conf is included in HTTP default

### Testing Commands
```bash
# Test default server response
curl -v -H "Host: nonexistent.domain" http://your-server-ip/

# Verify ACME challenge works
curl http://your-server-ip/.well-known/acme-challenge/test

# Check SSL certificate
openssl s_client -connect your-server-ip:443 -servername invalid.domain
```