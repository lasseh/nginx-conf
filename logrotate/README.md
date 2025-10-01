# Nginx Log Rotation Configuration

Automatically rotate nginx logs to prevent disk space issues and maintain manageable log sizes.

## What This Does

Logrotate automatically:
- Rotates logs daily (access logs) or as configured
- Compresses old logs to save disk space
- Keeps logs for a specified retention period
- Signals nginx to reopen log files after rotation
- Deletes old logs automatically

## Installation

### 1. Install Logrotate (if not already installed)

```bash
# Ubuntu/Debian
sudo apt install logrotate

# CentOS/RHEL
sudo yum install logrotate

# Verify installation
logrotate --version
```

### 2. Deploy Configuration

```bash
# Copy nginx logrotate config
sudo cp logrotate/nginx /etc/logrotate.d/nginx

# Set correct permissions
sudo chmod 644 /etc/logrotate.d/nginx
sudo chown root:root /etc/logrotate.d/nginx
```

### 3. Test Configuration

```bash
# Dry run - shows what would happen without actually rotating
sudo logrotate -d /etc/logrotate.d/nginx

# Verbose dry run
sudo logrotate -dv /etc/logrotate.d/nginx

# Force rotation (for testing)
sudo logrotate -f /etc/logrotate.d/nginx
```

### 4. Verify Automatic Execution

Logrotate runs automatically via cron:

```bash
# Check cron configuration
cat /etc/cron.daily/logrotate

# Check when it last ran
cat /var/lib/logrotate/status | grep nginx

# Test manual execution
sudo /etc/cron.daily/logrotate
```

## Configuration Details

### Default Configuration

**Main nginx logs** (`/var/log/nginx/*.log`):
- **Frequency:** Daily
- **Retention:** 14 days
- **Compression:** Yes (gzip)
- **Delay compression:** 1 day (for analysis)

**Error logs** (`/var/log/nginx/error.log`):
- **Frequency:** Daily
- **Retention:** 30 days (longer for debugging)
- **Compression:** Yes

**High-volume API logs** (`/var/log/nginx/api-*.log`):
- **Frequency:** Hourly
- **Retention:** 7 days (168 files)
- **Compression:** Yes

### Log File Naming

With `dateext` enabled, rotated logs look like:
```
access.log
access.log-2025-01-10
access.log-2025-01-09.gz
access.log-2025-01-08.gz
```

Without `dateext` (numbered):
```
access.log
access.log.1
access.log.2.gz
access.log.3.gz
```

## Customization

### Change Rotation Frequency

**Option 1: Time-based**
```bash
daily      # Every day at midnight (via cron.daily)
weekly     # Every week (Sunday by default)
monthly    # Every month (1st of month)
hourly     # Every hour (requires cron.hourly setup)
```

**Option 2: Size-based**
```bash
size 100M  # When file reaches 100MB
size 1G    # When file reaches 1GB
```

**Option 3: Combined**
```bash
daily
size 100M  # Rotate daily OR when file reaches 100MB (whichever comes first)
```

### Change Retention Period

```bash
# By rotation count
rotate 7       # Keep 7 rotated logs

# By age
maxage 30      # Delete logs older than 30 days

# By total size
maxsize 1G     # Delete oldest logs if total size exceeds 1GB
```

### Compression Options

```bash
# Gzip (default)
compress
compresscmd /bin/gzip
compressoptions -9    # Maximum compression

# Bzip2 (better compression, slower)
compress
compresscmd /bin/bzip2
compressext .bz2

# XZ (best compression, slowest)
compress
compresscmd /usr/bin/xz
compressext .xz

# No compression
nocompress
```

### Email Rotated Logs

```bash
# Email rotated logs before deletion
mail admin@example.com
mailfirst  # Email before rotation (or mailLast)

# Don't email
nomail
```

## How Log Rotation Works

### 1. Logrotate Runs (via cron)

Default schedule: Daily at 6:25 AM (Ubuntu/Debian)

```bash
# View cron schedule
cat /etc/cron.daily/logrotate
```

### 2. Check If Rotation Needed

Checks:
- Has it been long enough since last rotation?
- Is the log file big enough (if using size-based)?
- Does the log file exist and is not empty?

### 3. Perform Rotation

1. **Rename** `access.log` → `access.log-2025-01-10`
2. **Create** new empty `access.log` (with correct permissions)
3. **Signal nginx** to reopen log files (USR1 signal)
4. **Compress** old logs (if enabled and not first rotation)
5. **Delete** logs older than retention period

### 4. Signal Handling

```bash
# Logrotate sends USR1 signal to nginx
kill -USR1 $(cat /var/run/nginx.pid)

# This tells nginx to:
# - Close current log file handles
# - Open new log files
# - Continue logging without downtime
```

No downtime, no dropped log entries!

## Monitoring

### Check Last Rotation

```bash
# View logrotate state file
cat /var/lib/logrotate/status | grep nginx

# Example output:
"/var/log/nginx/access.log" 2025-1-10-6:0:0
"/var/log/nginx/error.log" 2025-1-10-6:0:0
```

### Check Rotated Logs

