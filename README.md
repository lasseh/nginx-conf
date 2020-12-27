# Webhuset NGiNX Config
## Structure
```tree
├── default-nginx-conf
├── nginx.conf
├── nginx.d
│   ├── buffers.conf
│   ├── filecache.conf
│   ├── gzip.conf
│   ├── logformat.conf
│   ├── mime.types
│   ├── tcp.conf
│   └── timeouts.conf
├── prefabs.d				// For inclusion in sites
│   ├── acme-challenge.conf
│   ├── general-wordpress.conf
│   ├── global-restrictions.conf
│   ├── site-static.conf
│   ├── stub-status.conf
│   ├── tls-header-hsts.conf
│   ├── tls-intermediate.conf
│   ├── tls-modern.conf
│   └── tls-old.conf
├── sites-available			// Available sites
│   ├── defaults-443.conf
│   ├── defaults-80.conf
│   ├── redirect.example.com.conf
│   └── www.wordpress.example.conf
└── sites-enabled			// Contains symlinks to sites in sites-available
    └── defaults-80.conf 		
```
