---
phase: 15-qml-desktop-skeleton
plan: 03
subsystem: frontend
tags: [qml, login, dashboard, navigation, apiclient]
dependency_graph:
  requires:
    - phase: 15-02
      provides: qml-api-client
  provides: [qml-login-flow, qml-dashboard-kpis, qml-api-integration]
  affects: [15-04, 16-notifications]
tech-stack:
  patterns: [callApi callback dispatcher pattern, StackView login-auth flow]
key-files:
  modified:
    - qml/Main.qml
    - qml/LoginPanel.qml
key-decisions:
  - "Keep header/footer as ApplicationWindow properties for layout consistency, StackView in content area"
  - "callApi callback map pattern replaces XMLHttpRequest for all 15+ API calls"
  - "ApiClient.authToken managed by C++ sidecar, not QML"
requirements-completed:
  - QML-01
  - QML-02
  - QML-03
metrics:
  duration: ~30min
  completed: 2026-05-19
---

# Phase 15 Plan 03: Login + Dashboard + Navigation Summary

**Replace all XMLHttpRequest calls with ApiClient singleton, implement credential-based login flow, and wire dashboard KPIs from live backend endpoints.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-05-19T09:30:00Z
- **Completed:** 2026-05-19T10:00:00Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- All 15+ `XMLHttpRequest` calls replaced with `callApi` callback dispatcher pattern using `ApiClient` singleton
- `LoginPanel.qml` rewritten to use `ApiClient.login()` with credential validation (non-empty check per T-15-08)
- `Main.qml` now uses `StackView` for login flow: LoginPanel on app launch, mainContentPage after successful auth
- Dashboard KPIs (`kpiRevenue`, `kpiOrders`, `kpiActiveGoods`, `kpiPartners`) fetched from `GET /api/v1/dashboard` and displayed in real StatCards
- Revenue trend chart uses `Repeater` with dynamic bars from `GET /api/v1/dashboard/revenue`
- Logout button with `ApiClient.logout()` returns user to login screen
- Loading indicator (BusyIndicator) shown while KPIs are being fetched

## Task Commits

1. **Task 1: Replace XMLHttpRequest with ApiClient** - `90fd984` (feat)
2. **Task 2: Implement credential-based login flow** - `aed60be` (feat)
3. **Task 3: Wire dashboard KPIs from real API endpoints** - `cd202b9` (feat)

## Files Created/Modified

- `qml/Main.qml` - Major refactoring: callApi helper, Connections block, StackView login flow, dashboard KPI wiring
- `qml/LoginPanel.qml` - Replaced XMLHttpRequest with ApiClient.login, added credential validation

## Decisions Made

- **callApi callback map pattern**: Used a `apiCallbacks` dictionary keyed by `method:path` to route ApiClient signals to the correct callback, avoiding verbose Connections blocks per endpoint
- **StackView for login flow**: ApplicationWindow header/footer remain visible during login; StackView in content area switches between LoginPanel and mainContentPage
- **Token management**: JWT stored in ApiClient C++ sidecar (not QML), injected automatically on all authenticated requests
- **loadInitialData()** called from LoginPanel's onLoginSucceeded handler, not from root-level Connections block (avoids double-load)

## Deviations from Plan

None - plan executed exactly as written.

### Threat Model Compliance

| Threat ID | Category | Status |
|-----------|----------|--------|
| T-15-08 | I (login flow) | ✅ LoginPanel validates non-empty username/password before calling ApiClient |
| T-15-09 | T (callApi helper) | ✅ Response data validated with type checks before display |
| T-15-10 | E (JSON.parse) | ✅ ApiClient handles JSON parsing natively; errors routed to onError callback |

## Issues Encountered

None.

## Next Phase Readiness

- All API calls now go through ApiClient singleton, ready for future backend integration
- Login flow and navigation are structurally complete — CRM, Goods, Documents pages work as contentStack pushes
- AppImage packaging (15-04) can bundle the completed QML app

---

*Phase: 15-qml-desktop-skeleton*
*Completed: 2026-05-19*
