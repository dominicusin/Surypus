---
phase: 13
name: Dashboard Core
wave: 1
depends_on: []
requirements: [DASH-01, DASH-02, DASH-03, DASH-04, DASH-05]
autonomous: true
---

# Plan: Dashboard Core — KPI Queries, Charts, and Real-Time Updates

## Overview

Implement the KPI dashboard backend (materialized views + REST API) and frontend rendering for both Web PWA (Chart.js) and QML Desktop (QtCharts). Create KPI-specific materialized views, expose `/api/v1/dashboard` endpoints, add WebSocket "dashboard" room, and render KPI cards + charts on both clients.

## Waves

### Wave 1: Backend — Materialized Views & API

#### Task 1.1: Create KPI materialized views

<read_first>
- sql/migrations/V179__cqrs_views.sql (existing mv_tenant_dashboard pattern)
- sql/migrations/V158__materialized_views_advanced.sql (mv_refresh_schedule pattern)
</read_first>

<action>
- Create `sql/migrations/V180__dashboard_kpi_views.sql`
- `mv_dashboard_revenue`: daily revenue aggregated by month (bill_total, bill_count, status)
- `mv_dashboard_orders`: order counts by status (draft, confirmed, shipped, received)
- `mv_dashboard_stock`: stock summary by location (total_qty, low_stock_count, zero_stock_count)
- `mv_dashboard_partners`: partner counts (suppliers, customers, total)
- Add all new MV to `refresh_all_mv()` function in V150

**SQL patterns:**
- Use `REFRESH MATERIALIZED VIEW CONCURRENTLY`
- Add unique indexes on each MV for concurrent refresh support
- Follow existing naming convention (`mv_dashboard_*`)
</action>

<acceptance_criteria>
- `V180__dashboard_kpi_views.sql` exists in sql/migrations/
- Contains 4 materialized views with unique indexes
- `refresh_all_mv()` function includes all 4 new views
</acceptance_criteria>

---

#### Task 1.2: Create dashboard API endpoints

<read_first>
- surypus-api/src/Surypus/API/Server.hs (route patterns)
- web/js/api.js §dashboard.stats (existing client-side declaration)
</read_first>

<action>
- Add `GET /api/v1/dashboard` endpoint returning KPI summary (revenue, orders, stock, partners)
- Add `GET /api/v1/dashboard/revenue` — revenue time-series data
- Add `GET /api/v1/dashboard/orders` — order status distribution
- Add `GET /api/v1/dashboard/stock` — stock level summary
- All endpoints return JSON, authenticated via JWT middleware
- Implement Hasql queries against new MV
- Add type definitions for Dashboard KPI response types
</action>

<acceptance_criteria>
- `GET /api/v1/dashboard` returns 200 + JSON with revenue, orders, stock, partners
- `GET /api/v1/dashboard/revenue` returns monthly revenue array
- `GET /api/v1/dashboard/orders` returns order counts by status
- `GET /api/v1/dashboard/stock` returns stock summary by location
- All endpoints return 401 without valid JWT
</acceptance_criteria>

---

#### Task 1.3: Add WebSocket "dashboard" room for real-time KPI updates

<read_first>
- src/Surypus/WebSocket.hs (room-based WS system)
- src/Surypus/WebSocket/Integration.hs (EventBus bridge)
</read_first>

<action>
- Register "dashboard" room in WebSocket room registry
- Create `broadcastKPIData` function that pushes KPI updates to dashboard room
- Connect `EventBus` to dashboard room (broadcast on bill create/update, stock change)
- Add periodic KPI refresh trigger (every 30s for non-critical KPIs)
</action>

<acceptance_criteria>
- "dashboard" room exists in WebSocket room registry
- KPI data is broadcast to dashboard room on relevant events
- Periodic refresh triggers every 30s for non-critical KPIs
- Existing inventory broadcasts continue to work unchanged
</acceptance_criteria>

---

### Wave 2: Web PWA — Chart.js Dashboard

#### Task 2.1: Add Chart.js to Web PWA

<read_first>
- web/index.html (SPA structure)
- web/js/app.js §renderDashboard (current hardcoded dashboard)
- web/css/style.css (existing styles)
</read_first>

<action>
- Add Chart.js CDN or npm dependency to web/index.html
- Replace hardcoded dashboard content in `renderDashboard()` with live API calls
- Render KPI cards: revenue (current + monthly), orders (by status), stock (total + low stock), partners (suppliers + customers)
- Render Chart.js charts:
  - Line chart: revenue trend (last 12 months)
  - Doughnut chart: order status distribution
  - Bar chart: stock by location
- Subscribe to WebSocket "dashboard" room for real-time updates
</action>

<acceptance_criteria>
- Dashboard loads KPI data from `/api/v1/dashboard/*` on page load
- Line chart shows revenue trend with date axis
- Doughnut chart shows order status with legend
- Bar chart shows stock levels with location labels
- KPI card values update in real-time when WebSocket push received
- Fallback polling every 30s if WebSocket disconnected
</acceptance_criteria>

---

#### Task 2.2: Dashboard responsive layout & offline caching

<read_first>
- web/css/style.css
- web/js/app.js
</read_first>

<action>
- Add CSS grid layout for KPI cards (4 columns desktop, 2 tablet, 1 mobile)
- Add chart container responsive sizing (100% width, auto height)
- Cache dashboard data in IndexedDB for offline access
- Show loading skeleton while data fetches
- Show error state if API unavailable
</action>

<acceptance_criteria>
- KPI cards display in 4-column grid on desktop, 2 on tablet, 1 on mobile
- Charts are full-width and resize with viewport
- Loading skeleton shown during API fetch
- Error message shown on API failure with retry button
- Cached data displays when offline (with "offline" indicator)
</acceptance_criteria>

---

### Wave 3: QML Desktop — Dashboard View

#### Task 3.1: Create QML dashboard view with QtCharts

<read_first>
- .planning/phases/surypus-13-dashboard-core/13-CONTEXT.md (decisions)
</read_first>

<action>
- Create `qml/DashboardView.qml` with:
  - Login flow (JWT auth, token storage in memory)
  - Navigation sidebar (Dashboard first, other modules stubs)
  - Dashboard page with KPI cards and QtCharts charts
- Use `QNetworkAccessManager` / `QRestAccessManager` for REST API calls
- Use `QtCharts` module for charts:
  - `QLineSeries` for revenue trend
  - `QPieSeries` for order status
  - `QBarSeries` for stock levels
- Subscribe to WebSocket "dashboard" room for updates
- Create `CMakeLists.txt` for QML app
</action>

<acceptance_criteria>
- `qml/DashboardView.qml` contains login, navigation, and dashboard
- Login authenticates via `/api/v1/auth/login` with JWT
- Dashboard fetches KPI data from `/api/v1/dashboard/*`
- Revenue line chart renders from API data
- Order status pie chart renders from API data
- Stock bar chart renders from API data
- Charts update on WebSocket push
- `CMakeLists.txt` builds QML app successfully
</acceptance_criteria>

---

## Verification Criteria

### must_haves
- All 5 DASH requirements implemented (DASH-01 through DASH-05)
- Web PWA dashboard loads with live data from API
- Chart.js renders revenue, orders, stock charts correctly
- WebSocket dashboard room broadcasts KPI updates
- QML dashboard view connects to API and renders QtCharts
- Materialized views refresh correctly via `refresh_all_mv()`

### nice_to_haves
- Offline caching with IndexedDB
- Responsive grid layout
- Loading skeletons and error states
- Date range filtering on dashboard
