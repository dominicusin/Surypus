# Surypus ERP — Plan for Autonomous Realization of All Goals

> **Source:** `~/src/Surypus` (local clone of `dominicusin/Surypus`, branch `main`)
> **ORM reference:** pGenie — https://pgenie.io/docs/
> **Goal:** entire ERP is generated from a single versioned DSL; changing the DSL auto-regenerates the ORM, SQL migrations, Datalog/logic layer, GET/POST API, QML UI, and everything else.
> **Created:** August 30, 2026

---

## 0. Deconstructed and Adjusted Goals

Based on repository inspection, here is the definitive goal breakdown:

### Goal 1: DSL-транспилер до статуса CI-артефакта

**Current state:**
- `surypus-codegen` exists at `~/src/Surypus/tools/surypus-codegen/`
- Has `build`, `check`, `migrate`, `version` commands
- `surypus-codegen.cabal`, `surypus-codegen.project` files present
- `src/DAL/Schema.hs`, `src/DAL/Types.hs` generated from `dsl/schema.yaml`
- `sql/migrations/V001__generated_orm.sql` generated
- `.github/workflows/ci.yml` has surypus-codegen steps

**Remaining:**
- Add `freeze` subcommand (generate `surypus.freeze` with hashes)
- Add `diff` subcommand (breaking change detection)
- Add CI gate that blocks PRs with breaking changes
- Add QML code generation
- Add API documentation generation

### Goal 2: Критический бизнес-цикл замкнут

**Current state:**
- `BillEntity`, `BillLineEntity` in DSL
- `src/Commerce/BillLine.hs`, `src/Commerce/Invoice.hs` exist
- `src/Commerce/Commerce.hs` exists (643 lines)
- `src/Finance/**/*.hs` exist (Accounting, Ledger, Tax, etc.)
- `src/DAL/EventStore.hs` exists (10644 lines)
- `src/DAL/MutationsORM.hs` exists (27654 lines)
- `src/DAL/QueriesORM.hs` exists (17727 lines)

**Remaining:**
- `POST /api/v1/bills` endpoint (likely exists in `src/API/Types.hs` or `src/API/API.hs`)
- Refinement validation (theorem_bill_total, amounts_nonnegative, vat_calculated)
- Event emission (BillCreatedEvent)
- Projections to accounting registers
- Audit entry
- Correlation ID propagation

### Goal 3: Периметр безопасности замкнут

**Current state:**
- `src/Surypus/**/*.hs` — unclear if exists
- `Surypus.RBAC`, `Surypus.JWT` — unclear if exists
- `src/API/Types.hs` exists (7209 bytes)
- `src/API/API.hs` exists (655 bytes)

**Remaining:**
- RBAC middleware on all routes
- Hardcoded stubs removal
- Refresh token rotation
- Property tests for RBAC invariants

### Goal 4: Observability-контур замкнут

**Current state:**
- `src/DAL/EventStore.hs` exists (event sourcing infrastructure)
- `src/Infrastructure/**/*.hs` exist (Email, Notification, Backup, etc.)
- `EventBus.hs` exists (1527 bytes)

**Remaining:**
- CircuitBreaker for DB, HTTP clients, worker
- Structured logging with correlation ID
- Correlation ID propagation through event sourcing

### Goal 5: AI-автоматизация патчей заменена тестовым каркасом

**Current state:**
- `test/Main.hs` exists
- `test/APITests.hs` exists
- `test/Integration/` directory exists
- `test/DAL/` directory exists
- `test/Finance/` directory exists
- `test/HR/` directory exists
- `test/Inventory/` directory exists
- `test/Domain/` directory exists
- `Surypus.cabal` has `test-suite surypus-test` with `QuickCheck` dependency

**Remaining:**
- QuickCheck property tests for refinement predicates
- QuickCheck property tests for RBAC policies
- QuickCheck property tests for event sourcing invariants

