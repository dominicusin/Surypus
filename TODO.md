# Surypus TODO

## Strategic Goals

### Architecture
- [ ] Migrate to proper Hasql parameterized queries (avoid string interpolation for security)
- [ ] Add database connection pooling with proper error handling
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
- [ ] Implement rate limiting middleware
- [ ] Add request logging and monitoring
- [ ] Implement API versioning strategy
- [ ] Add WebSocket support for real-time updates

### Security
- [ ] Implement JWT authentication with refresh tokens
- [ ] Add role-based access control (RBAC)
- [ ] Add audit logging for sensitive operations
- [ ] Implement API key authentication for integrations

### Testing
- [ ] Add property-based testing with QuickCheck
- [ ] Add integration tests for API endpoints
- [ ] Add database migration tests
- [ ] Add performance/load tests

### DevOps
- [ ] Add Docker configuration
- [ ] Add CI/CD pipeline
- [ ] Add database migrations (flyway/schema migrations)
- [ ] Add health check endpoints
- [ ] Add metrics (Prometheus)

---

## High Priority

- [ ] Add proper parameterized queries instead of string interpolation (security)
- [ ] Add filter parameters to paginated queries (connect filter types)
- [ ] Add sorting parameters to paginated queries
- [ ] Add JWT authentication middleware to protect endpoints
- [ ] Implement login endpoint with JWT token generation

## Medium Priority

- [ ] Add BillLineInput FromJSON instance
- [ ] Add PUT/DELETE endpoints for bills and orders
- [ ] Add goods prices CRUD endpoints
- [ ] Add taxes CRUD endpoints
- [ ] Add currencies CRUD endpoints

## Low Priority

- [ ] Run hlint and fix warnings
- [ ] Add hlint to CI pipeline
- [ ] Add pgformatter for SQL formatting

## Code Quality Tools

### Haskell (hlint) - Available: /usr/bin/hlint
- [ ] Fix hlint warnings
- [ ] Add hlint to CI pipeline
- [ ] Configure hlint rules in .hlint.yaml

### SQL (pgformatter) - Available: /usr/bin/pg_format
- [ ] Format SQL files in config/
- [ ] Add pre-commit hook for SQL formatting
- [ ] Add pgformatter to CI pipeline
