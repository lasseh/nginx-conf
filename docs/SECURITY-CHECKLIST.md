# Nginx Security Checklist

## SSL/TLS
- [ ] SSL certificates from trusted CA
- [ ] TLSv1.2 and TLSv1.3 only
- [ ] Strong cipher suites, no weak ciphers
- [ ] HSTS headers with appropriate max-age
- [ ] Perfect Forward Secrecy enabled

## Security Headers
- [ ] X-Frame-Options: DENY or SAMEORIGIN
- [ ] X-Content-Type-Options: nosniff
- [ ] X-XSS-Protection configured
- [ ] Content-Security-Policy for your application
- [ ] Referrer-Policy set appropriately

## Access Control
- [ ] Rate limiting zones configured
- [ ] Admin interfaces IP-restricted
- [ ] File access restrictions (.htaccess, .env, etc.)
- [ ] Server tokens disabled
- [ ] Connection and request size limits set

## Advanced Security (Optional)

### Fail2ban Integration
```bash
# /etc/fail2ban/filter.d/nginx-security.conf
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*" (404|403|400|444) .*$

# /etc/fail2ban/jail.local
[nginx-security]
enabled = true
filter = nginx-security
logpath = /var/log/nginx/access.log
maxretry = 5
bantime = 3600
```

### ModSecurity WAF
```nginx
load_module modules/ngx_http_modsecurity_module.so;

server {
    modsecurity on;
    modsecurity_rules_file /etc/nginx/modsec/main.conf;
}
```

### GeoIP Blocking
```nginx
map $geoip_country_code $blocked_country {
    default 0;
    CN 1;  # China
    RU 1;  # Russia
}

server {
    if ($blocked_country) {
        return 444;
    }
}
```

## Testing

### SSL/TLS Testing
```bash
# Test SSL configuration
curl -I https://yourdomain.com
openssl s_client -connect yourdomain.com:443

# Online tools:
# - https://www.ssllabs.com/ssltest/
# - https://securityheaders.com/
```

### Security Headers
```bash
# Verify headers are present
curl -I https://yourdomain.com | grep -E "(Strict-Transport|X-Content-Type|X-Frame|Content-Security)"
```

### Vulnerability Scanning
```bash
# Basic security scan
nmap -sV yourdomain.com

# Web application scan (own sites only)
nikto -h https://yourdomain.com
```

## Monitoring

### Key Metrics
- 404/403 error rates
- Failed login attempts  
- Unusual traffic patterns
- Large request sizes
- Suspicious user agents

### Log Analysis
```bash
# Attack patterns
grep "444\|403\|404" /var/log/nginx/access.log

# SQL injection attempts
grep -i "union\|select\|drop\|insert" /var/log/nginx/access.log

# XSS attempts
grep -i "script\|javascript\|onerror" /var/log/nginx/access.log
```

## Emergency Response
```bash
# Block IP immediately
sudo ufw insert 1 deny from ATTACKER_IP

# Monitor real-time attacks
tail -f /var/log/nginx/access.log | grep -E "(404|403|444)"
```