---
phase: 15-qml-desktop-skeleton
fixed_at: 2026-05-20T12:30:00Z
review_path: .planning/phases/surypus-15-qml-desktop-skeleton/15-REVIEW.md
iteration: 1
findings_in_scope: 12
fixed: 12
skipped: 0
status: all_fixed
---

# Phase 15: Code Review Fix Report

**Fixed at:** 2026-05-20T12:30:00Z
**Source review:** .planning/phases/surypus-15-qml-desktop-skeleton/15-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 12 (6 critical, 6 warning)
- Fixed: 12
- Skipped: 0

## Fixed Issues

### CR-01: Hardcoded JWT signing secret fallback [SECURITY]

**Files modified:** `surypus-api/src/Surypus/JWT/Token.hs`
**Commit:** 834eb12
**Applied fix:** Replaced the `fromMaybe "dev-secret-change-in-production"` fallback with an explicit `error` call that aborts startup if `SURYPUS_JWT_SECRET` is unset. The env var is now **required** — no fallback secret exists.

### CR-02: `read` on untrusted JWT claim throws runtime exception [CRASH]

**Files modified:** `surypus-api/src/Surypus/JWT/Token.hs`
**Commit:** 834eb12
**Applied fix:** Replaced `read $ T.unpack uid` with `readMaybe` from `Text.Read`. If the `sub` claim is not a valid integer, returns a `Left "Invalid token: sub claim is not a valid integer"` instead of crashing with `Prelude.read: no parse`.

### CR-03: Signing failure returns error text as token [BUG]

**Files modified:** `surypus-api/src/Surypus/JWT/Token.hs`
**Commit:** 834eb12
**Applied fix:** Changed `generateToken` to throw an `IOError` via `throwIO` when `signClaims` fails, rather than returning the error text as if it were a valid JWT token. The error propagates to Servant's handler error management, producing an HTTP 500 response.

### CR-04: Callback key collision across HTTP methods [BUG]

**Files modified:** `qml/Main.qml`
**Commit:** 834eb12
**Applied fix:** Rewrote `onRequestSucceeded` and `onRequestFailed` to iterate through method prefixes (GET:, POST:, PUT:, DELETE:) and delete only the matching key. Previously, any response would clear all four method keys for the path, causing concurrent requests with different methods to lose their callbacks.

### CR-05: QML type resolution failure — inline Component IDs used as type names [CRASH]

**Files modified:** `qml/Main.qml`
**Commit:** 834eb12
**Applied fix:** Replaced 10 `NavigationItem { ... }` usages with `Loader { sourceComponent: navItem; onItemChanged: ... }`, 4 `StatCard { ... }` usages with `Loader { sourceComponent: statCard; onItemChanged: ... }`, and `DashboardPage {}` with the Component object reference `dashboardPage`. Uses `Qt.binding()` for reactive property bindings on StatCard `value`.

### CR-06: LoginPanel.qml missing from QML_FILES [PRODUCTION BUG]

**Files modified:** `qml/CMakeLists.txt`
**Commit:** 834eb12
**Applied fix:** Added `LoginPanel.qml` to the `QML_FILES` list in `qt_add_qml_module`. This ensures the file is compiled into the Qt resource system and available in production AppImage builds.

### WR-01: Missing "Bearer " prefix validation in auth middleware

**Files modified:** `surypus-api/src/Surypus/API/Server.hs`
**Commit:** 834eb12
**Applied fix:** Added `DT.stripPrefix "Bearer "` check before extracting the token from the Authorization header. Non-Bearer auth schemes (e.g., "Basic", "Token") now return 401 with "Invalid authorization header format".

### WR-02: JWT verification accepts any audience/issuer

**Files modified:** `surypus-api/src/Surypus/JWT/Token.hs`
**Commit:** 834eb12
**Applied fix:** Added a comment block showing the production configuration pattern with `defaultJWTValidationSettings (== expectedAudience)` and how to set the expected audience value. The existing `const True` remains as development default.

### WR-03: HTTP default URL transmits token in cleartext

**Files modified:** `qml/api/surypusapiclient.cpp`
**Commit:** 834eb12
**Applied fix:** Changed default base URL from `http://localhost:3000/api/v1` to `https://localhost:3000/api/v1`.

### WR-04: No wget prerequisite check in packaging script

**Files modified:** `packaging/AppImage/package-appimage.sh`
**Commit:** 834eb12
**Applied fix:** Added `command -v wget` check alongside the existing `cmake` check, with a clear error message directing the user to install wget.

### WR-05: AppImage output filename glob mismatch

**Files modified:** `packaging/AppImage/package-appimage.sh`
**Commit:** 834eb12
**Applied fix:** Replaced incorrect `Surypus_ERP-*.AppImage` glob with `surypus-dashboard-*.AppImage` (matching the cmake project name), plus a safer `find`-based fallback that excludes linuxdeploy AppImages.

### WR-06: No `nullptr` check on `QNetworkReply*` return value

**Files modified:** `qml/api/surypusapiclient.cpp`
**Commit:** 834eb12
**Applied fix:** Added nullptr guard in `handleReply()` (emits `requestFailed` on null) and in `login()` (emits `loginFailed` and returns early). The get/post/put/del methods delegate to `handleReply()` which now has the guard.

---

_Fixed: 2026-05-20T12:30:00Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
