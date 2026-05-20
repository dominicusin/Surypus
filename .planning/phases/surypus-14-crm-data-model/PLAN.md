# Phase 14: CRM Data Model - Plan

## Phase Boundary
Implement contacts, companies, and deal pipeline with forecasting.

Requirements: CRM-01, CRM-02, CRM-03, CRM-04, CRM-05, CRM-06, CRM-07

Success Criteria:
- Contacts and companies CRUD works via API
- Deals progress through 5-7 pipeline stages
- Pipeline forecast shows probability-weighted revenue
- All CRM changes logged to EventStore

## Plans

### Plan 14-01 (Wave 1): DB migrations + domain types
**Objective:** Establish database schema and Haskell domain types for CRM entities.
**Files:**
- `sql/migrations/V182__crm_companies_contacts.sql` (already exists)
- `src/CRM/*.hs` (ensure types align with DB schema)
- `Surypus.cabal` (update if new modules exposed)

**Tasks:**
1. Verify existing migration V182 matches desired schema for companies, contacts, pipeline rules, deal stage history.
2. Ensure CRM domain types (Contact, Company, Deal, Activity, PipelineStage) are defined and have appropriate fields.
3. Add any missing fields or constraints to align Haskell types with DB schema.
4. Update Surypus.cabal if new CRM modules need to be exposed.

### Plan 14-02 (Wave 2): API CRUD for contacts/companies + fix stubs
**Objective:** Implement REST API endpoints for contacts and companies CRUD operations.
**Files:**
- `surypus-api/src/Surypus/API/CRM.hs` (new or existing)
- `surypus-api/src/Surypus/API/Server.hs` (register API routes)

**Tasks:**
1. Define Servant API types for contacts and companies (CRUD: create, read, update, delete, list).
2. Implement handlers that interact with DAL layer (to be created or existing).
3. Wire API routes into Server.hs.
4. Ensure proper error handling and validation.
5. Fix any existing stubs in the API layer.

### Plan 14-03 (Wave 3): RBAC permissions + event sourcing
**Objective:** Secure CRM API with role-based access control and log changes to event store.
**Files:**
- `src/Surypus/RBAC.hs` (define permissions for CRM)
- `src/Surypus/Authorization.hs` (middleware or helper functions)
- `src/DAL/EventStore/CRM.hs` (event sourcing logic for CRM entities)
- `surypus-api/src/Surypus/API/Server.hs` (apply auth middleware)

**Tasks:**
1. Define CRM-specific permissions (e.g., createContact, deleteCompany, etc.) in RBAC.hs.
2. Implement authorization checks in API handlers using Authorization.hs.
3. Implement event sourcing: for each CRM change (create, update, delete), append an event to the event store via DAL.EventStore.CRM.
4. Ensure events include relevant data for audit trail.
5. Integrate auth middleware in Server.hs to protect CRM endpoints.

### Plan 14-04 (Wave 4): Pipeline forecast refresh + stage rules + history
**Objective:** Implement deal pipeline stages, forecasting logic, and stage transition history.
**Files:**
- `src/CRM.hs` (core pipeline and forecast logic)
- `surypus-api/src/Surypus/API/Server.hs` (pipeline-related API endpoints)

**Tasks:**
1. Define pipeline stages (5-7 stages) with entry/exit criteria in CRM.hs.
2. Implement functions to move deals between stages, validating criteria.
3. Implement probability-weighted revenue forecast: sum over deals (amount * probability_by_stage).
4. Create API endpoints to retrieve pipeline stages, forecast, and stage history.
5. Ensure stage transitions are logged to crm_deal_stage_history table (via event sourcing or direct DAL).

### Plan 14-05 (Wave 5): Domain + integration tests
**Objective:** Verify CRM functionality with domain and integration tests.
**Files:**
- `test/Domain/CRMSpec.hs` (unit tests for domain logic)
- `test/Integration/CRMSpec.hs` (API integration tests)

**Tasks:**
1. Write domain tests for CRM types: validation, stage transitions, forecast calculations.
2. Write integration tests that spin up a test server and test CRM API endpoints (CRUD, pipeline, forecast).
3. Use testcontainers or temporary PostgreSQL for isolation.
4. Ensure tests cover success and failure cases.
5. Run tests to confirm they pass.

## Verification
Each plan should be verified by:
- Running `stack build` to ensure no compilation errors.
- Running relevant tests (`stack test --test-arguments="-m 'plan-14-*'"` or similar).
- Manual inspection of API endpoints (if applicable).
- Checking that success criteria are met.

## Dependencies
- Plan 14-01 must be completed before 14-02 (API needs DB schema).
- Plan 14-03 depends on 14-02 (API endpoints to secure).
- Plan 14-04 depends on 14-01 and 14-03 (pipeline logic and auth).
- Plan 14-05 depends on all previous plans (tests for implemented features).
