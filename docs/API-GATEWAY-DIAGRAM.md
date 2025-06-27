# API Gateway Architecture Diagram

## Request Flow Visualization

```
┌─────────────────┐    ┌──────────────────────────────────────────────────────────┐
│   Client Apps   │    │                    nginx API Gateway                     │
│                 │    │                  (api.example.com)                      │
│  • Web App      │    │                                                          │
│  • Mobile App   │────┤  ┌─────────────────────────────────────────────────────┐ │
│  • Third Party  │    │  │              Request Processing                     │ │
│                 │    │  │                                                     │ │
└─────────────────┘    │  │  1. Rate Limiting (per endpoint)                   │ │
                       │  │  2. CORS Headers                                    │ │
                       │  │  3. SSL Termination                                 │ │
                       │  │  4. Request Routing                                 │ │
                       │  │  5. Load Balancing                                  │ │
                       │  │  6. Health Checks                                   │ │
                       │  └─────────────────────────────────────────────────────┘ │
                       │                                                          │
                       │  ┌─────────────────────────────────────────────────────┐ │
                       │  │                Route Mapping                        │ │
                       │  │                                                     │ │
                       │  │  /auth/*      → Authentication Service             │ │
                       │  │  /users/*     → User Management Service            │ │
                       │  │  /orders/*    → Order Processing Service           │ │
                       │  │  /payments/*  → Payment Service                    │ │
                       │  │  /files/*     → File Upload Service                │ │
                       │  │  /analytics/* → Analytics Service                  │ │
                       │  │  /ws/*        → WebSocket Service                  │ │
                       │  │  /v1/*        → API Version 1                      │ │
                       │  │  /v2/*        → API Version 2                      │ │
                       │  └─────────────────────────────────────────────────────┘ │
                       └──────────────────────────────────────────────────────────┘
                                                    │
                       ┌────────────────────────────┼────────────────────────────┐
                       │                            │                            │
                       ▼                            ▼                            ▼
        ┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐
        │   Authentication        │  │   User Management       │  │   Order Processing      │
        │     Service             │  │      Service            │  │       Service           │
        │                         │  │                         │  │                         │
        │  • Node.js :3001        │  │  • Python :8001         │  │  • Go :8002             │
        │  • JWT tokens           │  │  • User profiles        │  │  • Order creation       │
        │  • Login/logout         │  │  • Settings             │  │  • Status tracking      │
        │  • Rate: 5 req/s        │  │  • Rate: 10 req/s       │  │  • Rate: 20 req/s       │
        └─────────────────────────┘  └─────────────────────────┘  └─────────────────────────┘

        ┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────────────────────┐
        │     Payment             │  │    File Upload          │  │     Analytics           │
        │     Service             │  │     Service             │  │      Service            │
        │                         │  │                         │  │                         │
        │  • Java :8003           │  │  • Node.js :3002        │  │  • Python :8004         │
        │  • Payment processing   │  │  • File uploads         │  │  • Event tracking       │
        │  • Refunds              │  │  • Download/delete      │  │  • Reports              │
        │  • Rate: 3 req/s        │  │  • Rate: 2 req/s        │  │  • Rate: 50 req/s       │
        └─────────────────────────┘  └─────────────────────────┘  └─────────────────────────┘
```

## Rate Limiting Strategy

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Rate Limiting Zones                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  auth_api:      5 req/s  (burst: 10)  ← Strict for security                   │
│  payment_api:   3 req/s  (burst: 5)   ← Very strict for financial ops         │
│  file_api:      2 req/s  (burst: 3)   ← Limited for resource usage            │
│  user_api:     10 req/s  (burst: 20)  ← Moderate for user operations          │
│  order_api:    20 req/s  (burst: 30)  ← Higher for business operations        │
│  analytics_api: 50 req/s (burst: 100) ← Permissive for data collection        │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Load Balancing Configuration

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            Upstream Configuration                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  upstream auth_service {                                                        │
│      server 127.0.0.1:3001 weight=3;     ← Primary server                     │
│      server 127.0.0.1:3011 weight=2;     ← Secondary server                   │
│      server 127.0.0.1:3021 backup;       ← Backup server                      │
│      keepalive 32;                        ← Connection pooling                 │
│  }                                                                              │
│                                                                                 │
│  upstream payment_service {                                                     │
│      server 127.0.0.1:8003;              ← Single server (high reliability)   │
│      keepalive 16;                                                              │
│  }                                                                              │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Security Layers

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                               Security Stack                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  1. SSL/TLS Termination                                                         │
│     ├── HTTP/3 with QUIC                                                       │
│     ├── TLS 1.2/1.3 only                                                       │
│     └── Perfect Forward Secrecy                                                │
│                                                                                 │
│  2. Rate Limiting                                                               │
│     ├── Per-endpoint limits                                                     │
│     ├── Burst handling                                                          │
│     └── DDoS protection                                                         │
│                                                                                 │
│  3. Security Headers                                                            │
│     ├── HSTS (2 years)                                                          │
│     ├── CSP (Content Security Policy)                                          │
│     ├── CORS (Cross-Origin Resource Sharing)                                   │
│     └── Anti-clickjacking                                                       │
│                                                                                 │
│  4. Request Validation                                                          │
│     ├── Body size limits                                                        │
│     ├── Timeout controls                                                        │
│     └── Header validation                                                       │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Monitoring & Observability

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            Monitoring Points                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  Health Checks:                                                                 │
│  ├── /health                    ← Gateway health                               │
│  ├── /status/auth               ← Auth service health                          │
│  ├── /status/users              ← User service health                          │
│  └── /status/orders             ← Order service health                         │
│                                                                                 │
│  Logging:                                                                       │
│  ├── Access logs (JSON format)                                                 │
│  ├── Error logs (structured)                                                   │
│  ├── Rate limiting events                                                       │
│  └── Upstream response times                                                    │
│                                                                                 │
│  Metrics:                                                                       │
│  ├── Request count per service                                                  │
│  ├── Response times (p50, p95, p99)                                            │
│  ├── Error rates                                                               │
│  ├── Rate limit hits                                                           │
│  └── SSL session reuse                                                         │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Example API Calls

```bash
# Authentication
curl -X POST https://api.example.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"user","password":"pass"}'

# User management
curl -X GET https://api.example.com/users/profile \
  -H "Authorization: Bearer <token>"

# Order creation
curl -X POST https://api.example.com/orders/create \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"product_id":123,"quantity":2}'

# Payment processing
curl -X POST https://api.example.com/payments/process \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"order_id":456,"amount":99.99}'

# File upload
curl -X POST https://api.example.com/files/upload \
  -H "Authorization: Bearer <token>" \
  -F "file=@document.pdf"

# Analytics event
curl -X POST https://api.example.com/analytics/events \
  -H "Content-Type: application/json" \
  -d '{"event":"page_view","page":"/dashboard"}'

# WebSocket connection
wscat -c wss://api.example.com/ws/notifications

# Health check
curl https://api.example.com/health
```