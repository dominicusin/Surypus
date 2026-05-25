# Requirements: Surypus ERP/CRM

**Defined:** 2026-05-25
**Core Value:** Современная ERP/CRM система на Haskell с формальной верификацией

## v1 Requirements

### Build Fixes — surypus-api

- [ ] **BUILD-01**: Fix Hasql Row type mismatches in `DAL/Queries.hs` (~16 errors from tuple→Row migration)
- [ ] **BUILD-02**: Fix `createTime` out-of-scope errors in `DAL/Queries.hs` (should be `updateTime`)
- [ ] **BUILD-03**: Fix Hasql `Statement` parameter type mismatch in `API/CRM.hs` (needs `Params` not `()`)
- [ ] **BUILD-04**: Fix `Either Hasql.Pool.UsageError` unwrapping in `API/CRM.hs` (list and single-value)
- [ ] **BUILD-05**: Fix JWT `addClaim`/`unregisteredClaims` deprecation warnings in `JWT/Token.hs`
- [ ] **BUILD-06**: `stack build` completes without errors across all packages
- [ ] **BUILD-07**: `stack test` compiles and existing tests pass

### Verification

- [ ] **VERF-01**: `stack build` exits with code 0
- [ ] **VERF-02**: `stack test` exits with code 0
- [ ] **VERF-03**: No deprecation warnings from JWT library
- [ ] **VERF-04**: Docker build succeeds with `docker-compose build`

## v2 Requirements

(None deferred — milestone scope is narrow build stabilization)

## Out of Scope

| Feature | Reason |
|---------|--------|
| New feature development | This milestone is strictly build fix and stabilization |
| Dependency upgrades beyond what's needed for build | Risk of introducing new issues |
| New tests beyond existing | Focus on getting current tests passing first |
| Code formatting or style changes | Would create noise alongside functional fixes |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUILD-01 | Phase 161 | Pending |
| BUILD-02 | Phase 161 | Pending |
| BUILD-03 | Phase 161 | Pending |
| BUILD-04 | Phase 161 | Pending |
| BUILD-05 | Phase 162 | Pending |
| BUILD-06 | Phase 161 | Pending |
| BUILD-07 | Phase 162 | Pending |
| VERF-01 | Phase 162 | Pending |
| VERF-02 | Phase 162 | Pending |
| VERF-03 | Phase 162 | Pending |
| VERF-04 | Phase 162 | Pending |

**Coverage:**
- v1 requirements: 11 total
- Mapped to phases: 11
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-25*
*Last updated: 2026-05-25 after new-milestone workflow*
