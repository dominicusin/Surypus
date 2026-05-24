# Codebase Concerns

**Analysis Date:** 2026-05-24

## Tech Debt

### 14 Near-Identical Circuit Breaker Implementations

**Issue:** The `System/` directory contains 14 circuit breaker modules with near-identical code duplicated across files. Each variant adds a small incremental feature (metrics, bulkhead, chaining, self-healing) but the core logic is copy-pasted.

**Files:**
- `src/System/CircuitBreakerBulkhead.hs` (215 lines)
- `src/System/CircuitBreakerBulkheadAdvanced.hs` (217 lines)
- `src/System/CircuitBreakerBulkheadFull.hs` (215 lines)
- `src/System/CircuitBreakerBulkheadFullWithMetrics.hs` (332 lines)
- `src/System/CircuitBreakerAdaptive.hs` (211 lines)
- `src/System/CircuitBreakerCircuit.hs` (181 lines)
- `src/System/CircuitBreakerExtended.hs` (161 lines)
- `src/System/CircuitBreakerFull.hs` (183 lines)
- `src/System/CircuitBreakerFullAdvanced.hs` (199 lines)
- `src/System/CircuitBreakerFullTopology.hs` (201 lines)
- `src/System/CircuitBreakerFullWithMetrics.hs` (186 lines)
- `src/System/CircuitBreakerChained.hs` (151 lines)
- `src/System/CircuitBreakerSelfHealing.hs` (211 lines)
- `src/System/CircuitBreakerWrapper.hs` (73 lines)

**Impact:** ~2,700 lines of duplicated code. A bug fix or improvement must be applied 14 times. Breaks DRY. The variants could be collapsed into a single parameterized implementation with type-level configuration.

**Fix approach:** Refactor into a single `CircuitBreaker.hs` with configurable strategies (bulkhead, retry, metrics, chaining, self-healing) using a typeclass or sum type. Keep wrapper modules as thin re-exports if backward compat is needed.

### 40 RBACCanon Migrations in Single Main Entry Point

**Issue:** `src/Surypus/App/Main.hs` (246 lines) generates 40 sequential SQL migration files on startup via 40 `let v001 = ...` through `let v040 = ...` bindings and then writes each to `sql/migrations/V###__rbac_*.generated.sql`. The latter half (V029-V040) are labeled "placeholder" and produce identical empty migrations.

**Files:** `src/Surypus/App/Main.hs` (lines 1-246), `src/Surypus/Domain/RBACCanon/Migration.hs` (288 lines)

**Impact:** This is not a real application entry point — it's a migration generator script that can only run once. `main` blocks on 40 sequential file writes. There is no actual server/app initialization. The placeholder migrations inflate the total count without providing value.

**Fix approach:** Replace with a single migration generator binary; consolidate redundant migrations; remove placeholders.

### Exact Duplicate Commerce Modules

**Issue:** Four `Commerce/` modules are duplicated under `Commerce/Payments/` with identical content but different module names:
- `src/Commerce/Payment.hs` ↔ `src/Commerce/Payments/Payment.hs` (95 lines each, only module name differs)
- `src/Commerce/CashRegister.hs` ↔ `src/Commerce/Payments/CashRegister.hs`
- `src/Commerce/PaymentCard.hs` ↔ `src/Commerce/Payments/PaymentCard.hs`
- `src/Commerce/CashOperation.hs` ↔ `src/Commerce/Payments/CashOperation.hs`

**Impact:** Import ambiguity and code drift. Any change must be made in two places. Haskell module system makes this a compile-time error if both are imported — yet both exist.

**Fix approach:** Remove one copy, update all imports to point to the canonical location.

### Pure Concept/Stub Modules (~150+ files)

**Issue:** Hundreds of modules exist as small data-type-only files (15-50 lines) under conceptual directories (`Cosmic/`, `Absolute/`, `Eternal/`, `Infinite/`, `Quantum/`, `Divine/`, etc.) that define types but contain no real business logic, IO, or algorithms.

**Files:** Examples include `src/CosmicEnlightenment/CosmicEnlightenment.hs`, `src/EternalGenesis/EternalGenesis.hs`, `src/DivineUnity/DivineUnity.hs`, `src/AbsolutePerfection/AbsolutePerfection.hs`, ~150+ similar modules.

