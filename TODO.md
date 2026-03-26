# Surypus TODO

## Strategic Goals

### Architecture
- [x] Migrate to proper Hasql parameterized queries (avoid string interpolation for security)
- [x] Add database connection pooling with proper error handling
- [ ] Implement repository pattern for DAL layer
- [ ] Add input validation layer (validate requests before DB operations)

### Business Logic
- [ ] Implement full accounting module (double-entry bookkeeping)
- [ ] Implement inventory/stock management with lot tracking
- [ ] Implement VAT calculations with multi-rate support
- [ ] Add payroll module integration
- [ ] Add report generation (JasperReports integration)

### API
- [ ] Add OpenAPI/Swagger documentation
- [x] Implement rate limiting middleware
- [x] Add request logging and monitoring
- [ ] Implement API versioning strategy
- [ ] Add WebSocket support for real-time updates

### Security
- [ ] Implement JWT authentication with refresh tokens
- [x] Add role-based access control (RBAC)
- [ ] Add audit logging for sensitive operations
- [ ] Implement API key authentication for integrations

### Testing
- [x] Add property-based testing with QuickCheck
- [ ] Add integration tests for API endpoints
- [ ] Add database migration tests
- [ ] Add performance/load tests

### DevOps
- [ ] Add Docker configuration
- [ ] Add CI/CD pipeline
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

## Medium Priority

- [x] Add BillLineInput FromJSON instance
- [x] Add PUT/DELETE endpoints for bills and orders
- [x] Add goods prices CRUD endpoints
- [x] Add taxes CRUD endpoints
- [x] Add currencies CRUD endpoints

## Low Priority

- [x] Run hlint and fix warnings
- [ ] Add hlint to CI pipeline
- [ ] Add pgformatter for SQL formatting

## Code Quality Tools

### Haskell (hlint) - Available: /usr/bin/hlint
- [x] Fix hlint warnings (from ~2951 to 0)
- [x] Add hlint to CI pipeline
- [x] Configure hlint rules in .hlint.yaml

### SQL (pgformatter) - Available: /usr/bin/pg_format
- [ ] Format SQL files in config/
- [ ] Add pre-commit hook for SQL formatting
- [ ] Add pgformatter to CI pipeline
