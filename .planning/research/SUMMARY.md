# Research Summary: Surypus ERP/CRM v2.0

**Domain:** ERP/CRM Desktop + Web PWA
**Researched:** 2026-05-18
**Overall confidence:** HIGH (Qt ecosystem well-documented, CRM patterns mature)

## Executive Summary

Surypus v2.0 adds a QML Desktop UI and major new feature areas (Dashboard, CRM, Reports, Orders, Notifications, Documents, Integrations) to the existing Haskell backend. The architecture follows a strict REST API boundary — QML and Web PWA are independent clients consuming the same endpoints. Qt 6.7+ provides mature REST client tooling (QRestAccessManager, OpenAPI generator, qtchartjs for Chart.js charts in QML), eliminating the need for a web view inside the desktop app. The CRM module should be designed with pipeline stages and probability forecasting from day one, not just CRUD forms. Dashboard queries require materialized views for performance. Both UIs share the same API, which simplifies testing but demands careful UX parity management.

## Key Findings

**Stack:** Qt 6.7+ (QRestAccessManager, OpenAPI Generator, qtchartjs) for QML Desktop. Chart.js + WebSocket for Web PWA. Existing Haskell backend extended with new endpoints.

**Architecture:** Strict REST API boundary. QML Desktop: QRestAccessManager + OpenAPI generated clients. Web PWA: Fetch API + WebSocket. Backend: new services for CRM, Dashboard KPI, Notifications, Integrations.

**Critical pitfall:** CRM without pipeline design = useless CRM. Must model stages, probabilities, and forecasting. QML ↔ Haskell FFI is a trap — always use REST.

## Implications for Roadmap

Based on research, suggested phase structure:

1. **Dashboard Core** — First because it visualizes existing data (revenue, stock). Establishes KPI query patterns and chart rendering for both UIs. Avoids pitfall #4 (materialized views from start).
2. **CRM Data Model** — Contacts, companies, deals with pipeline stages (5-7). New DB tables, CRUD API, pipeline forecasting. Must avoid pitfall #1 (pipeline logic from day one).
3. **QML Desktop Skeleton** — Login, navigation, dashboard view. Vertical slice proving the QML → REST API → Haskell flow. Avoids pitfall #2 (FFI trap).
4. **Notifications** — Email + desktop push. User preferences table. Avoids pitfall #5 (spam prevention).
5. **Reports** — Financial + inventory reports. Server-side PDF generation. Avoids pitfall #8 (client-side PDF).
6. **Purchase/Sales Orders** — New module, full CRUD + workflow.
7. **Document Workflow** — PDF export, document lifecycle.
8. **Integrations** — Banking feeds, external APIs. Adapter pattern. Avoids pitfall #6.
9. **Web PWA Polish** — Offline support, IndexedDB caching, responsive improvements. Avoids pitfall #10.

**Phase ordering rationale:** Dependencies drive order — Dashboard needs existing data (no new tables), CRM needs new tables, QML needs API endpoints, Notifications need user model, Reports need financial data, Orders need CRM contacts, Documents need orders, Integrations need API maturity.

**Research flags for phases:**
- Phase 2 (CRM): Likely needs deeper research on pipeline stage design for target industry
- Phase 8 (Integrations): Bank-specific research needed per country
- Phase 4 (QML): Well-documented Qt patterns, unlikely to need research

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Qt 6.7+ docs, official examples, active development |
| Features | MEDIUM | CRM pipeline best practices well-documented, but industry-specific |
| Architecture | HIGH | REST API boundary proven pattern, EventStore/WebSocket existing |
| Pitfalls | MEDIUM | Qt/Haskell specific pitfalls from experience; CRM pitfalls from industry analysis |

## Gaps to Address

- CRM pipeline stage design needs user input (B2B vs B2C, sales cycle length)
- Bank integration protocols (OFX, ISO 20022, SEPA) need country-specific research
- Qt version available on target OS (Ubuntu LTS Qt version vs Qt 6.7 requirement)
