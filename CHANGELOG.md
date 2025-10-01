# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-01-10

### Changed
- **BREAKING**: Removed HTTP/3 QUIC support due to `reuseport` conflicts in multi-site configurations
- **BREAKING**: Removed Brotli compression (simplified to gzip-only for better compatibility)
- Restructured proxy header configuration - moved from `conf.d/proxy.conf` to `snippets/proxy-headers.conf`
- Updated all site templates to use `snippets/proxy-headers.conf` for consistent proxy headers
- Moved WebSocket configuration from `conf.d/websocket.conf` to `conf.d/maps.conf` (map blocks only)
- Reorganized examples: moved `conf.d/websocket.conf` and `conf.d/sse.conf` to `examples/` directory

### Added
- Custom error pages with minimalist design (502, 503, 504)
- `snippets/error-pages.conf` for consistent error page handling
- `html/errors/` directory with stylish error pages featuring developer humor
- `conf.d/maps.conf` for WebSocket upgrade mapping and proxy forwarded headers
- `examples/sse-example.conf` - comprehensive Server-Sent Events reference configuration
- `examples/websocket-example.conf` - WebSocket configuration patterns
- Comprehensive `docs/SITES-AVAILABLE-GUIDE.md` covering all 11 site templates
- New `README.md` with beginner-friendly quick start guide
- Complete documentation overhaul with accurate architecture references

### Fixed
- Proxy headers no longer apply globally to all requests (security improvement)
- WebSocket support now uses proper map blocks instead of standalone config
- Rate limiting configuration more clearly documented per endpoint
- SSL certificate paths in default servers updated to use generic paths
- All documentation updated to reflect current architecture (no HTTP/3, no Brotli)

### Removed
- HTTP/3 and QUIC directives from all site configurations
- `snippets/brotli.conf` (user preference for gzip-only)
- `conf.d/general.conf` (empty, unused)
- `conf.d/websocket.conf` (moved to examples)
- `conf.d/sse.conf` (moved to examples)
- `docs/SERVER-SETUP.md` (outdated, content merged into other docs)

### Security
- Default proxy headers now only apply to proxy locations (not static files)
- Custom error pages prevent information disclosure when backends fail
- Improved separation of concerns in configuration architecture

## [1.0.0] - 2025-06-28

### Added
- Initial release of modern nginx configuration
- Comprehensive security hardening (HSTS, CSP, rate limiting)
- Performance optimizations (gzip compression, caching)
- Modular configuration structure with clear separation of concerns
- API Gateway setup with microservices routing
- Multiple site templates:
  - Static site/SPA configuration
  - WordPress with PHP-FPM
  - Reverse proxy for backend applications
  - Docker Compose service routing
  - Load balancer configuration
  - Development environment setup
  - Grafana, LibreNMS, NetBox examples
- Default server configuration for security (HTTP and HTTPS)
- SSL/TLS configuration (Mozilla Intermediate profile)
- Cloudflare integration (optional)
- WebSocket support via configuration includes
- Monitoring and logging setup with stub_status
- Security checklist and best practices documentation
- Comprehensive documentation in docs/ directory

### Security Features
- Rate limiting zones for different endpoint types (API, general)
- Security headers (HSTS, CSP, X-Frame-Options, X-Content-Type-Options, etc.)
- SSL/TLS hardening with modern cipher suites (TLS 1.2/1.3 only)
- Default servers catch invalid requests (return 444)
- Request body size limits and timeout controls
- Dangerous file blocking (.git, .env, .htaccess, etc.)

### Performance Features
- HTTP/2 enabled on all HTTPS sites
- Gzip compression for text-based assets
- Optimized caching strategies for static files
- Connection keep-alive optimization
- Upstream keepalive connections for backend proxying
- Sendfile and tcp_nopush enabled for efficient file transfers
- Worker process auto-tuning

### Documentation
- API Gateway architecture diagrams and setup guide
- Best practice site setup guide for multi-subdomain configurations
- Security implementation checklist
- Monitoring and observability setup guide
- Example configurations for common use cases
- Modular snippet documentation

---

## Version History

- **v2.0.0** - Simplified architecture, removed experimental features, improved documentation
- **v1.0.0** - Initial public release with comprehensive feature set
