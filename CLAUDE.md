# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a production-ready Nginx configuration repository with modular design for security hardening, performance optimization, and modern HTTP/3 support. It's designed for multi-site hosting with reusable configuration snippets.

## Testing and Validation

```bash
# Test configuration syntax (run after any changes)
sudo nginx -t

# Test specific site configuration
sudo nginx -t -c /etc/nginx/sites-available/example-site.com.conf

# Reload nginx after successful test
sudo nginx -s reload
```

## Architecture

The configuration follows a hierarchical include pattern:

```
nginx.conf (main)
├── conf.d/ (global configs loaded by main)
│   ├── security.conf, performance.conf, tls-intermediate.conf
│   ├── proxy.conf, websocket.conf, logformat.conf
│   └── cloudflare.conf, sse.conf
├── snippets/ (reusable blocks included in sites)
│   ├── proxy-headers.conf (standard proxy headers)
│   ├── security-headers.conf, deny-files.conf
│   ├── gzip.conf, brotli.conf
│   ├── letsencrypt.conf, rate-limiting.conf
│   └── php-fpm.conf, static-files.conf, websocket.conf
├── sites-available/ (site templates)
├── sites-enabled/ (symlinks to active sites)
└── sites-security/ (per-site security headers)
```

**Key Pattern**: `conf.d/` files are included globally at the http level in nginx.conf. `snippets/` files are manually included in specific site configurations where needed.

## Configuration Standards

### Site Configuration Pattern

When creating new site configurations:

1. **HTTP to HTTPS redirect** - Always include for port 80
2. **SSL certificates** - Use Let's Encrypt paths: `/etc/letsencrypt/live/{domain}/`
3. **HTTP/3 support** - Include QUIC listeners and Alt-Svc header
4. **Security includes**:
   - `conf.d/tls-intermediate.conf` (TLS settings)
   - `sites-security/{domain}.conf` (site-specific headers)
   - `conf.d/cloudflare.conf` (if behind Cloudflare)
5. **Proxy configurations** - Use `snippets/proxy-headers.conf` for standard headers
6. **Rate limiting** - Apply `limit_req zone=api` or `zone=general` as appropriate

### Proxy Header Usage

When proxying to backends, use `include snippets/proxy-headers.conf` instead of manually setting proxy headers. This provides:
- Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto
- X-Forwarded-Host, X-Request-ID

Add service-specific headers after the include.

### WebSocket Support

For WebSocket endpoints, include both:
1. Standard proxy headers: `include snippets/proxy-headers.conf`
2. WebSocket upgrade headers from `conf.d/websocket.conf` pattern:
   ```nginx
   proxy_set_header Upgrade $http_upgrade;
   proxy_set_header Connection $connection_upgrade;
   ```

### Rate Limiting Zones

Defined in nginx.conf:
- `zone=api` - 10r/s for API endpoints
- `zone=general` - 1r/s for general use

Apply with `limit_req zone=api burst=20 nodelay;`

### Upstream Definitions

Place upstream blocks at the end of site configurations:
```nginx
upstream backend_app {
    server 127.0.0.1:3000;
    keepalive 32;
}
```

## Site Deployment Workflow

1. Create configuration in `sites-available/{domain}.conf`
2. Create security headers in `sites-security/{domain}.conf` (if needed)
3. Test configuration: `sudo nginx -t`
4. Enable site: `sudo ln -s /etc/nginx/sites-available/{domain}.conf /etc/nginx/sites-enabled/`
5. Reload: `sudo nginx -s reload`

## Code Style

- **Indentation**: 4 spaces
- **Alignment**: Align directive values using spaces for readability
- **Comments**: Explain purpose, not syntax
- **Server blocks**: Separate with blank lines
- **Include order**: security → performance → general → proxy → TLS

## Security Requirements

All new configurations must include:
- HTTPS redirect on port 80
- Modern TLS settings (via tls-intermediate.conf)
- Security headers (X-Frame-Options, X-Content-Type-Options, etc.)
- Rate limiting on user-facing endpoints
- Deny rules for sensitive files (.git, .env, etc.)

## Common Tasks

### Adding a New Site

Use `sites-available/example-site.com.conf` as the template. It demonstrates:
- Multi-subdomain setup (main, api, admin)
- Static file caching strategies
- API proxying with CORS
- WebSocket support
- Rate limiting per endpoint

### Adding Proxy Headers

Always use `include snippets/proxy-headers.conf` for standard headers. Only add custom headers for service-specific needs (e.g., `X-Service`, `X-Request-ID`).

### Modifying Global Settings

- **Performance/security**: Edit `conf.d/performance.conf` or `conf.d/security.conf`
- **Proxy defaults**: Edit `conf.d/proxy.conf`
- **TLS settings**: Edit `conf.d/tls-intermediate.conf`

Changes to `conf.d/` files affect all sites globally.

## Documentation References

See `docs/` directory for detailed guides:
- `API-GATEWAY-SETUP.md` - Microservices routing patterns
- `BEST-PRACTICE-SITE-SETUP.md` - Multi-subdomain site configuration
- `MONITORING-SETUP.md` - Logging and metrics
- `SECURITY-CHECKLIST.md` - Security validation

## Notes

- Files in `sites-enabled/` should always be symlinks, never direct files
- The `.gitignore` excludes all `sites-enabled/*` except defaults
- `sites-security/` contains site-specific security headers (CSP, HSTS, etc.)
- Upstream keepalive is set in upstream blocks (typically 32 for backends, 16 for admin)
