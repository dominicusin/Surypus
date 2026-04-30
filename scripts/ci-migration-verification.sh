#!/usr/bin/env bash
set -euo pipefail

echo "Migration Verification Suite: starting"

# Dry-run migrations (no DB required)
echo "Running dry-run migration validation..."
bash scripts/ci-dry-run-mig.sh

# Optional: DB dry-run if a test DB connection is provided via env var
if [ -n "${TEST_PG_CONN:-}" ]; then
  if command -v psql > /dev/null 2>&1; then
    echo "Running database migration dry-run against: $TEST_PG_CONN"
    TMP=/tmp/migrate_all.sql
    rm -f "$TMP"
    echo "BEGIN;" > "$TMP"
    for f in sql/migrations/V*.generated.sql; do
      if [ -f "$f" ]; then
        echo "-- apply $f" >> "$TMP"
        cat "$f" >> "$TMP"
        echo ";" >> "$TMP"
      fi
    done
    echo "ROLLBACK;" >> "$TMP"
    psql "$TEST_PG_CONN" -f "$TMP" || { echo "DB migrations dry-run failed"; exit 1; }
    echo "DB migrations dry-run completed (rolled back)."
  else
    echo "psql not installed in CI image; skipping DB dry-run."
  fi
else
  echo "TEST_PG_CONN not set; skipping DB dry-run."
fi

# Basic static checks (if hlint is available in CI, do not fail if not present)
if command -v hlint > /dev/null 2>&1; then
  echo "Running hlint..."
  hlint . || true
fi

# Run targeted tests for migrations (MigrationDryRun and DSL tests)
echo "Running test suite for migrations..."
stack test --test-arguments "-m MigrationDryRun|RBACCanon.Migrations" --color

echo "Migration Verification Suite: completed"
