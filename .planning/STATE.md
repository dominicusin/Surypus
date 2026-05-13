# Project State

See: .planning/PROJECT.md (updated 2026-05-13)

Current focus: Phase 2 — Production Readiness

## Phase 1: API Production Readiness ✅ COMPLETE

### Phase 1.1 - Real DB Queries in API Handlers ✅
- `dashboardGet` → `getDashboardStats`
- `payrollList` → `getSalaries`
- `ordersStatus` → `updateOrderStatus`
- `reportsMeta` → `getReports`
- `reportGet` → `getReportById`
- `empGet` → `getEmployeeById`

### Phase 1.2 - JWT Authentication Middleware ✅
- `requirePermissionText_` принимает `Env` параметр
- `checkUserPermission` реализован с проверкой ролей
- `AuthProtect "jwt"` добавлен в `SurypusApi`
- `AuthHandler` создан для извлечения пользователя

### Phase 1.3 - RBAC Infrastructure ✅
- `getRoles`, `getGrants` DAL функции
- `checkUserPermission` реализует проверку прав

### Phase 1.4 - Additional Features ✅
- Jobs DAL функции реализованы (`getJobs`, `createJob`)
- Structured logging с correlation IDs
- WebSocket support

---
*Last updated: 2026-05-13*