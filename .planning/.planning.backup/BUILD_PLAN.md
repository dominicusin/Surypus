# Surypus Build Plan - PR-Sized Implementation Chunks

**Project Status**: ✅ Build Successful (stack build passes)

This plan breaks down the remaining work into logical PR-sized chunks (~3-5 tasks each), organized by domain layers and architectural concerns.

---

## Chunk 1: Data Layer Stabilization & Testing
**Scope**: Core DAL types, test fixtures, and in-memory database layer
**Purpose**: Establish a solid foundation for all higher layers to build upon

### [ ] 1.1 Stabilize DAL Types
**File**: `Surypus/src/DAL/Types.hs`
- [x] Define core record types for Person, Goods, Location, Bill, Stock
- [x] Add deriving clauses (Show, Eq, ToJSON, FromJSON)
- [x] Create type aliases for IDs and codes
- [x] Document field constraints and business rules
**Test**: `Surypus/test/DAL/TypesSpec.hs` ✅ PASS (23 tests)

### [ ] 1.2 Enhance DAL.DB In-Memory Store
**File**: `Surypus/src/DAL/DB.hs`
- [x] Add update operations for Person, Goods, Location, Bill, Stock
- [x] Implement delete operations with cascading rules
- [x] Add filtered query operations (queryByType, queryByStatus, etc.)
- [x] Add transaction support (simple atomicity)
**Test**: `Surypus/test/DAL/DBSpec.hs` ✅ PASS (35 tests)

### [ ] 1.3 Create DAL Test Fixtures
**File**: `Surypus/test/DAL/Fixtures.hs`
- [x] Create factory functions for test data (person, goods, locations)
- [x] Add random data generators using QuickCheck
- [x] Create realistic test scenarios (company + products + stock)
- [x] Implement cleanup utilities
**Test**: `Surypus/test/DAL/FixturesSpec.hs` ✅ PASS (47 tests)

### [x] 1.4 Write DAL Integration Tests
**File**: `Surypus/test/DAL/IntegrationSpec.hs`
- [x] Test CRUD operations for all entities
- [x] Test query combinations and filtering
- [x] Test concurrent access patterns
- [x] Test edge cases (duplicates, invalid IDs, etc.)
**Test Framework**: Hspec + QuickCheck ✅ PASS (105 total DAL tests)

---

## Chunk 2: HR Module Core (People & Organizations)
**Scope**: Person management, relationships, operations
**Purpose**: Enable personnel and organizational structure management

### [ ] 2.1 Implement Person CRUD Operations
**File**: `Surypus/src/HR/Person.hs` (enhance existing)
- [ ] Add smart constructors with validation
- [ ] Implement person status transitions (Active → Inactive → Deleted)
- [ ] Add duplicate detection (by INN/KPP)
- [ ] Create person summary view
**Test**: `Surypus/test/HR/PersonSpec.hs`

### [ ] 2.2 Implement Relations Manager
**File**: `Surypus/src/HR/Relations.hs`
- [ ] Create relation types (Manager, Subordinate, Colleague, etc.)
- [ ] Implement relation lifecycle (create, update, end)
- [ ] Add organizational hierarchy queries
- [ ] Validate relation constraints
**Test**: `Surypus/test/HR/RelationsSpec.hs`

### [ ] 2.3 Add HR Events & Audit Trail
**File**: `Surypus/src/HR/Events.hs` (new)
- [ ] Define HR domain events (PersonCreated, PersonUpdated, RelationChanged)
- [ ] Create event store interface
- [ ] Implement event sourcing for persons
- [ ] Add audit log queries
**Test**: `Surypus/test/HR/EventsSpec.hs`

### [ ] 2.4 HR CRUD API Handlers
**File**: `Surypus/surypus-api/src/Surypus/API/Handlers/HR.hs` (new)
- [ ] GET /persons (with filtering, pagination)
- [ ] GET /persons/{id}
- [ ] POST /persons (create with validation)
- [ ] PUT /persons/{id} (update)
- [ ] DELETE /persons/{id} (soft delete)
- [ ] GET /persons/{id}/relations
**API Tests**: `Surypus/test/API/HRHandlersSpec.hs`

---

## Chunk 3: Inventory Module Core (Goods & Stock)
**Scope**: Product catalog, warehouses, stock tracking
**Purpose**: Enable inventory management and stock operations

### [ ] 3.1 Implement Goods Catalog Management
**File**: `Surypus/src/Inventory/Goods.hs` (complete implementation)
- [ ] Define Goods record with units of measure
- [ ] Implement goods hierarchy (parent-child products)
- [ ] Add barcode/SKU management
- [ ] Create goods status (Active, Discontinued, etc.)
**Test**: `Surypus/test/Inventory/GoodsSpec.hs`

