# Surypus Project Structure

## Overview
This document describes the reorganized project structure after optimization.

## Directory Structure

```
Surypus/
├── app/                    # Entry point
│   └── Main.hs
├── config/                 # Configuration files
│   └── migrations/       # Database migrations
├── src/                    # Source code
│   ├── Core/              # Domain logic
│   │   ├── Services/      # Business logic services
│   │   ├── Accounting/
│   │   ├── Auth/
│   │   ├── HR/
│   │   ├── Inventory/
│   │   └── ...           # Other core modules
│   ├── DAL/              # Data Access Layer
│   │   ├── Repository/   # Repository modules
│   │   ├── Types.hs
│   │   ├── Queries.hs
│   │   ├── Mutations.hs
│   │   └── Procedures.hs
│   ├── DB/                # Alternative DB layer (used by JobQueue, Main)
│   ├── API/               # API handlers
│   │   ├── V1/          # API version 1 handlers
│   │   ├── Handlers/
│   │   └── Middlewares/
│   ├── Domain/            # Domain types
│   ├── Surypus/          # Utilities and helpers
│   │   ├── API/         # API utilities
│   │   ├── RBAC.hs
│   │   ├── JWT.hs
│   │   └── ...           # Other utilities
│   ├── System/           # System utilities
│   └── surypus-es/       # Event sourcing implementation
│       ├── Aggregates/
│       ├── Commands/
│       ├── Events/
│       └── ...
├── test/                  # Test suites
├── sql/                   # SQL files and migrations
│   ├── migrations/       # Database migrations (345 files)
│   ├── procedures/       # Stored procedures
│   ├── aggregate/        # Aggregate SQL
│   ├── event/            # Event store SQL
│   └── projection/       # Projection SQL
├── docs/                  # Documentation
├── scripts/               # Build and utility scripts
├── surypus-common/        # Common utilities library
├── surypus-api/          # API definitions
├── surypus-api-core/      # API core library
├── surypus-api-shim/      # API shim layer
└── surypus-frontend/      # Frontend code
```

## Key Changes Made

1. **Moved Service modules**: `src/Service/` → `src/Core/Services/`
2. **Updated module names**: `Service.*` → `Core.Services.*`
3. **Updated imports**: All imports updated to use new module paths
4. **Removed unused directories**: Integration/,  Prometheus/, Database/
5. **Moved documentation**: Markdown files from root → `docs/`
6. **Cleaned empty directories**
7. **Organized SQL files**: Moved root SQL files to `sql/archive/`

## Module Organization

- **Core**: Domain logic, business rules, calculations
- **Core/Services**: Business logic services that use DAL
- **DAL**: Data access layer with repositories
- **DB**: Alternative DB layer (used by specific modules)
- **API**: HTTP handlers, middleware, API types
- **Domain**: Domain types and data structures
- **Surypus**: Utilities, helpers, cross-cutting concerns
- **System**: System-level utilities

## Build Status

- ✅ Build passes
- ✅ All 154 tests pass
- ✅ No compilation errors

## Notes

- `src/DB/` and `src/DAL/` serve different purposes (different modules)
- `src/surypus-es/` contains event sourcing implementation
- The project uses Stack for building
- PostgreSQL is the database backend
