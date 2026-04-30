# RBAC Canon Documentation

This document outlines the minimal RBAC Canon domain scaffolding and the intended DSL integration for migrations.

- Domain: Surypus.Domain.RBACCanon
- Core concepts: Canon, Roles, Permissions
- Persistence: SQL migrations under sql/migrations (DSL-like generation planned)

Migration plan sketch:
- V001__rbac_basic_schema.sql creates the core tables.
- V002+ adding indices and helper views as needed.

Notes:
- The current DSL is a thin wire-format to enable safe migration generation from Haskell domain types.