### [ ] 3.2 Implement Warehouse & Location Management
**File**: `Surypus/src/Inventory/Warehouse.hs` (enhance existing)
- [ ] Standardize Location records
- [ ] Create warehouse types (Main, Branch, Return, etc.)
- [ ] Implement location allocation rules
- [ ] Add location capacity constraints
**Test**: `Surypus/test/Inventory/WarehouseSpec.hs`

### [ ] 3.3 Implement Stock Operations
**File**: `Surypus/src/Inventory/StockOps.hs` (new)
- [ ] Create stock movements (Receipt, Issue, Transfer, Adjustment)
- [ ] Implement stock queries (ByLocation, ByGood, Available, Reserved)
- [ ] Add stock level validations and alerts
- [ ] Implement FIFO/LIFO picking logic
**Test**: `Surypus/test/Inventory/StockOpsSpec.hs`

### [ ] 3.4 Inventory CRUD API Handlers
**File**: `Surypus/surypus-api/src/Surypus/API/Handlers/Inventory.hs` (new)
- [ ] GET /goods (with search, filters)
- [ ] POST /goods
- [ ] GET /warehouses (locations)
- [ ] GET /stock/available
- [ ] POST /stock/move (transfer between locations)
- [ ] GET /stock/history
**API Tests**: `Surypus/test/API/InventoryHandlersSpec.hs`

---

## Chunk 4: Commerce Module - Bills & Payments
**Scope**: Invoicing, bills, payment tracking
**Purpose**: Enable transaction recording and financial tracking

### [ ] 4.1 Implement Bill Management Core
**File**: `Surypus/src/Commerce/Bill.hs` (new comprehensive version)
- [ ] Define Bill record (header + lines)
- [ ] Implement bill status workflow (Draft → Posted → Closed)
- [ ] Create bill line items with quantity & pricing
- [ ] Add bill calculations (totals, taxes)
**Test**: `Surypus/test/Commerce/BillSpec.hs`

### [ ] 4.2 Implement Payment Processing
**File**: `Surypus/src/Commerce/Payment.hs` (enhance existing)
- [ ] Create payment methods (Cash, Card, Bank Transfer, etc.)
- [ ] Implement payment status (Pending, Completed, Failed)
- [ ] Add payment reconciliation logic
- [ ] Implement partial payments
**Test**: `Surypus/test/Commerce/PaymentSpec.hs`

### [ ] 4.3 Implement Invoicing Operations
**File**: `Surypus/src/Commerce/Invoicing.hs` (new)
- [ ] Create invoice from order/bill
- [ ] Implement invoice status (Issued, Paid, Overdue, Cancelled)
- [ ] Add tax calculations (VAT, GST, etc.)
- [ ] Create invoice numbering system
**Test**: `Surypus/test/Commerce/InvoicingSpec.hs`

### [ ] 4.4 Commerce CRUD API Handlers
**File**: `Surypus/surypus-api/src/Surypus/API/Handlers/Commerce.hs` (new)
- [ ] GET /bills (with status filter, pagination)
- [ ] POST /bills (create with items)
- [ ] PUT /bills/{id} (update status)
- [ ] POST /bills/{id}/post (finalize)
- [ ] GET /payments (list)
- [ ] POST /payments (record)
**API Tests**: `Surypus/test/API/CommerceHandlersSpec.hs`

---

## Chunk 5: Finance Module - Accounting Core
**Scope**: Chart of accounts, accounting entries, general ledger
**Purpose**: Enable double-entry bookkeeping and financial reporting

### [ ] 5.1 Implement Chart of Accounts
**File**: `Surypus/src/Finance/Account.hs` (enhance existing)
- [ ] Complete AccountClass and AccountNature definitions
- [ ] Add account validation (code format, parent-child rules)
- [ ] Implement account hierarchy traversal
- [ ] Create account summary views
**Test**: `Surypus/test/Finance/AccountSpec.hs`

### [ ] 5.2 Implement Journal Entries
**File**: `Surypus/src/Finance/Journal.hs` (complete implementation)
- [ ] Define JournalEntry with debits & credits
- [ ] Implement entry validation (balanced, non-zero)
- [ ] Add entry posting status
- [ ] Create entry numbering system
**Test**: `Surypus/test/Finance/JournalSpec.hs`

### [ ] 5.3 Implement General Ledger
**File**: `Surypus/src/Finance/Ledger.hs` (new)
- [ ] Create ledger account with running balance
- [ ] Implement transaction history per account
- [ ] Add balance queries (as-of, range)
- [ ] Create trial balance report
**Test**: `Surypus/test/Finance/LedgerSpec.hs`

