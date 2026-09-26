#!/usr/bin/env bash
#
# validate.sh — offline nginx config validation.
#
# Runs a real `nginx -t` against every site template AND the combined
# nginx.conf entrypoint, without a deployed nginx or real certificates.
# It stages a throwaway copy of the repo, generates a self-signed cert +
# dhparam, rewrites the absolute paths the templates assume (/etc/nginx,
# /etc/letsencrypt, /var/log/nginx, /etc/ssl) to point into the staging
# area, then validates each config in isolation.
#
# Requirements: nginx (with http_v2 + http_v3), openssl. No root needed.
# Usage:        scripts/validate.sh
# Exit code:    0 if all sites pass, 1 otherwise (suitable for CI).
#
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX="${NGINX:-nginx}"

command -v "$NGINX"  >/dev/null 2>&1 || { echo "error: nginx not found (set \$NGINX)"; exit 2; }
command -v openssl   >/dev/null 2>&1 || { echo "error: openssl not found"; exit 2; }

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/nginx-validate.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
RUN="$STAGE/_run"
CERT="$RUN/certs/cert.pem"
KEY="$RUN/certs/key.pem"
DH="$RUN/certs/dhparam.pem"
mkdir -p "$RUN/certs" "$RUN/logs" "$RUN/tmp"

echo "Staging repo + generating test cert material..."
cp -R "$REPO/." "$STAGE/repo" 2>/dev/null
rm -rf "$STAGE/repo/.git"
cp -R "$STAGE/repo/." "$STAGE/" && rm -rf "$STAGE/repo"

openssl req -x509 -newkey rsa:2048 -nodes -keyout "$KEY" -out "$CERT" \
  -days 2 -subj "/CN=validate.local" >/dev/null 2>&1
openssl dhparam -out "$DH" 2048 >/dev/null 2>&1

# Rewrite absolute paths + relative includes across every staged config.
while IFS= read -r f; do
  sed -i.bak -E \
    -e "s#/etc/ssl/certs/dhparam.pem#$DH#g" \
    -e "s#/etc/letsencrypt/live/[^/]+/privkey.pem#$KEY#g" \
    -e "s#/etc/ssl/private/[^; ]+#$KEY#g" \
    -e "s#/etc/letsencrypt/live/[^/]+/[A-Za-z]+\.pem#$CERT#g" \
    -e "s#/etc/ssl/certs/[A-Za-z0-9_.-]+\.(crt|pem)#$CERT#g" \
    -e "s#/etc/ssl/certs/[A-Za-z0-9_.-]+\.key#$KEY#g" \
    -e "s#ssl_stapling_verify[[:space:]]+on#ssl_stapling_verify off#g" \
    -e "s#include[[:space:]]+(snippets/)#include $STAGE/\1#g" \
    -e "s#include[[:space:]]+(conf.d/)#include $STAGE/\1#g" \
    -e "s#include[[:space:]]+(sites-security/)#include $STAGE/\1#g" \
    -e "s#/etc/nginx/#$STAGE/#g" \
    -e "s#/var/log/nginx/#$RUN/logs/#g" \
    -e "s#^([[:space:]]*server[[:space:]]+)[a-z][a-z0-9-]*:([0-9]+)#\1127.0.0.1:\2#" \
    "$f" && rm -f "$f.bak"
done < <(find "$STAGE" -path "$RUN" -prune -o -name '*.conf' -print)

PASS=0; FAIL=0; FAILED=()

# http_master FILE TLS BODY — write a standalone nginx.conf loading every
# conf.d file (TLS profile selectable: the two set the same directives).
http_master() {
  local pidfile; pidfile="$RUN/tmp/${1##*/}.pid"
  cat > "$1" <<EOF
pid $pidfile;
error_log $RUN/logs/error.log warn;
events { worker_connections 1024; }
http {
    include $STAGE/conf.d/mime.types;
    default_type application/octet-stream;
    include $STAGE/conf.d/logformat.conf;
    access_log $RUN/logs/access.log elk_json;
    include $STAGE/conf.d/headers.conf;
    include $STAGE/conf.d/maps.conf;
    include $STAGE/conf.d/security.conf;
    include $STAGE/conf.d/performance.conf;
    include $STAGE/conf.d/proxy.conf;
    include $STAGE/conf.d/$2;
    include $STAGE/conf.d/cloudflare.conf;
    include $STAGE/conf.d/security-monitoring.conf;
$3
}
EOF
}

run_test() {
  local label="$1" master="$2"
  local out; out=$("$NGINX" -t -p "$STAGE" -c "$master" 2>&1)
  if echo "$out" | grep -q "test is successful"; then
    PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m  %s\n' "$label"
  else
    FAIL=$((FAIL+1)); FAILED+=("$label"); printf '  \033[31mFAIL\033[0m  %s\n' "$label"
    echo "$out" | grep -E 'emerg|\[error\]' | sed 's/^/          /' | head -6
  fi
}

echo
echo "Per-site validation (each template in isolation):"
for site in "$STAGE"/sites-available/*.conf "$STAGE"/sites-enabled/*.conf; do
  [ -f "$site" ] || continue
  name=$(basename "$site")
  master="$RUN/tmp/master-$name"
  http_master "$master" tls-intermediate.conf "    include $site;"
  run_test "$name" "$master"
done

# Every snippet, included once in the context it documents — catches snippets
# no template uses (missing log_format, zone, variable, ...).
echo
echo "Snippets (each included once, with tls-modern.conf):"
master="$RUN/tmp/master-snippets.conf"
http_master "$master" tls-modern.conf "    server {
        include $STAGE/snippets/listen-https.conf;
        server_name snippets.test;
        ssl_certificate $CERT;
        ssl_certificate_key $KEY;
        root $RUN/tmp;
        include $STAGE/snippets/security-headers.conf;
        include $STAGE/snippets/deny-files.conf;
        include $STAGE/snippets/gzip.conf;
        include $STAGE/snippets/common-locations.conf;
        include $STAGE/snippets/static-files.conf;
        include $STAGE/snippets/error-pages.conf;
        include $STAGE/snippets/stub-status.conf;
        include $STAGE/snippets/php-fpm.conf;
        include $STAGE/snippets/security-monitoring.conf;
        include $STAGE/snippets/method-filter.conf;
        location /p/ {
            proxy_pass http://127.0.0.1:9;
            include $STAGE/snippets/proxy-headers.conf;
            include $STAGE/snippets/rate-limiting.conf;
        }
    }
    server {
        server_name redirect.test;
        include $STAGE/snippets/redirect-to-https.conf;
    }
    server {
        listen 127.0.0.1:8081;
        include $STAGE/snippets/error-pages-json.conf;
    }"
run_test "snippets/*.conf" "$master"

echo
echo "Combined entrypoint (nginx.conf -> sites-enabled/*):"
entry="$RUN/tmp/combined-nginx.conf"
sed -E -e 's/^user[[:space:]]+nginx;/# user nginx;/' \
       -e "s#^pid[[:space:]].*#pid $RUN/tmp/combined.pid;#" \
       "$STAGE/nginx.conf" > "$entry"
run_test "nginx.conf" "$entry"

echo
echo "Summary: $PASS passed, $FAIL failed"
[ "$FAIL" -gt 0 ] && { printf 'Failed: %s\n' "${FAILED[*]}"; exit 1; }
exit 0
