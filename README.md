# Surypus ERP/CRM

**Система управления предприятием нового поколения на Haskell с формальной верификацией**

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
- `DAL.Database` - Connection pool management (Hasql)
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
- Hasql 1.10 + PostgreSQL
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
