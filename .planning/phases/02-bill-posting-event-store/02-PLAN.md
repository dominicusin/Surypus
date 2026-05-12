# Phase 2 Plans: Bill Posting & Event Store

## Plan 2.1: Bill Posting Flow

### Objective

Implement complete bill posting: calculate amounts → stock movements → accounting entries.

### Prerequisites

- Phase 1 Plan 1.1 must be complete (real DB queries available)

### Tasks

1. **Calculate bill line amounts**
   - qty * price - discount + tax
   - Use stored procedure or Haskell calculation
2. **Create stock movements**
   - Decrease stock on sales bills
   - Increase stock on goods receipt bills
   - Track lot information
3. **Create accounting entries (AccTurn)**
   - Debit/Credit from bill items
   - VAT account entries
   - Update account balances
4. **Atomic transaction**
   - All steps in single DB transaction
   - Rollback on any failure

### Files to modify

- `src/Service/BillService.hs`
- `src/DAL/Mutations.hs`
- Database stored procedures

---

## Plan 2.2: Hasql Event Store

### Objective

Create Hasql-based event store for domain events.

### Tasks

1. **Create event_store table**
   - id, event_type, aggregate_id, payload, timestamp, sequence
2. **Implement appendEvent**
   - Type-safe Hasql query
   - Return event ID
3. **Implement getEvents**
   - By aggregate ID
   - By event type
4. **Implement replayAccount**
   - Replay all events for an account
   - Rebuild balance

### Files to create/modify

- `src/DAL/EventStore.hs`
- `sql/migrations/V010__event_store.sql` (if not exists)

---

## Plan 2.3: Event Store Integration

### Objective

Connect Event Store to Bill and Accounting services.

### Tasks

1. **Emit events from Bill Service**
   - On bill creation: BillCreated
   - On bill posting: BillPosted
2. **Emit events from Accounting**
   - On AccTurn creation: AccTurnCreated
3. **Emit events from Inventory**
   - On stock change: StockUpdated
4. **Outbox pattern**
   - Events stored in same transaction
   - Background processor publishes to event bus

### Files to modify

- `src/Service/BillService.hs`
- `src/Service/Accounting.hs`
- `src/Service/Inventory.hs`
- `src/Surypus/Event.hs`

---

## Plan 2.4: QuickCheck Properties

### Objective

Property-based tests for business invariants.

### Tasks

1. **VAT properties**
   - `prop_vat_nonnegative` — VAT amount ≥ 0
   - `prop_vat_max` — VAT ≤ line total
2. **Double-entry properties**
   - `prop_debit_credit_balance` — ΣDebit = ΣCredit
3. **Stock properties**
   - `prop_stock_nonnegative` — Stock balance ≥ 0
   - `prop_stock_conservation` — Rest = Initial + Receipt - Issue
4. **LiquidHaskell refinement types**
   - NonNeg type for money
   - Verification for critical functions

### Files to create/modify

- `test/Test/QuickCheck/Invariants.hs`
- `src/Service/BillService.hs` (add LH types)