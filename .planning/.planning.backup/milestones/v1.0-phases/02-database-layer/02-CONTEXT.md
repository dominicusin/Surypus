# Phase 2: Database Layer - Context

**Gathered:** 2026-05-14
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Implement Hasql-based database access layer with migrations. Create the foundation for PostgreSQL database operations used throughout the ERP system.
</domain>

<decisions>
## Implementation Decisions

### Database Access Pattern
- Use Hasql with prepared statements for all database operations
- Create a Database module with connection pool management
- Use Rel8 for complex queries where Hasql patterns are too verbose

### Migration Strategy
- Keep migrations in sql/migrations/ directory
- Use PostgreSQL's native migration capabilities
- Track schema version in database

### Connection Management
- Use hasql-pool for connection pooling
- Environment variables for connection configuration
</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Surypus.CoreTypes already exists
- DAL.Types exists for data access layer types

### Established Patterns
- Layered architecture (Domain, Core, DAL, API)
- PostgreSQL with Hasql/Rel8 planned

### Integration Points
- Main entry point should initialize database pool
- API handlers will use database functions from DAL
</code_context>

<specifics>
## Specific Ideas

- Create Database.hs module with init/close functions
- Create migrations table if not exists
- Add basic SQL migration scripts
</specifics>

<deferred>
## Deferred Ideas

None
</deferred>