### Goal 6: Web-фронтенд как канал верификации

**Current state:**
- `frontend/qml/Main.qml` exists
- `frontend/qml/AppState.qml` exists
- `frontend/qml/RestClient.qml` exists
- `frontend/qml/LoginPanel.qml` exists
- `frontend/qml/components/` exists
- `frontend/qml/screens/` exists

**Remaining:**
- QML invoice creation form
- QML invoice view form
- End-to-end scenario

### Goal 7: Job handler'ы поверх существующего диспетчера воркера

**Current state:**
- `src/DAL/Queue.hs` exists (9027 bytes)
- `src/DAL/DB.hs` exists (10629 bytes)

**Remaining:**
- Job handler'ы implemented
- Dispatch logic
- Retry policy
- Dead letter queue

### Goal 8: PayrollService — полная реализация

**Current state:**
- `src/DAL/Payroll.hs` exists (4569 bytes)
- `src/Core/Payroll/**/*.hs` unclear
- `src/HR/**/*.hs` exist (Payroll-related: `src/HR/Salary.hs`, `src/HR/Events.hs`)

**Remaining:**
- PayrollService with event sourcing
- API endpoints for payroll
- Projections
- Validation

### Goal 9: InventoryService — полная реализация

**Current state:**
- `src/DAL/Production.hs` exists (712 bytes)
- `src/DAL/QueriesORM.hs` exists (17727 bytes)
- `src/Inventory/` directory exists (test directory)
- `src/Core/Inventory.hs` exists (541 bytes)

**Remaining:**
- InventoryService with event sourcing
- Reservation logic
- Stock movement logic
- API endpoints

### Goal 10: CI-гейт блокировки breaking changes

**Current state:**
- CI workflow has surypus-codegen steps
- `surypus-codegen check` exists
- `surypus-codegen diff` — not implemented

**Remaining:**
- `surypus-codegen diff` command
- CI gate blocks PRs with breaking changes
- `--allow-breaking` flag for emergencies

### Goal 11: Второй DSL aggregate — проверка обобщаемости

**Current state:**
- `dsl/schema.yaml` has only `PersonEntity`

**Remaining:**
- Add second aggregate (e.g., `Employee` or `InventoryItem`)
- Verify transpiler is generalizable
- Test generated code compiles and works

### Goal 12: Документация refinement-предикатов в DSL

**Current state:**
- DSL schema has only basic fields
- No `refinements` section in DSL

**Remaining:**
- Add `refinements` section to DSL
- Generate documentation from DSL
- Store documentation in repository

### Goal 13: QML codegen для дополнительных форм

**Current state:**
- QML code generation not implemented in surypus-codegen
- Hand-written QML exists in `frontend/qml/`

**Remaining:**
- Add `surypus-codegen qml` command
- Generate QML forms for all entities
- Generate QML list views
- Generate QML models

### Low priority: Расширение ERP доменов

- Production/MRP, CRM, analytics — deferred after MVP

---

## 1. Process Architecture (BMAD → SpecKit → Beads → GSD → Git/CI)

### BMAD (governance layer)
- **`~/.planning/CHARTER.md`** — vision, constraints, acceptance model
- **`~/.planning/initiatives/*.md`** — initiatives

### SpecKit (contract layer)
- **`~/.specify/spec.md`** — requirements, constraints, acceptance criteria for each phase
- **`~/.openspec/changes/<name>/change.md`** — changes

### Beads (state graph)
- **`~/.beads/beads.json`** — task graph with dependencies
- **`~/.beads/metadata.json`** — state
- **`~/.beads/issues.jsonl`** — issue log

### GSD (execution plane)
- **`~/.gsd/plan.md`** — execution plan, real commands and outputs
- **`~/.gsd/phases/<name>/plan.md`** — phase-specific plans

### Git/CI
- Commit changes to Git
- CI runs and verifies
- PR for merge

