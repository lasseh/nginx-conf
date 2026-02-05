# HTTP/3 Implementation Guide

## Overview

This guide explains the differences between HTTP versions and provides implementation steps for enabling HTTP/3 in your nginx configuration.

## HTTP Protocol Comparison

### HTTP/1.1 (1997)

**How it works:**
- One request per TCP connection (or sequential requests with keep-alive)
- Text-based protocol
- No header compression
- No request prioritization

**Problems:**
- Head-of-line blocking: requests must complete in order
- Multiple connections needed for parallel downloads (browser limit: ~6/domain)
- Repeated headers waste bandwidth
- High latency for multiple resources

### HTTP/2 (2015)

**How it works:**
- Multiplexing: multiple requests over single TCP connection
- Binary protocol (more efficient parsing)
- Header compression (HPACK)
- Server push capability
- Stream prioritization

**Improvements:**
- Eliminates HTTP-level head-of-line blocking
- Single connection = less overhead, faster TLS handshakes
- ~30-50% faster than HTTP/1.1 in typical scenarios

**Remaining problem:**
- TCP head-of-line blocking: one lost packet blocks ALL streams
- TCP handshake + TLS handshake = latency

### HTTP/3 (2022)

**How it works:**
- Uses QUIC protocol over UDP (not TCP)
- Built-in TLS 1.3 (encrypted by default)
- Independent streams (no TCP head-of-line blocking)
- 0-RTT connection resumption
- Better mobile performance (connection migration)

**Improvements over HTTP/2:**
- ~10-30% faster on lossy networks (mobile, WiFi)
- Faster connection establishment (1-RTT or 0-RTT vs 2-3 RTT)
- Survives network changes (WiFi → cellular)
- Handles packet loss better

**Drawbacks:**
- UDP blocked on some corporate networks (~3-5% of users)
- Higher CPU usage (QUIC encryption overhead)
- Less mature ecosystem
- Some load balancers don't support it well

## Real-World Performance Impact

| Scenario | HTTP/1.1 | HTTP/2 | HTTP/3 |
|----------|----------|--------|--------|
| Good connection | 5.0s | 3.5s | 3.2s |
| Mobile/3G | 12.0s | 8.5s | 6.5s |
| 1% packet loss | 15.0s | 12.0s | 7.0s |

## Recommendation

### Current Status: HTTP/2 (Good)
Your nginx configuration currently uses HTTP/2, which is the recommended baseline for all modern HTTPS sites.

### When to Enable HTTP/3

Enable HTTP/3 if you have:
1. High mobile traffic with performance issues
2. Users on unreliable networks
3. Real-time/streaming applications
4. Confirmed nginx has HTTP/3 support (`nginx -V | grep http_v3`)

### Recommended Approach: HTTP/2 + HTTP/3 Fallback

This provides the best performance for modern clients while maintaining compatibility:
- HTTP/3 tries first (if advertised)
- Falls back to HTTP/2 for older clients
- Falls back to HTTP/1.1 for legacy clients

## Implementation Steps

### 1. Check HTTP/3 Support

```bash
# Verify nginx is compiled with HTTP/3 module
nginx -V 2>&1 | grep http_v3

# Expected output should include:
# --with-http_v3_module
```

### 2. Update Server Blocks

**Before (HTTP/2 only):**
```nginx
server {
    listen                  443 ssl;
    listen                  [::]:443 ssl;
    http2                   on;
    server_name             example-site.com;

    ssl_certificate         /etc/letsencrypt/live/example-site.com/fullchain.pem;
    ssl_certificate_key     /etc/letsencrypt/live/example-site.com/privkey.pem;
}
```

**After (HTTP/2 + HTTP/3):**
```nginx
server {
    listen                  443 ssl;
    listen                  443 quic reuseport;
    listen                  [::]:443 ssl;
    listen                  [::]:443 quic reuseport;
    http2                   on;
    http3                   on;
    server_name             example-site.com;

    # Advertise HTTP/3 support to browsers
    add_header              Alt-Svc 'h3=":443"; ma=86400';

    ssl_certificate         /etc/letsencrypt/live/example-site.com/fullchain.pem;
    ssl_certificate_key     /etc/letsencrypt/live/example-site.com/privkey.pem;
}
```

