# Surypus ERP/CRM

**Система управления предприятием нового поколения на Haskell с формальной верификацией**

## Quick Start

```bash
# Build project
stack build Surypus

# Run tests
stack test
```

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
- `Finance.Accounting` - General ledger
- `Finance.Ledger` - Journal entries
- `Finance.Tax` - Tax calculations

### API
- `Surypus.WebSocket` - Real-time notifications
- `Infrastructure.Encryption` - Password hashing

## Tech Stack
- Haskell (GHC 9.8.4)
- Hasql 1.10 + PostgreSQL
- Scotty/Servant REST API
- LiquidHaskell (optional verification)

## Status
Last autonomous cycle: 11/12 phases complete
