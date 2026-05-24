<!-- refreshed: 2026-05-24 -->
# Architecture

**Analysis Date:** 2026-05-24

## System Overview

Surypus is a formally verified ERP system written in Haskell. It uses a **layered monolith with event sourcing** architecture, organized around three vertical tiers (API, Service, Data) with horizontally-extended domain packages. The system is packaged as a Stack multi-package project with 6 cabal packages.

```text
┌─────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                            │
├──────────────────────┬──────────────────────┬───────────────────────┤
│   REST API (Servant) │   JSON API (Scotty)  │   WebSocket (STM)     │
│   `src/API/`         │   `API/Server.hs`    │   `Surypus/WebSocket` │
│   `surypus-api/`     │                      │                       │
└──────────┬───────────┴──────────┬───────────┴───────────┬───────────┘
           │                      │                       │
           ▼                      ▼                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       SERVICE / DOMAIN LAYER                         │
│                                                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ Finance  │  │ Inventory│  │ Commerce │  │ HR / CRM / Prod  │   │
│  │ 21 mods  │  │ 34 mods  │  │ 43 mods  │  │ 14+16+7 mods     │   │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────────┘   │
│                                                                    │
│  Service typeclass (`Service/Service.hs`)                          │
│  ServiceM = ReaderT Pool (ExceptT ServiceError IO)                  │
└─────────────────────────────────────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      DATA / INFRASTRUCTURE LAYER                    │
│                                                                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────────┐    │
│  │ DAL/     │  │ DAL/     │  │ Infrastructure/  │ Integration/ │    │
│  │ Database │  │EventStore│  │ Redis, WebSocket│ API, EDI, Hub│    │
│  │(Hasql)   │  │(Eventsrc)│  │ Backup, Files   │ External     │    │
│  └──────────┘  └──────────┘  └──────────┘  └────────────────┘    │
│                                                                    │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                  PostgreSQL (Dolt)                          │   │
│  │                  `config.yaml` port 34789                   │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| `Surypus` | Aggregator re-export for core modules | `src/Surypus.hs` |
| `Surypus.Core` | Exports DAL.Database, DAL.EventStore, WebSocket | `src/Surypus/Core.hs` |
| `Surypus.CoreTypes` | Core refined types (Decimal, NonNeg) | `src/Surypus/CoreTypes.hs` |
| `Surypus.JWT` | JWT token generation & validation | `src/Surypus/JWT.hs` |
| `Surypus.RBAC` | Role-based access control permissions | `src/Surypus/RBAC.hs` |
| `Surypus.WebSocket` | Real-time room-based event broadcasting | `src/Surypus/WebSocket.hs` |
| `Surypus.Metrics` | STM-based metrics counters & EKG integration | `src/Surypus/Metrics.hs` |
| `Surypus.Error` | Application error type hierarchy | `src/Surypus/Error.hs` |
| `Surypus.App.Main` | CLI entry point (RBAC migration generator) | `src/Surypus/App/Main.hs` |
| `API.Server` | Scotty-based integration REST server | `src/API/Server.hs` |
| `API.API` | API endpoint & log data types | `src/API/API.hs` |
| `DAL.Database` | Hasql PostgreSQL connection pool wrapper | `src/DAL/Database.hs` |
| `DAL.EventStore` | Event sourcing append/query with broadcast | `src/DAL/EventStore.hs` |
| `DAL.Types` | All ERP domain data types (965 lines) | `src/DAL/Types.hs` |
| `Service.Service` | Service typeclass & ServiceM monad | `src/Service/Service.hs` |
| `EventBus` | In-memory domain event bus with Kafka stub | `src/EventBus.hs` |
| `Core.Services.Accounting` | Core accounting read model & cache | `src/Core/Services/Accounting.hs` |
| `Infrastructure.hs` | Aggregator for infra modules | `src/Infrastructure.hs` |

## Pattern Overview

**Overall:** Layered monolith with event-sourcing substrate

**Key Characteristics:**
- **Haskell multi-package Stack project** — 6 cabal packages sharing types via `surypus-common`
- **Type-class based service architecture** — `Service` typeclass with `ServiceM` monad stack
- **Event sourcing** — `DAL.EventStore` provides event append/query with optional WebSocket broadcast
- **Wide domain surface** — 484+ source files across 30+ domain directories
- **Servant + Scotty dual API** — Servant for primary API, Scotty for integration endpoints
- **Dolt (PostgreSQL-compatible) database** — version-controlled SQL database via Dolt

## Layers

**Core Framework Layer (`src/Surypus/`):**
- Purpose: Shared primitives for the entire system
- Location: `src/Surypus/`
- Contains: CoreTypes, JWT, RBAC, WebSocket, Metrics, Error, Database.Pool, Refined validation, SQL generation DSL
- Depends on: `servant`, `jose`, `cryptonite`, `hasql`, `websockets`, `stm`
- Used by: All other layers and domain modules

**API / Transport Layer (`src/API/`, `surypus-api/`):**
- Purpose: HTTP surface — route definitions, middleware, request handling
- Location: `src/API/`, `surypus-api/src/Surypus/API/`, `surypus-api/src/Surypus/DAL/`
- Contains: Server, V1 routes, GraphQL proxy, integration REST, Auth middleware, Logger, Dashboard, CRM, Notifications, Reports, Orders, Bills, Payment, Persons, Goods, Classifiers, Workflow, AI
- Depends on: Core Framework, Domain modules
- Used by: HTTP clients, external systems

**Service / Domain Layer (`src/Finance/`, `src/Inventory/`, etc.):**
- Purpose: Business logic, domain types, aggregates
- Location: `src/Finance/` (21 mods), `src/Inventory/` (34 mods), `src/Commerce/` (43 mods), `src/HR/` (14 mods), `src/CRM/` (7 mods), `src/Production/` (16 mods), `src/Retail/` (6 mods), `src/Logistics/` (5 mods), `src/System/` (45+ mods), plus ~80 conceptual modules
- Contains: All business domain types, operations, state machines, validations
- Depends on: Core Framework, DAL types
- Used by: API layer, Service layer

**Service Monad Layer (`src/Service/`):**
- Purpose: Typed service orchestration with error handling
- Location: `src/Service/`
- Contains: `Service` typeclass, `ServiceM` monad stack (`ReaderT Pool (ExceptT ServiceError IO)`), InventoryService, BillService, CurrencyService, PayrollService, Workflow engine, Orchestrator, UI widgets
- Depends on: Domain modules, DAL
- Used by: API handlers

**Data Access Layer (`src/DAL/`):**
- Purpose: Database access, event store, repositories
- Location: `src/DAL/`
- Contains: Database pool wrapper (Hasql), EventStore (event sourcing), all shared types, DB query procedures, attachments, blockchain, documents, files, repository pattern
- Depends on: `hasql`, `hasql-pool`, `messagepack`, `cborg`
- Used by: Service layer, Core layer

**Infrastructure Layer (`src/Infrastructure/`):**
- Purpose: Pluggable infrastructure backends
- Location: `src/Infrastructure/`
- Contains: EventStore implementations (Accounting, Inventory, CRM), Redis TaskQueue, WebSocket InventoryBroadcast, FileStorage, Encryption (basic + advanced), Serializer, BackupManager, EmailSender, Notifications, Migration
- Depends on: Core Framework, DAL
- Used by: All layers above

**Integration Layer (`src/Integration/`, `src/External/`):**
- Purpose: External system integrations
- Location: `src/Integration/`, `src/External/`
- Contains: REST integration API, Webhook handling, EDI, Hub, BankStatement, Import/Export, Sync, Health; External systems: EGAIS, VETIS, Jasper, Pentaho, UHTT
- Depends on: API layer, Domain modules
- Used by: External systems

## Data Flow

### Primary Request Path (Servant API)

1. **HTTP Request arrives** — Warp server (`surypus-api/app/Main.hs`)
2. **Middleware applied** — CORS, logging (`Surypus.API.AuthMiddleware`, `Surypus.API.MetricsMiddleware`)
3. **JWT Authentication** — `Surypus.JWT.validateAccessToken` extracts user identity
4. **RBAC Authorization** — `Surypus.RBAC.requirePermissionChecked` checks permission against route
5. **Route handler** — Servant handler in `surypus-api/src/Surypus/API/` dispatches to domain logic
6. **Service operation** — `Service.ServiceM` monad runs via `ReaderT Pool (ExceptT ServiceError IO)`
7. **DAL query** — `DAL.Database.usePool` for Hasql queries via `DAL.Queries` or `DAL.Mutations`
8. **Event logging** — `DAL.EventStore.appendEvent` for event sourcing; optional WebSocket broadcast
9. **JSON response** — Aeson encoding returned via Servant handler

### Integration API Request Path (Scotty)

1. **HTTP Request** arrives at Scotty integration server (`src/API/Server.hs`)
2. **`API.Integration.REST.handleIntegrationRequest`** — dispatches to integration handlers
3. **Domain logic** — uses `Finance.Accounting`, `Inventory.Stock`, `Finance.Tax`, `Integration.BankStatement`
4. **Response** — JSON response returned

### Event Sourcing Flow

1. **Business operation** creates event via `DAL.EventStore.appendEvent`
2. **Event stored** in `event_store` table via Hasql
3. **Optional broadcast** — `appendEventBroadcast` invokes global WebSocket broadcaster
4. **WebSocket handler** — `Surypus.WebSocket.broadcastToRoom` publishes to subscribed rooms (inventory, dashboard, global)
5. **State replay** — `replayAccount` / `getEventsFrom` reconstructs aggregate state from event stream

### WebSocket Real-time Flow

1. **Client connects** — `Surypus.WebSocket.handleWebSocket` assigns unique key, joins "global" room
2. **Ping/keepalive** — 30-second ping thread
3. **Event broadcast** — `broadcastToRoom` delivers JSON-encoded events to all connections in room
4. **Rooms** — Global, inventory, dashboard — for scoped subscriptions
5. **Cleanup** — Disconnected clients removed via cleanup handler

**State Management:**
- Database state: PostgreSQL (Dolt) — the single source of truth
- Event sourcing: `event_store` table records all domain events with sequence numbers
- In-memory: WebSocket connections managed via STM `TVar (Map Text [(Int, WS.Connection)])`
- Metrics: STM `TVar` counters (httpRequestsTotal, httpRequestDuration, dbPoolConnections, jobQueueSize)
- Cache: Core accounting read model uses Redis cache (`Core/Accounting/RedisCache.hs`)
- Pool: Hasql-Pool manages database connection pool for concurrent access
- Event bus: In-memory `Chan` with optional Kafka publishing stub (`EventBus.hs`)
- Global state: `unsafePerformIO`-based `MVar` for WebSocket broadcaster (`DAL.EventStore`)

## Key Abstractions

**Service typeclass:**
- Purpose: Type-safe service interface with pool access
- File: `src/Service/Service.hs`
- Pattern: Typeclass with `ServiceM` monad (`ReaderT Pool (ExceptT ServiceError IO)`)

**Event type:**
- Purpose: Universal event for event sourcing
- File: `src/DAL/EventStore.hs`
- Fields: UUID, aggregateId, aggregateType, eventType, eventVersion, eventData (JSON), sequenceNumber, timestamps

**AppError type:**
- Purpose: Unified application error hierarchy
- File: `src/Surypus/Error.hs`
- Types: ValidationError, NotFoundError, ForbiddenError, ConflictError, DatabaseError, InternalError, AuthenticationError, AuthorizationError

**Permission type:**
- Purpose: Granular RBAC permission enumeration
- File: `src/Surypus/RBAC.hs`
- Pattern: ADT with 30+ constructors (PersonRead, GoodsWrite, etc.) mapped to `resource:action` text format

**WebSocketHandler:**
- Purpose: Room-based real-time event broadcasting
- File: `src/Surypus/WebSocket.hs`
- Pattern: STM-backed `TVar (Map Text [(Int, WS.Connection)])` with unique connection keys

**JWTConfig / TokenPair:**
- Purpose: JWT authentication with access + refresh tokens
- File: `src/Surypus/JWT.hs`
- Pattern: Development-grade JWT stub using simple hash-based tokens (production should use `jose` library)

## Entry Points

**API Server (Production):**
- Location: `surypus-api/app/Main.hs`
- Triggers: Warp run on port 3000
- Responsibilities: Starts Servant API server with Hasql database pool, logger

**Integration API Server (Scotty):**
- Location: `src/API/Server.hs` (`API.Server.runApp`)
- Triggers: Scotty run on configurable port
- Responsibilities: REST endpoints for accounting, inventory, tax, integrations, health

**RBAC Migration Generator:**
- Location: `src/Surypus/App/Main.hs`
- Triggers: Direct execution
- Responsibilities: Generates SQL migration files (V001-V040) for RBAC Canon schema

## Architectural Constraints

- **Threading:** Single-threaded event loop via Warp/Scotty; STM for shared state concurrency; Hasql-Pool for database connection pooling; `unsafePerformIO` for global broadcaster (`src/DAL/EventStore.hs:49-51`)
- **Global state:** Module-level `MVar` for WebSocket broadcaster in `DAL.EventStore` (`globalBroadcaster`); STM `TVar` for WebSocket connections in `Surypus.WebSocket`; STM `TVar` counters in `Surypus.Metrics`
- **Database migrations:** Generated programmatically from Haskell DSL (`src/Surypus/Infra/SqlGen/DSL.hs`) then written to `sql/migrations/` as `.generated.sql` files
- **Multi-package dependency chain:** `surypus-frontend` → `surypus-common` ← `surypus-api` ← `Surypus` (base library)

## Anti-Patterns

### Stub implementations masquerading as production code

**What happens:** Many core functions return stubs (e.g., `pure $ Right []` or `pure $ Right Nothing`) instead of real implementations. See `DAL.EventStore`, `Surypus.Database.Pool`, `Surypus.Metrics`, `Surypus.JWT`, `Surypus.API.AuthMiddleware`.
**Why it's wrong:** These modules have real-looking type signatures and documentation but do nothing — creating a false sense of completeness. Errors appear at runtime.
**Do this instead:** Mark stubs explicitly with `TODO` or separate into a `Stub` namespace. Consider using `error "Not implemented"` or `undefined` for compile-time protection against accidental use.

### Multiple evolving API server implementations

**What happens:** There are at least 3 API server implementations: `API.Server` (Scotty), `surypus-api/src/Surypus/API/Server.hs` (Servant), `Surypus.APIShim.Server` (shim wrapper). Each has its own entry point and route definitions.
**Why it's wrong:** Routes and behavior can diverge. Authentication, error handling, and middleware differ. Future developers don't know which one is canonical.
**Do this instead:** Consolidate to one server. Use `surypus-api/src/Surypus/API/Server.hs` (Servant) as the primary. Remove `API.Server` (Scotty) or relegate to a simple admin tool.

## Error Handling

**Strategy:** Monadic error handling via `ExceptT` in `ServiceM` stack; `Either Text` for DAL operations; generic `AppError` ADT with typed error cases; 403 thrown via Servant `throwError` in `requirePermissionChecked`.

**Patterns:**
- `ServiceM = ReaderT Pool (ExceptT ServiceError IO)` — service monad with typed errors
- `DAL.EventStore` functions return `IO (Either Text a)` for database operations
- `Surypus.RBAC` uses `Either Text ()` for permission checks, mapped to `Handler ()` with 403
- `AppError` discriminant with message + details for HTTP mapping

## Cross-Cutting Concerns

**Logging:** `fast-logger` via `Surypus.API.Logger`; `logStdoutDev` middleware for WAI; `putStrLn` used in some places
**Validation:** Smart constructors for refined types (`NonNeg`, `LedgerEntry`, `Transaction`); `validateTransaction` in `Finance.Accounting`; `Surypus.Validation` module
**Authentication:** JWT-based (`Surypus.JWT`); `Surypus.API.AuthMiddleware.withAuthzResolverAdvanced`; `Surypus.API.Authorization` module
**Metrics:** STM-based counters in `Surypus.Metrics`; ekg-core integration for `/metrics` endpoint
**Migration:** DSL-driven SQL generation (`Surypus.Infra.SqlGen.DSL`); programmatic migration generation in `Surypus.App.Main`; `Surypus.Domain.RBACCanon.Migration` for RBAC schema

---

*Architecture analysis: 2026-05-24*
