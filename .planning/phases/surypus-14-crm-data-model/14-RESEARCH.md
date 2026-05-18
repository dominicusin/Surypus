# Phase 14: CRM Data Model - Research

**Researched:** 2026-05-18
**Domain:** Customer Relationship Management data model, event sourcing, pipeline forecasting
**Confidence:** HIGH

## Summary

The codebase already has a partial CRM implementation: a DB migration (`V181__crm_schema.sql`) creates `crm_pipeline_stages`, `crm_deals`, and `crm_activities` tables, and `Surypus.API.CRM` provides Deal/Activity types with list/get/create queries wired into `Surypus.API.Server`. However, several critical pieces are missing: **contacts and companies tables** (the schema references `companies(id)` and `persons(id)` but only `persons` exists), **event sourcing for CRM**, **RBAC permissions for CRM**, **entry/exit criteria for pipeline stage transitions**, **contact/company search**, and **forecast materialized view refresh**. All integration patterns are well-established in the existing codebase: Hasql for DB access, Servant for API, `DAL.EventStore` for event sourcing (with `Infrastructure.EventStore.*` wrappers), and `Surypus.RBAC` for permission checks.

### Primary recommendation
Follow the established patterns from Inventory and Accounting: create domain types in `src/CRM/`, API types (Aeson) in `surypus-api/src/Surypus/API/CRM.hs` (extending existing module), SQL migrations in `sql/migrations/`, event store wrapper in `src/Infrastructure/EventStore/CRM.hs`, and RBAC permissions added to `Surypus.RBAC`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Contact/Company CRUD | API / Backend | Database / Storage | Core business logic - REST endpoints with DB persistence |
| Deal Pipeline | API / Backend | — | State machine with stage transitions, probability-weighted forecast |
| Event sourcing (audit) | Database / Storage | API / Backend | All CRM changes append to event_store; API layer calls EventStore |
| Pipeline forecast | Database / Storage | — | Materialized view computed from deals + stages; periodic refresh |
| Activity logging | API / Backend | Database / Storage | Nested under deal/contact resources; simple CRUD with event audit |
| RBAC enforcement | API / Backend | — | Permission checks in Servant handlers via Authorization middleware |
| WebSocket notifications | API / Backend | — | Broadcast CRM events to "crm" room on create/update/delete |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| hasql | 1.6+ | Type-safe PostgreSQL queries | Existing project standard - all DB access via hasql Statements |
| servant | 0.20 | REST API routing | Existing - API defined with Servant type-level DSL in Server.hs |
| aeson | 2.2+ | JSON encoding/decoding | Existing - deriveJSON or Generic for all API types |
| hasql-pool | 0.10 | Connection pooling | Existing - DAL.Database wraps Pool.acquire/use/release |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| hasql-decoders | (in hasql) | Row decoders (D.column) | Every DB read operation |
| aeson | 2.2+ | event_data JSONB encoding | Event sourcing payloads |
| websockets | 0.12 | Real-time event broadcast | Optional - for WebSocket notifications |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw hasql Statements | Persistent/Beam ORM | Hasql is existing standard; ORM would be inconsistent |
| Servant | Scotty | Servant is existing standard with type-level API safety |

**Version verification:**
```bash
# hasql - existing dependency in Surypus.cabal
# servant, aeson, hasql-pool - all in Surypus.cabal
# GHC 9.6.5 via stack resolver lts-22.21
```
[VERIFIED: Surypus.cabal and stack.yaml]

## Architecture Patterns

### System Architecture Diagram

