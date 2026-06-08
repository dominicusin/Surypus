# Phase 1: Core API & Database Integration ✅ COMPLETE - Plan

**Phase:** 1
**Name:** Core API & Database Integration ✅ COMPLETE
**Goal:** Connect all API handlers to real database operations, remove in-memory stubs

## Tasks

### Task 1: Replace DAL.DB in-memory stub with Persistent/Esqueleto operations
- [ ] Remove DAL.DB module (in-memory stub)
- [ ] Update DAL.Database to use Persistent/Esqueleto for all operations
- [ ] Add query functions for Person, Goods, Location, Bill, Stock using Esqueleto
- [ ] Add mutation functions for Person, Goods, Location, Bill, Stock using Persistent
- [ ] Update DAL.Database exports to use Persistent types

### Task 2: Update BillService to use real database operations
- [ ] Remove import of DAL.DB
- [ ] Import DAL.Database (ConnectionPool, runDb)
- [ ] Import Database.Persist.Sql (Entity, selectList, insert, update, delete, etc.)
- [ ] Replace DAL.DB.Database with ConnectionPool
- [ ] Replace DAL.DB.Database operations with runDb + Persistent/Esqueleto queries
- [ ] Replace DAL.DB.insertBill with Persistent insert
- [ ] Replace DAL.DB.insertStock with Persistent insert
- [ ] Update validateBill to use real database queries
- [ ] Update createAccountingEntries to use real database inserts
- [ ] Update updateStockLevels to use real database updates
- [ ] Update emitBillPostedEvent to use real event store

### Task 3: Connect API handlers to real database operations
- [ ] Update API.Server to use real database queries instead of stubs
- [ ] Update API.Integration.REST to use real database operations
- [ ] Update API.Integration.BankStatement to use real database
- [ ] Update API.Integration.REST to use DAL.Database (ConnectionPool, runDb)

### Task 4: Remove DAL.DB in-memory stub
- [ ] Delete src/DAL/DB.hs
- [ ] Update DAL.DAL to remove DAL.DB import
- [ ] Update Service.BillService to remove DAL.DB import
- [ ] Update any other modules importing DAL.DB

### Task 5: Verify all tests pass
- [ ] Run stack build
- [ ] Run stack test
- [ ] Verify no compilation errors

## Dependencies
- Uses DAL.Database (Persistent/Postgresql) - already implemented
- Uses DAL.Schema (EventStoreEntity) - already implemented
- Uses DAL.EventStore - already implemented

## Success Criteria
- All API handlers use real database operations
- No in-memory stubs remain (DAL.DB removed)
- stack build succeeds with 0 errors
- stack test passes (70 examples, 0 failures)