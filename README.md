# Surypus ERP/CRM

**Система управления предприятием нового поколения на Haskell с формальной верификацией**

## ✅ Verification & Test Stats

| Metric | Value |
|---|---|
| License | MPL-2.0 |
| Haskell modules | 486 |
| Test suites (Haskell) | 69 files in `test/` |
| Property-based tests | 3 — `Domain/HRPropertySpec`, `Domain/ProductionPropertySpec`, `Integration/PropertySpec` |
| Integration suites | 8 — CRUD, inventory lifecycle, negative paths, performance, pool, validation |
| SQL test scripts | 116 in `sql/test/` (of 511 SQL files total) |
| RBAC permissions | 33 |
| Formal verification | LiquidHaskell (optional), event-sourced audit trail |
| Toolchain | GHC 9.6.5 · Persistent 2.18 · Esqueleto 3.6 · PostgreSQL · Scotty |

**Milestone status:** v2.0 GUI & Features complete (Phases 13–21 ✅); infrastructure cycles Phases 160–171 ✅.
**Known debt:** `DAL/Queries.hs` type conversions pending fixes before full-suite DB test run.

## Quick Start

```bash
# Build project
stack build Surypus

# Run tests
stack test

# Run the API server
stack run
```

## API Documentation

Comprehensive API documentation is available in [API_DOCUMENTATION.md](API_DOCUMENTATION.md), including:
- Accounting API endpoints (ledgers, transactions, balances)
- Inventory API endpoints (goods, stock levels, movements)
- Tax API endpoints (rates, calculations)
- Reports API endpoints (balance sheet, income statement, inventory)
- Integration API endpoints (bank statement upload, health checks, status)

## Module Structure

### Core Modules
- `Surypus.CoreTypes` - Business types
- `Surypus.JWT` - Authentication tokens
- `Surypus.RBAC` - Role-based access control (33 permissions)

### Database Layer
- `DAL.Database` - Connection pool management (Persistent)
- `DAL.EventStore` - Event sourcing
- `DAL.Types` - Shared data types

### Inventory
- `Inventory.Goods` - Product catalog
- `Inventory.Stock` - Stock levels
- `Inventory.Location` - Warehouses

### Accounting
- `Finance.Accounting` - General ledger with transaction validation
- `Finance.Ledger` - Journal entries
- `Finance.Tax` - Tax calculations with VAT support

### API
- `API.Server` - Scotty web server with REST API endpoints
- `API.Integration.REST` - Integration API for bank statements
- `Surypus.WebSocket` - Real-time notifications
- `Infrastructure.Encryption` - Password hashing

### Reports
- `Reports.Report` - Report generation engine
- `Reports.Service` - Report service layer

## Tech Stack
- Haskell (GHC 9.6.5)
- Persistent 2.18 + Esqueleto 3.6 + PostgreSQL
- Scotty web framework
- Aeson for JSON serialization
- LiquidHaskell (optional verification)

## Recent Improvements

- **Phase 160-165**: Implemented Integration API, testing, Scotty web server, and API documentation
- **Phase 166-169**: Connected Accounting, Inventory, Tax, and Reports APIs to business logic modules
- **Phase 170**: Added comprehensive API integration tests
- **Phase 171**: Code cleanup and linting (replaced return with pure, removed redundant operators)

## Status
Last autonomous cycle: All planned infrastructure phases complete (Phases 160-171)

# Surypus – Canonical RBAC Refactor

Documentation:
- ARCHITECTURE: sql/docs/ARCHITECTURE.md
- RBAC canonicalization overview: sql/docs/RBAC_CANON.md
- Audit/logs: sql/docs/AUDIT.md

---

🔄 **Mirrors:** [![GitLab](https://img.shields.io/badge/GitLab-dominicusin-orange?logo=gitlab)](https://gitlab.com/dominicusin/Surypus) · GitHub is canonical.
