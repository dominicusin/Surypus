-- =================================================================================
-- Report Scheduling + Render Log
-- =================================================================================

CREATE TABLE IF NOT EXISTS report_schedule (
    id SERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL UNIQUE,
    report_name VARCHAR(128) NOT NULL,
    cron_expr VARCHAR(64) NOT NULL,
    params JSONB DEFAULT '{}'::jsonb,
    enabled BOOLEAN DEFAULT TRUE,
    next_run TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS report_render_snapshot (
    id SERIAL PRIMARY KEY,
    schedule_id INT NOT NULL REFERENCES report_schedule(id) ON DELETE CASCADE,
    run_id UUID DEFAULT uuid_generate_v4(),
    run_at TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(32) NOT NULL,
    message TEXT,
    jrxml TEXT
);

CREATE INDEX IF NOT EXISTS idx_report_schedule_next_run ON report_schedule(next_run);
CREATE INDEX IF NOT EXISTS idx_report_snapshot_schedule ON report_render_snapshot(schedule_id);

CREATE OR REPLACE FUNCTION report_schedule_set_updated()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_report_schedule_update
    BEFORE UPDATE ON report_schedule
    FOR EACH ROW
    EXECUTE FUNCTION report_schedule_set_updated();
