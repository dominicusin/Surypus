[⚠️ НЕ ОЧИЩАТЬ — посмотреть, что там]

Я проверил два файла, которые приリモート fetched. Возникла проблема с тем, что `read_file` иногда добавляет префиксы `21|`, `22|` к строкам — это артефакт инструмента, нужно чистить есть два файла:

Первый файл — strage_analysis_pgenie_plan.md, тут был конфликт с тем, что `read_file` добавляет префиксы к строкам. Я препорный образец, который показывает как всё устроено.

Файл highly состоящий из многих yaml-сущностей, в т.ч. с документацией (refinements, events, audit).

Доменная модель как в Haskell: есть покрытие, есть ресурсы. Переменные инструменты — управляемые средства.

Proceed from there in the plan: single source of truth, versioned YAML goes through pgenie, surypus-codegen emits Schema.hs, Types.hs, SQL migrations (real SQL this time, not Haskell TH pasted inside a .sql file). CI gate blocks breaking changes. QML-codegen extends form generation beyond MVP.

The user wants me to implement all objectives autonomously, adjusting and supplementing goal-setting. Based on the inputs:

**High priority goals:**
1. DSL transpiler → CI artifact (build/check/freeze/CI gate - DONE)
2. Critical business loop - bill posting flow → validation → event → projections → audit
3. Security perimeter - RBAC middleware + stable refresh tokens
4. Observability contour - CircuitBreaker + structured logging + correlation ID
5. Replace AI patch automation with QuickCheck test framework
6. Web frontend as verification channel (QML invoice scenario)
7. Job handlers on existing worker dispatcher
8. PayrollService - full implementation with event-sourced payroll model
9. InventoryService - full implementation with reservation + stock movement
10. Surypus-gen → mandatory CI gate blocking breaking changes
11. Extend DSL to second domain aggregate (InventoryItem/Employee)
12. Document refinement predicates as part of DSL schema
13. QML codegen for additional forms beyond MVP
14. Expand ERP domains: production/MRP, CRM, analytics/reporting

**Architecture decision:** BMAD → Spec Kit → Beads → GSD → Git/CI layered agent discipline. New agent extends existing graph, not plan from scratch.

**Current state assessment (based on local repo evidence):**
- DSL transpiler: BUILD PASSES, CHECK PASSES, MIGRATE generates SQL (but migration SQL had issue - generated Haskell TH code inside .sql, needs fixing to produce real SQL)
- `src/DAL/Schema.hs` and `src/DAL/Types.hs` - generated from dsl/schema.yaml
- .github/workflows/ci.yml - modified to add surypus-codegen steps
- IMPLEMENTATION_PLAN.md - created (46KB, 14 phases)
- `surypus-codegen.cabal` - standalone package for standalone tool
- `beads.lock` = e88a57c (commit hash)