### [ ] 5.4 Finance CRUD API Handlers
**File**: `Surypus/surypus-api/src/Surypus/API/Handlers/Finance.hs` (new)
- [ ] GET /accounts (chart of accounts)
- [ ] GET /journal (entries list)
- [ ] POST /journal (post entry)
- [ ] GET /ledger/{account-id} (account history)
- [ ] GET /trial-balance (report)
**API Tests**: `Surypus/test/API/FinanceHandlersSpec.hs`

---

## Chunk 6: Sales & CRM Module
**Scope**: Sales orders, CRM deals, customer management
**Purpose**: Enable sales pipeline and customer relationship tracking

### [ ] 6.1 Implement Sales Order Management
**File**: `Surypus/src/Sales/Order.hs` (new)
- [ ] Define Order with items and status
- [ ] Implement order status flow (Pending → Confirmed → Shipped → Completed)
- [ ] Add order pricing & discounts
- [ ] Create order-to-invoice link
**Test**: `Surypus/test/Sales/OrderSpec.hs`

### [ ] 6.2 Implement CRM Deal Management
**File**: `Surypus/src/CRM/Deal.hs` (enhance existing)
- [ ] Define deal stages and pipeline
- [ ] Implement deal probability & forecast
- [ ] Add activity tracking
- [ ] Create deal metrics
**Test**: `Surypus/test/CRM/DealSpec.hs`

### [ ] 6.3 Implement Contact & Lead Management
**File**: `Surypus/src/CRM/Contact.hs` (enhance existing)
- [ ] Standardize contact record
- [ ] Implement contact status (Active, Inactive, etc.)
- [ ] Add contact relationship tracking
- [ ] Create contact communication history
**Test**: `Surypus/test/CRM/ContactSpec.hs`

### [ ] 6.4 Sales & CRM API Handlers
**File**: `Surypus/surypus-api/src/Surypus/API/Handlers/Sales.hs` (new)
- [ ] GET /orders (with filtering)
- [ ] POST /orders (create with items)
- [ ] PUT /orders/{id}/status
- [ ] GET /crm/deals
- [ ] POST /crm/deals
- [ ] GET /crm/contacts
**API Tests**: `Surypus/test/API/SalesHandlersSpec.hs`

---

## Chunk 7: API Layer Cleanup & Documentation
**Scope**: Server implementation, handler organization, API documentation
**Purpose**: Stabilize and document the API surface

### [ ] 7.1 Refactor API Server Structure
**File**: `Surypus/surypus-api/src/Surypus/API/Server.hs`
- [ ] Extract handlers into separate modules (HR, Inventory, Commerce, Finance, Sales)
- [ ] Remove unused imports and unused bindings
- [ ] Add explicit type signatures to all top-level functions
- [ ] Organize middleware (auth, correlation, error handling)
**Tests**: Run `stack build` with no warnings

### [ ] 7.2 Create API Types & Schemas
**File**: `Surypus/surypus-api/src/Surypus/API/Types.hs` (enhance)
- [ ] Define request/response DTOs for all endpoints
- [ ] Add JSON serialization instances
- [ ] Create validation functions for inputs
- [ ] Add Swagger/OpenAPI annotations
**Test**: `Surypus/test/API/TypesSpec.hs`

### [ ] 7.3 Implement Error Handling
**File**: `Surypus/surypus-api/src/Surypus/API/Errors.hs` (new)
- [ ] Define domain error types
- [ ] Create error-to-HTTP mapping
- [ ] Implement structured error responses
- [ ] Add logging and error tracking
**Test**: `Surypus/test/API/ErrorsSpec.hs`

### [ ] 7.4 Add API Documentation
**Files**: 
- `Surypus/API_DOCUMENTATION.md` (new)
- `Surypus/ARCHITECTURE.md` (new)
- [ ] Document all endpoints with examples
- [ ] Create architecture diagrams
- [ ] Add deployment guide
- [ ] Create troubleshooting guide

---

## Chunk 8: System Utilities & Infrastructure
**Scope**: Logging, caching, rate limiting, background jobs
**Purpose**: Add operational capabilities and resilience

### [ ] 8.1 Fix & Enhance Logger Implementation
**File**: `Surypus/src/System/Logger.hs` (was partially fixed)
- [ ] Complete structured logging implementation
- [ ] Add log levels with proper severity
- [ ] Implement rotating file appenders
- [ ] Add contextual logging (correlation IDs)
**Test**: `Surypus/test/System/LoggerSpec.hs`

### [ ] 8.2 Implement Caching Layer
**File**: `Surypus/src/System/Cache.hs` (enhance existing)
- [ ] Complete STM-based cache implementation
- [ ] Add cache invalidation strategies
- [ ] Implement cache statistics
- [ ] Add cache warming on startup
**Test**: `Surypus/test/System/CacheSpec.hs`

