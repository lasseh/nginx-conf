# Nginx Configuration File Structure

This document explains the file structure and organization of this nginx configuration repository.

## 📁 Directory Structure

```
nginx-new/
├── nginx.conf                          # Main nginx configuration file
├── conf.d/                            # Core configuration modules
│   ├── cloudflare.conf                 # Cloudflare IP ranges for real IP detection
│   ├── general.conf                    # General settings, compression, static caching
│   ├── logformat.conf                  # Custom log formats
│   ├── mime.types                      # MIME type definitions
│   ├── performance.conf                # Performance optimizations (NEW)
│   ├── proxy.conf                      # Proxy settings and headers
│   ├── security.conf                   # Security headers and policies
│   └── tls-intermediate.conf           # SSL/TLS configuration (Mozilla Intermediate)
├── snippets/                          # Reusable configuration blocks
│   ├── letsencrypt.conf                # Let's Encrypt ACME challenge handling
│   ├── stub-status.conf                # Nginx status endpoint
│   └── websocket.conf                  # WebSocket proxy configuration
├── sites-available/                    # Available site configurations (templates)
│   ├── api-gateway.example.com.conf    # API Gateway example for microservices
│   └── example-site.com.conf           # Best practice site example
├── sites-enabled/                      # Active site configurations
│   ├── defaults-80.conf                # Default HTTP server (catch-all)
│   ├── ipv6.fail.conf                  # IPv6 testing site
│   └── whynoipv6.com.conf              # Production site example
├── sites-security/                     # Site-specific security configurations
│   ├── example-site.com.conf           # Security headers for example site
│   ├── ipv6.fail.conf                  # Security headers for IPv6 test site
│   └── whynoipv6.com.conf              # Security headers for main site
├── modules-enabled/                    # Nginx modules (empty by default)
├── docs/                               # Documentation
│   ├── API-GATEWAY-SETUP.md            # API Gateway configuration guide
│   ├── API-GATEWAY-DIAGRAM.md          # API Gateway architecture diagrams
│   ├── BEST-PRACTICE-SITE-SETUP.md     # Best practice site configuration guide
│   └── FILE-STRUCTURE.md               # This file
├── IMPROVEMENTS.md                     # Detailed changelog and improvements
└── README.md                           # Main documentation
```

## 🔧 Configuration File Purposes

### Core Configuration (`nginx.conf`)
- Main nginx configuration file
- Defines worker processes, events, and HTTP context
- Includes rate limiting zones
- References other configuration files via include directives

### Module Configurations (`conf.d/`)

#### `security.conf`
- Modern security headers (HSTS, CSP, CORS, etc.)
- Content Security Policy
- File access restrictions
- Anti-clickjacking protection

#### `general.conf`
- Basic nginx settings
- Gzip compression configuration
- Static asset caching rules
- Robots.txt and favicon handling

#### `performance.conf` ⭐ NEW
- File caching optimizations
- Output buffer settings
- Connection timeout optimizations
- Performance-related directives

#### `tls-intermediate.conf`
- SSL/TLS configuration following Mozilla Intermediate guidelines
- Cipher suites and protocols
- OCSP stapling
- Session caching

#### `proxy.conf`
- Proxy headers and settings
- Upstream connection configuration
- Timeout settings
- Buffering optimization

#### `cloudflare.conf`
- Cloudflare IP ranges for real IP detection
- Updated with 2025 IP ranges
- IPv4 and IPv6 support

#### `logformat.conf`
- Custom log formats
- Structured logging definitions

#### `mime.types`
- MIME type definitions for file extensions

### Prefab Configurations (`snippets/`)

#### `letsencrypt.conf`
- Let's Encrypt ACME challenge handling
- Allows certificate renewal without downtime

#### `websocket.conf`
- WebSocket proxy configuration
- Connection upgrade handling

#### `stub-status.conf`
- Nginx status endpoint configuration
- For monitoring and health checks

### Site Configurations

#### `sites-available/` (Templates)
- **`api-gateway.example.com.conf`**: Complete API gateway for microservices
- **`example-site.com.conf`**: Best practice multi-subdomain site

#### `sites-enabled/` (Active Sites)
- **`whynoipv6.com.conf`**: Production site with frontend, API, and stats
- **`ipv6.fail.conf`**: IPv6 testing site
- **`defaults-80.conf`**: Default HTTP server (catch-all)

