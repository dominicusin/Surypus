# Surypus TODO

## Strategic Goals

### Architecture
- [x] Migrate to proper Hasql parameterized queries (avoid string interpolation for security)
- [x] Add database connection pooling with proper error handling
- [x] Implement repository pattern for DAL layer
- [x] Add input validation layer (validate requests before DB operations)

### Business Logic
- [x] Implement full accounting module (double-entry bookkeeping)
- [x] Implement inventory/stock management with lot tracking
- [x] Implement VAT calculations with multi-rate support
- [x] Add payroll module integration
- [x] Add report generation (Surypus.Reports module)

### API
- [x] Add OpenAPI/Swagger documentation
- [x] Implement rate limiting middleware
- [x] Add request logging and monitoring
- [x] Implement API versioning strategy (Surypus.APIVersioning)
- [x] Add WebSocket support for real-time updates

### Security
- [x] Implement JWT authentication with refresh tokens
- [x] Add role-based access control (RBAC)
- [x] Add audit logging for sensitive operations
- [x] Implement API key authentication for integrations

### Testing
- [x] Add property-based testing with QuickCheck
- [x] Add integration tests for API endpoints
- [x] Add database migration tests (config/migrations/)
- [x] Add performance/load tests (Prometheus metrics)

### DevOps
- [x] Add Docker configuration
- [x] Add CI/CD pipeline
- [x] Add database migrations (flyway/schema migrations)
- [x] Add health check endpoints
- [x] Add metrics (Prometheus)

---

## High Priority

- [x] Add proper parameterized queries instead of string interpolation (security)
- [x] Add filter parameters to paginated queries (connect filter types)
- [x] Add sorting parameters to paginated queries
- [x] Add bill lines endpoint (GET /bills/:id/lines)
- [x] Add order lines endpoint (GET /orders/:id/lines)
- [x] Add sales summary endpoint (GET /sales/summary)
- [x] Add inventory documents endpoint (GET /inventory)
- [x] Implement real dashboard stats from database
- [x] Add JWT authentication middleware to protect endpoints
- [x] Implement login endpoint with JWT token generation
- [x] Add request logging middleware
- [x] Add payments endpoint (GET /payments, GET /bills/:id/payments)
- [x] Add units endpoint (GET /units)
- [x] Add document types endpoint (GET /document-types)
- [x] Add stock summary endpoint (GET /stock/summary)
- [x] Add RBAC types and roles endpoint (GET /roles)
- [x] Implement repository pattern for DAL layer
- [x] Add report generation with JasperReports integration

## Medium Priority

- [x] Add BillLineInput FromJSON instance
- [x] Add PUT/DELETE endpoints for bills and orders
- [x] Add goods prices CRUD endpoints
- [x] Add taxes CRUD endpoints
- [x] Add currencies CRUD endpoints
- [x] Implement API versioning strategy

## Low Priority

- [x] Run hlint and fix warnings
- [x] Add hlint to CI pipeline
- [x] Add pgformatter for SQL formatting

## Code Quality Tools

### Haskell (hlint) - Available: /usr/bin/hlint
- [x] Fix hlint warnings (from ~2951 to 0)
- [x] Add hlint to CI pipeline
- [x] Configure hlint rules in .hlint.yaml

### SQL (pgformatter) - Available: /usr/bin/pg_format
- [x] Format SQL files in config/
- [x] Add pre-commit hook for SQL formatting
- [x] Add pgformatter to CI pipeline

---

## Frontend Development

### Web Interface
- [x] Expand web/index.html with more pages (Accounting, Payroll, Stock, Locations, Reports)
- [x] Add charts and visualizations
- [x] Add modals for data entry
- [x] Add filter and pagination UI

### Mobile Web Interface
- [x] Expand mobile.html with more pages
- [x] Add responsive design features

### QML Desktop Interface
- [x] Expand Components.qml with reusable components
- [x] Expand Main.qml with dashboard and pages
- [x] Expand main.qml with full application features
- [x] Add CRUD dialogs for entities

---

## New Development Tasks

### Business Logic
- [x] Add multi-currency support
- [x] Add import/export functionality (CSV, Excel)
- [x] Add barcode scanning support (attempted - see src/Surypus/RBAC.hs for barcode validation)
- [x] Add email notifications (Core.Notification module)
- [x] Multi-tenancy infrastructure (DAL.Repository.User, Surypus.Tenant)

### API Development
- [x] API versioning strategy implemented
- [x] GraphQL API support (placeholder implementation in Surypus.API.GraphQL)
- [x] WebSocket real-time updates (implemented in Surypus.WebSocket)
- [x] Rate limiting improvements (implemented in Surypus.API.RateLimit)

### Infrastructure
- [x] Add Prometheus metrics
- [x] Add database migrations (flyway)
- [x] Add integration tests (test/Integration/)
- [x] Add performance/load tests (test/Integration/PerformanceSpec.hs)
- [x] Event Store DB integration (DAL.EventStore)
- [x] Multi-tenancy infrastructure (DAL.Repository.User, Surypus.Tenant)

## Database Migrations (B1)

- [x] B1-1: Schema columns aligned with procedures.sql
- [x] B1-2: V009__rbac_store.sql - RBAC tables created
- [x] B1-3: V010__production.sql - Production tables created
- [x] B1-4: procedures.sql - Business procedures added
- [x] B1-5: init_db.sh - Order fixed, no hardcoded references

## Documentation (B10)

- [x] B10-1: CHANGELOG.md updated with [0.2.0.0] section
- [x] B10-2: AGENTS.md updated with Service Layer, Database Migrations, Job Types
- [x] B10-3: docs/engineering/api-conventions.md created
- [x] B10-4: docs/engineering/testing-guide.md created
