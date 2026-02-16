# Certbot Deployment Hooks

Automatically reload nginx after SSL certificate renewal.

## What This Does

When certbot renews your SSL certificates, nginx needs to be reloaded to use the new certificates. This hook automates that process.

## First-Time Certificate Setup

If this is a fresh server with no Let's Encrypt certificates yet, follow these steps before installing the deploy hook.

### 1. Install Certbot

```bash
# Debian/Ubuntu
sudo apt update && sudo apt install certbot

# RHEL/Rocky/Alma
sudo dnf install certbot
```

### 2. Create the ACME Webroot Directory

The `snippets/letsencrypt.conf` snippet serves challenges from this path:

```bash
sudo mkdir -p /usr/share/nginx/html/letsencrypt/.well-known/acme-challenge
```

### 3. Enable the Site Config (HTTP Only)

Each site template includes `snippets/letsencrypt.conf` in its port 80 server block, which handles ACME challenges. Copy your site config and enable it:

```bash
# Copy a template and edit it
sudo cp sites-available/reverse-proxy.conf sites-available/your-app.com.conf
# Edit: server_name, upstream, etc.

# Enable the site
sudo ln -s /etc/nginx/sites-available/your-app.com.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo nginx -s reload
```

Nginx will serve HTTP on port 80 and handle ACME challenges. The HTTPS server block will fail to load until certificates exist — this is expected and nginx will still start.

### 4. Point DNS to Your Server

Create an A record (and AAAA for IPv6) pointing your domain to the server's IP. Wait for DNS propagation before requesting a certificate.

### 5. Request the Certificate

```bash
sudo certbot certonly --webroot \
    -w /usr/share/nginx/html/letsencrypt \
    -d your-app.com \
    -d www.your-app.com
```

Certbot places certificates in `/etc/letsencrypt/live/your-app.com/`.

### 6. Reload Nginx

Now that certificates exist, the HTTPS server block will load:

```bash
sudo nginx -t && sudo nginx -s reload
```

Verify with `curl -I https://your-app.com`.

### 7. Install the Deploy Hook

Continue with the installation section below to automate reloads on renewal.

## Installation

### 1. Copy Hook Script

```bash
# Copy the deploy hook to certbot's renewal hooks directory
sudo cp scripts/certbot-hooks/deploy.sh /etc/letsencrypt/renewal-hooks/deploy/

# Make it executable
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/deploy.sh

# Verify it's in place
ls -la /etc/letsencrypt/renewal-hooks/deploy/
```

### 2. Test the Hook

```bash
# Test certbot renewal process (dry run)
sudo certbot renew --dry-run

# Check the log for hook execution
sudo tail -20 /var/log/nginx/certbot-reload.log
```

### 3. Verify Automatic Renewal

Certbot sets up automatic renewal via systemd timer or cron:

```bash
# Check systemd timer (most common)
systemctl list-timers | grep certbot

# Or check cron
sudo cat /etc/cron.d/certbot
```

## How It Works

### Certbot Renewal Process

1. **Certbot runs** (via systemd timer or cron)
2. **Checks certificates** - sees which ones are expiring soon
3. **Renews certificates** - contacts Let's Encrypt, validates domain
4. **Runs deploy hooks** - executes all scripts in `renewal-hooks/deploy/`
5. **Our script runs:**
   - Tests nginx configuration (`nginx -t`)
   - Reloads nginx if test passes (`systemctl reload nginx`)
   - Verifies nginx is still running
   - Logs everything to `/var/log/nginx/certbot-reload.log`

### Hook Execution Timing

- **deploy** hooks run ONLY after successful renewal
- Certbot provides environment variables:
  - `$RENEWED_DOMAINS` - domains that were renewed
  - `$RENEWED_LINEAGE` - path to certificate directory

### Safety Features

✅ **Configuration test first** - won't reload if config has errors
✅ **Graceful reload** - no downtime, existing connections continue
✅ **Health check** - verifies nginx is still running after reload
✅ **Detailed logging** - all actions logged to file
✅ **Error handling** - exits on failure, certbot knows something went wrong

## Monitoring

### Check Hook Logs

