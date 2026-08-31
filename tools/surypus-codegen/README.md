# surypus-codegen

Type-safe transpiler for Surypus ERP. Reads `dsl/schema.yaml` and generates the full stack:

- `src/DAL/Schema.hs` (Persistent TH)
- `src/DAL/Types.hs` (Haskell types + LiquidHaskell refinements)
- `src/DAL/QueriesORM.hs` (Esqueleto SELECT queries)
- `src/DAL/MutationsORM.hs` (INSERT/UPDATE/DELETE)
- `src/DAL/ClassifiersORM.hs` (classifier lookups)
- `src/DAL/Procedures.hs` (stored-procedure wrappers)
- `sql/migrations/V{N}__*.sql` (DDL migrations)
- `openapi/spec.yaml` (OpenAPI 3.0)
- `frontend/qml/generated/*.qml` (QML forms + models)

See `strategic_analysis_pgenie_plan.md` for the full architecture.
