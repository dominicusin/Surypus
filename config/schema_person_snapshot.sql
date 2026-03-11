-- =============================================================================
-- Person Summary Snapshot / Materialized Job
-- =============================================================================

CREATE TABLE IF NOT EXISTS person_summary_snapshot (
    id BIGSERIAL PRIMARY KEY,
    run_id UUID DEFAULT uuid_generate_v4(),
    run_at TIMESTAMPTZ DEFAULT NOW(),
    status SMALLINT NOT NULL,
    category SMALLINT NOT NULL,
    total_persons BIGINT NOT NULL,
    total_credit_limit NUMERIC NOT NULL,
    avg_discount NUMERIC NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_person_snapshot_run ON person_summary_snapshot(run_id);
CREATE INDEX IF NOT EXISTS idx_person_snapshot_run_at ON person_summary_snapshot(run_at);

CREATE OR REPLACE FUNCTION run_person_summary_snapshot()
RETURNS TABLE (run_id UUID, run_at TIMESTAMPTZ)
LANGUAGE plpgsql
AS $$
DECLARE
    v_run UUID := uuid_generate_v4();
    v_run_at TIMESTAMPTZ := NOW();
BEGIN
    INSERT INTO person_summary_snapshot (run_id, run_at, status, category, total_persons, total_credit_limit, avg_discount)
    SELECT v_run, v_run_at, status, category, total_persons, total_credit_limit, avg_discount
    FROM get_person_summary();

    RETURN QUERY SELECT v_run, v_run_at;
END;
$$;
