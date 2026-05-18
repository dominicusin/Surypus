# Domain Pitfalls — v2.0 GUI & New Features

**Domain:** ERP/CRM Desktop + Web PWA
**Researched:** 2026-05-18

## Critical Pitfalls

### Pitfall 1: CRUD-only CRM (no pipeline logic)
**What goes wrong:** Building CRM as just CRUD forms without pipeline stages, probability forecasting, or deal progression tracking
**Why it happens:** Underestimating CRM domain complexity
**Consequences:** Useless "CRM" that no sales team will use
**Prevention:** Design pipeline stages, stage criteria, probability model, and forecasting from day one. 5-7 stages max.

### Pitfall 2: QML ↔ Haskell impedance mismatch
**What goes wrong:** Trying to call Haskell functions directly from QML via FFI
**Why it happens:** "Performance" concerns about REST overhead
**Consequences:** Tight coupling, brittle build, hard to debug
**Prevention:** Always QML → REST API → Haskell. Use OpenAPI generator for type safety. REST overhead is negligible (<10ms).

### Pitfall 3: Two UIs, one set of bugs
**What goes wrong:** QML and web UIs have different behavior for the same feature
**Why it happens:** Shared API but different rendering logic
**Consequences:** User confusion, double the testing effort
**Prevention:** API is the source of truth. UI-specific bugs are UI bugs. Test API separately, then each UI independently.

## Moderate Pitfalls

### Pitfall 4: Dashboard query performance
**What goes wrong:** KPI queries scan millions of rows every 30 seconds
**Prevention:** Materialized views, aggregation tables, cache KPI results (TTL 1-5 min)

### Pitfall 5: Notification spam
**What goes wrong:** Every event triggers a notification → users disable all
**Prevention:** Per-user notification preferences, rate limiting, digest mode

### Pitfall 6: Bank integration fragility
**What goes wrong:** Bank API changes break integration silently
**Prevention:** Adapter pattern per bank, webhook health monitoring, integration tests

## Minor Pitfalls

### Pitfall 7: Over-engineering the dashboard builder
**What goes wrong:** Building drag-drop widget system before basic dashboards work
**Prevention:** MVP = hardcoded dashboard with KPIs. Dashboard builder = v2.1.

### Pitfall 8: PDF generation on client
**What goes wrong:** QML/web PDF generation is inconsistent across platforms
**Prevention:** Server-side PDF generation (Haskell library), serve as download

### Pitfall 9: QML app distribution
**What goes wrong:** No distribution plan for desktop app
**Prevention:** Plan ahead: AppImage (Linux), MSIX (Windows), DMG (macOS), or Qt Installer Framework

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Dashboard | Query performance | Materialized views + caching from phase 1 |
| CRM | Over-engineering pipeline stages | Start with 5 stages, iterate |
| QML Desktop | Build all features before showing | Ship login + dashboard first (vertical slice) |
| Notifications | No preference system | Build user notification prefs table first |
| Integrations | One-off adapters | Adapter pattern + webhook health |
| Documents | Client-side PDF | Server-side generation |
| Web PWA | Ignoring offline | IndexedDB cache plan from start |

## Sources

- [CRM Pipeline Design Best Practices](https://kynetto.com/crm-pipeline-design/)
- [CRM Data Architecture](https://www.getcargo.ai/blog/crm-data-architecture-best-practices)
- [Qt REST client patterns](https://qt.io/blog/restful-client-applications-in-qt-6.7-and-forward)
- [Qt OpenAPI generator example](https://doc.qt.io/qt-6/qtopenapi-colorpalette-example.html)
