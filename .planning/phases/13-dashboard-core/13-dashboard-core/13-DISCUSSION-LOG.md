# Phase 13: Dashboard Core - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-18
**Phase:** 13-Dashboard Core
**Areas discussed:** KPI Composition, Chart Types, Real-time Strategy, QML vs Web Charts, Materialized Views

---

## KPI Composition

| Option | Description | Selected |
|--------|-------------|----------|
| Revenue only | Only financial KPIs | |
| All major KPIs | Revenue, orders, stock, persons | ✓ |
| Custom selection | User picks specific metrics | |

**User's choice:** All major KPIs
**Notes:** Wants full overview on dashboard — revenue, orders (count+statuses), stock levels, person/partner metrics

---

## Chart Types

| Option | Description | Selected |
|--------|-------------|----------|
| Lines only | Line charts for all metrics | |
| Per-metric | Different chart types per KPI | ✓ |
| Tables only | Tabular data, no charts | |

**User's choice:** Per-metric — lines for trends, bars for stock, doughnut for order statuses
**Notes:** Standard ERP dashboard convention

---

## Real-time Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| WebSocket push | Server pushes updates on change | |
| Periodic polling | Client fetches every N seconds | |
| Hybrid | WS for critical, polling for rest | ✓ |

**User's choice:** Hybrid (WebSocket + polling)
**Notes:** Existing WebSocket infra extended with dashboard room

---

## QML vs Web Charts

| Option | Description | Selected |
|--------|-------------|----------|
| Same lib both | qtchartjs for both | |
| Different | QtCharts (QML) + Chart.js (Web) | ✓ |
| Web only | No QML charts yet | |

**User's choice:** Different — QtCharts for QML Desktop, Chart.js for Web PWA
**Notes:** Both consume same REST API endpoints

---

## Materialized Views

| Option | Description | Selected |
|--------|-------------|----------|
| Existing only | Use current views, no new ones | |
| New only | Create fresh KPI views | |
| Hybrid | Existing + new as needed | ✓ |

**User's choice:** Hybrid — extend existing, create new where missing
**Notes:** 7 existing MV can be leveraged

---

## Claude's Discretion

- Dashboard layout grid structure and responsive breakpoints
- Chart color scheme (follow existing CSS variables)
- SQL aggregation query design within Hasql patterns

## Deferred Ideas

- Custom dashboard builder (drag-drop widgets) — future phase
- Mobile-specific dashboard layout — defer to PWA polish phase
