# External Integrations

**Analysis Date:** 2026-05-24

## APIs & External Services

**Government Regulatory Systems:**
- **EGAIS** - Russian alcohol tracking system (`External/EGAIS.hs`, `External/EGais/EGais.hs`)
  - Purpose: Track alcohol production and sales for compliance
  - Data types: Waybill, ActWriteOff, ActTurnover shipments
  - Statuses: Pending, Sent, Accepted, Rejected
  - Client: Custom types and stubs — no HTTP client code yet

- **VETIS** - Russian veterinary tracking system (`External/VETIS.hs`)
  - Purpose: Track animal products through supply chain
  - Data types: Entities (Producer, Storage, Transport, Recipient) and Movements
  - Statuses: Active, Archived
  - Client: Custom types only — HTTP integration not implemented

**E-Commerce:**
- **Universe-HTT (UHTT)** - Online store platform (`External/UHTT/UhttStore.hs`)
  - Purpose: External online store order integration
  - Data types: Store config (with API key), Orders (New, Processing, Shipped, Delivered)
  - Client: Custom types only — HTTP integration not implemented

**EDI:**
- **Electronic Data Interchange** (`Integration/EDI/EDI.hs`)
  - Purpose: B2B document exchange (orders, invoices, despatch advice, receipt advice)
  - Direction: Incoming and Outgoing
  - Statuses: Pending, Sent, Received, Accepted, Rejected
  - Client: Custom types only — transport not implemented

**Banking:**
- **Bank Statement Import** (`Integration/BankStatement.hs`)
  - Purpose: Import bank statements and auto-match to bills
  - Formats: OFX (SGML-based) and ISO 20022 (camt.053 XML)
  - Key features: Transaction parsing, bill matching, unmatched transaction flagging
  - OFX parser: Custom text-scanning (`Integration/BankStatement.hs:59-83`)
  - Database: Stores imported lines via Hasql, matches to existing bills

**Reporting Engines:**
- **JasperReports** (`External/Jasper/Jasper.hs`, `Reports/Jasper.hs`)
  - Purpose: Generate reports using JasperReports CLI/server
  - Config: JAR path
  - Integration: Placeholder — stubbed with mock file path return

- **Pentaho** (`External/Pentaho/Pentaho.hs`)
  - Purpose: Generate reports using Pentaho server
  - Config: Server URL
  - Integration: Placeholder — stubbed with mock file path return

- **Crystal Reports** (`Surypus/Reports/Conversion/CrystalToPdfSlave.hs`, `Surypus/Reports/Conversion/CrystalTypes.hs`)
  - Purpose: Convert Crystal Reports (.rpt) to PDF via PDF Slave format
  - Data types: CrystalReport, CrystalSection, CrystalSubreport
  - Integration: Conversion logic defined, but actual conversion engine not wired

**AI/LLM Providers:**
- **OpenAI** (`Surypus/AI.hs:24`)
  - Purpose: Document parsing, recommendations
  - Status: Stub — types defined, calls not implemented

- **Anthropic** (`Surypus/AI.hs:25`)
  - Purpose: Document parsing, recommendations
  - Status: Stub — types defined, calls not implemented

- **LocalLLM** (`Surypus/AI.hs:26`)
  - Purpose: Self-hosted LLM inference
  - Status: Stub — types defined, calls not implemented

**AGI (Experimental):**
- **AGI Engine** (`AGI/AGIIntegration.hs`)
  - Purpose: Experimental AGI capabilities (reasoning, learning, creativity, empathy, strategic)
  - Status: Stub — types and interface defined only

## Data Storage

**Databases:**
- **Dolt** - Version-controlled SQL database (Git-for-data)
  - Connection: PostgreSQL wire protocol (port `34789` default, configurable via `config.yaml`)
  - Client: Hasql library (`DAL/Database.hs` re-exports `Hasql.Pool`, `Hasql.Session`, `Hasql.Statement`)
  - Pool config: `databasePoolConfigFromEnv` defaults to `localhost:5432`, user `suryplus`, db `suryplus`
  - Schema: Event store (`event_store` table in `DAL/EventStore.hs`), user sessions (`user_sessions` table in `Surypus/RefreshTokenRepo.hs`), RBAC tables (DSL-generated migrations)
  - Migrations: SQL generated programmatically via `Surypus.Domain.RBACCanon.Migration` (40 migration versions, written to `sql/migrations/` directory)

**File Storage:**
- **Local filesystem** (`Infrastructure/FileStorage.hs`)
  - Purpose: File uploads with metadata tracking
  - Constraints: Base path configurable, max 100MB, allowed types: `.png`, `.jpg`, `.pdf`, `.txt`
  - No cloud storage integration detected