### Each phase follows this pattern:

1. BMAD: define phase objectives, risks, acceptance criteria
2. SpecKit: document requirements, constraints for the phase
3. Beads: create tasks, dependencies, track status
4. GSD: execute tasks, record real commands and outputs in plan.md
5. Git/CI: commit, verify CI passes, merge

---

## 2. Phase-by-Phase Plan with Goals, Tasks, Dependencies, Timeline

### Phase 0: Foundation and current state assessment (Week 1-2)

**Goals:**
- Understand current repository state
- Verify existing infrastructure works
- Establish baseline for all future work

**Tasks:**
1. Inspect all source directories and understand architecture
2. Verify surypus-codegen compiles and works
3. Verify DSL schema and generated artifacts match
4. Verify CI workflow
5. Inventory existing tests
6. Inventory existing QML frontend
7. Inventory existing event sourcing infrastructure
8. Inventory existing RBAC and JWT implementation
9. Document current state in plan.md

**Dependencies:** none

**Timeline:** Week 1-2

**Acceptance criteria:**
- Surypus-codegen compiles and runs
- DSL schema and generated artifacts verified
- CI workflow verified
- Current state documented

---

### Phase 1: DSL transpiler → CI artifact (Week 1-3)

**Goals:**
- surypus-codegen becomes CI artifact with full feature set
- CI gate blocks breaking changes

**Tasks:**

1. **Add `freeze` command to surypus-codegen:**
   - Generate `surypus.freeze` with DSL hash and artifact hashes
   - Store in repository

2. **Add `diff` command to surypus-codegen:**
   - Detect breaking changes (entity removal, field removal, type changes)
   - Non-breaking changes allowed
   - CI blocks breaking changes without `--allow-breaking`

3. **Enhance CI gate:**
   - Block PRs with breaking changes (without `--allow-breaking`)
   - Verify all generated artifacts match DSL
   - Verify freeze file consistency

4. **Add QML code generation:**
   - Generate QML forms for each entity
   - Generate QML list views
   - Generate QML models

5. **Add API documentation generation:**
   - Generate OpenAPI spec
   - Generate API_DOCUMENTATION.md

6. **Add Datalog generation:**
   - Generate Datalog rules from DSL

**Dependencies:** Phase 0

**Timeline:** Week 1-3

**Acceptance criteria:**
- All commands work (`build`, `check`, `migrate`, `freeze`, `diff`, `version`)
- CI gate blocks breaking changes
- QML code generation works
- API documentation generation works
- Datalog generation works

---

### Phase 2: Critical Business Cycle — Bill Posting Flow (Week 2-5)

**Goals:**
- Bill creation endpoint with validation, event emission, projections, audit
- End-to-end flow works

**Tasks:**

1. **Implement bill creation endpoint:**
   - `POST /api/v1/bills` endpoint
   - Accept `BillCreateRequest` JSON
   - Validate refinement predicates (theorem_bill_total, amounts_nonnegative, vat_calculated)
   - Create bill in database
   - Emit `BillCreatedEvent`
   - Run projections to accounting registers
   - Create audit entry with correlation ID
   - Return created bill with ID

2. **Implement refinement validation:**
   - Theorem: total = sum of lines
   - Theorem: all amounts >= 0
   - Theorem: vat = sum of line vats
   - Use LiquidHaskell predicates or runtime checks

3. **Implement event emission:**
   - Define `BillCreatedEvent` type
   - Emit event to event store
   - Include correlation ID

4. **Implement projections:**
   - Define projection types
   - Accounting projection: debit/credit entries
   - Inventory projection: stock updates, reservations
   - Tax projection: VAT calculations

5. **Implement audit trail:**
   - Define `AuditEntry` type
   - Create audit entry for bill creation
   - Include correlation ID

6. **Implement correlation ID:**
   - Generate correlation ID on request
   - Include in event emission
   - Include in projections
   - Include in audit entries
   - Include in logs