**Key fixes needed right now:**
- Migration SQL generation currently outputs Haskell TH code ({-# LANGUAGE ...), not real SQL

**Plan phases (14 total):**

Phase 0: Process architecture and framework (1 week)
- .planning/CHARTER.md, initiatives/
- .specify/ templates
- .beads/ beads.json, metadata.json, issues.jsonl
- .gsd/plan.md templates

Phase 1: DSL transpiler → CI artifact (2-3 weeks)
- freeze subcommand (surypus.freeze)
- CI gate (DSL→generated consistency)
- breaking change detection (compare schemas, reject incompatible)

Phase 2: Bill Posting Flow (3-4 weeks)
- POST /api/v1/bills (or invoices)
- refinement validation (theorem_bill_total, amounts_nonnegative, vat_calculated)
- emission event (BillPostedEvent)
- projection to accounting registers (debit/credit)
- audit entry with correlation ID
- verification via QML

Phase 3: Security perimeter - RBAC + refresh tokens (2-3 weeks)
- route inventory from API_DOCUMENTATION.md
- RBAC middleware on all routes
- refactor Surypus.RBAC (remove hardcoded stubs)
- refactor Surypus.JWT (remove fake-refresh-token, real rotation)
- integration tests (403 for unauthorized, rotate for refresh)

Phase 4: Observability - CircuitBreaker + correlation ID (2 weeks)
- CircuitBreaker on DB pool, HTTP clients, worker dispatcher
- correlation ID through API → event → projection → audit
- structured logging (JSON format with correlation_id)

Phase 5: QuickCheck test framework (3-4 weeks)
- Invoice refinement predicates (total == sum(lines), amounts >= 0, VAT calculated, refund conservation)
- RBAC policies (no cross-tenant escalation, permission store consistency)
- event sourcing replay (idempotent, deterministic)
- CI integration (stack test with quickcheck flag)

Phase 6: Web frontend as verification channel (2-3 weeks)
- QML invoice creation form
- QML invoice list/details
- end-to-end scenario: create bill via QML → API → DB (bill + event + projections + audit)
- verify DSL→ORM→API→QML chain works

Phase 7: Job handlers on worker dispatcher (2-3 weeks)
- find existing worker dispatcher skeleton
- implement handlers for business events (BillPosted → notification, report generation)
- event store integration (event → job → result)
- tests (property: job executes correctly, integration: event → job → result)

Phase 8: PayrollService (4-5 weeks)
- DSL: add payroll entities
- event sourcing (PayrollRunStarted, PayrollRunCompleted, PayrollEntryCalculated)
- refinement validation (salary >= 0, NDFL <= amount, net = gross - deductions)
- API (POST payroll/runs, GET payroll/runs/:id, GET payroll/employees/:id/history)
- projections (employee payroll records, finance integration)
- QuickCheck for payroll (amounts, validation)

Phase 9: InventoryService (4-5 weeks)
- DSL: add inventory entities
- stock movement (received, issued, moved)
- reservation (StockReservation → bill confirmation → issue, cancellation → release)
- refinement (available >= 0, reserved <= quantity, sum(reservations) <= quantity)
- API (POST inventory/reserve, POST inventory/issue, GET inventory/items/:id, GET inventory/movements)
- projections + audit
- QuickCheck for inventory invariants

Phase 10: CI gate - blocking breaking changes (1-2 weeks)
- compare schema across PR: remove entities/fields, type changes, enum changes = breaking
- CI blocks merge on breaking, allows non-breaking
- `--allow-breaking` flag for emergencies

Phase 11: Second DSL aggregate (2 weeks)
- add InventoryItemEntity to dsl/schema.yaml
- surypus-codegen build → generated code works
- verify generalisability (add → build → compiles + tests pass; remove → build → compiles without it)

Phase 12: Refinement predicate documentation in DSL (1 week)
- extend dsl/schema.yaml with refinements section per entity
- surypus-codegen doc → generates Markdown from DSL
- store in docs/refinements.md, CI verification

Phase 13: QML codegen beyond MVP (2-3 weeks)
- add surypus-codegen qml subcommand
- generate QML forms per entity (create, edit, list)
- styles integration with AppState.qml
- verify: generated form → API → DB (end-to-end)

Phase 14: ERP domain expansion (Low priority, long-term)
- production/MRP, CRM, analytics domains added to DSL
- each domain = phase 11 pattern: add entities → codegen → implement → test
- prioritization: Inventory (done), Payroll (done), CRM, Production/MRP, BI/reporting

**Dependencies and parallelization:**
- Phases 0, 1 independent
- After phase 1: 2, 3, 4, 5 can run in parallel
- Phase 6 depends on 2, 3
- Phase 10 depends on 1
- After phase 1: 7, 8, 9, 11, 12, 13 can run in parallel
- Phase 14 depends on all (domains built on base)

**Pre-existing work:**
- [x] DSL transpiler build/check/migrate working
- [x] CI gate added
- [x] IMPLEMENTATION_PLAN.md (46KB, 14 phases)
- [x] process-architecture.md (BMAD/SpecKit/GSD/Beads stack)
- [x] beads.lock = e88a57c
- [x] strategic_analysis_pgenie_plan.md (459 lines)
- [x] dsl/schema.yaml (54 entities)
- [x] surypus-codegen.cabal
- [ ] Migration SQL generation producing real SQL (not Haskell TH)

**Immediate next actions (continue autonomously):**
1. Fix migration SQL generation to produce real SQL syntax (not Haskell TH pasted in .sql file)
2. Rebuild surypus-codegen, run build+check+migrate+verify
3. Phase 0: .planning/CHARTER.md, .specify/ templates, .beads/ structure
4. Continue with plan phases in order (or parallelize post-phase-1)

I'll control this autonomously — continue with phases without asking for confirmation each step, unless (a) blocking issue, (b) user says stop, or (c) asks a question.

For execution now: I'll fix the migration SQL issue first (it's incorrectly outputting Haskell TH code inside .sql file — that's a bug that needs fixing before CI can pass), then rebuild and verify, then proceed with Phase 0.