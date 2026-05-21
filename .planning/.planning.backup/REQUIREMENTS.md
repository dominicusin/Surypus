# Milestone v2.0 Requirements

## Dashboard & Analytics
- [ ] **DASH-01**: User can view KPI cards (revenue, orders, stock counts, pending tasks) on dashboard
- [ ] **DASH-02**: User can view charts (line, bar, pie) for key metrics
- [ ] **DASH-03**: Dashboard updates in real-time via WebSocket
- [ ] **DASH-04**: User can filter dashboard by date range
- [ ] **DASH-05**: KPI data sourced from materialized views for performance

## CRM
- [ ] **CRM-01**: User can manage contacts (create, edit, delete, search)
- [ ] **CRM-02**: User can manage companies (create, edit, delete, search)
- [ ] **CRM-03**: User can manage deals in a pipeline with 5-7 stages
- [ ] **CRM-04**: Deals progress through pipeline stages with entry/exit criteria
- [ ] **CRM-05**: User can view pipeline forecast (probability-weighted revenue)
- [ ] **CRM-06**: User can log activities (calls, meetings, notes) on contacts/deals
- [ ] **CRM-07**: All CRM changes are event-sourced for audit trail

## QML Desktop UI
- [ ] **QML-01**: User can login with JWT credentials
- [ ] **QML-02**: User sees dashboard with KPIs and charts
- [ ] **QML-03**: User navigates between modules (Dashboard, CRM, Reports, etc.)
- [ ] **QML-04**: QML app connects to REST API via Qt 6.7+ QRestAccessManager
- [ ] **QML-05**: QML app uses OpenAPI-generated client code where possible
- [ ] **QML-06**: Application runs as native desktop app (AppImage/MSIX/DMG)

## Notifications
- [ ] **NOTIF-01**: User receives email notifications for configurable events
- [ ] **NOTIF-02**: User receives desktop push notifications (Qt system tray)
- [ ] **NOTIF-03**: User can configure notification preferences per type
- [ ] **NOTIF-04**: Notifications support digest mode (daily/weekly summary)

## Reports
- [ ] **RPT-01**: User can generate financial reports (P&L, balance sheet)
- [ ] **RPT-02**: User can generate inventory reports (stock levels, movements)
- [ ] **RPT-03**: Reports are exportable to PDF (server-side generation)
- [ ] **RPT-04**: Report calculations are verified with LiquidHaskell

## Purchase/Sales Orders
- [ ] **ORD-01**: User can create purchase orders with line items
- [ ] **ORD-02**: User can create sales orders with line items
- [ ] **ORD-03**: Orders have status workflow (draft → confirmed → shipped → received)
- [ ] **ORD-04**: Orders link to inventory (stock updates on confirmation)

## Document Workflow
- [ ] **DOC-01**: User can generate PDF for bills, invoices, reports
- [ ] **DOC-02**: Documents have lifecycle (draft → finalized → archived)
- [ ] **DOC-03**: Document generation is server-side (Haskell library)

## Integrations
- [ ] **INT-01**: User can import bank statements (OFX/ISO 20022)
- [ ] **INT-02**: Integration adapters follow a pluggable adapter pattern
- [ ] **INT-03**: Integration health is monitored with alerts
- [ ] **INT-04**: REST API supports external system integration

## Web PWA Improvements
- [ ] **PWA-01**: Dashboard caches data in IndexedDB for offline access
- [ ] **PWA-02**: Web UI is fully responsive (mobile, tablet, desktop)
- [ ] **PWA-03**: Chart.js visualizations updated via WebSocket
- [ ] **PWA-04**: PWA supports installable (manifest + service worker)

---

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| DASH-01 | | |
| DASH-02 | | |
| DASH-03 | | |
| DASH-04 | | |
| DASH-05 | | |
| CRM-01 | | |
| CRM-02 | | |
| CRM-03 | | |
| CRM-04 | | |
| CRM-05 | | |
| CRM-06 | | |
| CRM-07 | | |
| QML-01 | | |
| QML-02 | | |
| QML-03 | | |
| QML-04 | | |
| QML-05 | | |
| QML-06 | | |
| NOTIF-01 | | |
| NOTIF-02 | | |
| NOTIF-03 | | |
| NOTIF-04 | | |
| RPT-01 | | |
| RPT-02 | | |
| RPT-03 | | |
| RPT-04 | | |
| ORD-01 | | |
| ORD-02 | | |
| ORD-03 | | |
| ORD-04 | | |
| DOC-01 | | |
| DOC-02 | | |
| DOC-03 | | |
| INT-01 | | |
| INT-02 | | |
| INT-03 | | |
| INT-04 | | |
| PWA-01 | | |
| PWA-02 | | |
| PWA-03 | | |
| PWA-04 | | |

## Out of Scope (v2.0)

- Dashboard builder (drag-drop widgets) — deferred to v2.1
- Full email client — out of scope
- Embedded chat/messaging — out of scope
- Mobile native app (iOS/Android) — out of scope
