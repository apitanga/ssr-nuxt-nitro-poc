# Project Sketch: SSR Nuxt/Nitro PoC

**Folder**: `ssr-nuxt-nitro-poc/`  
**Created**: 2026-01-30  
**Status**: 🟡 Planning Complete → Ready to Scaffold

---

## Vision

A hands-on sandbox for exploring "cutting edge" serverless SSR architecture. The goal is deep understanding of primitives — not a product. Scale-to-zero compute, multi-region resilience, and avoiding vendor lock-in are core constraints.

---

## ✅ Decisions Made

| Decision | Choice | Date |
|----------|--------|------|
| Architecture | **Option A: CloudFront Origin Failover** | 2026-01-30 |
| App Functionality | **Server Clock + Weather Dashboard** | 2026-01-30 |
| Data Layer | **DynamoDB Global Tables** | 2026-01-30 |
| Primary Region | **us-east-1** (N. Virginia) | 2026-01-30 |
| DR Region | **us-west-2** (Oregon) | 2026-01-30 |

---

## Core Requirements

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Scale-to-zero | Must | True serverless — pay $0 when idle |
| Multi-region | Must | Active-active or hot standby across 2 regions |
| No Amplify | Must | Avoid lock-in; use native AWS primitives |
| SSR | Must | Server-side rendering, not static hosting |
| Learning Focus | Must | Architecture exploration over product features |

---

## Tech Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Framework | Nuxt 3 | Vue-based, Nitro engine, native Lambda preset |
| Rendering | Nitro | Compiles to Lambda handlers, handles cold starts |
| CDN | CloudFront | Edge caching + origin failover |
| Compute | Lambda (regional) | True scale-to-zero, full Nitro features |
| DNS | Route53 | Health checks + failover routing |
| Data | DynamoDB Global Tables | Active-active, serverless, scales to zero |
| Storage | S3 + CRR | Static assets replicated across regions |
| IaC | Terraform | Consistent with existing patterns, portable across accounts |
| Terraform Backend | Terraform Cloud | Remote state, locking, team collaboration |
| CI/CD | GitHub Actions | Native integration, OIDC support |
| Weather API | Open-Meteo or similar | Free, no key required for PoC |

---

## Architecture: Option A - CloudFront Origin Failover

```
                         Route53
                    (Health Checks)
                           │
                           ▼
              ┌─────────────────────┐
              │     CloudFront      │
              │   (Origin Group)    │
              └──────────┬──────────┘
                         │
            ┌────────────┴────────────┐
            │      Origin Group       │
            │  (Failover: 5xx/timeout)│
            └────────────┬────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ▼                │                ▼
┌───────────────┐       │       ┌───────────────┐
│   Primary     │◄──────┘──────►│      DR       │
│  us-east-1    │   (failover)  │   us-west-2   │
└───────┬───────┘               └───────┬───────┘
        │                               │
        ▼                               ▼
┌───────────────┐               ┌───────────────┐
│ Lambda +      │               │ Lambda +      │
│ Nitro (Nuxt)  │               │ Nitro (Nuxt)  │
└───────┬───────┘               └───────┬───────┘
        │                               │
        ▼                               ▼
┌───────────────┐               ┌───────────────┐
│  S3 Static    │◄─────────────►│  S3 Static    │
│   (CRR)       │ (replication) │   (CRR)       │
└───────────────┘               └───────────────┘
        │                               │
        └────────────┬──────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │ DynamoDB Global Tables │
         │   (active-active)     │
         └───────────────────────┘
```

### Request Flow

1. User requests `ssr-poc.pitanga.org`
2. Route53 health checks monitor both regions
3. CloudFront receives request, routes to Origin Group
4. Origin Group tries Primary (us-east-1) first
5. If Primary fails (5xx/timeout), automatic failover to DR
6. Lambda renders Nuxt app server-side
7. Weather API called based on user's IP/location
8. Response includes: server time, region, weather, visit counter
9. Counter incremented in DynamoDB Global Table

---

## App Features: Server Clock + Weather

### Core Features

| Feature | Purpose | Implementation |
|---------|---------|----------------|
| **Server Timestamp** | Prove SSR is working | `new Date()` rendered server-side |
| **Region Indicator** | Show which region served request | Lambda env var + response header |
| **Visit Counter** | Prove database persistence | DynamoDB atomic increment |
| **Weather Tile** | Make it fun/visual | IP geolocation → Open-Meteo API |
| **Failover Test** | Manual region failure simulation | Route53 health check override |