**Impact:** Inflates module count (484 `.hs` files) and build times. Confuses developers about what is real vs aspirational. These are listed in `Surypus.cabal` as `exposed-modules`, creating a false sense of completeness.

**Fix approach:** Remove unimplemented conceptual modules, or gate them behind a Cabal flag. Keep only modules that have actual implementations.

=== Stub Implementations with TODOs Where Real Code Is Needed

**Issue:** Critical infrastructure modules are stubbed out with `-- TODO` comments and no-op `return ()` / `return []` implementations.

| File | Stubbed Functions |
|------|-------------------|
| `src/Audit/Trail.hs` | `logAuditEntry`, `queryAuditTrail`, `exportAuditLog` |
| `src/Audit/Persistence.hs` | `insertAuditEntry`, `queryAuditByUser`, `exportUserData`, `anonymizeUserData` |
| `src/Kafka/Producer.hs` | `newKafkaProducer`, `produceMessage` |
| `src/EventBus.hs` | Kafka send in `publishEvent`, `startProcessor` processing |
| `src/Surypus/AI.hs` | `parseDocument`, `getRecommendations` |
| `src/MultiTenancy/Isolation.hs` | `setTenantContext`, `getTenantFromRequest` |
| `src/MultiTenancy/TenantConfig.hs` | Config lookup |
| `src/Analytics/Dashboard.hs` | KPI queries, time series |
| `src/Analytics/Export.hs` | Excel export, PDF export |
| `src/Surypus/RBAC.hs` (line 152) | Database query for roles/permissions |
| `src/Infrastructure/Backup.hs` | Backup operations |

**Impact:** These modules are listed as dependencies by other code but will silently return empty/unit results in production. Audit, GDPR compliance, and event-driven architecture are non-functional.

### 100% Commented-Out API Server

**Issue:** `src/Integration/API/API.hs` (125 lines) is entirely commented out — every function definition, import, and type signature. The actual Servant API server has never been wired up.

**Impact:** There is no running HTTP server in this codebase. The entire API layer declared in `API/` and `Integration/` is dead code.

### runtime `error` Calls That Will Crash Production

**Issue:** Several modules contain `error "..."` calls that will throw uncatchable exceptions at runtime:

- `src/Surypus/AI.hs:71`: `respCreatedAt = error "not implemented"` — called in `parseDocument` stub
- `src/DigitalTwin/TwinSystem.hs:39`: `error "no time"` — called in `createTwinEntity`
- `src/DigitalTwin/TwinSystem.hs:44`: `error "no time"` — called in `updateTwinState`
- `src/Science/ML/DemandForecasting.hs:45`: `error "use real date"` — called when constructing forecast points
- `src/Core/Accounting/Cache.hs:57`: `RM.replayAccountEvents undefined accountId ""` — passes `undefined` as first argument

**Impact:** Any code path that reaches these will crash the entire process with an uncatchable `ErrorCall` exception. Since these are in core modules (AI, DigitalTwin, ML, Accounting), they represent ticking time bombs.

## Known Bugs

### Password "Hashing" Is Not Cryptographic

**Issue:** `src/Infrastructure/Encryption.hs` implements a custom password hashing scheme that is trivially reversible:
- Uses a constant salt `"deadbeef"` (line 44)
- The `simpleHash` function (lines 65-69) only applies XOR with iteration count across the first `min iter 1000` bytes, and `xor` is actually `(+)` (line 73), not XOR.
- `hashPassword` is labeled "would use bcrypt in production" (line 39) but production is shipping with this.
- `initEncryption` uses zeroed key/IV: `BS.replicate 32 0x00` / `BS.replicate 16 0x00` (lines 23-24)
- `encrypt`/`decrypt` pass through data unchanged (lines 32-37)

**Files:** `src/Infrastructure/Encryption.hs`

**Impact:** All encrypted data and password hashes in the system are trivially reversible. Zero security provided.

### Fake JWT Tokens With No Signature Verification