7. **Test end-to-end flow:**
   - Create bill via API
   - Verify event emission
   - Verify projections
   - Verify audit entry
   - Verify correlation ID propagation

**Dependencies:** Phase 1 (DSL transpiler)

**Timeline:** Week 2-5

**Acceptance criteria:**
- `POST /api/v1/bills` works end-to-end
- All refinement predicates enforced
- Event emitted
- Projections created
- Audit entry created
- Correlation ID propagated

---

### Phase 3: Security Perimeter — RBAC + Refresh Tokens (Week 3-6)

**Goals:**
- RBAC middleware on all routes
- Hardcoded stubs removed
- Refresh token rotation stable

**Tasks:**

1. **Analyze current state:**
   - Inspect `src/Surypus/**/*.hs` for RBAC and JWT implementation
   - Identify hardcoded stubs
   - Identify what needs to be fixed

2. **Implement RBAC middleware:**
   - Middleware for all routes
   - Extract JWT from request
   - Validate JWT
   - Check permissions
   - Return 403 if unauthorized

3. **Remove hardcoded stubs:**
   - Replace `Surypus.RBAC` stubs with real implementation
   - Replace `Surypus.JWT` stubs with real implementation

4. **Implement refresh token rotation:**
   - Store refresh tokens in database
   - Generate new refresh token on use
   - Invalidate old refresh token
   - No silent failures

5. **Implement RBAC property tests:**
   - Property: no cross-tenant escalation
   - Property: role permissions are correct

**Dependencies:** Phase 2 (for bill endpoints), Phase 4 (for observability)

**Timeline:** Week 3-6

**Acceptance criteria:**
- RBAC middleware on all routes
- Hardcoded stubs removed
- Refresh token rotation stable
- Property tests pass

---

### Phase 4: Observability Contour — CircuitBreaker + Structured Logging (Week 4-7)

**Goals:**
- CircuitBreaker on all external I/O boundaries
- Structured logging with correlation ID
- Correlation ID propagated through event sourcing

**Tasks:**

1. **Implement CircuitBreaker:**
   - CircuitBreaker type with states: closed, open, half-open
   - CircuitBreaker for database pool
   - CircuitBreaker for HTTP clients
   - CircuitBreaker for worker dispatcher
   - Configurable thresholds and timeouts

2. **Implement structured logging:**
   - JSON format logs
   - Correlation ID in every log entry
   - Log levels: debug, info, warn, error
   - Structured fields: timestamp, level, correlationId, message, fields

3. **Implement correlation ID propagation:**
   - Generate correlation ID on request
   - Include in event emission
   - Include in projections
   - Include in audit entries
   - Include in logs

4. **Integrate with event sourcing:**
   - Correlation ID in event store
   - Correlation ID in event emission
   - Correlation ID in projections

**Dependencies:** Phase 2 (for bill endpoints), Phase 3 (for RBAC)

**Timeline:** Week 4-7

**Acceptance criteria:**
- CircuitBreaker works for all I/O boundaries
- Correlation ID propagated through all layers
- Structured logs with correlation ID
- Metrics collected

---

### Phase 5: Property-based Test Framework (Week 5-8)

**Goals:**
- Replace AI patch automation with systematic test framework
- QuickCheck property tests for refinement predicates, RBAC policies, event sourcing invariants

**Tasks:**

1. **Implement QuickCheck property tests for Invoice refinement predicates:**
   - `prop_invoice_total_equals_sum_lines`
   - `prop_invoice_amounts_nonnegative`
   - `prop_vat_calculated_correctly`
   - `prop_invoice_refund_conserves`

2. **Implement QuickCheck property tests for RBAC policies:**
   - `prop_no_cross_tenant_escalation`
   - `prop_role_permissions_are_subset`

