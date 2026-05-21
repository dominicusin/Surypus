# Phase 20: Integrations - Plan

**Planned:** 2026-05-19
**Status:** Ready for execution
**Waves:** 3 waves

## Overview

Implement external system integration framework with bank statement import (OFX/ISO 20022), adapter pattern, health monitoring, and REST API documentation for external use.

## Wave 1: Database and RBAC Foundation

### Plan 20-01: Database Migrations

**Objective:** Add integration configuration and health monitoring tables

**Files:**
- `sql/migrations/V188__integration_config.sql`
- `sql/migrations/V189__integration_health.sql`

**Tasks:**
1. Create `integration_config` table for adapter credentials
2. Create `integration_health` table for monitoring status
3. Add indexes for tenant_id and adapter_type lookups
4. Add foreign key constraints where applicable

**Schema Details:**
```sql
-- integration_config table
CREATE TABLE integration_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  adapter_type TEXT NOT NULL,
  credentials JSONB NOT NULL,
  enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_integration_config_tenant ON integration_config(tenant_id);
CREATE INDEX idx_integration_config_type ON integration_config(adapter_type);

-- integration_health table
CREATE TABLE integration_health (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  adapter_type TEXT NOT NULL,
  last_success TIMESTAMPTZ,
  last_failure TIMESTAMPTZ,
  failure_count INT DEFAULT 0,
  status TEXT DEFAULT 'healthy' CHECK (status IN ('healthy', 'degraded', 'down')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_integration_health_tenant ON integration_health(tenant_id);
CREATE INDEX idx_integration_health_type ON integration_health(adapter_type);
CREATE INDEX idx_integration_health_status ON integration_health(status);
```

**Success Criteria:**
- Migrations run successfully
- Tables created with correct schema
- Indexes created for performance

---

### Plan 20-02: RBAC Permissions

**Objective:** Add integration-specific permissions to RBAC system

**Files:**
- `src/Surypus/RBAC.hs`
- `src/Surypus/Authorization.hs`

**Tasks:**
1. Add permission types: `IntegrationRead`, `IntegrationWrite`, `IntegrationAdmin`
2. Add permission mappings in Authorization.hs for integration endpoints
3. Update permission constants and helper functions

**Permission Mappings:**
```haskell
-- In RBAC.hs
integrationRead = Permission "IntegrationRead"
integrationWrite = Permission "IntegrationWrite"
integrationAdmin = Permission "IntegrationAdmin"

-- In Authorization.hs
integrationReadPaths = 
  [ "/api/v1/integrations/bank-statement/imports"
  , "/api/v1/integrations/bank-statement/lines/:import_id"
  , "/api/v1/integrations/health"
  , "/api/v1/integrations/config/:adapter_type"
  ]

integrationWritePaths =
  [ "/api/v1/integrations/bank-statement/upload"
  , "/api/v1/integrations/bank-statement/match/:line_id/:bill_id"
  ]

integrationAdminPaths =
  [ "/api/v1/integrations/config/:adapter_type"
  ]
```

**Success Criteria:**
- Permissions defined in RBAC.hs
- Path mappings added to Authorization.hs
- Compile succeeds
- Tests pass

---

## Wave 2: Bank Statement Import Enhancement

### Plan 20-03: Auto-Matching Logic

**Objective:** Implement automatic matching of imported transactions to bills

**Files:**
- `src/Integration/BankStatement.hs`
- `src/Integration/Matching.hs` (new)

**Tasks:**
1. Create `Matching.hs` module with matching algorithm
2. Implement `matchTransactionsToBills` function
3. Add database query for matching logic
4. Update `importStatementLines` to trigger auto-matching
5. Add manual match endpoint function

**Matching Algorithm:**
```haskell
matchTransactionsToBills :: Pool -> Text -> IO (Either Text Int)
matchTransactionsToBills pool importId = do
  let matchStmt = Statement
        "UPDATE bank_statement_line \
        \SET matched_bill_id = bill.id, is_matched = true \
        \FROM bill \
        \WHERE bank_statement_line.import_id = $1 \
        \  AND ABS(bill.total - bank_statement_line.amount) <= 0.01 \
        \  AND ABS(bill.date - bank_statement_line.txn_date) <= 3 \
        \  AND bill.currency = bank_statement_line.currency \
        \  AND bank_statement_line.is_matched = false \
        \RETURNING bank_statement_line.id"
        (E.param (E.nonNullable E.text))
        (D.row (D.column (D.nonNullable D.uuid)))
        True
  result <- usePool pool $ Session.statement importId matchStmt
  case result of
    Left err -> return $ Left $ T.pack $ show err
    Right matchedIds -> return $ Right $ length matchedIds
```

**Success Criteria:**
- Matching function implemented
- Database query works correctly
- Auto-matching triggers on import
- Manual match function available