```bash
# List rotated logs
ls -lh /var/log/nginx/

# Example output:
-rw-r----- 1 nginx adm  1.2M Jan 10 12:00 access.log
-rw-r----- 1 nginx adm  5.3M Jan  9 23:59 access.log-2025-01-09
-rw-r----- 1 nginx adm  1.1M Jan  8 23:59 access.log-2025-01-08.gz
-rw-r----- 1 nginx adm  1.2M Jan  7 23:59 access.log-2025-01-07.gz
```

### Check Disk Usage

```bash
# Total size of nginx logs
du -sh /var/log/nginx/

# Size by file type
du -sh /var/log/nginx/*.log
du -sh /var/log/nginx/*.gz

# List largest log files
ls -lhS /var/log/nginx/ | head -10
```

### Check Logrotate Logs

```bash
# View logrotate's own log
sudo cat /var/log/logrotate.log

# Or journalctl (systemd)
sudo journalctl -u logrotate
```

## Troubleshooting

### Logs Not Rotating

**Check logrotate configuration:**
```bash
sudo logrotate -d /etc/logrotate.d/nginx
```

**Check permissions:**
```bash
ls -l /etc/logrotate.d/nginx
# Should be: -rw-r--r-- root root

ls -ld /var/log/nginx/
# Should be: drwxr-xr-x nginx adm
```

**Check cron is running:**
```bash
sudo systemctl status cron
```

**Manually run logrotate:**
```bash
sudo logrotate -f /etc/logrotate.d/nginx
```

### Permission Errors

**Error: "error: skipping because parent directory has insecure permissions"**

Fix parent directory permissions:
```bash
sudo chmod 755 /var/log/nginx
```

**Error: "error: error creating output file"**

Fix nginx user/group:
```bash
sudo chown -R nginx:adm /var/log/nginx
```

### Nginx Not Reopening Logs

**Check nginx PID file exists:**
```bash
ls -l /var/run/nginx.pid
cat /var/run/nginx.pid
```

**Check nginx process:**
```bash
ps aux | grep nginx
```

**Manually signal nginx:**
```bash
sudo nginx -s reopen
# or
sudo kill -USR1 $(cat /var/run/nginx.pid)
```

### Compressed Logs Not Created

**Check compression is enabled:**
```bash
grep compress /etc/logrotate.d/nginx
```

**Check compression tools installed:**
```bash
which gzip
gzip --version
```

**Check delaycompress:**
```bash
# With delaycompress, files are compressed on NEXT rotation
# This is intentional - allows time to analyze recent logs
```

## Advanced Configuration

### Per-Site Log Rotation

If you log each site to its own file:

```nginx
# In site configuration
access_log /var/log/nginx/example.com-access.log;
error_log /var/log/nginx/example.com-error.log;
```

Add to logrotate config:
```bash
/var/log/nginx/example.com-*.log {
    daily
    rotate 7
    # ... rest of config
}
```

### Conditional Rotation (by size)

Only rotate if file is large enough:

```bash
/var/log/nginx/*.log {
    daily
    rotate 14
    size 10M      # Only rotate if file is >10MB
    maxage 30     # But delete anything older than 30 days regardless
    # ... rest of config
}
```

### Custom postrotate Script

```bash
postrotate
    # Custom script after rotation
    /usr/local/bin/analyze-logs.sh

    # Upload to S3
    aws s3 cp /var/log/nginx/*.gz s3://my-bucket/logs/

    # Send metrics
    curl -X POST https://metrics.example.com/log-rotated

    # Signal nginx
    if [ -f /var/run/nginx.pid ]; then
        kill -USR1 $(cat /var/run/nginx.pid)
    fi
endscript
```

### Separate Config for Development

```bash
# /etc/logrotate.d/nginx-dev
/var/log/nginx/*.log {
    hourly        # More frequent for debugging
    rotate 24     # Keep 24 hours
    nocompress    # Don't compress (easier to read)
    missingok
    notifempty
    create 0640 nginx adm
}
```

## Best Practices

✅ **Test before deploying** - Use `logrotate -d` to test
✅ **Keep error logs longer** - Useful for debugging
✅ **Compress old logs** - Saves significant disk space
✅ **Monitor disk usage** - Set up alerts for low disk space
✅ **Verify rotation works** - Check after first deployment
✅ **Use dateext** - Easier to find logs by date
✅ **Set appropriate retention** - Balance between disk space and debugging needs
✅ **Don't rotate too frequently** - Hourly rotation creates many files

## Disk Space Estimation

Example calculation for access logs:

```
Traffic: 1000 req/s
Log line: ~200 bytes
Daily log size: 1000 * 200 * 86400 = ~17GB/day uncompressed

With gzip compression (~10:1):
Daily compressed: ~1.7GB/day

With 14-day retention:
Total disk usage: ~24GB (1 uncompressed + 13 compressed)
```

## Related Documentation

- [Logrotate Manual](https://linux.die.net/man/8/logrotate)
- [Nginx Logging Documentation](https://nginx.org/en/docs/syslog.html)
- [Nginx Reopen Signal](https://nginx.org/en/docs/control.html)