### 3. Firewall Configuration

HTTP/3 uses UDP instead of TCP. Ensure UDP port 443 is open:

```bash
# UFW
sudo ufw allow 443/udp

# iptables
sudo iptables -A INPUT -p udp --dport 443 -j ACCEPT

# firewalld
sudo firewall-cmd --permanent --add-port=443/udp
sudo firewall-cmd --reload
```

### 4. Update nginx.conf Comment

Remove or update the comment in `nginx.conf:108`:

**Before:**
```nginx
# Key Features:
#   - HTTP/2 enabled on all HTTPS sites
#   - No HTTP/3/QUIC (experimental, causes issues)
```

**After:**
```nginx
# Key Features:
#   - HTTP/2 + HTTP/3 enabled on all HTTPS sites
#   - QUIC support for improved mobile performance
```

### 5. Apply Changes

Apply changes to all HTTPS server blocks in:
- `sites-available/example-site.com.conf` (3 server blocks)
- `sites-available/api-gateway.example.com.conf`
- `sites-available/wordpress.conf`
- `sites-available/static-site.conf`
- `sites-available/reverse-proxy.conf`
- `sites-available/librenms.example.com.conf`
- `sites-available/netbox.example.com.conf`
- `sites-available/grafana.example.com.conf`
- `sites-available/defaults-443.conf`
- Any other active sites in `sites-enabled/`

### 6. Test Configuration

```bash
# Test syntax
sudo nginx -t

# If successful, reload
sudo nginx -s reload
```

### 7. Verify HTTP/3 is Working

```bash
# Test with curl (requires curl with HTTP/3 support)
curl -I --http3 https://your-domain.com

# Check Alt-Svc header
curl -I https://your-domain.com | grep -i alt-svc
# Expected: alt-svc: h3=":443"; ma=86400

# Browser DevTools (Chrome/Edge):
# 1. Open DevTools → Network tab
# 2. Add "Protocol" column
# 3. Load your site
# 4. Look for "h3" in the Protocol column
```

## Rollback Plan

If issues occur, revert by:

1. Remove QUIC listeners:
   ```nginx
   # Remove these lines:
   listen                  443 quic reuseport;
   listen                  [::]:443 quic reuseport;
   http3                   on;
   add_header              Alt-Svc 'h3=":443"; ma=86400';
   ```

2. Test and reload:
   ```bash
   sudo nginx -t && sudo nginx -s reload
   ```

## Monitoring

After enabling HTTP/3, monitor:

1. **CPU usage** - QUIC encryption is more CPU-intensive
2. **Connection protocol distribution** - Check nginx logs for protocol usage
3. **Error rates** - Watch for UDP-related connection issues
4. **Performance metrics** - Measure actual improvement in page load times

## Additional Resources

- [nginx HTTP/3 documentation](https://nginx.org/en/docs/http/ngx_http_v3_module.html)
- [QUIC at Cloudflare](https://blog.cloudflare.com/http3-the-past-present-and-future/)
- [HTTP/3 explained](https://http3-explained.haxx.se/)

## Decision Matrix

| Factor | Stick with HTTP/2 | Enable HTTP/3 |
|--------|-------------------|---------------|
| Mobile traffic > 50% | | ✓ |
| Real-time/streaming | | ✓ |
| Users on unstable networks | | ✓ |
| CPU resources limited | ✓ | |
| Conservative approach | ✓ | |
| Maximum performance | | ✓ |
| Enterprise/corporate users | ✓ | |

## Conclusion

**Current recommendation: Stick with HTTP/2** unless you have specific performance requirements or high mobile traffic. HTTP/2 provides excellent performance with minimal complexity and universal support.

When ready to implement HTTP/3, follow the steps above and monitor performance closely for the first few weeks.
