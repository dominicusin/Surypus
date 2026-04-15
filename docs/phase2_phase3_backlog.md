# Phase 2–3 Backlog

This backlog captures MVP (Phase 2) tasks and Phase 3 scaling tasks with acceptance criteria and rough priorities.

## Epic: Phase 2 — Accounts & Journal Entries (ACID)
- US-2-1 Login and RBAC
  - Description: User logs in and obtains JWT with roles/permissions.
  - Acceptance Criteria: 200 and token present; token usable for protected endpoints; RBAC evaluated per request.
  - Priority: 1
  - Story Points: 3
- US-2-2 Create Account
  - Description: Admin can create accounts with code, name, type, currency, description, is_active.
  - Acceptance Criteria: 201 Created; code unique; stored with timestamps; ready for subsequent journal entries.
  - Priority: 1
  - Story Points: 5
- US-2-3 Read Accounts
  - Description: Get accounts list and single account details.
  - Acceptance Criteria: 200; accounts contain the created account; code is unique.
  - Priority: 2
  - Story Points: 3
- US-2-4 Create Journal Entry
  - Description: Create a debit/credit entry for an account.
  - Acceptance Criteria: 201 Created; balance read-model updated within 5–10s; validations ensure account exists.
  - Priority: 1
  - Story Points: 5
- US-2-5 RBAC negative test
  - Description: Non-authorized user cannot create accounts.
  - Acceptance Criteria: 403 Forbidden.
  - Priority: 2
  - Story Points: 2
- US-2-6 Health & Readiness
  - Description: Health and readiness endpoints implemented.
  - Acceptance Criteria: 200 OK with status fields.
  - Priority: 2
  - Story Points: 2
- US-2-7 OpenAPI Docs
  - Description: Swagger/OpenAPI docs generated and accessible.
  - Acceptance Criteria: /docs or /swagger.json available and valid.
  - Priority: 3
  - Story Points: 2

## Epic: Phase 2 Read Models & Polling
- US-2-8 Read model: account_balances
  - Description: Materialize balance per account.
  - Acceptance Criteria: API can read balances; updates reflect journal entries after 5–10s.
  - Priority: 2
  - Story Points: 5
- US-2-9 Read model: ledger_projection
  - Description: Aggregate debits/credits per account per period.
  - Acceptance Criteria: Read model returns correct totals for a period.
  - Priority: 2
  - Story Points: 5
- US-2-10 Dashboard endpoint
  - Description: /api/v1/dashboard aggregates revenue, stock, pending payments.
  - Acceptance Criteria: 200 with fields revenue, stockValue, pendingPayments.
  - Priority: 2
  - Story Points: 3
- US-2-11 Read-model caching
  - Description: In-memory TTL-based cache for read models.
  - Acceptance Criteria: Cache TTL of 5–10s; cache hits reduce DB load.
  - Priority: 2
  - Story Points: 3
- US-2-12 Phase 2 Integration tests
  - Description: CRUD flows with RBAC and read models.
  - Acceptance Criteria: All phase-2 tests pass in CI.
  - Priority: 2
  - Story Points: 5

## Epic: Phase 3 — Accounts ES; Read Models; Proxy GraphQL; Redis Queues
- US-3-1 Accounts Event Store
  - Description: Add accounting_events table and append-only events for Accounts.
  - Acceptance Criteria: events appended on each state change; replay utility reconstructs balance.
  - Priority: 1
  - Story Points: 8
- US-3-2 Account read-model replay
  - Description: Rebuild account_balances from event stream.
  - Acceptance Criteria: After replay, balances match expected post-events.
  - Priority: 1
  - Story Points: 5
- US-3-3 Read models: Redis cache for phase 3
  - Description: Introduce Redis for caching and as a simple message bus.
  - Acceptance Criteria: 5–10s TTL caches; Redis streams for cross-process events.
  - Priority: 2
  - Story Points: 5
- US-3-4 GraphQL Proxy (Phase 3)
  - Description: Add GraphQL proxy service that forwards to REST endpoints.
  - Acceptance Criteria: /graphql endpoint returns data consistent with REST; no direct DB access.
  - Priority: 2
  - Story Points: 5
- US-3-5 Redis Queue (Line for background jobs)
  - Description: Introduce Redis/Bull for background tasks (notifications, reconciliation).
  - Acceptance Criteria: Enqueue/dequeue works; tasks retry on failure.
  - Priority: 3
  - Story Points: 5
- US-3-6 WebSocket real-time (Phase 3)
  - Description: Real-time updates to dashboards and client apps.
  - Acceptance Criteria: WebSocket endpoint broadcasts events when keys change.
  - Priority: 3
 - Story Points: 5

## Epic: Phase 3 – OpenAPI & GraphQL (Preview)
- US-3-7 Proxy usage and client migration plan
  - Description: Prepare GraphQL client integration plan and migration guide.
  - Acceptance Criteria: Client can start with GraphQL once proxy ready.
  - Priority: 3
  - Story Points: 3
