Environment Variables (production):
- SURYPUS_DEBUG: enable verbose logging
- SURYPUS_SKIP_RBAC_TESTS: skip RBAC tests locally
- SURYPUS_PROMETHEUS: enable metrics exporter
- DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD: DB connection
- OPA_URL: policy engine endpoint
- JWT_SECRET: JWT signing secret (for server)
- PORT: HTTP port (default 8080)
- API_BASE: API base URL (for frontend)
- GEARS: optional feature flags

Notes:
- Each variable should be documented with expected values and defaults in README.
- All changes should be tested via integration tests and UI workflow.
