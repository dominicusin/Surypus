---
inclusion: fileMatch
fileMatchPattern: ['**/server/**', '**/services/**', '**/db/**', '**/models/**', '**/migrations/**', '**/DAL/**', '**/API/**', '**/src/**/*.hs']
description: Backend conventions (auto-loaded when working in server code)
---
# Backend Standards

## Database
- Migrations: Flyway-style numbered SQL files in `sql/migrations/` (V001–V182+). Always add new migration as next sequential number.
- Query layer: Hasql with typed decoders — no ORM, no string interpolation. All queries in `src/DAL/` or `surypus-api/src/DAL/`.
- Event sourcing: critical state changes go to `event_store` table. Projections in `sql/projection/`, aggregates in `sql/aggregate/`.
- RBAC schema: `sql/core/V001__rbac_schema.sql`. OPA policies: `opa/policies/rbac.rego`.

## API Patterns
- All handlers follow: `liftIO $ Module.function (envPool env) args` → pattern match `QuerySuccess`/`QueryError`
- `QueryError "Not Found"` → `throwError err404`; other errors → `err500` with message body
- New endpoints: add to `SurypusApi` type in `Server.hs`, add handler to `server` function, implement in domain module

## Error Handling
- Never leak internal errors to clients — use structured error messages
- Log structured errors with correlation ID (see `correlationMiddleware`)
- Use `QueryResult a = QuerySuccess a | QueryError Text` from `DAL.Types`

## Performance
- Add indexes for frequent queries (see `config/schema_indexes_performance.sql`)
- Cache expensive operations (materialized views for dashboard KPIs)
- Set query timeouts in hasql-pool config
