# Phase 191: Bill Posting Flow - Context

**Gathered:** 2026-05-30
**Status:** Ready for planning
**Mode:** Planning

## Phase Boundary

Implement complete postBill flow: validate → calcAmount → AccTurn → Stock → status update.

## Success Criteria

1. `postBill` validates bill state before posting
2. `postBill` creates double-entry AccTurn records
3. `postBill` updates stock levels
4. Bill status transitions correctly
5. All steps in single transaction
6. stack build passes

## Existing Code Insights

The ORM migration is complete. `DAL.Procedures.postBill` exists but calls a stored procedure. Need to implement full flow with:
- Bill validation
- Accounting entry creation (Debit/Credit)
- Stock updates
- Status transition

## Specific Ideas

- Use `runSqlPool` for transactional consistency
- Call `calcAccountBalance` after posting
- Update `BillEntity` status field
- Ensure proper error handling with rollback
