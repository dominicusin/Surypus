-- V329__rbac_canonical_finalization_status_view.sql
-- Create a view that summarizes the latest canonicalization status
CREATE OR REPLACE VIEW rbac.vw_canon_status AS
WITH latest_metrics AS (
    SELECT *
    FROM rbac.canon_metrics
    ORDER BY run_at DESC
    LIMIT 1
), latest_event AS (
    SELECT *
    FROM rbac.canon_events
    ORDER BY run_at DESC
    LIMIT 1
), latest_batch AS (
    SELECT *
    FROM rbac.canon_batch_runs
    WHERE ended_at IS NOT NULL
    ORDER BY ended_at DESC
    LIMIT 1
)
SELECT
    m.run_at AS metrics_run_at,
    m.updated_rows AS metrics_updated_rows,
    m.details AS metrics_details,
    e.run_at AS event_run_at,
    e.table_schema AS event_table_schema,
    e.table_name AS event_table_name,
    e.updated AS event_updated,
    b.started_at AS batch_started_at,
    b.ended_at AS batch_ended_at,
    b.batch_size AS batch_batch_size,
    b.total_updated AS batch_total_updated,
    b.status AS batch_status,
    b.details AS batch_details
FROM latest_metrics m
LEFT JOIN latest_event e ON true
LEFT JOIN latest_batch b ON true;