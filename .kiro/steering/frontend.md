---
inclusion: fileMatch
fileMatchPattern: ['**/*.qml', '**/*.tsx', '**/*.jsx', '**/components/**', '**/pages/**', '**/styles/**', '**/*.css', '**/*.scss', '**/web/**/*.js']
description: Frontend conventions (auto-loaded when working in UI code)
---
# Frontend Standards

## Two Frontends
- **QML Desktop** (`qml/`, `frontend/qml/`): Qt 6.7+, C++ bridge, CMake build
- **Web PWA** (`web/`): Vanilla JS + Chart.js, no framework

## QML Desktop
- API calls via `QRestAccessManager` (Qt 6.7+) — see `qml/main.qml`
- Auth: JWT stored in-memory, sent as `Authorization: Bearer <token>`
- Build: `cmake -B build && cmake --build build` in `qml/`
- Entry point: `qml/Main.qml` (75k lines — main app), `qml/main.qml` (10k — launcher)
- Components: `qml/components/Components.qml`

## Web PWA
- Entry: `web/index.html`, `web/js/app.js` (~40k lines)
- Styling: `web/css/style.css`
- Charts: Chart.js for all visualizations
- Real-time: WebSocket connection to `/ws` endpoint
- No build step — plain JS served statically

## Accessibility
- All interactive elements keyboard-accessible
- Semantic HTML, proper ARIA labels
- Color contrast meets WCAG AA

## API Integration
- Base URL: `http://localhost:8080/api/v1`
- Auth header: `Authorization: Bearer <jwt>`
- Error handling: check HTTP status, show user-friendly messages
