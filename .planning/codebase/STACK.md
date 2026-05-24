# Technology Stack

**Analysis Date:** 2026-05-24

## Languages

**Primary:**
- Haskell (GHC) - All application source code (484 `.hs` files)

**Secondary:**
- Not detected - No other languages used in source

## Runtime

**Environment:**
- GHC (Glasgow Haskell Compiler) - Exact version not pinned (no `stack.yaml`, `cabal.project`, or `package.yaml` found)

**Package Manager:**
- Not detected - No `cabal`, `stack`, or `package.yaml` build configuration found in the repository
- Source-only layout — no dependency manifest checked in

## Frameworks

**Core Web:**
- **Servant** (`Servant` in `Surypus.RBAC` at `Surypus/RBAC.hs:18`) - Primary web framework for API handlers with typed endpoints
- **Scotty** (`Web.Scotty` in `API/Server.hs:9`) - Lighter-weight web framework used for the Integration API server
- **WAI** (`Network.Wai` in `Surypus/API/AuthMiddleware.hs:10`, `Surypus/API/MetricsMiddleware.hs:9`) - Web Application Interface layer

**Database Access:**
- **Hasql** (`Hasql.Pool`, `Hasql.Session`, `Hasql.Statement`, `Hasql.Decoders`, `Hasql.Encoders`) - PostgreSQL client library used throughout for database operations

**JSON:**
- **Aeson** (`Data.Aeson`) - JSON serialization/deserialization across the codebase

**Concurrency:**
- **STM** (`Control.Concurrent.STM`) - Software Transactional Memory for shared state (metrics, secrets, monitoring, tracing)
- **MVar** (`Control.Concurrent.MVar`) - Global broadcaster in `DAL/EventStore.hs:50`
- **Chan** (`Control.Concurrent.Chan`) - Event bus channel in `EventBus.hs:8`

**Testing:**
- Not detected - No test framework files found

**Build/Dev:**
- Not detected - No build system files committed

## Key Dependencies

**Critical:**
- **Hasql** (PostgreSQL client) - All database access goes through this library
- **Servant** - Typed API layer and auth middleware
- **Scotty** - Integration API server
- **Aeson** - JSON handling throughout

**Infrastructure:**
- **hedis** (`Database.Redis`) - Redis client for WebSocket pub/sub (`Surypus/WebSocket/RedisPublisher.hs`) and task queues (`Infrastructure/Redis/TaskQueue.hs`)
- **Network.HTTP.Client** - HTTP client for GraphQL proxy (`API/GraphQL/Proxy.hs:36`)

**Supporting Libraries (identified from source imports):**
- `Data.UUID.V4` - UUID generation
- `Data.Time` - Time handling
- `Data.ByteString` - Binary data
- `Data.Text` - Text handling (heavy usage)
- `Network.Wai.Middleware.Cors` - CORS middleware (`API/Server.hs:19`)
- `Network.Wai.Middleware.RequestLogger` - Request logging (`API/Server.hs:18`)

## Configuration

**Environment:**
- `config.yaml` at `/config.yaml` - Dolt SQL server configuration (listener host `0.0.0.0`, port `34789`, all other settings commented out)
- `.beads/config.yaml` at `.beads/config.yaml` - Beads listener config (host `0.0.0.0`, port `34789`, log level info)
- Database configuration loaded from environment via `Surypus.Database.Pool.databasePoolConfigFromEnv` (`Surypus/Database/Pool.hs:37`) — defaults to `localhost:5432`, user `suryplus`, database `suryplus`, pool size 10, timeout 30s

**Key Configurations:**
- `DOLT_SQL_PORT=34789` - Dolt SQL server port
- Postgres-compatible connection params (host, port, user, password, database)
- JWT secret key (loaded at application startup)
- AI provider configuration (OpenAI/Anthropic/LocalLLM)

**Build:**
- Not detected

## Platform Requirements

**Development:**
- GHC compiler
- Dolt SQL server
- Redis server (for WebSocket broadcasting and task queues)
- PostgreSQL-compatible client libraries (Hasql)
- Network access to Kafka brokers (for event streaming — currently stubbed)

**Production:**
- Dolt SQL server (version-controlled database)
- Redis server (pub/sub, task queues)
- Network access to external integrations (EGAIS, VETIS, EDI providers, bank APIs)

---

*Stack analysis: 2026-05-24*
