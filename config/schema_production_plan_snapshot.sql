-- ============================================================================
-- Production plan snapshot log
-- ============================================================================

CREATE TABLE IF NOT EXISTS production_plan_snapshot (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    plan JSONB NOT NULL,
    params TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_production_plan_snapshot_created ON production_plan_snapshot(created_at);