---

### Plan 20-04: REST API Endpoints

**Objective:** Add REST API endpoints for bank statement import

**Files:**
- `src/Surypus/API/Integration.hs` (new)
- `src/Surypus/API/Server.hs`

**Tasks:**
1. Create `Integration.hs` API module
2. Implement upload endpoint for OFX/ISO 20022 files
3. Implement list imports endpoint
4. Implement get transaction lines endpoint
5. Implement manual match endpoint
6. Add routes to Server.hs
7. Add JWT authentication middleware
8. Add RBAC authorization checks

**API Endpoints:**
```haskell
-- POST /api/v1/integrations/bank-statement/upload
uploadBankStatement :: Pool -> Text -> Text -> IO (Either Text ImportResult)

-- GET /api/v1/integrations/bank-statement/imports
listBankStatementImports :: Pool -> Text -> IO (Either Text [ImportHeader])

-- GET /api/v1/integrations/bank-statement/lines/:import_id
getBankStatementLines :: Pool -> Text -> IO (Either Text [BankTxn])

-- POST /api/v1/integrations/bank-statement/match/:line_id/:bill_id
manualMatchTransaction :: Pool -> Text -> Int64 -> IO (Either Text ())
```

**Success Criteria:**
- All endpoints implemented
- Authentication required
- Authorization checks in place
- Error handling for invalid files
- Returns proper JSON responses

---

## Wave 3: Health Monitoring and Adapter Pattern

### Plan 20-05: Health Monitoring

**Objective:** Implement health monitoring for integrations

**Files:**
- `src/Integration/Health.hs` (new)
- `src/Integration/Monitor.hs` (new)

**Tasks:**
1. Create `Health.hs` module with health check types
2. Implement `recordHealthSuccess` function
3. Implement `recordHealthFailure` function
4. Implement `getHealthStatus` function
5. Create `Monitor.hs` with background job logic
6. Add health check endpoint to API
7. Implement alerting via webhook

**Health Check Logic:**
```haskell
recordHealthSuccess :: Pool -> Text -> Text -> IO (Either Text ())
recordHealthSuccess pool tenantId adapterType = do
  let stmt = Statement
        "INSERT INTO integration_health (tenant_id, adapter_type, last_success, failure_count, status) \
        \VALUES ($1, $2, NOW(), 0, 'healthy') \
        \ON CONFLICT (tenant_id, adapter_type) \
        \DO UPDATE SET last_success = NOW(), failure_count = 0, status = 'healthy'"
        (E.param (E.nonNullable E.text) <> E.param (E.nonNullable E.text))
        D.noResult
        True
  usePool pool $ Session.statement (tenantId, adapterType) stmt

recordHealthFailure :: Pool -> Text -> Text -> IO (Either Text ())
recordHealthFailure pool tenantId adapterType = do
  let stmt = Statement
        "INSERT INTO integration_health (tenant_id, adapter_type, last_failure, failure_count, status) \
        \VALUES ($1, $2, NOW(), 1, 'degraded') \
        \ON CONFLICT (tenant_id, adapter_type) \
        \DO UPDATE SET last_failure = NOW(), failure_count = failure_count + 1, \
        \  status = CASE WHEN failure_count + 1 > 3 THEN 'degraded' ELSE status END"
        (E.param (E.nonNullable E.text) <> E.param (E.nonNullable E.text))
        D.noResult
        True
  usePool pool $ Session.statement (tenantId, adapterType) stmt
```

**Success Criteria:**
- Health recording functions work
- Status updates correctly on success/failure
- Health endpoint returns current status
- Alerting triggers on degraded status

---

### Plan 20-06: Adapter Pattern

**Objective:** Create pluggable adapter pattern for integrations

**Files:**
- `src/Integration/Adapter.hs` (new)
- `src/Integration/BankStatementAdapter.hs` (new)

**Tasks:**
1. Create `Adapter.hs` with `IntegrationAdapter` typeclass
2. Implement `BankStatementAdapter` instance
3. Add adapter configuration functions
4. Create adapter registry
5. Document adapter pattern

**Typeclass Definition:**
```haskell
class IntegrationAdapter a where
  adapterType :: a -> Text
  connect :: a -> IO (Either Text Connection)
  fetch :: Connection -> IO (Either Text [Data])
  transform :: [Data] -> [DomainEntity]
  persist :: Pool -> [DomainEntity] -> IO (Either Text ())
  healthCheck :: Pool -> Text -> IO (Either Text HealthStatus)
```

