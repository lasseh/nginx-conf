# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Production-ready, modular nginx configuration for multi-site hosting with security hardening, HTTP/2 and HTTP/3 (QUIC) support, and a two-layer monitoring stack. All configs are templates — replace placeholder domains with actual domains before use.

## Validation

```bash
make test                    # validate (nginx -t per template) + test-runtime (Docker, curl assertions)
make lint                    # shellcheck scripts/ and tests/runtime/
sudo nginx -t                # On a host: test syntax (run after every change)
sudo nginx -s reload         # Graceful reload (no downtime)
```

`make test-runtime` (`tests/runtime/`) enables every template at once in `nginx:mainline`, points all upstreams at an echo stub, and asserts response headers and upstream-received headers. Add an assertion to `tests/runtime/run.sh` for any header/routing behaviour you change — `nginx -t` can't see those bugs.

## Architecture

```
nginx.conf
├── conf.d/          # HTTP-level globals — loaded once, affects ALL server blocks
├── snippets/        # Reusable blocks — selectively included in server/location blocks
├── sites-available/ # Site templates (10 templates, not loaded directly)
├── sites-enabled/   # Active sites (symlinks → sites-available/, loaded by nginx.conf)
├── sites-security/  # Per-site security headers (CSP, HSTS overrides)
├── monitoring/      # Prometheus + Grafana Alloy + dashboard
└── examples/        # SSE and WebSocket reference configs
```

### conf.d/ vs snippets/ (critical distinction)

**conf.d/** files are included globally at the `http {}` level in nginx.conf. They set defaults for ALL server blocks (proxy timeouts, TLS settings, log formats, variable maps). Never include conf.d/ files in location blocks.

**snippets/** files are manually included where needed — in `server {}` or `location {}` blocks. They provide reusable directives (proxy headers, security headers, deny rules, gzip, HTTP/3 headers).

### Include hierarchy in a typical site config

```nginx
# Server level
include snippets/security-headers.conf; # Generic security headers — OR, not both:
# include sites-security/domain.conf;   # site-specific full header set (CSP, COEP, ...)
include snippets/http3.conf;            # Alt-Svc header for HTTP/3
include snippets/deny-files.conf;       # Block .git, .env, backups

# Location level
location /api/ {
    proxy_pass http://backend;
    include snippets/proxy-headers.conf; # Host, X-Real-IP, X-Forwarded-*
}
```

### add_header inheritance

Stock nginx drops ALL parent `add_header` directives in any `location` (or `if`) that sets its own. `conf.d/headers.conf` sets `add_header_inherit merge` at http level (requires nginx >= 1.29.3), so locations append to the server's headers instead. Consequences:

- **Never** re-include `snippets/security-headers.conf` (or http3.conf) inside a location — with merge every header is sent twice.
- Set each header name at **one** level. A name set at server and location level is sent twice. To override a header for a whole server (e.g. admin's `X-Frame-Options DENY`), give that server its own `sites-security/` file instead of layering on top.
- Don't combine `expires` with `add_header Cache-Control` — `expires` emits its own Cache-Control. Put `max-age` in the Cache-Control value.
- Use `default_type`, not `add_header Content-Type` (which adds a second Content-Type).
- An OPTIONS `if` must come **before** any `rewrite ... break` in the same location; `break` stops the rewrite phase, so the `if` never runs.

```nginx
location /static/ {
    add_header Cache-Control "public, max-age=31536000, immutable";  # HSTS/CSP/Alt-Svc still inherited
}
```

`make test-runtime` asserts no duplicate headers and that security headers reach every tested location.

### sites-security/ files

Per-domain security header customization. Included at server level in site configs. Contains `add_header` directives (HSTS, CSP, COEP, COOP, CORP) and optionally `location` blocks for file/path restrictions. Use these when a site needs a custom CSP or different cross-origin policy than the generic snippet.

### WebSocket pattern

The `$connection_upgrade` variable is defined in `conf.d/maps.conf` (not a separate websocket.conf). WebSocket locations need:

```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
include snippets/proxy-headers.conf;
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
```

### Monitoring stack

Two layers in `monitoring/`:
- **Layer 1:** stub_status + nginx-prometheus-exporter (connection counts, request totals)
- **Layer 2:** Grafana Alloy (tails access logs in `elk_json` format → Prometheus metrics for 4xx/5xx rates, response time histograms, bytes/s → Loki for log search)

The global access log in nginx.conf uses `elk_json` format (defined in `conf.d/logformat.conf`) which Alloy parses. The Grafana dashboard (`monitoring/grafana/nginx-dashboard.json`) has 23 panels (18 visualizations across 5 row sections) covering both layers.

## Site Configuration Pattern

Every HTTPS site config follows this structure:

1. HTTP server on port 80 → `return 301 https://`
2. HTTPS server on port 443 with `ssl`, `quic`, `http2 on`, `http3 on`
3. SSL certs from Let's Encrypt: `/etc/letsencrypt/live/{domain}/`
4. Security includes: `snippets/security-headers.conf`, `snippets/http3.conf`, `snippets/deny-files.conf`
5. Proxy locations using `include snippets/proxy-headers.conf`
6. Upstream blocks at end of file with `keepalive 32`

Rate limiting is disabled by default. See `docs/RATE-LIMITING.md` to enable.

## Code Style

- 4-space indentation
- Align directive values with spaces for readability
- Comments explain "why", not "what"
- CSP headers must be a single line (HTTP/2 RFC 7540 §8.1.2 forbids line folding)

## Site Deployment

```bash
cp sites-available/reverse-proxy.conf sites-available/newsite.com.conf
# Edit: server_name, ssl paths, upstream
sudo nginx -t
sudo ln -s /etc/nginx/sites-available/newsite.com.conf /etc/nginx/sites-enabled/
sudo nginx -s reload
```

## Key Files Reference

| File | Purpose |
|------|---------|
| `conf.d/proxy.conf` | Global proxy timeouts (60s), buffering, HTTP/1.1 upstream |
| `conf.d/headers.conf` | `add_header_inherit merge` — server headers reach every location (nginx >= 1.29.3) |
| `conf.d/maps.conf` | WebSocket upgrade mapping, RFC 7239 forwarded header |
| `conf.d/tls-intermediate.conf` | TLS 1.2+1.3, Mozilla Intermediate ciphers, OCSP |
| `conf.d/tls-modern.conf` | TLS 1.3 only (optional, stricter) |
| `conf.d/security-monitoring.conf` | HTTP-level maps for attack detection (optional) |
| `snippets/proxy-headers.conf` | Host, X-Real-IP, X-Forwarded-*, X-Request-ID |
| `snippets/security-headers.conf` | HSTS, X-Frame-Options, COEP/COOP/CORP, Permissions-Policy |
| `snippets/deny-files.conf` | Blocks .git, .env, backups, config files, VCS dirs |
| `snippets/error-pages.conf` | HTML error pages (404, 500, 502, 503, 504) from `html/errors/` |
| `snippets/error-pages-json.conf` | JSON error pages (404, 429, 500, 502-504) for APIs |
| `snippets/security-monitoring.conf` | Server-level attack pattern location blocks |
