# Phase 20: Integrations - Context

**Gathered:** 2026-05-19
**Status:** Ready for planning
**Mode:** Autonomous (auto-selected decisions)

## Phase Boundary

External system integration framework with bank statement import (OFX/ISO 20022), adapter pattern, health monitoring, and REST API documentation for external use.

## Implementation Decisions

### Bank Statement Import

**Format Support:** OFX and ISO 20022 (camt.053) - existing `Integration.BankStatement` module already implements parsers for both formats. Reuse and extend this module.

**Database Schema:** Existing `bank_statement_import` and `bank_statement_line` tables (V187 migration) provide the foundation. Add matching logic to link imported transactions to bills.

**Import Flow:**
1. User uploads file via REST API endpoint
2. Parse using existing `parseOFX` or `parseISO20022` functions
3. Persist using existing `importStatementLines` function
4. Auto-match transactions to existing bills by amount/date
5. Flag unmatched transactions for manual review

### Adapter Pattern

**Adapter Interface:** Create a typeclass `IntegrationAdapter` with methods:
- `connect :: IO (Either Text Connection)`
- `fetch :: Connection -> IO (Either Text [Data])`
- `transform :: [Data] -> [DomainEntity]`
- `persist :: Pool -> [DomainEntity] -> IO (Either Text ())`

**Concrete Adapters:**
1. `BankStatementAdapter` - wraps existing OFX/ISO 20022 parsing
2. `MarketplaceAdapter` - placeholder for future marketplace integrations
3. `PaymentGatewayAdapter` - placeholder for payment processor integrations

**Configuration:** Store adapter credentials in `integration_config` table (tenant_id, adapter_type, credentials_json, enabled).

### Health Monitoring

**Health Check Table:** `integration_health` (tenant_id, adapter_type, last_success, last_failure, failure_count, status).

**Monitoring Logic:**
- On successful import: update `last_success`, reset `failure_count`, set status = 'healthy'
- On failure: update `last_failure`, increment `failure_count`, set status = 'degraded' if count > 3
- Background job checks every 5 minutes for adapters with `failure_count > 5` and sends alerts

**Alerting:** Use existing webhook infrastructure (`Integration.Integration` Webhook type) to send health alerts to configured endpoints.

### REST API for External Use

**Authentication:** Require JWT with `IntegrationRead` or `IntegrationWrite` permissions (add to RBAC).

**Endpoints:**
- `POST /api/v1/integrations/bank-statement/upload` - upload and parse OFX/ISO 20022 file
- `GET /api/v1/integrations/bank-statement/imports` - list import history
- `GET /api/v1/integrations/bank-statement/lines/:import_id` - get transaction lines
- `POST /api/v1/integrations/bank-statement/match/:line_id/:bill_id` - manual match
- `GET /api/v1/integrations/health` - health status for all adapters
- `POST /api/v1/integrations/config/:adapter_type` - configure adapter credentials

**OpenAPI Documentation:** Generate using existing OpenAPI tooling. Add examples for OFX upload and matching flow.

### RBAC Permissions

Add to existing RBAC system:
- `IntegrationRead` - view imports, health status
- `IntegrationWrite` - upload files, configure adapters, manual matching
- `IntegrationAdmin` - manage adapter configurations, health alerts

Map these to role permissions in `Authorization.hs`.

## Existing Code Insights

**Reusable Assets:**
- `Integration.BankStatement` - OFX/ISO 20022 parsers, `importStatementLines` function
- `Integration.Integration` - EDIProvider, Webhook, SMSAccount, InternetAccount types
- `bank_statement_import` and `bank_statement_line` tables (V187 migration)
- Existing webhook infrastructure for health alerts

**Established Patterns:**
- Hasql for database operations (see `importStatementLines` pattern)
- JSON-based configuration storage (follow existing config table patterns)
- RBAC permission system (add new permissions following existing pattern)
- REST API endpoints in `Surypus.API.Server` (add new endpoints following Scotty pattern)

**Integration Points:**
- Add new endpoints to `Surypus.API.Server`
- Add RBAC permissions to `Surypus.RBAC` and `Surypus.Authorization`
- Add health monitoring to background job system (if exists) or create new scheduler
- Extend `Integration.hs` to re-export new adapter modules

## Specific Ideas

**Auto-Matching Logic:** Match transactions to bills by:
1. Exact amount match (within 0.01 tolerance)
2. Date proximity (transaction date within 3 days of bill date)
3. Currency match
4. Prioritize exact matches, then fuzzy matches

**Error Handling:** On parse failure, return detailed error with line number and context. Store error message in `bank_statement_import.error_msg`.

**Async Processing:** For large files (>1000 transactions), process asynchronously using background job. Return import_id immediately, poll status endpoint for progress.

## Deferred Ideas

- CSV format support for bank statements (defer to future phase)
- Automatic reconciliation suggestions (defer to future phase)
- Multi-bank account management (defer to future phase)
- Marketplace integrations (defer to future phase)
- Payment gateway integrations (defer to future phase)

## Canonical References

- `.planning/ROADMAP.md` - Phase 20 definition and requirements
- `.planning/REQUIREMENTS.md` - INT-01 through INT-04 requirements
- `src/Integration/BankStatement.hs` - Existing OFX/ISO 20022 parsing
- `src/Integration/Integration.hs` - Existing integration types
- `sql/migrations/V187__bank_statement_import.sql` - Existing database schema
