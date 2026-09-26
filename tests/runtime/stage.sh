#!/usr/bin/env bash
#
# stage.sh — turn the repo (mounted at /src) into a runnable /etc/nginx with
# EVERY site template enabled at once, all upstreams pointed at the echo stub,
# and self-signed certs at every path the templates reference.
#
# Runs inside the nginx:mainline container before nginx starts.
#
set -euo pipefail

SRC=/src
ETC=/etc/nginx
ECHO=echo:8080

rm -rf "${ETC:?}"/*
cp -R "$SRC"/nginx.conf "$SRC"/conf.d "$SRC"/snippets "$SRC"/sites-available \
      "$SRC"/sites-security "$SRC"/html "$SRC"/modules-enabled "$ETC"/
mkdir -p "$ETC"/sites-enabled /var/log/nginx /usr/share/nginx/html/letsencrypt
# The image symlinks access/error logs to stdout/stderr; Alloy needs real files.
rm -f /var/log/nginx/*.log

for site in "$ETC"/sites-available/*.conf; do
    ln -s "../sites-available/$(basename "$site")" "$ETC/sites-enabled/"
done

# Point every upstream member and literal proxy_pass address at the echo stub.
sed -i -E \
    -e "s#^([[:space:]]*server[[:space:]]+)[A-Za-z0-9_.-]+:[0-9]+#\1$ECHO#" \
    -e "s#(proxy_pass[[:space:]]+http://)[0-9.]+:[0-9]+#\1$ECHO#" \
    "$ETC"/sites-available/*.conf

# One self-signed cert/key, copied to every path the configs reference.
TMP=$(mktemp -d)
openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj "/CN=runtime.test" \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" >/dev/null 2>&1
grep -rhoE '^[[:space:]]*ssl_(certificate|certificate_key|trusted_certificate|dhparam)[[:space:]]+[^;]+' "$ETC" |
    awk '{print $1, $2}' | sort -u |
    while read -r directive path; do
        mkdir -p "$(dirname "$path")"
        case "$directive" in
            ssl_certificate_key) cp "$TMP/key.pem" "$path" ;;
            ssl_dhparam)         openssl dhparam -dsaparam -out "$path" 2048 >/dev/null 2>&1 ;;
            *)                   cp "$TMP/cert.pem" "$path" ;;
        esac
    done

# Document roots with a few files so static locations have something to serve.
grep -rhoE '^[[:space:]]*root[[:space:]]+[^;$]+' "$ETC"/sites-available |
    awk '{print $2}' | sort -u |
    while read -r root; do
        mkdir -p "$root"
        echo '<!doctype html><title>t</title>' > "$root/index.html"
        echo 'body{}' > "$root/style.css"
        echo '//' > "$root/app.js"
        echo 'User-agent: *' > "$root/robots.txt"
        : > "$root/favicon.ico"
    done

nginx -t
