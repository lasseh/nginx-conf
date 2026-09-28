#!/usr/bin/env bash
#
# run.sh — behaviour tests for the enabled templates.
#
# Runs inside the nginx container (see compose.yaml) against 127.0.0.1, with
# every site enabled at once. Upstreams are the echo stub, whose response body
# lists the request headers nginx forwarded — so each test can check both what
# the client got back and what the backend received.
#
set -uo pipefail

PASS=0; FAIL=0
HDRS=$(mktemp); BODY=$(mktemp)
trap 'rm -f "$HDRS" "$BODY"' EXIT

# req HOST PATH [curl args...] — HTTPS request; fills $HDRS and $BODY.
req() {
    local host=$1 path=$2; shift 2
    CURRENT="https://$host$path $*"
    curl -sk --http1.1 -o "$BODY" -D "$HDRS" --resolve "$host:443:127.0.0.1" \
        "$@" "https://$host$path" | tr -d '\r' >/dev/null
    tr -d '\r' < "$HDRS" > "$HDRS.tmp" && mv "$HDRS.tmp" "$HDRS"
}

# req80 HOST PATH [curl args...] — plain HTTP request on port 80.
req80() {
    local host=$1 path=$2; shift 2
    CURRENT="http://$host$path $*"
    curl -s -o "$BODY" -D "$HDRS" --resolve "$host:80:127.0.0.1" \
        "$@" "http://$host$path" >/dev/null
    tr -d '\r' < "$HDRS" > "$HDRS.tmp" && mv "$HDRS.tmp" "$HDRS"
}

ok()   { PASS=$((PASS+1)); }
fail() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$CURRENT" "$1"; }

# Response header assertions (case-insensitive names, ERE on the value).
# check MESSAGE CMD... — pass if CMD succeeds.
check() { local msg=$1; shift; if "$@"; then ok; else fail "$msg"; fi; }
absent() { ! grep -qiE "$1" "$2"; }
dupes() { cut -d: -f1 | tr '[:upper:]' '[:lower:]' | grep -v '^$' | sort | uniq -d | tr '\n' ' '; }

status()   { check "status $(head -1 "$HDRS" | cut -d' ' -f2), want $1" grep -q "^HTTP/[0-9.]* $1" "$HDRS"; }
has()      { check "missing response header $1${2:+ ~ $2}" grep -qiE "^$1:.*${2:-}" "$HDRS"; }
lacks()    { check "unexpected response header $1" absent "^$1:" "$HDRS"; }
no_dupes() { local d; d=$(sed 1d "$HDRS" | dupes); check "duplicate response headers: $d" test -z "$d"; }

# Upstream (echo body) assertions: what nginx forwarded to the backend.
proxied()     { check "request did not reach the upstream" grep -qi '^host:' "$BODY"; }
up_has()      { check "upstream did not receive $1${2:+ ~ $2}" grep -qiE "^$1: .*${2:-}" "$BODY"; }
up_lacks()    { check "upstream received $1${2:+ ~ $2}" absent "^$1: ${2:-.*}" "$BODY"; }
up_no_dupes() { local d; d=$(dupes < "$BODY"); check "duplicate upstream headers: $d" test -z "$d"; }

# Baseline security headers every HTTPS response must carry.
secure() { has Strict-Transport-Security; has X-Content-Type-Options nosniff; has Alt-Svc 'h3='; no_dupes; }

echo "Runtime tests:"

# --- every template is served -------------------------------------------------
req your-app.com /;                          status 200; proxied
req your-docker-app.com /api/x;              status 200; proxied
req grafana.example.com /;                   status 200; proxied
req netbox.example.com /;                    status 200; proxied
req api.example.com /orders/1;               status 200; proxied

# --- response headers survive locations that add their own (C1) ------------
# Static site: every location sets Cache-Control, which used to drop Alt-Svc.
req your-static-site.com /;                  status 200; secure; has Cache-Control
req your-static-site.com /style.css;         status 200; secure; has Cache-Control immutable

# sites-security CSP/COEP must reach cached assets and HTML, not just the server block.
for p in / /index.html /robots.txt /favicon.ico /style.css; do
    req example-site.com "$p";               secure; has Content-Security-Policy; has Cross-Origin-Embedder-Policy credentialless