**Issue:** `src/Surypus/JWT.hs` implements JWT generation and validation using entirely fake tokens:
- Access tokens: signature is `T.take 20 $ T.pack $ show $ sum $ map fromEnum $ T.unpack toSign` (line 101) — a simple checksum, not HMAC
- Refresh tokens: literally the string `"fake-refresh-token-" <> userId` (line 110)
- Token validation (`validateAccessToken`, `decodeAndValidateToken`) ignores the signature entirely and does naive string parsing
- `decodeAndValidateToken` (line 149) always returns `userId = 1, role = "user"` regardless of input

**Impact:** Any attacker can forge JWTs. There is no authentication security. The `role = "user"` bypass means all RBAC authorization logic is effectively disabled.

### EventBus `startProcessor` Is a Busy Spin

**Issue:** `src/EventBus.hs` `startProcessor` (lines 51-55) is an unbounded recursive loop reading from a `Chan` with no delay, backpressure, or error handling. It will consume 100% CPU on one core forever.

**Impact:** If started, this will pin a CPU core.

### Singleton Logger/Growing Memory

**Issue:** `src/System/Logger.hs` defines `newtype Logger = Logger (TVar [LogEntry])` — an unbounded `[LogEntry]` list that grows forever with no eviction or log rotation.

**Impact:** Memory leak. The logger will consume ever-increasing RAM in production.

## Security Considerations

### Plaintext Password Storage in DAL.Types

**Issue:** `src/DAL/Types.hs:289` defines `User` with field `userPassword :: !(Maybe Text)` — storing passwords as nullable plaintext in the core data type. No indication of hashing at the type level.

**Risk:** Any code handling a `User` value has access to the raw password string.

**Current mitigation:** None.

**Recommendations:** Replace with a `HashedPassword` newtype; ensure hashing happens at the boundary.

### Hardcoded Database Password

**Issue:** `src/Surypus/Database/Pool.hs:44` hardcodes `pcPassword = ""` as the database password.

**Risk:** Empty password for database access.

**Current mitigation:** Password is empty; connection presumably relies on local socket trust.

**Recommendations:** Move to environment variable with `lookupEnv`.

### API Types Expose Password in Login Request

**Issue:** `src/API/Types.hs:96` defines `lrPassword :: Text` in the login request type. Password validation in `src/System/Auth.hs:39` is `T.length pwd >= 6`.

**Risk:** Only minimum length validation. No complexity, no rate limiting on login attempts in the visible code.

**Recommendations:** Add rate limiting at the API layer; strengthen password policy.

### Secrets Manager Stores Without Encryption

**Issue:** `src/System/Secrets.hs` stores secrets in-memory as `ByteString` in a `TVar (Map.Map Text (BS.ByteString, SecretMetadata))`. The `storeSecret` function (line 46) stores the value literally without encryption. There is no persistence layer.

**Risk:** Process memory dump exposes all secrets. Restart loses all stored secrets.

**Recommendations:** Encrypt at rest; add persistent storage; seal memory.

### MultiTenancy Authorization Defaults to True

**Issue:** `src/MultiTenancy/Isolation.hs:31` — `checkTenantAccess` always returns `True` (stub).

**Risk:** No actual tenant isolation exists despite the multi-tenancy architecture. All tenants can access all data.

## Performance Bottlenecks

### 965-Line DAL/Types.hs Monolith

**Problem:** `src/DAL/Types.hs` is a 965-line file defining 50+ data types, all with JSON instances. Uses `{-# LANGUAGE DuplicateRecordFields #-}`, which is known to cause ambiguity issues in field accessors.

**Cause:** All API/DAL types centralized in one file instead of being co-located with their domain modules.

**Improvement path:** Split into domain-specific type files (e.g., `DAL/Types/Bill.hs`, `DAL/Types/Goods.hs`).

### `DuplicateRecordFields` Extension Enabled

**Problem:** `src/DAL/Types.hs:3` enables `DuplicateRecordFields`. Multiple types define fields with the same name (e.g., `userId` in `User` and `billPersonId` in `Bill`) — this extension disables the compiler's ability to infer record field selectors, masking bugs.

**Improvement path:** Use unique field naming or avoid record syntax for these types.

