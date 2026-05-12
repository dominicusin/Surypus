# Phase 1 Plans: API Production Readiness

## Plan 1.1: Real DB Queries in API Handlers

### Objective

Replace hardcoded stubs in surypus-api/Server.hs with real Hasql queries.

### Tasks

1. **Audit current handlers** — List all handlers returning stubs
2. **DAL connection** — Ensure DAL.Queries and DAL.Mutations are imported
3. **Replace stubs**:
   - `personsList` → `getPersonsPaginated`
   - `billsList` → `getBillsPaginated`
   - `goodsList` → `getGoodsPaginated`
   - `dashboardGet` → real queries to accounts, stock, bills
4. **Test each endpoint** — Verify data returns correctly

### Files to modify

- `surypus-api/Server.hs`
- `Surypus.cabal` (add dependencies if needed)

---

## Plan 1.2: JWT Authentication Middleware

### Objective

Implement JWT authentication protecting all API endpoints.

### Tasks

1. **Add JWT middleware** — Check Authorization header on protected routes
2. **Login endpoint** — POST /api/v1/auth/login returns JWT
3. **Token validation** — Verify token signature and expiry
4. **401 responses** — Return Unauthorized for missing/invalid tokens

### Files to modify

- `surypus-api/Server.hs`
- `src/Surypus/Auth.hs` (if exists, or create)

---

## Plan 1.3: RBAC Authorization

### Objective

Add role-based access control to protected operations.

### Tasks

1. **Add requirePermission middleware** — Check user role has permission
2. **Protect write operations**:
   - POST /persons
   - PUT /persons/:id
   - DELETE /persons/:id
   - Same for goods, bills
3. **403 responses** — Return Forbidden for unauthorized

### Files to modify

- `surypus-api/Server.hs`
- `src/DAL/Repository/RBAC.hs`

---

## Plan 1.4: Integration Tests

### Objective

Set up comprehensive test suite with real database.

### Tasks

1. **Create test database** — Run scripts/setup_test_db.sh
2. **Test fixtures** — Create test users, goods, bills
3. **Test cases**:
   - auth: login success/failure
   - persons: CRUD operations
   - goods: CRUD operations
   - bills: create, post, verify accounting
4. **Remove skip flags** — Tests pass without SURYPUS_SKIP_RBAC_TESTS

### Files to modify

- `test/API/ServerSpec.hs`
- `test/App.hs`
- `.github/workflows/ci.yml`