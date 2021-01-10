# Webhuset NGiNX Config
## Structure
```tree
├── letsencrypt
│   ├── renew-ssl.sh
│   ├── ssl-available
│   │   └── example.com.ini
│   ├── ssl-enabled
│   └── www
├── nginx.conf
├── nginx.d
│   ├── buffers.conf
│   ├── defaults
│   │   ├── fastcgi.conf
│   │   ├── fastcgi_params
│   │   ├── koi-utf
│   │   ├── koi-win
│   │   ├── mime.types
│   │   ├── nginx.conf
│   │   ├── scgi_params
│   │   ├── uwsgi_params
│   │   └── win-utf
│   ├── filecache.conf
│   ├── gzip.conf
│   ├── logformat.conf
│   ├── mime.types
│   ├── tcp.conf
│   └── timeouts.conf
├── prefabs.d
│   ├── acme-challenge.conf
│   ├── general-wordpress.conf
│   ├── global-restrictions.conf
│   ├── site-static.conf
│   ├── stub-status.conf
│   ├── tls-header-hsts.conf
│   ├── tls-intermediate.conf
│   ├── tls-modern.conf
│   └── tls-old.conf
├── sites-available
│   ├── defaults-443.conf
│   ├── defaults-80.conf
│   ├── redirect.example.com.conf
│   ├── reverse-proxy.conf
│   ├── reverse-proxy_old.conf
│   ├── stub_status.conf
│   └── wordpress-example.conf
└── sites-enabled
    └── defaults-80.conf -> ../sites-available/defaults-80.conf	
```

## Acme
Create a letsencrypt/ssl-enabled/domain.com.ini config for every site with acme auto renew

#### /etc/crontab.d/acme
```sh
30 2 * * 1 /etc/nginx/letsencrypt/ssl-renew >> /var/log/ssl-renewal.log
```