**Caching:**
- **Redis** (`Surypus/WebSocket/RedisPublisher.hs`, `Infrastructure/Redis/TaskQueue.hs`)
  - Purpose 1: Pub/sub for WebSocket event broadcasting (`surypus:events` channel on `localhost:6379`)
  - Purpose 2: Background task queue with RPUSH/BRPOP pattern
  - Client: `hedis` (`Database.Redis`)
  - Status: Functional for task queue, stub-wired for WebSocket publishing

## Authentication & Identity

**Auth Provider:**
- **Custom JWT-based authentication** (`Surypus/JWT.hs`)
  - Implementation: Custom JWT-like token generation (stub — uses simple HMAC-like hashing)
  - Production recommendation: file comment suggests `jose` library (`Surypus/JWT.hs:83`)
  - Token lifecycle: Access tokens (1 hour expiry), Refresh tokens (14 days expiry)
  - Token storage: `user_sessions` table via `Surypus/RefreshTokenRepo.hs`
  - JWT config: Secret key, expiry durations loaded at runtime

**Authorization:**
- **Custom RBAC** (`Surypus/RBAC.hs`)
  - 30 permission types covering: Person, Goods, Bill, Payment, Location, Stock, Accounting, Payroll, Reports, Users, Settings, Admin
  - Permission format: `resource:action` (e.g., `person:read`, `bill:write`)
  - Permission checking via `requirePermission` (IO-based) and `requirePermissionChecked` (Servant Handler-based)
  - Integration API authorization via `Surypus.API.Authorization` — maps HTTP method + path to required permission

**Session Management:**
- Session storage in `user_sessions` table
- Token rotation with atomic transaction (delete old, invalidate all others, insert new) in `Surypus/RefreshTokenRepo.hs:51-72`

## Monitoring & Observability

**Metrics:**
- **Custom STM-based metrics** (`Surypus/Metrics.hs`, `System/Metrics.hs`)
  - Counters, gauges, distributions via STM TVars
  - HTTP request total/duration, DB pool connections, job queue size tracked
  - EKG server mentioned (`startMetricsServer`) but stubbed

**Health Checks:**
- **Custom health monitoring** (`System/HealthCheck.hs`)
  - Checks: database, cache, queue, external services
  - Configurable interval (30s), retry (3), timeout (10s), parallel checks
  - Health status exposed via Integration API (`/api/v1/integrations/health`)

**Tracing:**
- **Custom distributed tracing** (`System/Tracing.hs`)
  - Trace context with trace_id, span_id, parent_span_id
  - Span management with tagging and logging
  - JSON serialization for trace export

**Logging:**
- **Custom in-memory logger** (`System/Logger.hs`)
  - Log levels: Debug, Info, Warn, Error, Critical
  - STM-backed circular buffer with source and context tracking

**Alerting:**
- **Custom alert system** (`System/Monitoring.hs`)
  - Threshold-based alerts with severity levels (Low, Medium, High, Critical)
  - Configurable alert channels (stub implementation)

## CI/CD & Deployment

**Hosting:**
- Not detected — no deployment configuration found

**CI Pipeline:**
- Not detected — no CI/CD configs found

## Environment Configuration

**Required env vars (detected from code):**
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` — Database connection (via `databasePoolConfigFromEnv`)
- `JWT_SECRET` — JWT signing secret
- `REDIS_HOST`, `REDIS_PORT` — Redis connection (defaults: `localhost:6379`)

**Secrets location:**
- `System.Secrets` module (`System/Secrets.hs`) — In-memory encrypted secret store with rotation, audit logging, and category management
- Node-level secret management for DatabaseCredentials, APIKeys, EncryptionKeys, ServiceTokens, AdminCredentials

## Webhooks & Callbacks

**Outgoing:**
- **Webhook system** (`Integration/Webhook.hs`)
  - Events: BillCreated, BillUpdated, OrderCreated, PaymentReceived
  - Config: URL, secret, enabled flag per webhook
  - Delivery logging with status code and response tracking
  - Transport: Not implemented (types only)

**Incoming:**
- **Bank statement upload** (`/api/v1/integrations/bank-statement/upload`) — Accepts OFX/ISO20022 file uploads via the Integration API

## Event Bus & Messaging

**In-Memory Event Bus:**
- **Custom EventBus** (`EventBus.hs`)
  - Channel-based pub/sub for domain events
  - Domain events with ID, type, timestamp, payload, source

**Kafka Integration:**
- **Kafka Producer** (`Kafka/Producer.hs`)
  - Stub implementation targeting `surypus-events` topic
  - `EventBus` has `ebKafkaEnabled` flag — when true, events are forwarded to Kafka
  - Currently logs to stdout instead of sending

**WebSocket Broadcasting:**
- **Redis pub/sub + WebSocket** (`Surypus/WebSocket/RedisPublisher.hs`, `Surypus/WebSocket/Integration.hs`)
  - Events published to Redis channel `surypus:events`, broadcast to WebSocket rooms
  - Rooms: `bills`, `inventory`, `persons`, `notifications` (routed by message routing key prefix)

---

*Integration audit: 2026-05-24*
