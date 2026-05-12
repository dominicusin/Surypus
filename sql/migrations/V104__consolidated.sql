-- Migration V104: Consolidated snapshot policy and projection
-- Original files: V104__snapshot_policy.sql, V104__snapshot_policy_and_build.sql

-- Placeholder for snapshot policy configuration
-- Actual implementation would create policy tables and functions
CREATE TABLE IF NOT EXISTS snapshot_policy (
    id SERIAL PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projection_build_queue (
    id SERIAL PRIMARY KEY,
    projection_name TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);
