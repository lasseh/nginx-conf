# Nginx Configuration Repository - Comprehensive Review

**Review Date:** 2025-11-27 (updated 2026-01-30)
**nginx-conf Version:** v2.0.0+

---

## Executive Summary

Comprehensive review of the nginx-conf repository. All critical and moderate bugs from the original review have been resolved. This document tracks what was found and what was fixed.

---

## Resolved Issues

All bugs and issues below have been fixed.

### Critical Bugs (Previously Blocking)

| Bug | Description | Resolution |
|-----|-------------|------------|
| BUG-001 | WordPress references non-existent `snippets/fastcgi-php.conf` | Removed redundant includes — surrounding code already has fastcgi_pass and fastcgi_params |
| BUG-002 | WordPress `brotli_static on;` directive | Removed (Brotli module not installed) |
| BUG-003 | `deny-files.conf` blocks `.json` files | Removed `.json` from blocked extensions |
| BUG-004 | LibreNMS incorrect PHP routing (api.php, ajax.php) | Routes through `index.php` (Laravel pattern) |
| BUG-005 | LibreNMS rate limiting too restrictive (1r/s) | Rate limiting removed |
| BUG-006 | API Gateway duplicate rate limit zones | Zones use unique `gw_` prefix, commented out by default |

### Moderate Bugs (Previously Causing Issues)

| Bug | Description | Resolution |
|-----|-------------|------------|
| BUG-007 | Load balancer incomplete server line | Fixed trailing space |
| BUG-008 | Load balancer WebSocket 3s timeout | Changed to 3600s |
| BUG-009 | Grafana multiline CSP header | Single line |
| BUG-010 | NetBox missing HTTP/2 directive | HTTP/2 and HTTP/3 present |
| BUG-011 | API Gateway copy-paste error in orders location | Correct service names |
| BUG-012 | `security-headers.conf` COEP breaks external resources | Strict versions commented out, relaxed defaults active |

### Security & Correctness Fixes

| Fix | Description | Resolution |
|-----|-------------|------------|
| FIX-1.2 | Duplicate `log_format security` name | Renamed to `security_monitor` in `snippets/security-monitoring.conf` |
| FIX-2.1 | `deny-files.conf` blocks `/admin/` path globally | Removed `admin`, `administrator`, `wp-admin`, `config` from regex |
| FIX-2.2 | `http3.conf` enables `ssl_early_data` unconditionally | Commented out with replay attack warning |
| FIX-2.3 | `static-files.conf` location blocks clear parent security headers | Added `include snippets/security-headers.conf;` to each location block |
| FIX-2.4 | NetBox missing security headers | Added `include snippets/security-headers.conf;` |
| FIX-2.5 | Inconsistent proxy header usage in api-gateway and grafana | Replaced manual headers with `include snippets/proxy-headers.conf;` |
| FIX-2.6 | Redundant `include conf.d/proxy.conf` in location blocks | Replaced with `include snippets/proxy-headers.conf;` |
| FIX-2.7 | WordPress inconsistent `fastcgi_params` paths | Normalized to relative paths |
| FIX-2.8 | `defaults-443.conf` undocumented `ssl_stapling off` | Added comment explaining self-signed cert rationale |

### Best Practices & Modernization

| Fix | Description | Resolution |
|-----|-------------|------------|
| FIX-3.1 | `X-XSS-Protection "1; mode=block"` deprecated | Changed to `"0"` across all files with explanation |
| FIX-3.2 | Stale "No HTTP/3/QUIC" comment in `nginx.conf` | Updated to reflect per-site HTTP/3 via `snippets/http3.conf` |
| FIX-3.3 | Missing `gzip_static on;` in gzip snippet | Added `gzip_static on;` after `gzip on;` |
| FIX-3.4 | `security-monitoring.conf` flags curl/wget/python | Commented out with false-positive explanation |
| FIX-3.5 | PHP version hardcoded without guidance | Added prominent version comment to `snippets/php-fpm.conf` |
| FIX-3.6 | `development.conf` missing HTTP-only notice | Added warning about HTTP-only being intentional |
| FIX-3.7 | Grafana duplicate security headers | Removed headers already provided by `snippets/security-headers.conf` |
| MODERN-002 | TLS 1.3-only option | `conf.d/tls-modern.conf` created |
| HTTP/3 | HTTP/3 snippet | `snippets/http3.conf` created |
| ISSUE-004 | OCSP resolver formatting | Reformatted with comments |

---

## Architecture Notes

### Header Inheritance

nginx discards ALL parent `add_header` directives when a child location block uses its own `add_header`. Any location block that sets cache headers or CORS headers must also re-include `snippets/security-headers.conf` to retain security headers. This is by design in nginx — not a bug.

### Proxy Header Pattern

All proxy locations should use `include snippets/proxy-headers.conf;` for standard headers (Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto, X-Forwarded-Host, X-Request-ID). Service-specific headers go after the include.

`conf.d/proxy.conf` is loaded globally at the HTTP level in `nginx.conf` and sets proxy defaults (timeouts, buffering). It should NOT be included in location blocks — use `snippets/proxy-headers.conf` instead.

### Rate Limiting

Rate limiting is disabled by default across all configurations. See `docs/RATE-LIMITING.md` for the comprehensive guide on enabling it.

---

## Testing Commands

```bash
# Test configuration syntax
sudo nginx -t

# Check for duplicate log_format names
grep -r 'log_format' conf.d/ snippets/

# Verify no broken includes
grep -r 'include.*snippets/' sites-available/ | while read line; do
    file=$(echo "$line" | grep -oP 'snippets/\S+\.conf')
    [ -f "$file" ] || echo "MISSING: $file (referenced in $line)"
done

# Reload after changes
sudo nginx -s reload
```
