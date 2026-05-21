# Technology Stack — v2.0 GUI & New Features

**Project:** Surypus ERP/CRM
**Researched:** 2026-05-18

## Recommended Stack

### QML Desktop UI
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Qt 6.7+ | ≥6.7 | Desktop UI framework | Modern QRestAccessManager/QNetworkRequestFactory for REST, QML + C++ bridge, OpenAPI client generator |
| QRestAccessManager | Qt 6.7+ | REST client for QML/C++ | Reduces boilerplate by ~40%, native JSON support, streaming text decoding |
| Qt OpenAPI Generator | Qt 6.x | Auto-generate REST clients from OpenAPI spec | Type-safe API calls, signal-based responses, QML singleton exposure |
| qtchartjs | 0.x (GitHub) | Chart.js in QML (CPU render) | 8 chart types, real-time streaming, no WebEngine needed, MIT license |
| QtCharts | Qt 6.5+ | Native Qt charts | Graphics View Framework, QWidget/QML types, production-ready |

### Web PWA
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Chart.js | 4.x | Web dashboard charts | Lightweight, well-supported, used by Odoo analytics |
| WebSocket | — | Real-time updates | Existing in v1.0, extend for dashboard live data |
| IndexedDB | — | Offline-first PWA data | Local caching for dashboards and CRM |

### Backend (existing Haskell stack)
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Hasql | 1.10 | PostgreSQL driver | Existing in v1.0 |
| Scotty/Servant | — | REST API | Existing — will extend with new endpoints |
| PostgreSQL 16+ | 16 | Database | Existing, add new tables for CRM, analytics |

### New Backend Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Chart/analytics SQL | — | Aggregation queries for dashboards | Dashboard/Reports |
| Email/SMTP | — | Email notifications | Notification system |
| Banking API lib | — | OFX/ISO 20022/SEPA | Bank integrations |
| PDF generation | — | Document generation | Document workflow |

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| QML Charts | qtchartjs + QtCharts | Custom Canvas render | More effort, less feature-rich |
| Web charts | Chart.js | D3.js, Plotly | Steeper learning curve, heavier |
| Desktop UI framework | Qt 6.7+ | Electron | Electron is heavier, Qt more native + Haskell FFI potential |
| QML REST | QRestAccessManager | Manual XMLHttpRequest in JS | Boilerplate, error-prone |

## Installation Notes

- Qt 6.7+ required for QRestAccessManager (Tech Preview in 6.7, stable in 6.8+)
- qtchartjs requires CMake 3.21+, C++17, Qt Quick module
- OpenAPI generator requires Qt 6.x and cmake function `qt6_add_openapi_client`

## Sources

- [Qt REST client blog (Qt 6.7)](https://qt.io/blog/restful-client-applications-in-qt-6.7-and-forward)
- [Qt OpenAPI ColorPalette example](https://doc.qt.io/qt-6/qtopenapi-colorpalette-example.html)
- [qtchartjs GitHub](https://github.com/code-brew-studio/qtchartjs)
- [Qt Charts documentation](https://doc.qt.io/qt-6.5/qtcharts-index.html)
- [Qt REST guide](https://www.learnqt.guide/qt-rest-additions_qt-6-7)
