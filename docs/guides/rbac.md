# How RBAC Works

## Overview

Surypus implements Role-Based Access Control (RBAC) for multi-tenant operations.

## Core Concepts

- **Tenant** — an isolated organizational unit (company, department)
- **Role** — a named set of permissions (e.g., `Admin`, `Accountant`, `Manager`)
- **Permission** — a fine-grained action right (e.g., `bill:create`, `report:view`)
- **User** — an authenticated person assigned one or more roles
- **Policy** — a rule that evaluates whether a user-action-resource tuple is allowed

## RBAC Module Structure

```text
Surypus.RBAC
├── Types        -- RBAC types (Role, Permission, Policy)
├── Store        -- Persistent RBAC storage operations
├── Evaluator    -- Policy evaluation engine
└── SelfHeal     -- Automatic RBAC consistency repair
```

## Permission Model

Permissions follow the pattern `resource:action`:

| Permission | Description |
|------------|-------------|
| `bill:create` | Create new bills |
| `bill:approve` | Approve bills |
| `report:view` | View financial reports |
| `admin:users` | Manage users and roles |
| `inventory:adjust` | Adjust inventory counts |

## Policy Evaluation

```haskell
-- | Check whether a user is authorized for an action on a resource.
--
-- >>> canUser (User "alice" [Role "Accountant"]) "bill:create" "bill:123"
-- True
canUser :: User -> Permission -> ResourceId -> Bool
```

## Tenant Isolation

Each tenant has its own namespace:

```text
Tenant: acme-corp
├── Roles: Admin, Accountant, Manager
├── Users: alice (Accountant), bob (Admin)
└── Resources: bills.*, reports.*
```

## Self-Healing

The RBAC self-heal module (`rbac_self_heal_incremental.sql`) automatically:

1. Detects orphaned roles (no users assigned)
2. Detects missing permissions on existing roles
3. Detects inconsistent policy assignments
4. Generates repair SQL statements

## Related Modules

- `Surypus.RBAC.Store` — persistent storage
- `Surypus.RBAC.Types` — type definitions
- `Surypus.JWT` — authentication integration

## See Also

- [Architecture: Security](../ARCHITECTURE.md)
- [Database: RBAC schema](../DATABASE.md)
