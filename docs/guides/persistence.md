# How Persistence Works

## Overview

Surypus uses PostgreSQL as its primary persistence layer, with stored procedures for heavy computations.

## Core Concepts

- **Migrations** — versioned SQL files in `sql/migrations/` (V000–V1005)
- **Stored Procedures** — business logic executed in PostgreSQL
- **Persistent** — type-safe ORM layer for Haskell
- **Esqueleto** — type-safe SQL builder

## Architecture

```text
Haskell Application
        │
        ├── persistent ──────► PostgreSQL tables
        ├── esqueleto  ──────► Type-safe SQL queries
        ├── raw SQL  ────────► Stored procedures
        └── migration ───────► Schema versioning
```

## Migration System

All database changes go through `sql/migrations/`:

| File | Description |
|------|-------------|
| `V001__initial_schema.sql` | Companies, persons, goods |
| `V002__goods.sql` | Inventory tables |
| `V003__bills.sql` | Bills and orders |
| `V004__accounting.sql` | Accounting tables |
| `V005__payroll.sql` | Payroll tables |
| `V006__jobs.sql` | Job scheduling |
| `V007__auth.sql` | Authentication |
| `V008__audit.sql` | Audit logging |
| `V009__rbac_store.sql` | RBAC tables |
| `V1005__payroll_results.sql` | Payroll results |

## Running Migrations

```bash
# Apply all pending migrations
psql -h localhost -U surypus -d surypus -f sql/migrations/init_db.sh

# Apply single migration
psql -h localhost -U surypus -d surypus -f sql/migrations/V009__rbac_store.sql
```

## Stored Procedures

Heavy computations live in PostgreSQL:

- `calc_vat()` — VAT calculation
- `calc_bill_totals()` — Bill total computation
- `get_lot_bounds()` — Lot boundary queries

## Related Modules

- `Surypus.DAL` — Database access layer
- `Surypus.Queries` — Query builders
- `Surypus.Mutations` — Mutation operations

## See Also

- [Database Documentation](../DATABASE.md)
- [Architecture](../ARCHITECTURE.md)
