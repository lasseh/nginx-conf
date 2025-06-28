# Nginx Snippets Usage Guide

## Directory Structure

- **`conf.d/`** - Core configurations applied globally or automatically
- **`snippets/`** - Optional, reusable configuration blocks

## Available Snippets

### Essential Snippets (Recommended for most sites)
```nginx
include snippets/security-headers.conf;  # Security headers (XSS, CSRF, etc.)
include snippets/gzip.conf;              # Compression for better performance
include snippets/static-files.conf;      # Optimized static file serving
include snippets/deny-files.conf;        # Block access to sensitive files
```

### SSL/HTTPS Sites
```nginx
# SSL configuration is in conf.d/tls-intermediate.conf (included automatically)
```

### High-Traffic Sites
```nginx
include snippets/rate-limiting.conf;     # Protection against abuse/DoS
include snippets/brotli.conf;            # Modern compression (if module available)
```

### PHP Sites
```nginx
include snippets/php-fpm.conf;           # Standard PHP-FPM configuration
```

### Special Purpose
```nginx
include snippets/letsencrypt.conf;       # ACME challenge handling
include snippets/stub-status.conf;       # Nginx status monitoring
include snippets/websocket.conf;         # WebSocket support (included globally)
```

## Usage Examples

### Basic Website
```nginx
server {
    # ... SSL and server config ...
    
    include conf.d/tls-intermediate.conf;
    include conf.d/general.conf;
    include conf.d/performance.conf;
    
    # Add snippets as needed
    include snippets/security-headers.conf;
    include snippets/gzip.conf;
    include snippets/static-files.conf;
    include snippets/deny-files.conf;
    
    # ... locations ...
}
```

### API Server
```nginx
server {
    # ... SSL and server config ...
    
    include conf.d/tls-intermediate.conf;
    include conf.d/general.conf;
    include conf.d/performance.conf;
    
    # API-specific snippets
    include snippets/gzip.conf;
    include snippets/rate-limiting.conf;  # Important for APIs
    include snippets/deny-files.conf;
    
    # ... API locations ...
}
```

### PHP Application
```nginx
server {
    # ... SSL and server config ...
    
    include conf.d/tls-intermediate.conf;
    include conf.d/general.conf;
    include conf.d/performance.conf;
    
    include snippets/security-headers.conf;
    include snippets/gzip.conf;
    include snippets/static-files.conf;
    include snippets/deny-files.conf;
    include snippets/php-fpm.conf;
    
    # ... locations ...
}
```

## Migration Notes

The following configurations have been moved from `conf.d/` to `snippets/`:

- Security headers → `snippets/security-headers.conf`
- Gzip compression → `snippets/gzip.conf`  
- Static file caching → `snippets/static-files.conf`

These are now optional includes that you can add to your server blocks as needed.