### UI Mockup

```
┌─────────────────────────────────────────┐
│  🌍 SSR Server Clock Dashboard          │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────┐  ┌─────────────────┐   │
│  │ ⏰ Server   │  │ 🌡️ Weather      │   │
│  │    Time     │  │                 │   │
│  │             │  │  ☀️ 72°F        │   │
│  │  2:34:56 PM │  │  New York, NY   │   │
│  │  UTC-5      │  │  Clear skies    │   │
│  └─────────────┘  └─────────────────┘   │
│                                         │
│  ┌─────────────┐  ┌─────────────────┐   │
│  │ 🌎 Region   │  │ 👥 Visit Count  │   │
│  │             │  │                 │   │
│  │ us-east-1   │  │    1,247        │   │
│  │ (N. Virginia)│  │   total visits  │   │
│  └─────────────┘  └─────────────────┘   │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │  🧪 Test Failover (Admin Only)      ││
│  │  [Simulate us-east-1 Failure]       ││
│  └─────────────────────────────────────┘│
│                                         │
└─────────────────────────────────────────┘
```

---

## Data Model

### DynamoDB Global Table: `ssr-poc-visits`

```
PK (Partition Key)  SK (Sort Key)      Attributes
──────────────────  ─────────────      ──────────
GLOBAL              COUNTER            count: number (atomic increment)
SESSION#<id>        METADATA           ip: string, region: string, 
                                       userAgent: string, timestamp: number
```

### Items

| PK | SK | Purpose |
|----|----|---------|
| `GLOBAL` | `COUNTER` | Global visit counter (atomic increment) |
| `SESSION#<uuid>` | `METADATA` | Per-session metadata (for analytics/debug) |

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | SSR dashboard (time, region, weather, count) |
| `/api/health` | GET | Health check for Route53 |
| `/api/counter` | POST | Increment visit counter |
| `/api/weather` | GET | Get weather by IP (server-side) |
| `/admin/failover` | POST | Trigger manual failover simulation |

---

## Success Criteria

- [ ] Nuxt 3 SSR rendering on Lambda
- [ ] CloudFront origin failover working (< 5 seconds)
- [ ] DynamoDB Global Tables replicating us-east-1 ↔ us-west-2
- [ ] Weather tile displays based on request IP geolocation
- [ ] Visit counter increments atomically
- [ ] True scale-to-zero (no Provisioned Concurrency in PoC)
- [ ] Terraform-managed infrastructure
- [ ] Documented cold start behavior
- [ ] Documented failover behavior
- [ ] Can manually trigger and observe failover

---

## Open Questions / Future Enhancements

- [ ] Use actual GeoIP service (MaxMind) vs simple IP mapping?
- [ ] Add WebSocket for "live" clock updates?
- [ ] Add authentication (Cognito) for admin failover controls?
- [ ] Add CloudWatch dashboard for monitoring?
- [ ] Compare cold start: Lambda vs Lambda@Edge vs Fargate?

---

## Related Context

- **Motivation**: Theme switcher issues in `vue-appsync` project — wanted true SSR, hit S3 static hosting limitations
- **Inspiration**: Want to understand Nitro on Lambda deeply
- **Constraint Parallels**: Similar to Fiserv requirements (resilience, scale, compliance)
- **Personal**: Andre Pitanga, Cloud Architect at Fiserv, Glen Ridge NJ

---

## Next Steps

1. ✅ Architecture decided (Option A)
2. ✅ App functionality defined (Server Clock + Weather)
3. ✅ Data layer chosen (DynamoDB Global Tables)
4. ✅ Terraform project structure with CI/CD user
5. ✅ Nuxt 3 app with Nitro Lambda preset
6. ✅ GitHub Actions CI/CD workflows
7. 🔄 Deploy infrastructure (includes CI/CD user creation)
8. 🔄 Retrieve CI/CD credentials from Secrets Manager
9. 🔄 Configure GitHub secrets
10. 🔄 Deploy single region (us-east-1) first
11. 🔄 Add DR region (us-west-2) and Global Tables
12. 🔄 Configure CloudFront origin failover
13. 🔄 Test failover behavior
10. 🔄 Document findings

---

## Notes

- Keep it simple — this is a learning exercise
- Document everything for future reference
- Weather API: https://open-meteo.com/ (free, no API key needed)
- IP Geolocation: Consider `ipapi.co` or MaxMind GeoLite2
