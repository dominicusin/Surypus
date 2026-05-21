# Phase 20: Integrations - Research

**Researched:** 2026-05-19
**Status:** Complete

## Existing Infrastructure

### Bank Statement Import (INT-01)

**Current Implementation:**
- `src/Integration/BankStatement.hs` - OFX and ISO 20022 (camt.053) parsers
- Functions: `parseOFX`, `parseISO20022`, `importStatementLines`
- Database: `bank_statement_import` and `bank_statement_line` tables (V187 migration)

**Parser Details:**
- OFX: Extracts `<STMTTRN>` blocks, parses DTPOSTED, DTAVAIL, TRNAMT, MEMO, FITID
- ISO 20022: Extracts `<Ntry>` blocks, parses BookgDt/Dt, ValDt/Dt, Amt, AddtlNtryInf, AcctSvcrRef, Nm
- Both return `BankTxn` type with date, amount, currency, description, ref, counterparty
- `importStatementLines` persists to database using Hasql

**Gap Analysis:**
- ✅ Parsing exists for OFX and ISO 20022
- ✅ Database persistence exists
- ❌ No auto-matching logic to link transactions to bills
- ❌ No REST API endpoints for upload/retrieval
- ❌ No RBAC permissions for integration operations
- ❌ No health monitoring

### Integration Types (INT-02)

**Current Types in `Integration.Integration`:**
- `EDIProvider` - EDI exchange provider (id, code, name, URL, login, flags)
- `Webhook` - Webhook configuration (id, URL, event, secret, flags)
- `SMSAccount` - SMS provider (id, name, provider, login, password)
- `InternetAccount` - Mail account (id, name, server, login, password, port, SSL)

**Gap Analysis:**
- ✅ Basic integration types exist
- ❌ No adapter pattern/typeclass for pluggable integrations
- ❌ No configuration storage table
- ❌ No adapter interface for fetch/transform/persist operations

### Health Monitoring (INT-03)

**Current Infrastructure:**
- Webhook infrastructure exists for notifications
- No dedicated health monitoring system
- No background job scheduler detected

**Gap Analysis:**
- ❌ No `integration_health` table
- ❌ No health check logic
- ❌ No alerting mechanism for failed integrations
- ❌ No background job for periodic health checks

### REST API Documentation (INT-04)

**Current Infrastructure:**
- OpenAPI tooling exists (see `tools/GenSwagger.hs`)
- REST API in `Surypus.API.Server` using Scotty
- JWT authentication exists
- RBAC system exists

**Gap Analysis:**
- ❌ No integration-specific endpoints
- ❌ No OpenAPI documentation for integration endpoints
- ❌ No integration permissions in RBAC

## Technical Approach

### Adapter Pattern Design

**Typeclass Interface:**
```haskell
class IntegrationAdapter a where
  connect :: IO (Either Text Connection)
  fetch :: Connection -> IO (Either Text [Data])
  transform :: [Data] -> [DomainEntity]
  persist :: Pool -> [DomainEntity] -> IO (Either Text ())
```

**Concrete Adapters:**
1. `BankStatementAdapter` - wraps existing OFX/ISO 20022 parsing
2. Future: `MarketplaceAdapter`, `PaymentGatewayAdapter`

**Configuration Storage:**
```sql
CREATE TABLE integration_config (
  id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL,
  adapter_type TEXT NOT NULL,
  credentials JSONB NOT NULL,
  enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Auto-Matching Logic

**Algorithm:**
1. For each imported transaction:
   - Find bills with amount match (±0.01 tolerance)
   - Filter by date proximity (transaction date within 3 days of bill date)
   - Filter by currency match
   - Prioritize exact matches, then fuzzy matches
2. Update `bank_statement_line.matched_bill_id` and `is_matched` flags
3. Flag unmatched transactions for manual review

**Database Query:**
```sql
UPDATE bank_statement_line
SET matched_bill_id = bill.id, is_matched = true
FROM bill
WHERE bank_statement_line.import_id = $1
  AND ABS(bill.total - bank_statement_line.amount) <= 0.01
  AND ABS(bill.date - bank_statement_line.txn_date) <= 3
  AND bill.currency = bank_statement_line.currency
LIMIT 1;
```

### Health Monitoring Design

**Table Schema:**
```sql
CREATE TABLE integration_health (
  id UUID PRIMARY KEY,
  tenant_id UUID NOT NULL,
  adapter_type TEXT NOT NULL,
  last_success TIMESTAMPTZ,
  last_failure TIMESTAMPTZ,
  failure_count INT DEFAULT 0,
  status TEXT DEFAULT 'healthy' CHECK (status IN ('healthy', 'degraded', 'down'))
);
```

**Monitoring Logic:**
- On success: update `last_success`, reset `failure_count`, set status = 'healthy'
- On failure: update `last_failure`, increment `failure_count`, set status = 'degraded' if count > 3
- Background job: check every 5 minutes for adapters with `failure_count > 5`, send alerts

**Alerting:** Use existing webhook infrastructure to send health alerts.

### RBAC Permissions

**New Permissions:**
- `IntegrationRead` - view imports, health status
- `IntegrationWrite` - upload files, configure adapters, manual matching
- `IntegrationAdmin` - manage adapter configurations, health alerts

**Mapping in Authorization.hs:**
```haskell
integrationReadPaths = ["/api/v1/integrations/bank-statement/imports", "/api/v1/integrations/health"]
integrationWritePaths = ["/api/v1/integrations/bank-statement/upload", "/api/v1/integrations/config"]
integrationAdminPaths = ["/api/v1/integrations/config/:adapter_type"]
```

### REST API Endpoints

**Bank Statement Endpoints:**
- `POST /api/v1/integrations/bank-statement/upload` - upload and parse OFX/ISO 20022 file
- `GET /api/v1/integrations/bank-statement/imports` - list import history
- `GET /api/v1/integrations/bank-statement/lines/:import_id` - get transaction lines
- `POST /api/v1/integrations/bank-statement/match/:line_id/:bill_id` - manual match

**Health Endpoints:**
- `GET /api/v1/integrations/health` - health status for all adapters

**Config Endpoints:**
- `POST /api/v1/integrations/config/:adapter_type` - configure adapter credentials
- `GET /api/v1/integrations/config/:adapter_type` - get adapter configuration

## Implementation Order

1. **Database migrations** - Add `integration_config`, `integration_health` tables
2. **RBAC permissions** - Add integration permissions to RBAC system
3. **Auto-matching logic** - Implement matching function and database query
4. **REST API endpoints** - Add bank statement upload/retrieval endpoints
5. **Health monitoring** - Implement health check logic and background job
6. **Adapter pattern** - Create typeclass and concrete adapters
7. **OpenAPI documentation** - Generate documentation for new endpoints
8. **Tests** - Unit tests for matching logic, integration tests for API endpoints

## Risks and Mitigations

**Risk:** OFX/ISO 20022 parsing may fail on malformed files
**Mitigation:** Add detailed error handling with line numbers and context, store error in `bank_statement_import.error_msg`

**Risk:** Auto-matching may produce false positives
**Mitigation:** Require manual confirmation for fuzzy matches, flag for review

**Risk:** Background job scheduler may not exist
**Mitigation:** Use simple timer-based approach or defer to existing job system if found

**Risk:** Large files may timeout during upload
**Mitigation:** Implement async processing for files >1000 transactions