done
req example-site.com /health;                status 200; secure; has Content-Type application/json
req example-site.com /api/x -X OPTIONS -H 'Origin: https://a.test'
                                             status 204; secure; has Access-Control-Allow-Origin https://a.test; has Access-Control-Max-Age

# api./admin. subdomains: one value per header, even where they override the site policy.
req api.example-site.com /health;            status 200; secure; has Content-Type application/json
req api.example-site.com /x -X OPTIONS -H 'Origin: https://a.test'
                                             status 204; secure; has Access-Control-Allow-Origin https://a.test
req admin.example-site.com /;                status 200; secure; has X-Frame-Options DENY; has Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline';"

# api-gateway: server-level CORS on every route, including preflights and errors.
req api.example.com /payments/x -H 'Origin: https://a.test'
                                             status 200; secure; has Access-Control-Allow-Origin https://a.test
req api.example.com /users/1 -X OPTIONS -H 'Origin: https://a.test'
                                             status 204; secure; has Access-Control-Allow-Origin https://a.test
req api.example.com /health;                 status 200; secure; has Content-Type application/json; has X-API-Gateway
req api.example.com /nope;                   status 404; secure; has Content-Type application/json
# nginx-generated errors use snippets/error-pages-json.conf (html/errors/*.json).
req api.example.com /docs/nope;              status 404; secure; has Content-Type application/json
check "404 body is not the JSON error page" grep -q '"error"' "$BODY"
# Nested cache locations must still proxy (they used to serve from disk).
req api.example.com /users/a.json;           status 200; proxied; secure; has Cache-Control max-age=300
req api.example.com /analytics/reports/x;    status 200; proxied; secure; has Cache-Control max-age=900
# sites-security files carry headers only: JSON API routes and manifests are
# not caught by a stray `\.json$` deny.
req api.example-site.com /users/1.json;      status 200; proxied; secure
req example-site.com /manifest.json;         status 200; secure; has Content-Security-Policy
# Nested font location adds CORS only; Cache-Control comes from its parent once.
req example-site.com /font.woff2;            status 200; secure; has Access-Control-Allow-Origin; has Cache-Control immutable
# stub_status inside an HTTPS server with security headers: one X-Frame-Options.
req admin.your-load-balanced-app.com /nginx_status
                                             status 200; secure; has X-Frame-Options SAMEORIGIN
# Admin assets go to admin_app, not a static-files regex location.
req admin.example-site.com /app.js;          status 200; proxied; secure

# Preflights in if-blocks used to lose every CORS header set on the location.
req your-load-balanced-app.com /api/x -X OPTIONS -H 'Origin: https://a.test'
                                             status 204; secure; has Access-Control-Allow-Origin https://a.test
req your-docker-app.com /api/x -X OPTIONS -H 'Origin: https://a.test'
                                             status 204; secure; has Access-Control-Allow-Origin https://a.test
req80 dev.local /x -X OPTIONS -H 'Origin: https://a.test'
                                             status 204; no_dupes; has Access-Control-Allow-Origin https://a.test

# Server-level CSP must survive cache-header locations.
for p in / /login /public/x /avatar/x /style.css /health; do
    req grafana.example.com "$p";            secure; has Content-Security-Policy
done
req netbox.example.com /health;              status 200; secure; has Content-Type application/json
req librenms.example.com /health;            status 200; secure; has Content-Type application/json

# --- shared site skeleton (C5) -----------------------------------------------
# Port 80 redirects to the host the client asked for (was always the first
# server_name), keeping path and query.
for h in your-app.com www.your-app.com your-static-site.com www.example-site.com api.example-site.com \
         admin.example-site.com grafana.example.com netbox.example.com librenms.example.com api.example.com \
         foo.your-load-balanced-app.com foo.your-docker-app.com; do
    req80 "$h" '/p?q=1';                     status 301; has Location " https://$h/p\\?q=1$"
done
# Every HTTPS server blocks dotfiles and VCS metadata.
for h in your-app.com your-static-site.com example-site.com api.example-site.com admin.example-site.com \
         grafana.example.com netbox.example.com librenms.example.com api.example.com \
         your-load-balanced-app.com admin.your-load-balanced-app.com your-docker-app.com db.your-docker-app.com; do
    req "$h" /.git/config;                   status 403
    req "$h" /.env;                          status 403
