# Project State

See: .planning/PROJECT.md (updated 2026-05-13)

Current focus: Phase 1 — API Production Readiness

## Current Status

- **Phase:** 1 (Active)
- **Active Plan:** Phase 1.2 — JWT Authentication Middleware (nearly complete)
- **Last Milestone:** AuthProtect added to API

## Phase 1 Plans

| Plan | Title | Status | Target Date |
|------|-------|--------|-------------|
| 1.1 | Real DB Queries in API Handlers | ✅ **complete** | Week 1 |
| 1.2 | JWT Authentication Middleware | 🔄 **in_progress** | Week 1-2 |
| 1.3 | RBAC Verification | pending | Week 2 |
| 1.4 | Integration Tests with PostgreSQL | pending | Week 2-3 |

## Completed Today

### Phase 1.1 - API Handlers (COMPLETE)
- `dashboardGet`, `payrollList`, `ordersStatus` - используют реальные DAL функции
- `reportsMeta`, `reportGet` - используют реальные DAL функции

### Phase 1.2 - JWT Authentication (REFACTORED)
- `requirePermissionText_` принимает `Env` параметр
- `checkUserPermission` реализован с проверкой ролей
- `AuthProtect "jwt"` добавлен в SurypusApi
- `AuthHandler` создан для извлечения пользователя

## Known Issues
- `hashtables-1.3.1` build fails due to C compilation error (system dependency)
- `empGet`, `jobsList`, `jobsPending`, `jobsCreate` remain as stubs
- AuthHandler нужно доработать для извлечения токена из заголовка

---
*Last updated: 2026-05-13*