```
                         ┌──────────────────────┐
                         │     HTTP Client       │
                         │  (REST API Consumer)   │
                         └──────┬───────────────┘
                                │
                         ┌──────▼───────────────┐
                         │  Auth Middleware      │
                         │  (Surypus.API.Server) │
                         │  JWT + RBAC check     │
                         └──────┬───────────────┘
                                │
                         ┌──────▼───────────────┐
                         │  Servant Router       │
                         │  api/v1/crm/*        │
                         └──────┬───────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                  │
     ┌────────▼────────┐ ┌─────▼──────┐  ┌───────▼───────┐
     │ Contact/Company  │ │ Deal       │  │ Activity      │
     │ CRUD Handler     │ │ Pipeline   │  │ Logging       │
     │ (Surypus.API.CRM)│ │ (CRM.hs)   │  │ (CRM.hs)      │
     └────────┬─────────┘ └─────┬──────┘  └───────┬───────┘
              │                 │                  │
     ┌────────▼─────────────────▼──────────────────▼───────┐
     │              DAL Layer (hasql Statements)           │
     │  DAL.Queries (reads) + DAL.Mutations (writes)       │
     └────────┬──────────────────────────┬─────────────────┘
              │                          │
     ┌────────▼────────┐       ┌─────────▼────────┐
     │  Event Store    │       │  PostgreSQL       │
     │  (DAL.EventStore│       │  ┌─────────────┐  │
     │   + CRM wrapper)│       │  │ crm_* tables│  │
     │  events via     │       │  ├─────────────┤  │
     │  event_store    │       │  │ mv_crm_     │  │
     │  append-only    │       │  │ forecast    │  │
     └─────────────────┘       │  └─────────────┘  │
                               └──────────────────┘
```

### Recommended Project Structure

**New modules to create (in src/):**
```
src/
├── CRM/                          # CRM domain types
│   ├── Contact.hs                # Contact data type, validation
│   ├── Company.hs                # Company data type, validation  
│   ├── Deal.hs                   # Deal, DealStage, pipeline transitions
│   ├── Activity.hs               # Activity (call, meeting, note) types
│   └── Pipeline.hs               # Forecast, stage criteria logic
├── Infrastructure/
│   └── EventStore/
│       └── CRM.hs                # CRMEvent + event store wrapper (pattern: Infrastructure.EventStore.Accounting)
└── ...
```

**Files to extend/update:**
```
surypus-api/src/Surypus/API/
├── CRM.hs                        # EXTEND - add Contact, Company types + handlers
├── Server.hs                     # EXTEND - add contact/company routes
├── ...

src/
├── Surypus/
│   ├── RBAC.hs                   # EXTEND - add CRM permissions
│   ├── API/
│   │   └── Authorization.hs      # EXTEND - add CRM path→permission mapping
│   └── WebSocket.hs              # EXTEND - add broadcastToCRMRoom

src/DAL/Queries.hs                # EXTEND - add CRM queries (or create DAL.CRM)
src/DAL/Mutations.hs              # EXTEND - add CRM mutations

sql/migrations/
├── V182__crm_companies_contacts.sql   # NEW - companies + contacts tables
├── V183__crm_event_types.sql          # NEW - register CRM event types
└── V184__crm_forecast_refresh.sql     # NEW - periodic forecast refresh
```

### Pattern 1: Domain Data Types (no Aeson instances)
**What:** Pure domain types with no JSON serialization concerns - mirrors Inventory.Stock, Finance.Types, HR.Person.
**When to use:** For the `src/CRM/` modules that define business types used in business logic.

```haskell
-- Source: Inventory.Stock pattern (src/Inventory/Stock.hs)
data Stock = Stock
  { sGoodsId :: Int64,
    sLocationId :: Int64,
    sQtty :: Double,
    sResrvQtty :: Double,
    ...
  } deriving (Show, Eq)
```
[CITED: src/Inventory/Stock.hs]

### Pattern 2: API/DAL Types (Aeson deriving Generic)
**What:** API-facing types that use `deriving (Generic)` + standalone `instance ToJSON/FromJSON` - mirrors DAL.Types.
**When to use:** For types exposed through the REST API.

```haskell
-- Source: DAL.Types pattern (src/DAL/Types.hs)
data Deal = Deal
  { dealId :: !Int64,
    dealName :: !Text,
    dealValue :: !Double,
    ...
  } deriving stock (Show, Eq, Generic)

instance ToJSON Deal
instance FromJSON Deal
```
[CITED: src/DAL/Types.hs line 44-60, 86-87]

