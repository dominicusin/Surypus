# Surypus Backlog — Все сессии

Эпик: Phase 2 — Accounts & Journal Entries (ACID)

## US-2-1: Login and RBAC (P1, 3SP)
User logs in and obtains JWT with roles/permissions. Acceptance: 200 and token present; token usable for protected endpoints; RBAC evaluated per request.

## US-2-2: Create Account (P1, 5SP)
Admin can create accounts with code, name, type, currency, description, is_active. Acceptance: 201 Created; code unique; stored with timestamps; ready for subsequent journal entries.

## US-2-3: Read Accounts (P2, 3SP)
Get accounts list and single account details. Acceptance: 200; accounts contain the created account; code is unique.

## US-2-4: Create Journal Entry (P1, 5SP)
Create a debit/credit entry for an account. Acceptance: 201 Created; balance read-model updated within 5-10s; validations ensure account exists.

## US-2-5: RBAC negative test (P2, 2SP)
Non-authorized user cannot create accounts. Acceptance: 403 Forbidden.

## US-2-6: Health & Readiness (P2, 2SP)
Health and readiness endpoints implemented. Acceptance: 200 OK with status fields.

## US-2-7: OpenAPI Docs (P3, 2SP)
Swagger/OpenAPI docs generated and accessible. Acceptance: /docs or /swagger.json available and valid.

## US-2-8: Read model account_balances (P2, 5SP)
Materialize balance per account. Acceptance: API can read balances; updates reflect journal entries after 5-10s.

## US-2-9: Read model ledger_projection (P2, 5SP)
Aggregate debits/credits per account per period. Acceptance: Read model returns correct totals for a period.

## US-2-10: Dashboard endpoint (P2, 3SP)
/api/v1/dashboard aggregates revenue, stock, pending payments. Acceptance: 200 with fields revenue, stockValue, pendingPayments.

## US-2-11: Read-model caching (P2, 3SP)
In-memory TTL-based cache for read models. Acceptance: Cache TTL of 5-10s; cache hits reduce DB load.

## US-2-12: Phase 2 Integration tests (P2, 5SP)
CRUD flows with RBAC and read models. Acceptance: All phase-2 tests pass in CI.

---

Эпик: Phase 3 — Event Sourcing, Redis, GraphQL, WebSocket

## US-3-1: Accounts Event Store (P1, 8SP)
Add accounting_events table and append-only events for Accounts. Acceptance: events appended on each state change; replay utility reconstructs balance.

## US-3-2: Account read-model replay (P1, 5SP)
Rebuild account_balances from event stream. Acceptance: After replay, balances match expected post-events.

## US-3-3: Read models Redis cache (P2, 5SP)
Introduce Redis for caching and as a simple message bus. Acceptance: 5-10s TTL caches; Redis streams for cross-process events.

## US-3-4: GraphQL Proxy (P2, 5SP)
Add GraphQL proxy service that forwards to REST endpoints. Acceptance: /graphql endpoint returns data consistent with REST; no direct DB access.

## US-3-5: Redis Queue (P3, 5SP)
Introduce Redis/Bull for background tasks (notifications, reconciliation). Acceptance: Enqueue/dequeue works; tasks retry on failure.

## US-3-6: WebSocket real-time (P3, 5SP)
Real-time updates to dashboards and client apps. Acceptance: WebSocket endpoint broadcasts events when keys change.

## US-3-7: Proxy usage and client migration plan (P3, 3SP)
Prepare GraphQL client integration plan and migration guide. Acceptance: Client can start with GraphQL once proxy ready.