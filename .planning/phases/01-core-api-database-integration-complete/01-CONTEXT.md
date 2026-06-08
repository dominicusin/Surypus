# Phase 1: Core API & Database Integration ✅ COMPLETE - Context

**Gathered:** 2026-06-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Connect all API handlers to real database operations, remove in-memory stubs. Replace DAL.DB in-memory stub with real database operations using Persistent/Esqueleto. Update BillService to use real database operations. Connect API handlers to real database operations. Remove DAL.DB in-memory stub.

</domain>

<decisions>
## Implementation Decisions

### the agent's Discretion
All implementation choices are at the agent's discretion — pure infrastructure phase

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- DAL.Database: Persistent/Postgresql connection pool with runDb
- DAL.Schema: Persistent schema definitions with EventStoreEntity
- DAL.EventStore: Event store with Persistent operations
- DAL.Queries/DAL.QueriesORM: Query functions using Esqueleto
- DAL.Mutations/DAL.MutationsORM: Mutation functions
- DAL.Types: Type definitions including QueryResult, Bill, etc.
- Finance.Accounting: Accounting types with LiquidHaskell refinements
- Inventory.Stock: Stock types with validation
- Finance.Tax: Tax calculation with smart constructors
- Reports.Report: Report types

### Established Patterns
- Persistent/Esqueleto for database operations
- runDb pattern for running SqlPersistT actions
- ServiceResult/QueryResult for error handling
- Smart constructors with validation (e.g., mkTaxRate, mkStock)
- LiquidHaskell refinement types for invariants
- Service modules orchestrate DAL operations

### Integration Points
- API.Server uses DAL.ORMPool.ConnectionPool
- API.Integration.REST uses DAL.Database (ConnectionPool, runDb)
- Service.BillService uses DAL.DB (in-memory stub) - needs migration
- DAL.EventStore uses DAL.Database (ConnectionPool, runDb)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>