### Pattern 3: Hasql Row Decoders
**What:** Applicative-style row decoders for reading DB rows - mirrors DAL.Queries.
**When to use:** Any time you read from the database.

```haskell
-- Source: DAL.Queries pattern (surypus-api/src/Surypus/DAL/Queries.hs line 78-88)
personRowDecoder :: D.Row Person
personRowDecoder =
  Person
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.text)
    ...
```
[CITED: surypus-api/src/Surypus/DAL/Queries.hs]

### Pattern 4: Event Store Wrapper
**What:** Domain-specific event store that wraps `DAL.EventStore` - mirrors Infrastructure.EventStore.Accounting.
**When to use:** For event-sourcing CRM operations.

```haskell
-- Source: Infrastructure.EventStore.Accounting pattern (src/Infrastructure/EventStore/Accounting.hs)
data CRMEvent
  = ContactCreatedEvent ContactCreated
  | DealStageChangedEvent DealStageChanged
  | ActivityLoggedEvent ActivityLogged
  deriving (Show, Eq, Generic)

$(deriveJSON defaultOptions ''CRMEvent)

getEventInfo :: CRMEvent -> (Int64, Text, Text)
getEventInfo (ContactCreatedEvent ev) = (ccContactId ev, "crm_contact", "ContactCreated")

appendCRMEvent :: AccountingEventStore -> CRMEvent -> IO (Either Text ())
appendCRMEvent store event = do
  let (aggId, aggType, evType) = getEventInfo event
  latestSeqRes <- ES.getLatestSequence (cesPool store) aggId aggType
  case latestSeqRes of
    Left err -> pure $ Left err
    Right latestSeq ->
      ES.appendEvent (cesPool store) aggId aggType evType 1 (toJSON event) Nothing (latestSeq + 1)
```
[CITED: src/Infrastructure/EventStore/Accounting.hs lines 38-168]

### Pattern 5: API Handler with Servant + QueryResult
**What:** Handler pattern using `liftIO + Pool -> QueryResult -> throwError err500` - mirrors Surypus.API.Server.
**When to use:** For all API endpoint handlers.

```haskell
-- Source: Surypus.API.Server pattern (surypus-api/src/Surypus/API/Server.hs lines 162-167)
crmDealsList :: Env -> Handler [CRM.Deal]
crmDealsList env = do
  result <- liftIO $ CRM.listDeals (envPool env)
  case result of
    QuerySuccess deals -> pure deals
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "CRM error: " <> TL.fromStrict err}
```
[CITED: surypus-api/src/Surypus/API/Server.hs]

### Anti-Patterns to Avoid
- **Mixing domain and API types**: Keep domain types (no Aeson) in `src/CRM/` and API types (Aeson) in `surypus-api/src/Surypus/API/CRM.hs`. The existing `Surypus.API.CRM` currently has both roles - should be refactored to separate concerns.
- **Direct SQL in handlers without Statement abstraction**: Always use Hasql `Statement` with `E.param`/`D.column` instead of raw string interpolation (SQL injection risk).
- **Using `Int64` for IDs when schema uses UUID**: The CRM schema uses `UUID PRIMARY KEY` but the existing `Surypus.API.CRM.hs` uses `Text` for IDs. This is inconsistent with the rest of the codebase (which uses `Int64`) but correct for the UUID-based CRM schema.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DB connection pool | Custom pool mgmt | hasql-pool | Existing - DAL.Database already wraps it |
| JSON serialization | Manual encoding | Aeson (deriveGeneric or TemplateHaskell) | Existing standard in DAL.Types, API.Types |
| JWT auth | Custom crypto | jose 0.10 (already in deps) | Existing dependency in Surypus.cabal |
| SQL type safety | String interpolation | Hasql Statement + E.param/D.column | Existing standard - prevents SQL injection |
| Pipeline stage transitions | Manual stage tracking | DB table `crm_pipeline_stages` + probability column | Already exists in V181__crm_schema.sql |
| Forecast computation | Ad-hoc calculation | Materialized view `mv_crm_pipeline_forecast` | Already exists in V181__crm_schema.sql |