3. **Implement QuickCheck property tests for event sourcing invariants:**
   - `prop_event_replay_deterministic`
   - `prop_event_replay_same_as_fold`
   - `prop_accounting_projection_balance`

4. **Add tests to CI:**
   - Run QuickCheck tests in CI
   - Block PRs if tests fail

5. **Create test documentation:**
   - Document test properties
   - Document test data generators

**Dependencies:** Phase 2 (for bill endpoints), Phase 3 (for RBAC)

**Timeline:** Week 5-8

**Acceptance criteria:**
- All property tests pass
- Tests in CI
- PRs blocked if tests fail

---

### Phase 6: Web Frontend — QML Invoice Scenario (Week 6-9)

**Goals:**
- QML invoice creation form works
- QML invoice view form works
- End-to-end scenario works

**Tasks:**

1. **Implement QML invoice creation form:**
   - Form with fields: code, billType, docStatus, docDate, total, taxAmount
   - Line items list with add/remove/edit
   - Submit button calls `POST /api/v1/bills`
   - Validation feedback

2. **Implement QML invoice view form:**
   - Display bill details
   - Display line items
   - Get data from `GET /api/v1/bills/:id`

3. **Implement QML list of bills:**
   - List of bills
   - Filter and sort capabilities
   - Click to view bill

4. **Integrate with REST client:**
   - Use existing `frontend/qml/RestClient.qml`
   - Call bill creation endpoint
   - Call bill view endpoint
   - Call bills list endpoint

5. **Test end-to-end flow:**
   - Create invoice via QML form
   - View invoice via QML view
   - Verify data in database

**Dependencies:** Phase 2 (for bill endpoints)

**Timeline:** Week 6-9

**Acceptance criteria:**
- QML invoice creation works
- QML invoice view works
- End-to-end flow works

---

### Phase 7: Job Handler'ы (Week 7-9)

**Goals:**
- Job handler'ы implemented on existing worker dispatcher
- Retry policy works
- Dead letter queue works

**Tasks:**

1. **Find existing worker dispatcher:**
   - Inspect `src/DAL/Queue.hs`
   - Inspect `src/DAL/DB.hs`
   - Understand existing infrastructure

2. **Implement job handler'ы:**
   - Define job types: GenerateInvoicePDF, SendInvoiceEmail, ProcessPayment, UpdateInventory, RecalculateTax
   - Implement handler for each job type
   - Dispatch jobs to handlers

3. **Implement retry logic:**
   - Exponential backoff
   - Maximum retry attempts
   - Dead letter queue for failed jobs

4. **Integrate with event sourcing:**
   - Events trigger jobs
   - Jobs processed by worker

5. **Add job monitoring:**
   - Job status tracking
   - Job metrics
   - Failed job alerts

**Dependencies:** Phase 2 (for bill endpoints), Phase 4 (for observability)

**Timeline:** Week 7-9

**Acceptance criteria:**
- Job handler'ы implemented
- Dispatch works
- Retry logic works
- Dead letter queue works
- Event-to-job flow works

---

### Phase 8: PayrollService — Event-Sourced (Week 8-11)

**Goals:**
- PayrollService with event sourcing works
- API for payroll works
- Validation works

**Tasks:**

1. **Extend DSL for payroll:**
   - Add payroll entities (PayrollRun, PayrollEntry, PayrollLine)
   - Add fields: grossAmount, taxAmount, netAmount, status, periodStart, periodEnd, employeeId
   - Add refinement predicates

2. **Implement event sourcing for payroll:**
   - Events: PayrollRunCreated, PayrollEntryAdded, PayrollRunApproved, PayrollRunCompleted, PayrollRunFailed
   - Emit events on state changes

3. **Implement API for payroll:**
   - `POST /api/v1/payroll/runs`
   - `GET /api/v1/payroll/runs/:id`
   - `GET /api/v1/payroll/entries`
   - `POST /api/v1/payroll/approve`

