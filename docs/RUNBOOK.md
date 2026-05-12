# Development Runbook

## Current Blockers

1. **Database Connectivity** - PostgreSQL 14/15 not available locally
   - Docker/podman requires root privileges (blocked)
   - CI runs tests against remote PostgreSQL service

2. **Test Execution** - Cannot run `stack test` without database
   - Surypus-628 requires real database for RBAC tests
   - Surypus-616 requires database for connection pooling tests
   - Surypus-619 requires API server with database

## Available Infrastructure

- **scripts/setup_test_db.sh** - Creates surypus_test database
- **scripts/init_db.sh** - Initializes production database
- **test/MakeTestSeed.hs** - Test fixtures with TEST_DB_DSN support

## CI/CD Status

✅ Matrix testing: GHC 9.6.6, 9.8.4; PostgreSQL 14, 15
✅ Stack build: Configured (nix disabled)
✅ HLint: Integrated with --color and --pedantic
✅ Migration validation: scripts/check_schema_uniqueness.sh

## Next Steps

1. Provide PostgreSQL service for local testing
2. Run `scripts/setup_test_db.sh` to create test database
3. Set TEST_DB_DSN and run tests
4. Complete Surypus-628 (RBAC tests without skip flag)
