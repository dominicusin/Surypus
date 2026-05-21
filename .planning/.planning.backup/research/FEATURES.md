# Feature Landscape — v2.0 GUI & New Features

**Domain:** ERP/CRM Desktop + Web PWA
**Researched:** 2026-05-18

## Table Stakes

Features users expect. Missing = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Dashboard with KPIs | Every ERP has a home dashboard | Med | Revenue, orders, stock, pending tasks |
| Real-time chart updates | Users expect live data | Med | WebSocket push to both QML and web |
| CRM contact management | Core CRM feature | Low | Contacts, companies, deals pipeline |
| Document export (PDF) | Print/email documents | Low | Bills, invoices, reports as PDF |
| Email notifications | Standard for alerts | Low | SMTP integration |
| Dashboard filters (date range) | Analytics 101 | Low | Date picker, period comparison |
| Responsive web PWA | Mobile access expected | Med | Existing PWA needs polish |

## Differentiators

Features that set product apart.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| QML Desktop + Web PWA dual UI | Use on desktop or browser seamlessly | High | Shared REST API, separate frontends |
| Haskell-verified accounting | Formal verification of financial reports | Med | LiquidHaskell on report calculations |
| Event-sourced audit trail | Full history of all CRM changes | Med | Existing EventStore extended |
| Custom dashboard builder | User-configurable widgets/layouts | High | Drag-drop, per-user config |
| Bank feed integration | Auto-import transactions | Med | OFX/ISO 20022/SEPA |
| Push notifications to desktop | Real-time alerts without app open | Med | Qt system tray + native notifications |

## Anti-Features

Features to explicitly NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Embedded chat/messaging | Scope creep, existing tools better | Integrate with Slack/Telegram |
| Full email client | Not an email replacement | Basic email sending only |
| Office document editing | Google Docs/M365 already exist | PDF generation only |
| Custom CSS theming engine | Maintenance burden | Qt styles + CSS variables for web |

## Feature Dependencies

```
Auth/RBAC → Dashboard (needs user context)
Auth/RBAC → CRM (needs user context)
Inventory → Dashboard (needs stock data for KPI)
Bills/Accounting → Reports (needs financial data)
Dashboard (web) → WebSocket (live updates)
Notifications → User preferences (per-user config)
Integrations → REST API (all integrations use API)
QML Desktop → REST API (all data via API)
QML Desktop → Auth/RBAC (login first)
```

## MVP Recommendation

Prioritize by dependency order:

1. **Dashboard KPIs** (revenue, orders, stock counts — uses existing data)
2. **CRM contacts + pipeline** (new data model, core CRM)
3. **QML Desktop skeleton** (login, dashboard view connects to API)
4. **Notifications** (email + desktop push)
5. **Reports** (financial + inventory)
6. **Purchase/Sales orders** (new module)
7. **Document workflow** (PDF export)
8. **Integrations** (bank feeds, API)
9. **Dashboard builder** (customizable widgets)

Defer: Dashboard builder to v2.1
