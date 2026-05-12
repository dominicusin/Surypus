# Phase 1: API Production Readiness - Context

**Gathered:** 2026-05-13
**Status:** Ready for planning

## Phase Boundary

Make the API production-ready by connecting real database queries, implementing authentication, and setting up comprehensive testing.

## Implementation Decisions

### API Layer

- Use Hasql for all database queries (type-safe)
- Keep Scotty framework (existing architecture)
- Return JSON responses for all endpoints
- Add pagination parameters (limit, offset, filters)

### Authentication

- JWT tokens with refresh token rotation
- Store refresh tokens in PostgreSQL
- 15-minute access token expiry
- 7-day refresh token expiry

### Authorization

- RBAC roles: admin, manager, user
- Permissions checked via middleware
- 403 for unauthorized, 401 for unauthenticated

### Testing

- PostgreSQL test database (surypus_test)
- Test fixtures for creating test data
- Integration tests cover all CRUD endpoints

## Canonical References

### Downstream agents MUST read these before planning or implementing.

- `.planning/PROJECT.md` — Project overview and context
- `.planning/REQUIREMENTS.md` — Detailed requirements
- `src/surypus-api/Server.hs` — Current API handlers
- `Surypus.cabal` — Project structure and dependencies

---

*Phase: 01-api-production-readiness*
*Context gathered: 2026-05-13*