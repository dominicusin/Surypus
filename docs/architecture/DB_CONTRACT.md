# Database Contract

> Surypus ERP/CRM
> Generated: 2026-09-02

## Overview

The database contract ensures that SQL migrations are consistent with the domain contract defined in `dsl/schema.yaml`. Every table, constraint, and migration must be verifiable against the domain model.

## Schema Mapping

### Entity-to-Table Mapping

| Domain Entity | SQL Table | Migration File |
|---------------|-----------|----------------|
| PersonEntity | person | aggregate/V012__person_aggregate.sql |
| CustomerEntity | customer | aggregate/V013__customer_aggregate.sql |
| ProductionOrderEntity | production_order | aggregate/V014__production_order_aggregate.sql |
| ReportConfigEntity | report_config | aggregate/V015__report_config_aggregate.sql |
| InventoryEntity | inventory | aggregate/V001__inventory_aggregate.sql |
| BillEntity | bill | aggregate/V002__bill_aggregate.sql |

### Constraints

| Constraint Type | Location | Verification |
|----------------|----------|-------------|
| Primary Key | All entity tables | `PRIMARY KEY` clause |
| Foreign Key | Cross-reference tables | `REFERENCES` clause |
| Unique | Identifiers | `UNIQUE` constraint |
| Check | Status, type fields | `CHECK` constraint |
| Not Null | Mandatory fields | `NOT NULL` clause |

## Migration Ordering

Migrations use the standard format: `V{number}__{description}.sql`

- Aggregate migrations: `sql/aggregate/V*.sql`
- Core migrations: `sql/core/`
- Event migrations: `sql/event/`
- Procedure migrations: `sql/procedures/`
- Policy migrations: `sql/policy/`
- Projection migrations: `sql/projection/`
- Seed migrations: `sql/seeds/`
- Service migrations: `sql/service/`
- Test migrations: `sql/test/`

## Contract-to-SQL Verification

Every entity in `dsl/schema.yaml` must have:
1. A corresponding migration file
2. Table name matching `sql_table` in schema
3. All mandatory fields (`nullable: false`) as `NOT NULL` columns
4. All identifiers as `UNIQUE` or `PRIMARY KEY`

## Drift Detection

```bash
# Check for schema vs SQL drift
python3 tools/documentation/generate-inventory.py
# Compare entities against migration files
grep -r "CREATE TABLE" sql/aggregate/ | grep -v "/*" | sort
```

## SQL Assertions

### Primary/Foreign/Unique/Check Constraints

Each migration file must include explicit assertions for:
- Primary key definition
- Foreign key references
- Unique constraints
- Check constraints for validation

### Migration Ordering Test

Migrations must be applied in version order:
- V001 → V002 → ... → V015+
- No gaps in version numbers
- No duplicate version numbers

### Idempotent Migration Behavior

All migrations must be idempotent:
- Running a migration twice produces the same result
- `IF NOT EXISTS` clauses for tables
- `IF NOT EXISTS` clauses for constraints

## Frozen State

The `sql/frozen/` directory contains verified, frozen migration files that must not change.

## Test Coverage

SQL tests are located in `sql/tests/contract/` and `sql/test/`.
