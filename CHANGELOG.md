# Changelog

All notable changes to this project will be documented in this file.

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