4. **Implement payroll calculations:**
   - Gross amount calculation
   - Tax calculation (NDFL, etc.)
   - Net amount = gross - taxes
   - Validation: all amounts >= 0

5. **Implement payroll projections:**
   - Accounting entries for payroll
   - Payment status tracking

6. **Implement payroll audit:**
   - Audit entries for payroll actions
   - Correlation ID propagation

7. **Implement payroll property tests:**
   - `prop_payroll_net_calculated_correctly`
   - `prop_payroll_amounts_nonnegative`

**Dependencies:** Phase 2 (for bill endpoints), Phase 5 (for property tests)

**Timeline:** Week 8-11

**Acceptance criteria:**
- PayrollService works end-to-end
- All invariants maintained
- Correlation ID propagated

---

### Phase 9: InventoryService — Full Implementation (Week 9-12)

**Goals:**
- InventoryService with event sourcing works
- Reservation logic works
- Stock movement logic works

**Tasks:**

1. **Extend DSL for inventory:**
   - Add inventory entities (StockReservation, StockMovement, StockItem)
   - Add fields: goodsId, locationId, quantity, reservedQuantity, movementType, timestamp, billId
   - Add refinement predicates

2. **Implement event sourcing for inventory:**
   - Events: StockReserved, StockReleased, StockMovementPosted

3. **Implement API for inventory:**
   - `POST /api/v1/inventory/reserve`
   - `POST /api/v1/inventory/release`
   - `POST /api/v1/inventory/move`
   - `GET /api/v1/inventory/stock/:goodsId`
   - `GET /api/v1/inventory/reservations`

4. **Implement stock reservation:**
   - Reserve stock for bill
   - Release reservation on bill cancellation
   - Verify reservation quantity <= available quantity

5. **Implement stock movement:**
   - Receipt: increase stock
   - Issue: decrease stock
   - Transfer: move between locations

6. **Implement inventory projections:**
   - Update stock quantities
   - Update reservation status
   - Maintain inventory balance

7. **Implement inventory audit:**
   - Audit entries for inventory actions
   - Correlation ID propagation

8. **Implement inventory property tests:**
   - `prop_inventory_reservation_quantity_nonnegative`
   - `prop_inventory_movement_quantity_nonnegative`
   - `prop_inventory_balance_never_negative`

**Dependencies:** Phase 2 (for bill endpoints), Phase 5 (for property tests)

**Timeline:** Week 9-12

**Acceptance criteria:**
- InventoryService works end-to-end
- Reservation logic correct
- Movement logic correct
- All invariants maintained
- Correlation ID propagated

---

### Phase 10: CI Gate — Breaking Changes (Week 10-12)

**Goals:**
- CI gate blocks breaking changes
- Emergency override available

**Tasks:**

1. **Implement breaking change detection:**
   - Detect entity removal
   - Detect field removal
   - Detect type changes
   - Detect enum changes

2. **Implement CI gate:**
   - Add `surypus-codegen diff` command
   - Compare current schema with previous schema
   - Block PRs with breaking changes
   - Allow `--allow-breaking` for emergencies

3. **Test breaking change detection:**
   - Test entity removal detection
   - Test field removal detection
   - Test type change detection
   - Test non-breaking changes allowed

**Dependencies:** Phase 1 (for DSL transpiler)

**Timeline:** Week 10-12

**Acceptance criteria:**
- Breaking changes detected
- PRs blocked
- Emergency override available

---

### Phase 11: Second DSL Aggregate — Generalisability (Week 11-13)

**Goals:**
- Second aggregate added to DSL
- Transpiler is generalisable

**Tasks:**

1. **Add InventoryItem to DSL:**
   - Define InventoryItem entity
   - Add fields: itemId, code, name, description, unitId, categoryId, quantity, minStock, maxStock, weight, volume, locationId, status
   - Add refinement predicates

