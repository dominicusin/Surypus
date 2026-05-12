# Phase 1: API Production Readiness

**Goal:** API возвращает реальные данные, аутентификация работает, тесты проходят

**Duration:** 2-3 weeks
**Start Date:** 2026-05-13

---

## Plan 1.1: Real DB Queries in API Handlers

**Status:** partial

### Analysis Complete

Good news: Most handlers already use real DB queries via `Surypus.API.*` modules.

### Remaining Stub Handlers

| Handler | Issue | Fix |
|---------|-------|-----|
| `ordersStatus` | Returns hardcoded `OrderResponse 1 "Demo" 1 ...` | Use `DAL.Mutations.updateOrderStatus` |
| `ordersDelete` | Returns `pure ()` | Use `DAL.Mutations.deleteOrder` |
| `taxesUpdate` | Returns hardcoded response | Use `DAL.Mutations.updateTax` |
| `taxesDelete` | Returns `pure ()` | Use `DAL.Mutations.deleteTax` |
| `currenciesCreate` | Returns `CurrencyResponse 100 "New" "XXX"` | Use `DAL.Mutations.createCurrency` |
| `currenciesUpdate` | Returns hardcoded response | Use `DAL.Mutations.updateCurrency` |
| `currenciesDelete` | Returns `pure ()` | Use `DAL.Mutations.deleteCurrency` |
| `accCreate`, `accUpdate`, `accDelete` | Return hardcoded responses | Use DAL mutations |
| `entriesCreate`, `entriesUpdate`, `entriesDelete` | Return hardcoded responses | Use DAL mutations |
| `reportsMeta`, `reportGet`, `reportJrxml` | Return hardcoded responses | Use DAL queries |
| `dashboardGet` | Returns hardcoded `"null"` | Query actual metrics |
| `jobsList`, `jobsPending` | Return empty/hardcoded | Use `DAL.Queries.getJobs` |
| `metricsGet` | Returns `MetricsResponse 0 0 0` | Query actual metrics |

### Acceptance Criteria
- [ ] All stub handlers replaced with real DB calls
- [ ] No hardcoded response data remains

---

## Plan 1.2: JWT Authentication Middleware

**Status:** pending

### Critical Finding

`requirePermission` in `src/Surypus/RBAC.hs` (line 88-89) is a stub:
```haskell
requirePermission :: Permission -> IO ()
requirePermission _ = pure ()
```

This means **no endpoints are actually protected** - the `requirePermission_` wrapper on line 72-74 of Server.hs does nothing.

### Implementation Required

1. **Add user context extraction** from JWT token
2. **Implement permission check** in `requirePermission` that:
   - Looks up user's roles from RBAC store
   - Checks if required permission is granted
   - Throws 403 if permission denied
3. **Update handler context** to pass user info through

### Acceptance Criteria
- [ ] JWT tokens validated on protected routes
- [ ] 403 returned for missing permissions
- [ ] User context available in all handlers

---

## Plan 1.3: RBAC Verification

**Status:** pending

### Tasks

1. **Review RBAC store**
   - Check `src/Surypus/RBAC/Store.hs`
   - Review `RBAC.md` documentation

2. **Implement permission checks**
   - Add `requirePermission` to protected endpoints
   - Check user roles against required permissions
   - Return 403 for insufficient permissions

3. **Test permissions**
   - Test with different user roles
   - Verify access denied scenarios

### Acceptance Criteria
- [ ] Permission checks on all state-changing endpoints
- [ ] Users see only authorized data
- [ ] 403 returned for unauthorized access
- [ ] Roles: admin, manager, accountant, warehouse, viewer

---

## Plan 1.4: Integration Tests with PostgreSQL

**Status:** pending

### Tasks

1. **Test database setup**
   - Create `surypus_test` database
   - Run migrations on test database
   - Add test data seeding

2. **Write integration tests**
   - Test full request/response cycle
   - Test authentication flow
   - Test CRUD operations with real data

3. **CI configuration**
   - Add PostgreSQL service to CI
   - Run tests against real database in CI

### Acceptance Criteria
- [ ] Tests run against PostgreSQL
- [ ] Test database created automatically
- [ ] All integration tests pass
- [ ] CI runs tests successfully