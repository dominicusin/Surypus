# Domain Contract

> Surypus ERP/CRM
> Version: 1.0.0
> Generated: 2026-09-02

## Overview

The domain contract defines the canonical entities, refinements, and events that form the source of truth for the Surypus system. `dsl/schema.yaml` is the normative contract; Haskell domain types and generated code are derived from it.

## Contract Categories

### Entities

Entities defined in `dsl/schema.yaml` represent the core domain objects. Each entity maps to a PostgreSQL table with explicit field definitions.

| Entity | SQL Table | Fields | Nullable Fields |
|--------|-----------|--------|-----------------|
| PersonEntity | person | code, name, inn, kpp, personType, status | code, inn, kpp, status |
| CustomerEntity | customer | ... | ... |

**Rules:**
- Every entity must have a `name` and `sql_table` mapping.
- Fields with `nullable: false` are mandatory.
- Identifiers (`code`) must be unique within their entity type.

### Refinements

Refinements are constraints applied to entity fields:
- `type: Text` — string fields with optional length constraints
- `type: Int` — integer fields with optional min/max bounds
- `type: Decimal` — monetary values requiring precision specification

### Events

Domain events represent state changes:
- Event identity and ordering guarantees are defined per bounded context
- Events are immutable facts
- Event schemas derive from entity field changes

## Backward-Compatible Schema Changes

### Allowed (Non-breaking)
- Adding new optional fields (`nullable: true`)
- Adding new entities
- Adding new refinements to existing fields
- Extending enum values

### Restricted (Requires Migration)
- Adding new mandatory fields (`nullable: false`) — requires default value
- Changing field types — requires explicit migration path
- Removing fields — requires deprecation period

### Prohibited (Breaking)
- Renaming entities or fields without alias mapping
- Changing field nullability from `false` to `true` for mandatory fields
- Removing entities or fields without migration

## Schema Validation

All changes to `dsl/schema.yaml` must pass:
1. YAML schema validation
2. Entity uniqueness check (no duplicate entity names)
3. Field referential integrity (all referenced tables exist)
4. Type consistency check

## Test Contract

```haskell
-- test/Contract/SchemaSpec.hs
-- Validates schema.yaml against contract rules
main :: IO ()
main = do
    schema <- loadSchema "dsl/schema.yaml"
    validateEntities schema
    validateFieldUniqueness schema
    validateReferentialIntegrity schema
```
