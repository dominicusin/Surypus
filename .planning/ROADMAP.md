# Roadmap: Surypus ERP/CRM

## Phase 1 — API Production Readiness

**Goal:** API returns real DB data, authentication works, tests pass
**Status:** planned
**Plans:** 4

### Plan 1.1: Real DB Queries in API Handlers

**Objective:** Replace hardcoded stubs with DAL queries in surypus-api/Server.hs
**Estimate:** 8h
**Deliverable:** API endpoints return real PostgreSQL data

### Plan 1.2: JWT Authentication Middleware

**Objective:** Implement JWT authentication protecting all endpoints
**Estimate:** 4h
**Deliverable:** /api/v1/auth/login endpoint returns valid JWT

### Plan 1.3: RBAC Authorization

**Objective:** Add requirePermission checks to all write operations
**Estimate:** 4h
**Deliverable:** 403 Forbidden for unauthorized operations

### Plan 1.4: Integration Tests

**Objective:** Set up test database and integration test suite
**Estimate:** 6h
**Deliverable:** Tests pass against PostgreSQL database

---

## Phase 2 — Bill Posting & Event Store

**Goal:** Full bill posting flow with event sourcing
**Status:** planned
**Depends on:** Phase 1
**Plans:** 4

### Plan 2.1: Bill Posting Flow

**Objective:** Implement CalcBillLineAmount → StockMovements → AccTurn atomically
**Estimate:** 12h
**Deliverable:** Bills can be created and posted with correct accounting

### Plan 2.2: Hasql Event Store

**Objective:** Create event store integration in DAL/EventStore.hs
**Estimate:** 6h
**Deliverable:** Events stored with type-safe Hasql queries

### Plan 2.3: Event Store Integration

**Objective:** Connect Event Store to Accounting and Inventory services
**Estimate:** 6h
**Deliverable:** Events emitted for all domain changes

### Plan 2.4: QuickCheck Properties

**Objective:** Property tests for invariants (VAT≥0, ΣDebit=ΣCredit)
**Estimate:** 8h
**Deliverable:** Automated verification of business rules

---

**Total Phases:** 2
**Current Phase:** 1