# Surypus Strategic Analysis — Pāñcāvayava Structure

## Thesis
Surypus — formally verified ERP on Haskell. Current state: "structure exists, implementation absent". API handlers return hardcoded stubs, core business flow (Bill posting) incomplete, RBAC middleware partially connected, Event Store layer only declared.

## Goals & Task List

### Goal 1 — Production-Ready API (5 tasks)
1.1 [CRITICAL] Real DB queries in all API handlers — replace pure (SomeResponse []) with DAL calls
1.2 [CRITICAL] DAL/Procedures.hs integration — route all CRUD through stored procedures
1.3 [CRITICAL] Stabilize DB migrations — resolve V001-V012 vs 20240616_*.sql conflicts
1.4 [CRITICAL] Complete RBAC middleware — requirePermission for every endpoint per RBAC.md
1.5 [CRITICAL] Fix refresh token rotation — atomic Hasql transaction, silent error elimination

### Goal 2 — Bill Posting (2 tasks)
2.1 [CRITICAL] postBill end-to-end: validate → calcAmount → AccTurn → Stock → status update
2.2 [HIGH] LiquidHaskell invariants for Bill (NonNeg, balance conservation)

### Goal 3 — Testing (3 tasks)
3.1 [CRITICAL] Integration tests against real PostgreSQL in CI
3.2 [HIGH] QuickCheck property tests for all domain invariants
3.3 [HIGH] Eliminate SURYPUS_SKIP_RBAC_TESTS flag

### Goal 4 — Business Domains (3 tasks)
4.1 [HIGH] HR/Payroll: SalaryCharge, periods, NDFL + social tax
4.2 [MEDIUM] Production: TechCard, WorkOrder, MRP
4.3 [HIGH] Inventory document lifecycle (Draft→Approved→Posted→Archived)

### Goal 5 — Infrastructure (4 tasks)
5.1 [HIGH] Job Worker: processPendingJobs with retry + dead-letter
5.2 [MEDIUM] Prometheus metrics: http_requests_total, duration_seconds, db_pool
5.3 [MEDIUM] Event Store foundation: event_store table + outbox pattern
5.4 [HIGH] Connection pooling + CircuitBreaker on Hasql pool

### Goal 6 — Frontend/DevOps (3 tasks)
6.1 [HIGH] Web UI: real API calls, JWT login, WebSocket live updates
6.2 [MEDIUM] Docker optimization: libpq-dev, layer caching, slim image
6.3 [HIGH] CI/CD gates: build+test, hlint, matrix testing, dry-run migrations

## Conclusion
Critical path: Migrations(1.3) → DB queries(1.1) → Bill posting(2.1) → RBAC(1.4) → Integration tests(3.1)
Parallel: Job Worker(5.1), Payroll(4.1), Metrics(5.2)
