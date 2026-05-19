# Roadmap v2.0 — GUI & New Features

## Phase 13: Dashboard Core

**Goal:** Implement backend KPI queries and chart rendering for both QML and Web UIs.

**Requirements:** DASH-01, DASH-02, DASH-03, DASH-04, DASH-05

**Success Criteria:**
- KPI queries use materialized views (performant)
- Charts render correctly in web (Chart.js) and QML (qtchartjs)
- Real-time WebSocket updates work for dashboard data
- Date range filters affect KPI values

---

## Phase 14: CRM Data Model

**Goal:** Implement contacts, companies, and deal pipeline with forecasting.

**Requirements:** CRM-01, CRM-02, CRM-03, CRM-04, CRM-05, CRM-06, CRM-07

**Success Criteria:**
- Contacts and companies CRUD works via API
- Deals progress through 5-7 pipeline stages
- Pipeline forecast shows probability-weighted revenue
- All CRM changes logged to EventStore

**Plans:** 5 plans in 5 waves

| Plan | Wave | Objective | Files | 
|------|------|-----------|-------|
| 14-01 | 1 | DB migrations + domain types | V182__crm_companies_contacts.sql, src/CRM/*.hs, Surypus.cabal |
| 14-02 | 2 | API CRUD for contacts/companies + fix stubs | surypus-api/src/Surypus/API/{CRM,Server}.hs |
| 14-03 | 3 | RBAC permissions + event sourcing | RBAC.hs, Authorization.hs, EventStore/CRM.hs, Server.hs |
| 14-04 | 4 | Pipeline forecast refresh + stage rules + history | CRM.hs, Server.hs |
| 14-05 | 5 | Domain + integration tests | test/Domain/CRMSpec.hs, test/Integration/CRMSpec.hs |

---

## Phase 15: QML Desktop Skeleton

**Goal:** First working QML Desktop application connected to backend.

**Requirements:** QML-01, QML-02, QML-03, QML-04, QML-05, QML-06

**Success Criteria:**
- Login flow works with JWT
- Dashboard shows KPIs fetched via REST API
- Navigation between modules works
- QRestAccessManager or OpenAPI client used for API calls
- App packages as AppImage

**Plans:** 4 plans in 3 waves

| Plan | Wave | Objective | Files |
|------|------|-----------|-------|
| 15-01 | 1 | Backend: Real JWT authentication (jose signing, auth middleware) | surypus-api/src/Surypus/JWT/Token.hs, Server.hs, surypus-api.cabal |
| 15-02 | 1 | QML: REST client layer (QRestAccessManager C++ wrapper, CMake build) | qml/api/ApiClient.qml, qml/CMakeLists.txt, qml/main.cpp |
| 15-03 | 2 | QML: Login flow, real dashboard KPIs, module navigation | qml/Main.qml, qml/LoginPanel.qml |
| 15-04 | 3 | Packaging: AppImage build script and desktop entry | packaging/AppImage/* |

---

## Phase 16: Notifications

**Goal:** Implement email and desktop push notification system.

**Requirements:** NOTIF-01, NOTIF-02, NOTIF-03, NOTIF-04

**Success Criteria:**
- Email notifications sent for configurable events
- Desktop push notifications work (Qt system tray)
- User can set notification preferences
- Digest mode sends daily/weekly summaries

---

## Phase 17: Reports

**Goal:** Financial and inventory reports with PDF export.

**Requirements:** RPT-01, RPT-02, RPT-03, RPT-04

**Success Criteria:**
- P&L and balance sheet reports generate correctly
- Inventory stock reports available
- PDF export works (server-side)
- LiquidHaskell verifies report calculations

---

## Phase 18: Purchase/Sales Orders

**Goal:** New purchase and sales order module.

**Requirements:** ORD-01, ORD-02, ORD-03, ORD-04

**Success Criteria:**
- Purchase orders with line items CRUD
- Sales orders with line items CRUD
- Orders have status workflow
- Inventory updates on order confirmation

---

## Phase 19: Document Workflow

**Goal:** Document generation and lifecycle management.

**Requirements:** DOC-01, DOC-02, DOC-03

**Success Criteria:**
- PDF generation works for bills and invoices
- Documents have lifecycle management
- All document operations via server-side generation

---

## Phase 20: Integrations

**Goal:** External system integration framework.

**Requirements:** INT-01, INT-02, INT-03, INT-04

**Success Criteria:**
- Bank statement import works (OFX/ISO 20022)
- Adapter pattern documented and working
- Integration health monitoring works
- REST API documented for external use

---

## Phase 21: Web PWA Polish

**Goal:** Offline support, responsiveness, and PWA features.

**Requirements:** PWA-01, PWA-02, PWA-03, PWA-04

**Success Criteria:**
- Dashboard works offline with IndexedDB cache
- UI is responsive on mobile, tablet, desktop
- Chart.js updates via WebSocket
- PWA is installable with manifest + service worker