**Key insight:** The CRM schema is 80% already designed in V181__crm_schema.sql. The gap is the contacts/companies tables and event sourcing integration.

## Common Pitfalls

### Pitfall 1: ID Type Mismatch
**What goes wrong:** CRM schema uses `UUID` for IDs (consistent with event sourcing), but most existing entities use `Int64`. Existing `Surypus.API.CRM` already uses `Text` for IDs (correct for UUID). Mixing `Int64` and `UUID` between CRM tables and references to `persons(id)`.
**Why it happens:** `persons(id)` is `BIGSERIAL` (Int64) but CRM tables use `gen_random_uuid()`.
**How to avoid:** Use `UUID` for CRM primary keys (as V181 already does). When referencing `persons(id)`, use `UUID` or store the Int64 directly. The `V181__crm_schema.sql` already references `persons(id)` as UUID which would need `persons` to have UUID IDs - this is a mismatch since persons actually uses BIGSERIAL. Keep CRM UUID IDs but use `person_id BIGINT REFERENCES persons(id)` instead of `UUID REFERENCES persons(id)`.
**Warning signs:** Compile errors with UUID decode/encode in hasql statements, or runtime FK constraint violations.

### Pitfall 2: Event Sequence Conflicts
**What goes wrong:** `DAL.EventStore` uses `(aggregate_id Int64, aggregate_type Text)` as the event stream key. If CRM creates contacts with UUID IDs, the Int64 aggregate_id won't fit UUIDs.
**Why it happens:** The existing DAL.EventStore.hs uses Int64 for aggregate_id (line 33: `eventAggregateId :: Int64`), while the CRM schema uses UUID as primary key.
**How to avoid:** Use the event sourcing approach from `Infrastructure.EventStore.Accounting` which uses Int64 aggregate IDs. For CRM, either (a) use Int64 IDs for CRM aggregates and map UUID display IDs separately, or (b) extend DAL.EventStore to support UUID aggregate_id. Option (a) is simpler and follows existing patterns.
**Warning signs:** Cannot store CRM events because aggregate_id must be Int64.

### Pitfall 3: Materialized View Staleness
**What goes wrong:** `mv_crm_pipeline_forecast` is a materialized view that must be refreshed. If not refreshed on deal updates, the forecast will be stale.
**How to avoid:** After every deal stage change, call `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_crm_pipeline_forecast` or create a periodic refresh via pg_cron or a trigger.
**Warning signs:** Forecast doesn't match actual deal values.

### Pitfall 4: Missing Companies Table
**What goes wrong:** V181__crm_schema.sql references `companies(id)` as a FK from `crm_deals`, but no `companies` table exists.
**How to avoid:** Create `crm_companies` table in a new migration. Alternatively, the existing `persons.person` table with `person_type = 1` (PKCompany) serves as the company registry.
**Warning signs:** Foreign key constraint violations when creating deals with company_id.

## Code Examples

Verified patterns from official sources:

### Common Operation: Create a Contact (following Person CRUD pattern)
```haskell
-- Source: DAL.Mutations pattern (surypus-api/src/Surypus/DAL/Mutations.hs)
contactInputEncoder :: E.Params ContactInput
contactInputEncoder =
  (ciFirstName >$< E.param (E.nonNullable E.text))
    <> (ciLastName >$< E.param (E.nonNullable E.text))
    <> (ciEmail >$< E.param (E.nullable E.text))
    <> (ciPhone >$< E.param (E.nullable E.text))
    <> (ciCompanyId >$< E.param (E.nullable E.int8))

createContact :: Pool -> ContactInput -> IO (QueryResult MutationResult)
createContact pool input =
  runMutationReturningId
    pool
    "INSERT INTO crm_contacts (first_name, last_name, email, phone, company_id) \
    \VALUES ($1, $2, $3, $4, $5) RETURNING id"
    contactInputEncoder
    input
    "Contact created successfully"
```
[CITED: surypus-api/src/Surypus/DAL/Mutations.hs lines 68-95 pattern]

