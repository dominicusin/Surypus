# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0.0] - 2026-04-17

### Added
- **Stability Phase**: Major refactoring toward production-ready architecture
- **Real OpenAPI**: Auto-generated Swagger documentation at `/swagger.json`
- **RBAC In-Memory**: Role-based access control with in-memory authorization
- **JWT Refresh Tokens**: Token refresh endpoint `/auth/refresh`
- **Service Layer Refactoring**: Domain-driven service functions (Core.Services.*)
- **API Conventions**: Standardized response format `{status, data, error}`
- **Property-Based Testing**: QuickCheck for domain invariants
- **Database Migrations**: Flyway-style migrations V001-V010 in `config/migrations/`

### Changed
- API response format: all endpoints return `{status, data, error}`
- Error handling: proper HTTP status codes (400/401/403/404/409/500)
- Pagination: `limit`, `offset`, `total` query parameters
- Field naming: camelCase with domain prefixes (bill*, person*, sr*)

### Modules
- Core.Services (Tax, Goods, Person, Accounting, Inventory)
- Core.API (Handlers, Middleware, Types)
- DAL.Repository (Person, Goods, Bill, Stock)
- Surypus.RBAC
- Surypus.JWT
- Surypus.OpenAPI

### Database Tables
- New: roles, permissions, user_roles, role_permissions
- New: job_types, job_payloads

### API Endpoints
- Auth: login, logout, me, refresh
- RBAC: GET /roles, GET /permissions
- Jobs: GET /jobs, POST /jobs, GET /jobs/:id
- OpenAPI: GET /swagger.json, GET /api-docs

---

## [0.1.0.0] - 2026-03-11

### Added
- Initial release
- **Core Modules**: 253 Haskell modules for ERP functionality
- **Database**: PostgreSQL schema with 30+ tables, constraints, indexes, triggers
- **API Server**: REST API with CRUD operations (port 8080)
- **Authentication**: JWT-based auth with login/logout/me endpoints
- **QML UI**: Complete desktop application with navigation
- **Web UI**: Desktop and Mobile (PWA) interfaces
- **Reports**: 9 PDF-Slave templates (invoice, order, goods requisition, act, payroll, inventory, balance, cash in/out)
- **Conversion**: CrystalReports to PDF-Slave and JasperReports converters
- **Tests**: 32 unit tests passing
- **CI/CD**: GitHub Actions workflow

### Modules
- Core (Payroll, Accounting, HR, Goods, Inventory, Document, etc.)
- DB (Person, Goods, Location, JobQueue, Accounting)
- Domain (Person, Goods, Job, etc.)
- Surypus (Z3, Reports, I18n, Core)
- Surypus.Reports (Conversion, Templates)
- Surypus.Foreign (QML bindings)
- APIServer

### Templates
- invoice.yaml - Счёт-фактура
- order.yaml - Счёт на оплату
- goods_requisition.yaml - Товарная накладная (ТОРГ-12)
- act.yaml - Акт выполненных работ
- payroll.yaml - Расчётная ведомость
- inventory.yaml - Остатки товаров
- balance.yaml - Бухгалтерский баланс
- cash_in.yaml - ПКО
- cash_out.yaml - РКО

### Database Tables
- companies, persons, goods, goods_groups
- locations, stock
- bills, bill_items
- accounts, accounting_entries
- employees, payroll
- jobs, reports
- user_sessions, audit_log

### API Endpoints
- Health, Auth (login, logout, me)
- Persons CRUD
- Goods CRUD
- Locations CRUD
- Bills CRUD
- Stock
- Accounting (accounts, entries)
- Payroll (employees, salary)
- Jobs
- Reports (including templates)
