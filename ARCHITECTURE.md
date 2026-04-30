RBACCanon Migration and DSL Architecture

- Domain: RBACCanon
  - Core domain types and models in Surypus.Domain.RBACCanon
  - DSL-based migration generator translating domain changes into SQL migrations
  - Migrations are written to sql/migrations as versioned files (V001..)

- Infra
  - DSL in Surypus.Infra.SqlGen.DSL provides basic builders for SQL: CREATE, ALTER, DROP, RENAME, constraints
  - Migration.hs wires domain changes to DSL builders and emits migration strings

- Observability
  - Skeleton modules and tests exist to collect latency, backlog, throughput metrics
  - Plans to add dashboards and alert rules (CI) later

- Concurrency
  - Skeleton for stress tests, queues, round‑robin/backpressure patterns
  - Tests stubbed for now; will evolve to real orchestration

- Config
  - RuntimeConfig structure with defaults; audit and validation hooks to be added

- CI/CD
  - Migration generation and tests to run in CI; linting and type checks