### Common Operation: Query Deals with Filters
```haskell
-- Source: DAL.Queries pattern (surypus-api/src/Surypus/DAL/Queries.hs line 306-317)
getDealsByStage :: Pool -> Text -> IO (QueryResult [Deal])
getDealsByStage pool stageId = do
  let stmt = preparable
        "SELECT id::text, deal_name, deal_value, stage_id::text, \
        \  person_id::text, company_id::text, \
        \  expected_close_date::text, priority, probability, is_active \
        \FROM crm_deals WHERE stage_id = $1::uuid AND is_active = true \
        \ORDER BY deal_value DESC"
        (E.param (E.nonNullable E.text))
        (D.rowList dealRowDecoder)
  res <- use pool $ Session.statement stageId stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)
```
[CITED: surypus-api/src/Surypus/DAL/Queries.hs pattern]

### Common Operation: Event-Sourced Deal Stage Change
```haskell
-- Source: Infrastructure.EventStore.Accounting pattern (src/Infrastructure/EventStore/Accounting.hs lines 153-168)
advanceDealStage :: CRMEventStore -> Int64 -> Text -> Text -> IO (Either Text ())
advanceDealStage store dealId fromStage toStage = do
  let event = CRMEvent $ DealStageChanged DealStageChanged
        { dscDealId = dealId
        , dscFromStage = fromStage
        , dscToStage = toStage
        , dscTimestamp = <$ getCurrentTime
        }
  appendCRMEvent store event
  -- Also write to crm_deals table for read model
  -- Write to event_store via DAL.EventStore
```
[CITED: src/Infrastructure/EventStore/Accounting.hs]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| — | CRM in separate API module | V181 migration | Existing foundation to extend |
| — | Event sourcing via DAL.EventStore | Existing | Follow Accounting/Inventory pattern |
| — | UUID primary keys for CRM | V181 migration | Consistent with event sourcing patterns |

**Deprecated/outdated:**
- None identified. The CRM is a new domain building on established patterns.

## Existing Codebase Assets to Leverage

### Already Implemented (in surypus-api/src/Surypus/API/CRM.hs):
- `Deal` data type with Aeson ToJSON
- `DealInput` with FromJSON/ToJSON
- `DealStage` with ToJSON
- `Activity` with ToJSON
- `ActivityInput` with FromJSON/ToJSON
- `PipelineForecast` with ToJSON
- `listDeals` - SELECT with JOINs
- `createDeal` - INSERT with RETURNING
- `getDeal` - SELECT by ID
- `updateDealStage` - stage transition
- `getPipelineForecast` - reads MV
- `listActivities` - list by deal_id

### Already Implemented (in surypus-api/src/Surypus/API/Server.hs):
- CRM routes: list deals, create deal, get deal, update stage, pipeline forecast, deal activities
- `Env` pattern wrapping `Pool` + `Logger` + `WebSocketHandler`
- `correlationMiddleware` + `authMiddleware`

### Stubs to Complete:
- `updateDeal` - returns "Not implemented"
- `deleteDeal` - returns "Not implemented"
- `createActivity` - returns "Not implemented"

### DB Schema Already Exists (sql/migrations/V181__crm_schema.sql):
- `crm_pipeline_stages` (id UUID, tenant_id, stage_name, stage_order, stage_probability, stage_color, is_active)
- `crm_deals` (id UUID, tenant_id, deal_name, deal_value, stage_id FK to stages, person_id, company_id, contact_id, owner_id, expected_close_date, priority, probability, notes, tags, is_active, created_at, updated_at)
- `crm_activities` (id UUID, tenant_id, deal_id FK to deals, person_id, activity_type, subject, description, activity_date, is_completed)
- `mv_crm_pipeline_forecast` (materialized view with stage_name, stage_order, stage_probability, deal_count, pipeline_value, weighted_forecast)
- Default 6 stages: Lead (10%), Qualified (25%), Proposal (50%), Negotiation (75%), Closed Won (100%), Closed Lost (0%)

