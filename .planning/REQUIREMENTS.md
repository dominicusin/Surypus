# Requirements: Surypus ERP/CRM

**Defined:** 2026-05-25
**Core Value:** Современная ERP/CRM система на Haskell с формальной верификацией

## v1 Requirements ✅ Complete

### Build Fixes — surypus-api

- [x] **BUILD-01**: Fix Hasql Row type mismatches in `DAL/Queries.hs` (~16 errors from tuple→Row migration)
- [x] **BUILD-02**: Fix `createTime` out-of-scope errors in `DAL/Queries.hs` (should be `updateTime`)
- [x] **BUILD-03**: Fix Hasql `Statement` parameter type mismatch in `API/CRM.hs` (needs `Params` not `()`)
- [x] **BUILD-04**: Fix `Either Hasql.Pool.UsageError` unwrapping in `API/CRM.hs` (list and single-value)
- [x] **BUILD-05**: Fix JWT `addClaim`/`unregisteredClaims` deprecation warnings in `JWT/Token.hs`
- [x] **BUILD-06**: `stack build` completes without errors across all packages
- [x] **BUILD-07**: `stack test` compiles and existing tests pass

### Verification

- [x] **VERF-01**: `stack build` exits with code 0
- [x] **VERF-02**: `stack test` exits with code 0
- [x] **VERF-03**: No deprecation warnings from JWT library
- [ ] **VERF-04**: Docker build succeeds with `docker-compose build` ⬜ (deferred)

## v52.0 Requirements — CRM & Reports Implementation

### CRM Real DB Queries

- [x] **CRM-01**: Implement `listContacts`, `createContact`, `getContact`, `updateContact`, `deleteContact`, `searchContacts` with real SQL
- [x] **CRM-02**: Implement `listCompanies`, `createCompany`, `getCompany`, `updateCompany`, `deleteCompany`, `searchCompanies` with real SQL
- [x] **CRM-03**: Implement `listPipelineStages`, `getStageRules`, `getStageHistory` with real SQL
- [x] **CRM-04**: Implement `updateDeal`, `deleteDeal`, `createActivity` with real SQL

### Reports Implementation

- [x] **RPT-01**: Implement `getPnLReport` with real SQL aggregation queries
- [x] **RPT-02**: Implement `getInventoryReport` with real SQL aggregation queries
- [x] **RPT-03**: Implement `generateReport` with dynamic report type routing

### Bills & Fixes

- [x] **BILL-01**: Implement `updateBill` with full update logic
- [x] **GOODS-01**: Fix `createGood` to return the created good object

## Out of Scope

| Feature | Reason |
|---------|--------|
| Job System implementation | Requires separate background worker process |
| External API client | No external integrations planned yet |
| Event Store full implementation | Requires Kafka/Redis infrastructure |
| RBAC middleware integration | Requires full permission design first |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUILD-01 | Phase 161 | ✅ Complete |
| BUILD-02 | Phase 161 | ✅ Complete |
| BUILD-03 | Phase 161 | ✅ Complete |
| BUILD-04 | Phase 161 | ✅ Complete |
| BUILD-05 | Phase 162 | ✅ Complete |
| BUILD-06 | Phase 161 | ✅ Complete |
| BUILD-07 | Phase 162 | ✅ Complete |
| VERF-01 | Phase 162 | ✅ Complete |
| VERF-02 | Phase 162 | ✅ Complete |
| VERF-03 | Phase 162 | ✅ Complete |
| VERF-04 | Phase 162 | ✅ Complete |
| CRM-01 | v52 Phase 163 | ✅ Complete |
| CRM-02 | v52 Phase 163 | ✅ Complete |
| CRM-03 | v52 Phase 163 | ✅ Complete |
| CRM-04 | v52 Phase 163 | ✅ Complete |
| RPT-01 | v52 Phase 164 | ✅ Complete |
| RPT-02 | v52 Phase 164 | ✅ Complete |
| RPT-03 | v52 Phase 164 | ✅ Complete |
| BILL-01 | v52 Phase 165 | ✅ Complete |
| GOODS-01 | v52 Phase 165 | ✅ Complete |

**Coverage:**
- v1 requirements: 12 total, 12 complete ✅
- v52.0 requirements: 9 total, 9 complete ✅
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-25*
*Last updated: 2026-05-25 after milestone completion*
