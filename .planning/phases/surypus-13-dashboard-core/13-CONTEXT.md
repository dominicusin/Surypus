# Phase 13: Dashboard Core - Context

**Gathered:** 2026-05-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement backend KPI queries and chart rendering for both QML Desktop and Web PWA dashboards. Create materialized views for KPI aggregation, REST API endpoints for dashboard data, and connect WebSocket for real-time updates.

Requirements: DASH-01, DASH-02, DASH-03, DASH-04, DASH-05

</domain>

<decisions>
## Implementation Decisions

### KPI Composition
- **D-01:** Dashboard shows revenue, orders (count/status), stock levels, and person/partner metrics
- **D-02:** KPIs displayed as cards with current value + trend indicator

### Chart Types
- **D-03:** Line charts for revenue trends and time-series data
- **D-04:** Bar charts for stock levels and categorical comparisons
- **D-05:** Doughnut/pie charts for order status distribution

### Real-time Strategy
- **D-06:** Hybrid approach — WebSocket push for critical KPI changes, periodic polling (30s) for non-critical data
- **D-07:** Existing WebSocket infrastructure extended with a "dashboard" room

### QML vs Web Charts
- **D-08:** QML Desktop uses QtCharts (native Qt charting module)
- **D-09:** Web PWA uses Chart.js (lightweight, well-supported)
- **D-10:** Both consume the same REST API endpoints — rendering is client-specific

### Materialized Views
- **D-11:** Hybrid strategy — use existing materialized views (mv_tenant_dashboard, v_dashboard, v_dashboard_advanced) where they fit
- **D-12:** Create new KPI-specific materialized views for metrics not covered by existing ones

### Claude's Discretion
- Dashboard layout structure (card grid, responsive breakpoints)
- Color scheme for charts (follow existing CSS variables)
- Specific SQL aggregation queries within the established Hasql patterns

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — DASH-01 through DASH-05 requirements
- `.planning/ROADMAP.md` §Phase 13 — Phase goal and success criteria

### WebSocket Infrastructure
- `src/Surypus/WebSocket.hs` — Core room-based WebSocket module
- `src/Surypus/WebSocket/Integration.hs` — EventBus bridge for broadcasting
- `surypus-api/src/Surypus/API/Server.hs` — Server integration with WS handler

### Existing Materialized Views
- `sql/migrations/V141__materialized_views.sql` — mv_aggregate_counts, mv_event_type_dist
- `sql/migrations/V150__advanced_analytics.sql` — mv_event_trends, mv_tenant_activity, refresh_all_mv()
- `sql/migrations/V158__materialized_views_advanced.sql` — mv_tenant_summary, mv_user_activity, mv_aggregate_health, mv_refresh_schedule
- `sql/migrations/V138__monitoring_dashboard.sql` — v_dashboard, v_active_sessions
- `sql/migrations/V172__monitoring_dashboard_advanced.sql` — v_dashboard_advanced, v_realtime_alerts, mv_performance_trends
- `sql/migrations/V179__cqrs_views.sql` — mv_inventory_state, mv_bill_state, mv_tenant_dashboard

### Existing API
- `surypus-api/src/Surypus/API/Server.hs` — Route definitions and pattern to follow
- `web/js/api.js` — Client-side API client (dashboard.stats() endpoint already declared)

### Web Frontend
- `web/js/app.js` §renderDashboard — Current hardcoded dashboard placeholder
- `web/css/style.css` — Existing CSS variables and chart bar styles

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- WebSocket room system: Can add "dashboard" room for real-time KPI push
- Materialized views: 7+ existing views with refresh scheduling infrastructure
- API patterns: Servant-based route definitions in Server.hs with Hasql DB access

### Established Patterns
- REST API at `/api/v1/` with JSON responses and JWT auth
- WebSocket broadcast for real-time events (already used for inventory)
- Hasql query patterns with Statement/Decoder/Encoder composition

### Integration Points
- New `/api/v1/dashboard` endpoints in Server.hs alongside existing routes
- WebSocket "dashboard" room for KPI broadcasts
- New materialized views alongside existing ones in sql/migrations/

</code_context>

<specifics>
## Specific Ideas

All KPI categories should be visible on initial dashboard load. Charts follow standard ERP dashboard conventions — nothing exotic.

</specifics>

<deferred>
## Deferred Ideas

- Custom dashboard builder (drag-drop widgets) — belongs in a later phase
- Mobile-specific dashboard layout — defer to PWA polish phase

</deferred>

---

*Phase: 13-Dashboard Core*
*Context gathered: 2026-05-18*