### startProcessor Event Loop - CPU Peg

**Problem:** See EventBus section above. Busy loop with no `threadDelay`.

### Unbounded Logger List

**Problem:** See Logger section above. No log rotation or cap on `[LogEntry]`.

## Fragile Areas

### HR/Operations.hs

**File:** `src/HR/Operations.hs` (270 lines)

**Why fragile:** One of the largest real business-logic modules. High complexity, centralized HR operations. Any change to employee lifecycle logic touches this file.

**Test coverage:** No tests found anywhere in the project.

### Source of Truth Ambiguity in Commerce Modules

**File:** `src/Commerce/` duplicated under `src/Commerce/Payments/`

**Why fragile:** It's impossible to know which copy is the "real" one. Imports could resolve to either. Refactoring will break silently.

### Core/Accounting/RedisCache.hs

**File:** `src/Core/Accounting/RedisCache.hs` (303 lines)

**Why fragile:** Large module mixing Redis interaction, caching logic, and accounting domain events. Depends on `undefined` (via `Core/Accounting/Cache.hs:57`) in the cache miss path.

### DigitalTwin/TwinSystem.hs

**File:** `src/DigitalTwin/TwinSystem.hs` (48 lines)

**Why fragile:** Contains two `error "no time"` calls that will crash hard if the simulation is accessed.

### System/Configuration.hs

**File:** `src/System/Configuration.hs` (approx. 90 lines)

**Why fragile:** Directly reads `lookupEnv "JWT_SECRET"`, `lookupEnv "SESSION_SECRET"`, `lookupEnv "OPA_TOKEN"` — if JWT and session secrets aren't set, the system still starts but authentication becomes trivially predictable.

## Scaling Limits

**Module count explosion:** 484 `.hs` files in `src/` — build times will grow linearly. The `Surypus.cabal` `exposed-modules` list is extremely long.

**No database migration pipeline:** 40 generated SQL files in `sql/migrations/` via a one-shot generator. No versioned migration runner (no `Hasql` migration runner, no `postgres-embedded`, no `persistent` migration).

**No test suite:** Zero test files found. No `test-suite` stanza found in `Surypus.cabal`. No confidence for refactoring the 2,700 lines of duplicated circuit breaker code.

## Dependencies at Risk

**No external crypto libraries in use:** JWT uses hand-rolled "signatures". Password hashing uses a custom XOR-based "hash". Encryption passes data through unchanged. The `Surypus.cabal` `build-depends` does not include `cryptonite`, `bcrypt`, `jose`, `hs-jose`, or any established crypto library.

**Impact:** The authentication, authorization, and encryption claims of the system are false. Any security audit will fail immediately.

## Missing Critical Features

**GDPR compliance:** `src/Audit/Persistence.hs` has `exportUserData` and `anonymizeUserData` as empty stubs. GDPR right-to-access and right-to-deletion cannot be fulfilled.

**Database audit trail:** `src/Audit/Trail.hs` `logAuditEntry` only prints to stdout. No database persistence for audit records.

**Event-driven architecture:** `src/EventBus.hs` publishes to a `Chan` but `startProcessor` does nothing with events. Kafka integration is stubbed. The entire event-sourcing architecture claimed by the system is non-functional.

**API server:** The Servant API server in `src/Integration/API/API.hs` is 100% commented out. No HTTP endpoints are served.

**AI/ML integration:** `src/Surypus/AI.hs` returns stubs. `src/Science/ML/DemandForecasting.hs` contains `error "use real date"`. Not usable.

## Test Coverage Gaps

**No tests exist anywhere in the repository.** Zero test files were found. The `Surypus.cabal` file has no `test-suite` stanza.

**What's not tested:** Everything. All 484 modules, all business logic (HR operations, inventory management, accounting, order processing), all security code (JWT, encryption, RBAC), all infrastructure (event bus, Kafka, Redis).

**Risk:** Any refactor, especially of the 14 duplicate circuit breaker modules, is blind. Regressions will ship to production without detection.

**Priority:** High — no testing infrastructure exists at any level (unit, integration, property-based).

---

*Concerns audit: 2026-05-24*