### [ ] 8.3 Complete Rate Limiter Implementation
**File**: `Surypus/src/System/RateLimiter.hs` (was partially fixed)
- [ ] Implement sliding window rate limiting
- [ ] Add per-user/per-IP limits
- [ ] Create rate limit headers in responses
- [ ] Add distributed rate limiting support
**Test**: `Surypus/test/System/RateLimiterSpec.hs`

### [ ] 8.4 Create Background Job System
**File**: `Surypus/src/System/JobQueue.hs` (was partially fixed)
- [ ] Complete job queue implementation
- [ ] Add job status tracking
- [ ] Implement retry logic with backoff
- [ ] Create job scheduling
**Test**: `Surypus/test/System/JobQueueSpec.hs`

---

## Chunk 9: Testing Infrastructure & Fixtures
**Scope**: Test utilities, factories, generators
**Purpose**: Enable comprehensive testing across all modules

### [ ] 9.1 Create Test Fixtures Framework
**File**: `Surypus/test/Fixtures.hs` (new)
- [ ] Define reusable test data builders
- [ ] Create factory patterns for domain objects
- [ ] Implement test database setup/teardown
- [ ] Add random data generators
**Test**: Run all existing tests successfully

### [ ] 9.2 Implement Property-Based Testing
**File**: `Surypus/test/Properties.hs` (new)
- [ ] Create Arbitrary instances for domain types
- [ ] Define properties for business rules
- [ ] Add roundtrip serialization properties
- [ ] Implement shrinking strategies
**Test**: `Surypus/test/PropertiesSpec.hs`

### [ ] 9.3 Create API Test Helpers
**File**: `Surypus/test/API/Helpers.hs` (new)
- [ ] Implement request builders
- [ ] Create response validators
- [ ] Add authentication test utilities
- [ ] Create endpoint discovery helpers
**Test**: All API endpoint tests use helpers

### [ ] 9.4 Add Integration Test Suite
**File**: `Surypus/test/IntegrationSpec.hs` (new)
- [ ] Test full workflows (Order → Invoice → Payment)
- [ ] Test multi-domain interactions
- [ ] Add performance tests
- [ ] Test error scenarios and edge cases
**Test Target**: 80%+ coverage

---

## Chunk 10: Documentation & Examples
**Scope**: User guides, API examples, deployment guides
**Purpose**: Enable developers and operators to use the system

### [ ] 10.1 Create API Examples & Postman Collection
**Files**:
- `Surypus/examples/postman-collection.json` (new)
- `Surypus/examples/api-examples.md` (new)
- [ ] Create realistic API call examples for each endpoint
- [ ] Include authentication examples
- [ ] Add error handling examples
- [ ] Create workflow examples (complete order flow)

### [ ] 10.2 Create Developer Setup Guide
**File**: `Surypus/DEVELOPER_GUIDE.md` (new)
- [ ] Environment setup instructions
- [ ] Building and running tests
- [ ] Running the server locally
- [ ] Common development tasks
- [ ] Debugging tips

### [ ] 10.3 Create Architecture & Design Documentation
**File**: `Surypus/ARCHITECTURE.md` (new)
- [ ] System architecture overview
- [ ] Domain model diagrams
- [ ] API structure and conventions
- [ ] Data flow diagrams
- [ ] Decision records (ADRs)

### [ ] 10.4 Create Operational Guides
**Files**:
- `Surypus/DEPLOYMENT.md` (new)
- `Surypus/MONITORING.md` (new)
- [ ] Deployment procedures
- [ ] Configuration guide
- [ ] Monitoring and alerting setup
- [ ] Backup and recovery procedures
- [ ] Troubleshooting guide

---

## Implementation Priority & Dependencies

```
Chunk 1 (Data Layer) 
  ↓
├─→ Chunk 2 (HR)     ├─→ Chunk 6 (Sales/CRM)
├─→ Chunk 3 (Inventory)  ├─→ Chunk 4 (Commerce)
└─→                          └─→ Chunk 5 (Finance)
                                     ↓
                                 Chunk 7 (API)
                                     ↓
                                 Chunk 8 (System Utils)
                                     ↓
                              Chunk 9 (Testing)
                                     ↓
                              Chunk 10 (Docs)
```

## Quality Gates for Each Chunk

- ✅ All tests pass (`stack test`)
- ✅ No compiler warnings (`stack build 2>&1 | grep -i warning`)
- ✅ Code review approval
- ✅ Documentation complete
- ✅ Test coverage ≥ 80%

---

## Timeline Estimate

- **Chunk 1**: 2-3 days (foundation)
- **Chunks 2-6**: 1 week each (domain modules, parallel possible)
- **Chunk 7**: 2 days (API cleanup)
- **Chunk 8**: 3 days (system utils)
- **Chunk 9**: 2 days (testing)
- **Chunk 10**: 2-3 days (documentation)

**Total**: ~6-8 weeks for full implementation