### Note on Schema Issues:
1. `crm_deals` references `companies(id)` but no companies table exists → needs `crm_companies` table or use `persons.person` with `person_type = PKCompany`
2. `crm_deals` references `persons(id)` as UUID but `persons.person` uses BIGSERIAL → use BIGINT FK instead
3. No `crm_contacts` table → needs one
4. No entry/exit criteria for stage transitions → needs `crm_pipeline_rules` or criteria columns on `crm_pipeline_stages`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `persons.person` table uses BIGSERIAL (Int64) IDs, not UUID | DB Schema | FK constraint in crm_deals needs BIGINT, not UUID |
| A2 | Companies should be modeled as a separate `crm_companies` table rather than reusing `persons.person` with `PKCompany` | Data Model | Schema change needed if decision reverses |
| A3 | The existing `DAL.EventStore`'s Int64 aggregate_id is adequate for CRM event sourcing | Event Store | If UUID aggregate IDs are required, DAL.EventStore needs extension |
| A4 | The project has a `pg_cron` extension or trigger-based approach for MV refresh | Operations | Manual REFRESH CONCURRENTLY may be required in API handlers |

## Open Questions

1. **[Companies: separate table vs persons reuse]**
   - What we know: `persons.person` has `person_type` field with `PKCompany` variant. The CRM schema references `companies(id)` in V181. The HR/Person.hs already supports companies as a person kind.
   - What's unclear: Should we create `crm_companies` as a new table (cleaner CRM domain) or add a `crm_company_profiles` view/table that references `persons.person` where `person_type = PKCompany` (avoids data duplication)?
   - Recommendation: Create `crm_companies` table following same UUID pattern as other CRM tables, with a foreign key to `persons.person(id)`. This keeps CRM self-contained while linking to existing person data.

2. **[ID strategy: UUID vs Int64]**
   - What we know: CRM schema uses UUID PKs; rest of the codebase uses Int64; DAL.EventStore expects Int64 aggregate_id
   - What's unclear: Should we change CRM to Int64 for consistency, or handle the UUID→Int64 mapping for event sourcing?
   - Recommendation: Keep UUID for CRM tables (V181 is already deployed), use a secondary `bigint_serial_id` column in each CRM table for event sourcing compatibility, or extend DAL.EventStore with UUID support.

3. **[Event sourcing granularity]**
   - What we know: Accounting/Inventory event sourcing wraps DAL.EventStore at the aggregate level
   - What's unclear: Should each CRM entity (Contact, Company, Deal) be its own aggregate type, or should everything be under "crm" aggregate?
   - Recommendation: Three separate aggregates: "crm_contact", "crm_company", "crm_deal" (consistent with "goods_stock", "account" patterns).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| PostgreSQL | DB persistence | ✓ | (via hasql-pool) | — |
| GHC 9.6.5 | Compilation | ✓ | 9.6.5 (from stack.yaml lts-22.21) | — |
| hasql + hasql-pool | DB access | ✓ | 1.6+ | — |
| servant + servant-server | API | ✓ | 0.20 | — |
| aeson | JSON | ✓ | 2.2+ | — |
| uuid | UUID handling | ✓ | 1.3+ (in deps) | — |

**Missing dependencies with no fallback:** None identified.

## Validation Architecture

