# Phase 2: Bill Posting & Event Store - Context

**Gathered:** 2026-05-13
**Status:** Ready for planning
**Depends on:** Phase 1 completion

## Phase Boundary

Implement complete bill posting flow with double-entry accounting, stock movements, and event sourcing foundation.

## Implementation Decisions

### Bill Posting Flow

- Atomic transaction: calculate amounts → update stock → create accounting entries
- Bill status flow: draft → posted → (canceled)
- VAT calculated via stored procedures
- Stock movements tracked with lot information

### Event Store

- Event types: BillCreated, BillPosted, StockUpdated, AccTurnCreated
- Append-only log in PostgreSQL
- Replay function to rebuild state
- Outbox pattern for reliable event publishing

### Testing

- QuickCheck properties for financial invariants
- LiquidHaskell types for non-negative values
- Integration tests for full posting flow

## Canonical References

### Downstream agents MUST read these before planning or implementing.

- `.planning/PROJECT.md` — Project overview
- `.planning/REQUIREMENTS.md` — Requirements BILL-01 through BILL-04, EVT-01 through EVT-04
- `.planning/phases/01-api-production-readiness/01-PLAN.md` — Phase 1 context
- `src/Service/BillService.hs` — Existing service structure
- `src/DAL/Mutations.hs` — Database mutation patterns

---

*Phase: 02-bill-posting-event-store*
*Context gathered: 2026-05-13*