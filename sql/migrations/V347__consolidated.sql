-- Migration V347: Consolidated RBAC canonical concurrency tests
-- Original files: V347__rbac_canonical_concurrency_tests.sql, V347__rbac_canonical_concurrency_tests_test.sql

-- Create test results table
CREATE TABLE IF NOT EXISTS concurrency_test_results (
    id SERIAL PRIMARY KEY,
    test_name TEXT,
    result BOOLEAN,
    executed_at TIMESTAMPTZ DEFAULT NOW()
);
