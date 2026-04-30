# ROADMAP

- Implement domain-driven RBACCanon with full SQL generation DSL
- Extend MV019–MV040 migrations and tests (unique constraints, views, notes, etag, etc.)
- Extend MV033–MV040 with concrete migrations and tests, and MV041–MV044 placeholders for future growth
- Extend migrations further to V029–V032 (more indexes, views, constraints)
- Implement dry-run migrations in CI and ensure end-to-end DSL migration pipeline
- Expand Observability/Concurrency/Config tests and runbooks
- Integrate migrations into CI with DSL generation + domain tests + linting
- Expand Observability, Concurrency, Self-Heal, and Config domains
- Integrate migrations with a DSL‑driven compiler
- Build CI checks for migrations + domain tests
