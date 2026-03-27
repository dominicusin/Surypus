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
- [ ] Add report generation (JasperReports integration)

### API
- [x] Add OpenAPI/Swagger documentation
- [x] Implement rate limiting middleware
- [x] Add request logging and monitoring
- [ ] Implement API versioning strategy
- [x] Add WebSocket support for real-time updates

### Security
- [x] Implement JWT authentication with refresh tokens
- [x] Add role-based access control (RBAC)
- [x] Add audit logging for sensitive operations
- [x] Implement API key authentication for integrations

### Testing
- [x] Add property-based testing with QuickCheck
- [ ] Add integration tests for API endpoints
- [ ] Add database migration tests
- [ ] Add performance/load tests

### DevOps
- [x] Add Docker configuration
- [x] Add CI/CD pipeline
- [ ] Add database migrations (flyway/schema migrations)
- [x] Add health check endpoints
- [ ] Add metrics (Prometheus)

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
- [ ] Add barcode scanning support
- [ ] Add email notifications

### API Development
- [x] API versioning strategy implemented
- [ ] GraphQL API support
- [ ] WebSocket real-time updates
- [ ] Rate limiting improvements

### Infrastructure
- [x] Add Prometheus metrics
- [x] Add database migrations (flyway)
- [ ] Add integration tests
- [ ] Add performance/load tests