2. **Verify transpiler generalisability:**
   - Run `surypus-codegen build` with new aggregate
   - Verify generated code compiles
   - Verify generated code works
   - Remove aggregate and verify transpiler still works

3. **Test generated code:**
   - Compile generated code
   - Run tests
   - Verify functionality

**Dependencies:** Phase 1 (for DSL transpiler), Phase 10 (for CI gate)

**Timeline:** Week 11-13

**Acceptance criteria:**
- Second aggregate added to DSL
- Transpiler generates code for new aggregate
- Generated code compiles and works
- Transpiler is generalisable

---

### Phase 12: Documentation of Refinement Predicates (Week 12-13)

**Goals:**
- Refinement predicates documented in DSL
- Documentation generated from DSL
- Documentation accessible to non-technical stakeholders

**Tasks:**

1. **Add refinement predicates to DSL:**
   - Document each predicate in DSL schema
   - Include description, formula, LiquidHaskell annotation

2. **Generate documentation:**
   - Add `surypus-codegen doc` command
   - Generate Markdown documentation
   - Include all refinement predicates

3. **Store documentation in repository:**
   - Store in `docs/refinements.md`
   - Update with each schema change

**Dependencies:** Phase 1 (for DSL transpiler), Phase 11 (for second aggregate)

**Timeline:** Week 12-13

**Acceptance criteria:**
- Refinement predicates documented in DSL
- Documentation generated from DSL
- Documentation accessible to non-technical stakeholders

---

### Phase 13: QML Code Generation — Beyond MVP (Week 12-14)

**Goals:**
- QML forms generated for all entities
- Forms work and integrated into frontend

**Tasks:**

1. **Add QML code generation to transpiler:**
   - `surypus-codegen qml` command
   - Generate QML forms for each entity
   - Generate QML list views
   - Generate QML models

2. **Generate forms for all entities:**
   - PersonForm, PersonList, PersonModel
   - GoodsForm, GoodsList, GoodsModel
   - BillForm, BillList, BillModel
   - InvoiceForm, InvoiceList, InvoiceModel
   - EmployeeForm, EmployeeList, EmployeeModel
   - And more...

3. **Integrate with frontend:**
   - Generated forms in `frontend/qml/generated/`
   - Import in `frontend/qml/Main.qml`
   - Wire up navigation

**Dependencies:** Phase 1 (for DSL transpiler), Phase 11 (for second aggregate)

**Timeline:** Week 12-14

**Acceptance criteria:**
- QML forms generated for all entities
- Forms compile and work
- Forms integrated into frontend

---

## 3. Risk Register

| Risk | Severity | Mitigation |
|------|----------|------------|
| Surypus-codegen doesn't compile or run | Critical | Verify build before proceeding; fix compilation errors first |
| DSL schema doesn't match existing database | High | Use existing DDL to reverse-engineer DSL schema; verify generated DDL matches |
| RBAC/JWT implementation is stub or non-existent | High | Inspect `src/Surypus/**/*.hs`; if stubs, implement from scratch |
| Event sourcing infrastructure incomplete | High | Inspect `src/DAL/EventStore.hs`; if incomplete, implement basic event store first |
| QML/REST client infrastructure incomplete | Medium | Inspect `frontend/qml/`; if incomplete, implement basic infrastructure first |
| QuickCheck tests cannot be run in CI | Medium | Configure CI to run QuickCheck tests; if not possible, run locally and document |
| Breaking change detection is too strict or too lenient | Medium | Test breaking change detection with various changes; adjust as needed |
| Second aggregate doesn't prove generalisability | Medium | Choose aggregate that is structurally different from first; if fails, try different aggregate |

---

## 4. Process Architecture Integration

For each phase, the BMAD→SpecKit→Beads→GSD→Git/CI pattern applies:

### BMAD (governance layer)
- Define phase objectives, risks, acceptance criteria
- Document in `~/.planning/initiatives/<phase>.md`