**BankStatementAdapter Instance:**
```haskell
data BankStatementAdapter = BankStatementAdapter
  { bsaTenantId :: Text
  , bsaFormat :: Text  -- "OFX" or "ISO20022"
  }

instance IntegrationAdapter BankStatementAdapter where
  adapterType = const "BankStatement"
  connect = const $ return $ Right ()
  fetch _ = return $ Right []  -- File-based, no connection needed
  transform = id  -- Already parsed as BankTxn
  persist = importStatementLines
  healthCheck pool tenantId = getHealthStatus pool tenantId "BankStatement"
```

**Success Criteria:**
- Typeclass defined with all required methods
- BankStatementAdapter instance implemented
- Configuration storage works
- Adapter registry functional
- Pattern documented

---

### Plan 20-07: OpenAPI Documentation

**Objective:** Generate OpenAPI documentation for integration endpoints

**Files:**
- `api/rest/openapi.yaml` (update)
- `tools/GenSwagger.hs` (update if needed)

**Tasks:**
1. Add integration endpoint definitions to openapi.yaml
2. Document request/response schemas
3. Add authentication requirements
4. Add examples for OFX upload
5. Generate OpenAPI spec
6. Verify documentation completeness

**OpenAPI Schema:**
```yaml
paths:
  /api/v1/integrations/bank-statement/upload:
    post:
      summary: Upload bank statement file
      requestBody:
        content:
          multipart/form-data:
            schema:
              type: object
              properties:
                file:
                  type: string
                  format: binary
                format:
                  type: string
                  enum: [OFX, ISO20022]
      responses:
        '200':
          description: Import successful
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ImportResult'
```

**Success Criteria:**
- All endpoints documented
- Request/response schemas defined
- Authentication documented
- Examples provided
- OpenAPI spec generates successfully

---

## Wave 4: Testing and Validation

### Plan 20-08: Unit Tests

**Objective:** Add unit tests for matching logic and adapter functions

**Files:**
- `test/Integration/MatchingSpec.hs` (new)
- `test/Integration/AdapterSpec.hs` (new)

**Tasks:**
1. Create test suite for matching algorithm
2. Test exact match scenarios
3. Test fuzzy match scenarios
4. Test no-match scenarios
5. Create test suite for adapter typeclass
6. Test BankStatementAdapter instance
7. Test health recording functions

**Test Cases:**
```haskell
-- MatchingSpec.hs
spec = do
  describe "matchTransactionsToBills" $ do
    it "matches exact amount and date" $ do
      -- test implementation
    
    it "matches within tolerance" $ do
      -- test implementation
    
    it "matches within date range" $ do
      -- test implementation
    
    it "flags no matches" $ do
      -- test implementation
```

**Success Criteria:**
- All unit tests pass
- Coverage > 80% for new modules
- Edge cases tested

---

### Plan 20-09: Integration Tests

**Objective:** Add integration tests for API endpoints

**Files:**
- `test/API/IntegrationSpec.hs` (new)

**Tasks:**
1. Create test database with sample data
2. Test upload endpoint with OFX file
3. Test upload endpoint with ISO 20022 file
4. Test list imports endpoint
5. Test get lines endpoint
6. Test manual match endpoint
7. Test health endpoint
8. Test authentication and authorization

**Integration Test Flow:**
```haskell
spec = do
  describe "Bank Statement API" $ do
    it "uploads OFX file successfully" $ do
      -- upload test OFX file
      -- verify import created
    
    it "returns import history" $ do
      -- list imports
      -- verify response
    
    it "matches transactions to bills" $ do
      -- create test bill
      -- upload statement
      -- verify auto-match
```

**Success Criteria:**
- All integration tests pass
- Endpoints return correct responses
- Authentication blocks unauthorized requests
- Authorization enforces permissions

---

## Requirements Coverage

| REQ-ID | Description | Plan(s) | Status |
|--------|-------------|---------|--------|
| INT-01 | Bank statement import (OFX/ISO 20022) | 20-03, 20-04 | Planned |
| INT-02 | Adapter pattern documented and working | 20-06 | Planned |
| INT-03 | Integration health monitoring works | 20-05 | Planned |
| INT-04 | REST API documented for external use | 20-04, 20-07 | Planned |

## Dependencies

**External Dependencies:**
- PostgreSQL 16+ (existing)
- Hasql (existing)
- Scotty (existing)
- JWT (existing)

**Internal Dependencies:**
- `DAL.Database` for connection pool
- `Surypus.RBAC` for permissions
- `Surypus.Authorization` for path mappings
- `Integration.BankStatement` for existing parsers

## Success Criteria

**Overall:**
- All 9 plans complete
- All tests pass (unit + integration)
- OpenAPI documentation generated
- RBAC permissions enforced
- Health monitoring functional
- Adapter pattern documented

**Per Wave:**
- Wave 1: Database migrations run, RBAC permissions added
- Wave 2: Auto-matching works, API endpoints functional
- Wave 3: Health monitoring active, adapter pattern implemented
- Wave 4: Tests pass, documentation complete