#### `sites-security/` (Site-Specific Security)
- Contains security headers specific to each site
- Allows customization of CSP and other security policies per site

## 🔗 Include Path Structure

### Main Configuration Includes
```nginx
# In nginx.conf
include conf.d/mime.types;                    # MIME types
include conf.d/logformat.conf;                # Log formats
include conf.d/tls-intermediate.conf;         # TLS settings
include snippets/websocket.conf;              # WebSocket support
include /etc/nginx/modules-enabled/*.conf;     # Dynamic modules
include /etc/nginx/sites-enabled/*.conf;       # Active sites
```

### Site Configuration Includes
```nginx
# In site configurations
include conf.d/tls-intermediate.conf;         # TLS settings
include sites-security/example-site.com.conf;  # Site-specific security
include conf.d/general.conf;                  # General settings
include conf.d/performance.conf;              # Performance optimizations
include conf.d/cloudflare.conf;               # Cloudflare IP ranges
include conf.d/proxy.conf;                    # Proxy settings (when needed)
include snippets/letsencrypt.conf;            # ACME challenge (HTTP servers)
include snippets/websocket.conf;              # WebSocket support (when needed)
```

## 📋 File Naming Conventions

### Domain-Based Naming
- Site configurations: `domain.com.conf`
- Security configurations: `domain.com.conf` (in sites-security/)
- Examples: `example-site.com.conf`, `api-gateway.example.com.conf`

### Functional Naming
- Core modules: `function.conf` (e.g., `security.conf`, `performance.conf`)
- Prefabs: `purpose.conf` (e.g., `letsencrypt.conf`, `websocket.conf`)

### Directory Purposes
- `conf.d/`: Core nginx functionality modules
- `snippets/`: Reusable configuration blocks
- `sites-available/`: Template/example configurations
- `sites-enabled/`: Active site configurations
- `sites-security/`: Site-specific security policies

## ⚙️ Configuration Deployment

### Development/Testing
```bash
# Use relative paths (as in repository)
include conf.d/security.conf;
include sites-security/example-site.com.conf;
```

### Production Deployment
```bash
# Copy to /etc/nginx/ and use relative paths
sudo cp -r conf.d/ /etc/nginx/
sudo cp -r snippets/ /etc/nginx/
sudo cp -r sites-security/ /etc/nginx/
sudo cp sites-available/example-site.com.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/example-site.com.conf /etc/nginx/sites-enabled/
```

## 🔍 Configuration Validation

### Check Include Paths
```bash
# Test configuration syntax
nginx -t

# Check which files are being included
nginx -T | grep "include"

# Verify file existence
find /etc/nginx -name "*.conf" -type f
```

### Common Issues
1. **Missing files**: Ensure all included files exist
2. **Permission issues**: Files must be readable by nginx user
3. **Syntax errors**: Use `nginx -t` to validate
4. **Path issues**: Verify relative vs absolute paths

## 📊 File Dependencies

### Core Dependencies
```
nginx.conf
├── conf.d/mime.types
├── conf.d/logformat.conf
├── conf.d/tls-intermediate.conf
├── snippets/websocket.conf
└── sites-enabled/*.conf
    ├── conf.d/tls-intermediate.conf
    ├── sites-security/*.conf
    ├── conf.d/general.conf
    ├── conf.d/performance.conf
    ├── conf.d/cloudflare.conf
    └── conf.d/proxy.conf (conditional)
```

### Optional Dependencies
- `snippets/letsencrypt.conf` (for ACME challenges)
- `snippets/websocket.conf` (for WebSocket support)
- `snippets/stub-status.conf` (for monitoring)

## 🚀 Best Practices

### File Organization
1. **Modular approach**: Separate concerns into different files
2. **Consistent naming**: Use clear, descriptive names
3. **Logical grouping**: Group related configurations together
4. **Documentation**: Comment complex configurations

### Include Strategy
1. **Order matters**: Include files in logical order
2. **Avoid duplication**: Don't include the same file multiple times
3. **Use relative paths**: For portability and clarity
4. **Test thoroughly**: Validate after any changes

### Maintenance
1. **Version control**: Track all configuration changes
2. **Backup before changes**: Always backup working configurations
3. **Test in staging**: Validate changes before production
4. **Monitor logs**: Check for errors after deployment

This file structure provides a clean, maintainable, and scalable nginx configuration suitable for modern web applications and microservices architectures.