### SpecKit (contract layer)
- Document requirements, constraints, acceptance criteria for the phase
- Document in `~/.specify/<phase>/spec.md`

### Beads (state graph)
- Create tasks for the phase
- Define dependencies
- Track status in `~/.beads/beads.json`

### GSD (execution plane)
- Execute tasks
- Record real commands and outputs in `~/.gsd/phases/<phase>/plan.md`
- Verify completion

### Git/CI
- Commit changes to Git
- CI runs and verifies
- PR for merge
- Merge when CI passes

---

## 5. State Verification

Before starting each phase, verify:

1. Surypus-codegen compiles and runs
2. DSL schema is valid
3. Generated artifacts match DSL
4. CI passes
5. Tests pass
6. QML frontend works (if applicable)
7. API endpoints work (if applicable)

---

## 6. Blockers and Mitigations

### Blocker 1: Surypus-codegen doesn't compile or run
- **Impact:** All phases blocked
- **Mitigation:** Verify build; fix compilation errors; if unfixable, document workaround

### Blocker 2: DSL schema doesn't match existing database
- **Impact:** Generated DDL won't match existing schema
- **Mitigation:** Use existing DDL to reverse-engineer DSL; verify generated DDL matches; if mismatch, reconcile

### Blocker 3: RBAC/JWT implementation is stub or non-existent
- **Impact:** Goal 3 can't be achieved
- **Mitigation:** Inspect `src/Surypus/**/*.hs`; if stubs, implement from scratch

### Blocker 4: Event sourcing infrastructure incomplete
- **Impact:** Goals 2, 8, 9 can't be achieved
- **Mitigation:** Inspect `src/DAL/EventStore.hs`; if incomplete, implement basic event store first

### Blocker 5: QML/REST client infrastructure incomplete
- **Impact:** Goal 6 can't be achieved
- **Mitigation:** Inspect `frontend/qml/`; if incomplete, implement basic infrastructure first

### Blocker 6: QuickCheck tests cannot be run in CI
- **Impact:** Goal 5 can't be fully achieved
- **Mitigation:** Configure CI to run QuickCheck tests; if not possible, run locally and document

---

## 7. Verification Gates

Each phase must pass:

1. Code compiles
2. Tests pass
3. CI passes
4. Generated artifacts match DSL
5. Breaking changes detected
6. End-to-end flows work (if applicable)

---

## 8. Summary

This plan provides a comprehensive, detailed roadmap for autonomous realization of all Surypus ERP goals. Each phase has:

- Clear objectives
- Specific tasks
- Dependencies
- Timeline
- Acceptance criteria
- Risks and mitigations

The plan respects the process architecture (BMAD→SpecKit→Beads→GSD→Git/CI) and provides for continuous verification throughout implementation.

The plan starts with foundation and current state assessment, then moves through incremental phases, each building on the previous. The final phases address long-term goals like second aggregate generalisability, documentation, and QML code generation.

All goals from the original request are addressed:

1. ✅ DSL transpiler → CI artifact (Phase 1)
2. ✅ Critical business cycle closed (Phase 2)
3. ✅ Security perimeter closed (Phase 3)
4. ✅ Observability contour closed (Phase 4)
5. ✅ AI patch automation replaced by test framework (Phase 5)
6. ✅ Web frontend as verification channel (Phase 6)
7. ✅ Job handlers on worker dispatcher (Phase 7)
8. ✅ PayrollService event-sourced (Phase 8)
9. ✅ InventoryService full implementation (Phase 9)
10. ✅ CI gate blocking breaking changes (Phase 10)
11. ✅ Second DSL aggregate for generalisability (Phase 11)
12. ✅ Documentation of refinement predicates in DSL (Phase 12)
13. ✅ QML code generation beyond MVP (Phase 13)

Low-priority: ERP domain expansion (production/MRP, CRM, analytics) deferred after MVP.