done

# --- what upstreams receive (C2) --------------------------------------------
# Every proxied location: one of each forwarded header, and no
# `Connection: close` (which would defeat the upstream keepalive pool).
upstream_ok() { proxied; up_no_dupes; up_has X-Request-ID; up_has X-Forwarded-Host; up_lacks Connection close; }
for t in your-app.com:/ your-docker-app.com:/ your-docker-app.com:/api/x your-docker-app.com:/ws/x \
         db.your-docker-app.com:/ redis.your-docker-app.com:/ monitoring.your-docker-app.com:/ queue.your-docker-app.com:/ \
         grafana.example.com:/ grafana.example.com:/api/x grafana.example.com:/api/live/x grafana.example.com:/write \
         grafana.example.com:/public/x netbox.example.com:/ \
         api.example.com:/auth/x api.example.com:/users/1 api.example.com:/ws/x api.example.com:/v1/x \
         example-site.com:/api/x api.example-site.com:/auth/x api.example-site.com:/upload/x api.example-site.com:/ws/x \
         api.example-site.com:/ admin.example-site.com:/ admin.example-site.com:/api/x \
         your-load-balanced-app.com:/ your-load-balanced-app.com:/api/x your-load-balanced-app.com:/static/x \
         your-load-balanced-app.com:/ws/x; do
    req "${t%%:*}" "${t#*:}"; upstream_ok
done
for t in dev.local:/ dev.local:/ws/x dev.local:/vite-hmr dev.local:/storybook/ dev.local:/docs/ dev.local:/dev-tools/ \
         api.dev.local:/ storybook.dev.local:/ docs.dev.local:/; do
    req80 "${t%%:*}" "${t#*:}"; upstream_ok
done

# WebSocket handshakes are forwarded from any proxied location...
ws=(-H 'Upgrade: websocket' -H 'Connection: Upgrade')
for t in grafana.example.com:/api/live/x api.example.com:/ws/x your-app.com:/ example-site.com:/api/x; do
    req "${t%%:*}" "${t#*:}" "${ws[@]}"; up_has Upgrade websocket; up_has Connection upgrade; up_no_dupes
done
# ...but no other protocol upgrade (h2c smuggling).
req your-app.com / -H 'Upgrade: h2c' -H 'Connection: Upgrade'
                                             up_lacks Upgrade; up_lacks Connection upgrade

# --- monitoring: exporter and Alloy see this traffic (C3) --------------------
# Layer 1: the exporter (monitoring/prometheus/nginx-exporter.yml flags) can
# read stub_status on 127.0.0.1.
CURRENT="exporter http://127.0.0.1:9113/metrics"
curl -s http://127.0.0.1:9113/metrics > "$BODY"
check "nginx_up is not 1" grep -q '^nginx_up 1' "$BODY"

# Layer 2: Alloy turns every site's access log into the metric names the
# dashboard and alerts query. Logs are buffered (flush=5s), so poll.
req librenms.example.com /    # its only other request (/health) isn't logged
CURRENT="alloy http://alloy:12345/metrics"
sites=(your-app.com your-static-site.com example-site.com api.example-site.com admin.example-site.com
       grafana.example.com netbox.example.com librenms.example.com api.example.com
       your-load-balanced-app.com your-docker-app.com dev.local)
for _ in $(seq 60); do
    curl -s http://alloy:12345/metrics > "$BODY"
    missing=0
    for s in "${sites[@]}"; do grep -q "^nginx_http_requests_by_status_total{.*server_name=\"$s\"" "$BODY" || missing=1; done
    [ "$missing" -eq 0 ] && break
    sleep 1
done
for s in "${sites[@]}"; do
    check "no request metric for server_name=$s" grep -q "^nginx_http_requests_by_status_total{.*server_name=\"$s\"" "$BODY"
done
check "no duration histogram"  grep -q '^nginx_http_request_duration_seconds_bucket{' "$BODY"
check "no bytes counter"       grep -q '^nginx_http_response_bytes_total{' "$BODY"
# Only access logs may feed the counters; an error-log line has no status.
check "non-access-log lines counted (status_class=\"xx\")" absent 'status_class="xx"' "$BODY"

echo "Summary: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