> workflow.nyquist_validation is enabled in config (absent = enabled).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | hspec 2.11 + QuickCheck 2.14 |
| Config file | (defined in Surypus.cabal test-suite) |
| Quick run command | `stack test --test-arguments='--match "CRM"'` |
| Full suite command | `stack test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CRM-01 | Contact CRUD | integration | `stack test --test-arguments='--match "CRM.Contact"'` | ❌ Wave 0 |
| CRM-02 | Company CRUD | integration | `stack test --test-arguments='--match "CRM.Company"'` | ❌ Wave 0 |
| CRM-03 | Deal pipeline stages | integration | `stack test --test-arguments='--match "CRM.Deal"'` | ❌ Wave 0 |
| CRM-04 | Stage entry/exit criteria | unit + property | `stack test --test-arguments='--match "CRM.Pipeline"'` | ❌ Wave 0 |
| CRM-05 | Pipeline forecast | integration | `stack test --test-arguments='--match "CRM.Forecast"'` | ❌ Wave 0 |
| CRM-06 | Activity logging | integration | `stack test --test-arguments='--match "CRM.Activity"'` | ❌ Wave 0 |
| CRM-07 | Event sourcing audit | integration | `stack test --test-arguments='--match "CRM.EventStore"'` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `stack build --fast surypus-api` (compile check only)
- **Per wave merge:** `stack test --test-arguments='--match "CRM"'`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/Domain/CRMSpec.hs` — covers CRM-01 through CRM-07
- [ ] `test/Integration/CRMLifecycleSpec.hs` — API-level integration tests
- [ ] No CRM test infrastructure exists yet

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | JWT via Surypus.JWT (already in authMiddleware) |
| V3 Session Management | yes | JWT tokens via existing auth |
| V4 Access Control | yes | RBAC via Surypus.RBAC + Authorization.hs |
| V5 Input Validation | yes | Hasql prepared statements (prevents SQLi) + domain validators |
| V8 Data Protection | yes | Event store append-only audit trail |

### Known Threat Patterns for CRM

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unauthorized deal read | Information Disclosure | RBAC: `crm:read` permission check on GET endpoints |
| Unauthorized deal stage change | Tampering | RBAC: `crm:write` permission check on stage transition |
| Unauthorized contact delete | Tampering / Repudiation | RBAC: `crm:delete` + event store audit trail |
| SQL injection via search | Injection | Hasql `E.param` for all user input (parameterized queries) |
| Data loss on stage transition | Tampering | Event sourcing + optimistic concurrency via sequence_number |

## Sources

### Primary (HIGH confidence)
- [VERIFIED: surypus-api/src/Surypus/API/CRM.hs] - Existing Deal/Activity types, queries
- [VERIFIED: surypus-api/src/Surypus/API/Server.hs] - CRM route wiring, Env pattern, handler pattern
- [VERIFIED: sql/migrations/V181__crm_schema.sql] - CRM table definitions, MV, default stages
- [VERIFIED: src/DAL/EventStore.hs] - Event store append/query API
- [VERIFIED: src/Infrastructure/EventStore/Accounting.hs] - Event store wrapper pattern
- [VERIFIED: src/Infrastructure/EventStore/Inventory.hs] - Event store wrapper pattern
- [VERIFIED: src/Surypus/RBAC.hs] - Permission type, permissionToText, requirePermission
- [VERIFIED: src/Surypus/API/Authorization.hs] - Path→permission mapping
- [VERIFIED: surypus-api/src/Surypus/DAL/Queries.hs] - Row decoder + query pattern
- [VERIFIED: surypus-api/src/Surypus/DAL/Mutations.hs] - Mutation encoder + insertion pattern
- [VERIFIED: surypus-api/src/Surypus/DAL/Repository.hs] - Repository pattern
- [VERIFIED: src/DAL/Types.hs] - API types pattern (Generic + ToJSON/FromJSON)
- [VERIFIED: src/Finance/Types.hs] - Domain types pattern (no Aeson instances)
- [VERIFIED: src/HR/Person.hs, HR/Contact.hs] - Existing person/contact domain types

### Secondary (MEDIUM confidence)
- [VERIFIED: Surypus.cabal] - Build dependencies (hasql, servant, aeson, etc.)
- [VERIFIED: stack.yaml] - GHC 9.6.5 via lts-22.21
- [VERIFIED: src/Surypus/WebSocket.hs] - WebSocket broadcast pattern for CRM notifications

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - verified against Surypus.cabal + existing modules
- Architecture: HIGH - patterns consistent across Inventory, Finance, Accounting modules
- Pitfalls: MEDIUM - some assumptions about ID strategy need confirmation

**Research date:** 2026-05-18
**Valid until:** 2026-06-18 (stable codebase, no fast-moving dependencies)