```bash
# View recent hook executions
sudo tail -50 /var/log/nginx/certbot-reload.log

# Watch logs in real-time
sudo tail -f /var/log/nginx/certbot-reload.log

# Search for errors
sudo grep ERROR /var/log/nginx/certbot-reload.log
```

### Test Hook Manually

```bash
# Simulate certbot calling the hook
sudo RENEWED_DOMAINS="example.com www.example.com" \
     RENEWED_LINEAGE="/etc/letsencrypt/live/example.com" \
     /etc/letsencrypt/renewal-hooks/deploy/deploy.sh
```

## Troubleshooting

### Hook Not Running

**Check hook directory:**
```bash
ls -la /etc/letsencrypt/renewal-hooks/deploy/
```

**Verify permissions:**
```bash
# Should be executable
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/deploy.sh
```

**Check certbot logs:**
```bash
sudo tail -50 /var/log/letsencrypt/letsencrypt.log
```

### Nginx Reload Failing

**Check nginx configuration:**
```bash
sudo nginx -t
```

**Check nginx service:**
```bash
sudo systemctl status nginx
```

**Check nginx error log:**
```bash
sudo tail -50 /var/log/nginx/error.log
```

### Certbot Not Auto-Renewing

**Check renewal timer:**
```bash
# Systemd
systemctl status certbot.timer
systemctl list-timers | grep certbot

# Cron
sudo cat /etc/cron.d/certbot
```

**Test renewal manually:**
```bash
sudo certbot renew --dry-run
```

## Advanced Configuration

### Add Notifications

Edit `deploy.sh` and uncomment the notification section:

```bash
# Example: Slack webhook
curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"🔒 SSL certificates renewed: $RENEWED_DOMAINS\"}"

# Example: Email
echo "SSL certificates renewed for $RENEWED_DOMAINS" | \
  mail -s "SSL Renewal Success" admin@example.com

# Example: Telegram
curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "text=SSL certificates renewed: $RENEWED_DOMAINS"
```

### Multiple Hooks

You can have multiple scripts in the deploy directory:

```bash
/etc/letsencrypt/renewal-hooks/deploy/
├── 01-test-config.sh      # Test nginx config
├── 02-reload-nginx.sh     # Reload nginx
├── 03-notify-team.sh      # Send notification
└── 04-update-cdn.sh       # Update CDN with new cert
```

Scripts run in alphabetical order.

### Pre and Post Hooks

Certbot supports three hook types:

```bash
renewal-hooks/
├── pre/          # Runs BEFORE renewal attempt
├── deploy/       # Runs AFTER successful renewal (our script here)
└── post/         # Runs AFTER renewal attempt (success or failure)
```

**Example pre-hook** (stop nginx during renewal):
```bash
#!/bin/bash
# /etc/letsencrypt/renewal-hooks/pre/stop-nginx.sh
systemctl stop nginx
```

**Example post-hook** (always runs, even if renewal failed):
```bash
#!/bin/bash
# /etc/letsencrypt/renewal-hooks/post/always-start-nginx.sh
systemctl start nginx
```

## Best Practices

✅ **Keep it simple** - our deploy hook does one thing well
✅ **Test first** - always run `nginx -t` before reload
✅ **Log everything** - helps with troubleshooting
✅ **Verify health** - check nginx is running after changes
✅ **Monitor logs** - set up alerts for hook failures
✅ **Test renewals** - run `certbot renew --dry-run` monthly

## Certificate Renewal Schedule

Let's Encrypt certificates:
- **Valid for:** 90 days
- **Auto-renewal starts:** 30 days before expiry
- **Certbot timer runs:** Twice daily (Ubuntu/Debian)
- **Actual renewal:** Only happens if cert expires within 30 days

This means:
- Day 1: Certificate issued
- Day 60: Certbot starts trying to renew
- Day 90: Certificate expires (if not renewed)

The twice-daily timer ensures renewal happens even if one attempt fails.

## Security Considerations

🔒 **Hook runs as root** - required for nginx reload
🔒 **Validates config** - won't reload broken config
🔒 **Logs are protected** - only root can read `/var/log/nginx/`
🔒 **No secrets in hook** - uses system commands only

## Related Documentation

- [Certbot Documentation](https://eff-certbot.readthedocs.io/en/stable/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Nginx Reload Signal](https://nginx.org/en/docs/control.html)
