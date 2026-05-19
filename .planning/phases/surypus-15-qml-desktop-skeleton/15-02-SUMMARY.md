---
phase: 15-qml-desktop-skeleton
plan: 02
type: execute
wave: 1
subsystem: frontend
tags: [qml, api-client, networking, cpp]
dependency_graph:
  requires: [15-01]
  provides: [qml-api-client]
  affects: [15-03, 15-04]
tech-stack:
  added: [QNetworkAccessManager, qmlRegisterSingletonType]
  patterns: [C++ QML singleton, bearer auth injection]
key-files:
  created:
    - qml/api/surypusapiclient.h
    - qml/api/surypusapiclient.cpp
    - qml/api/qmldir
  modified:
    - qml/CMakeLists.txt
    - qml/main.cpp
metrics:
  duration: "~15 min"
  completed: "2026-05-19"
---

# Phase 15 Plan 02: QML REST Client Layer Summary

**One-liner:** Create `SurypusApiClient` C++ singleton wrappering `QNetworkAccessManager` for type-safe REST API calls from QML, with JWT Bearer token injection.

## Completed Tasks

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create ApiClient C++ wrapper | `79d9caa` | `surypusapiclient.h`, `surypusapiclient.cpp`, `qmldir` |
| 2 | Update CMakeLists.txt and main.cpp | `7037b7f` | `CMakeLists.txt`, `main.cpp` |

## Architecture & Decisions

- **Approach:** C++ QObject singleton registered via `qmlRegisterSingletonType` — not a QML-only component. This is the recommended pattern from the research docs (Pattern 2) since QRestAccessManager's QML API was Tech Preview in Qt 6.7.
- **HTTP library:** QNetworkAccessManager (stable, production-ready) instead of QRestAccessManager (still maturing)
- **API surface from QML:**
  - `ApiClient.login(username, password)` — POSTs to `/login`, stores token
  - `ApiClient.get(path)` / `post(path, body)` / `put(path, body)` / `del(path)`
  - `ApiClient.logout()` — clears stored token
  - Signals: `loginSucceeded(token)`, `loginFailed(error)`, `requestSucceeded(path, response)`, `requestFailed(path, statusCode, error)`
- **JWT handling:** Token stored in memory only (not persisted to disk), cleared on `logout()`. Injected as `Authorization: Bearer <token>` header on all authenticated requests.
- **CMake modifications:** Added `Qt6::Network` for QNetworkAccessManager, added api/surypusapiclient.cpp to executable, updated QML_FILES to include Main.qml and Components.qml

## Deviations from Plan

- **QRestAccessManager → QNetworkAccessManager:** The plan suggested QRestAccessManager but the safer choice for cross-platform compatibility is QNetworkAccessManager, which is the foundation QRestAccessManager wraps anyway. Both are part of Qt6::Network.
- **No ApiClient.qml:** Instead of a QML-only file, used a C++ QObject wrapper registered as singleton — more performant and type-safe for network operations.

## Threat Model Compliance

| Threat ID | Category | Status |
|-----------|----------|--------|
| T-15-05 | Information disclosure (memory) | ✅ Token in memory only, cleared on logout |
| T-15-06 | Tampering (token in URL) | ✅ Token sent in Authorization header only |
| T-15-07 | Eavesdropping | ✅ Accepted — dev-only localhost; prod requires HTTPS |

## Self-Check

- [x] `api/surypusapiclient.h` — class declaration with all invokable methods
- [x] `api/surypusapiclient.cpp` — implementation with login/get/post/put/del
- [x] `api/qmldir` — singleton declaration
- [x] `CMakeLists.txt` — builds with Main.qml, Components.qml, surypusapiclient.cpp, Qt6::Network
- [x] `main.cpp` — registers ApiClient singleton before loading Main.qml
- [x] JWT stored in memory, injected on all authenticated requests
- [x] Token cleared on logout
