---
inclusion: always
description: Product context and goals
---
# Product Overview

## Purpose
Surypus is a formally-verified ERP/CRM system for SMB retail and wholesale businesses. It covers the full business lifecycle: inventory, finance/accounting, CRM, HR, production, logistics, and commerce.

Key differentiator: LiquidHaskell formal verification for financial calculations ensures correctness at the type level.

## Target Users
- Business owners and managers (dashboard, reports)
- Accountants (finance, accounting entries, bills)
- Warehouse managers (inventory, stock movements)
- Sales teams (CRM, deals, pipeline)
- HR managers (staff, payroll)

## Key Features
- **Inventory**: goods, locations, stock movements, FIFO projection
- **Finance/Accounting**: double-entry bookkeeping, bills, payments, tax
- **CRM**: contacts, companies, deal pipeline with forecasting, activities
- **HR**: staff, payroll, goals
- **Production**: production orders, BOM
- **Logistics**: receipts, transport
- **Commerce**: retail POS, loyalty, bonus points
- **Reports**: financial (P&L, balance sheet), inventory, PDF export
- **Integrations**: bank statements (OFX/ISO 20022), EDI, marketplace
- **Notifications**: email, desktop push (Qt system tray), digest mode

## Milestone v2.0 — GUI & New Features
Current active milestone. Phases 13–21:
- Phase 13: Dashboard Core ✅
- Phase 14: CRM Data Model (Waves 1-2 done)
- Phase 15: QML Desktop Skeleton (UI done)
- Phase 16–21: Notifications, Reports, Orders, Documents, Integrations, PWA Polish

## Success Metrics
- All financial calculations pass LiquidHaskell verification
- API response time < 200ms p95 under normal load
- QML desktop app packages as AppImage (Linux), MSIX (Windows), DMG (macOS)
- Test coverage: unit + property-based + integration for all domain modules
