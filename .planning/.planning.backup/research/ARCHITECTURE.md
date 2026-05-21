# Architecture Patterns — v2.0 GUI & New Features

**Domain:** ERP/CRM Desktop + Web PWA
**Researched:** 2026-05-18

## Recommended Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Clients                           │
│  ┌──────────────────┐   ┌────────────────────────┐  │
│  │  QML Desktop App  │   │   Web PWA (improved)   │  │
│  │  (Qt 6.7+)        │   │   (HTML/JS/CSS)        │  │
│  │  - QtCharts        │   │   - Chart.js           │  │
│  │  - QRestAccessMgr  │   │   - WebSocket (live)   │  │
│  │  - System tray     │   │   - IndexedDB cache    │  │
│  └────────┬─────────┘   └────────────┬───────────┘  │
└───────────┼──────────────────────────┼──────────────┘
            │ REST API (JSON)          │ REST + WS
            ▼                          ▼
┌─────────────────────────────────────────────────────┐
│              Haskell Backend (existing)               │
│  ┌─────────┐ ┌──────────┐ ┌──────────────────────┐  │
│  │  Auth    │ │  RBAC    │ │   API Endpoints       │  │
│  │  (JWT)   │ │          │ │   /api/v2/*           │  │
│  └─────────┘ └──────────┘ │   - Dashboard KPI      │  │
│                            │   - CRM (contacts,    │  │
│  ┌──────────────────────┐  │     deals, pipeline)  │  │
│  │  EventStore          │  │   - Reports            │  │
│  │  (audit trail)       │  │   - Orders             │  │
│  └──────────────────────┘  │   - Documents          │  │
│                            │   - Notifications      │  │
│  ┌──────────────────────┐  │   - Integrations       │  │
│  │  WebSocket           │  └──────────────────────┘  │
│  │  (real-time push)    │                            │
│  └──────────────────────┘                            │
└─────────────────────────────────────────────────────┘
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| QML Desktop | Login, dashboard, CRM forms, charts | REST API (QRestAccessManager) |
| Web PWA | Same features via browser | REST API + WebSocket |
| API Server | All business logic | Database, EventStore |
| Dashboard Service | KPI aggregations, chart data | DB (SQL aggregates) |
| CRM Service | Contacts, companies, deals | DB (new tables) |
| Notification Service | Email + desktop push | SMTP, WebSocket |
| Integration Service | Bank feeds, external APIs | External HTTP APIs |

### Data Flow

```
QML/Web → login(JWT) → API Gateway → RBAC check → Service → DB → Response → Client
                                          ↓
                                     EventStore (audit)
                                          ↓
                                    WebSocket broadcast (live updates)
```

## Patterns to Follow

### Pattern 1: Qt OpenAPI Client Generator
**What:** Auto-generate QML-friendly REST clients from OpenAPI specification using `qt6_add_openapi_client`
**When:** All QML <-> API communication
**Example:** Expose generated `ColorsApi`/`UsersApi` as QML singletons via `QML_FOREIGN` macro

### Pattern 2: QRestAccessManager + QNetworkRequestFactory
**What:** Factory-based REST requests with automatic JSON serialization
**When:** Custom QML REST calls not covered by OpenAPI generator
**Example:** Set base URL once, call `get("/api/v2/dashboard/kpi")` with lambda callback

### Pattern 3: WebSocket Live Dashboard
**What:** Server pushes KPI updates via WebSocket, client updates charts reactively
**When:** Real-time dashboard data
**Existing:** WebSocket infrastructure from v1.0

### Pattern 4: Offline-First PWA
**What:** Cache dashboard data in IndexedDB, sync when online
**When:** Web PWA dashboards

## Anti-Patterns to Avoid

### Anti-Pattern 1: Direct DB access from QML
**Why bad:** Security risk, breaks separation of concerns
**Instead:** All data through REST API with JWT auth

### Anti-Pattern 2: Heavy chart rendering on main thread
**Why bad:** Blocks UI, poor UX
**Instead:** Use qtchartjs (CPU render via QuickJS) or WebWorker for web

### Anti-Pattern 3: Polling instead of WebSocket
**Why bad:** Wasted bandwidth, stale data
**Instead:** WebSocket push + optimistic UI updates

## Scalability Considerations

| Concern | Current (v1.0) | With v2.0 |
|---------|----------------|-----------|
| API endpoints | ~20 REST endpoints | ~40+ (add CRM, dashboard, orders, reports) |
| Concurrent QML clients | 0 (new) | 5-50 desktop clients |
| Real-time updates | WebSocket basic | Dashboard + notification broadcasts |
| PDF generation | None | Server-side generation |
| External API integrations | None | 3-5 integration connectors |

## Sources

- [Qt REST client blog (Qt 6.7)](https://qt.io/blog/restful-client-applications-in-qt-6.7-and-forward)
- [Qt OpenAPI generator](https://doc.qt.io/qt-6/qtopenapi-colorpalette-example.html)
- [CRM Data Architecture Best Practices](https://www.getcargo.ai/blog/crm-data-architecture-best-practices)
