-- V345__rbac_canonical_status.sql
-- Consolidated status object for canonicalization health checks
CREATE OR REPLACE FUNCTION rbac.canon_status() RETURNS JSONB AS $$
DECLARE
  v_inconsistencies INTEGER;
  v_consistent BOOLEAN;
  v_last_run RECORD;
  v_last_batch RECORD;
  v_cb RECORD;
  v_cb_state VARCHAR(20);
BEGIN
  v_inconsistencies := rbac.count_canon_inconsistencies();
  v_consistent := (v_inconsistencies = 0);

  SELECT * INTO v_last_run FROM rbac.canon_metrics ORDER BY run_at DESC LIMIT 1;
  SELECT * INTO v_last_batch FROM rbac.canon_batch_runs ORDER BY ended_at DESC LIMIT 1;
  SELECT * INTO v_cb FROM rbac.canon_circuit_breaker WHERE id = 1;
  v_cb_state := v_cb.state;

  RETURN jsonb_build_object(
    'consistent', v_consistent,
    'inconsistencies', v_inconsistencies,
    'last_run', ( SELECT row_to_json(r) FROM (SELECT run_at, updated_rows, details FROM rbac.canon_metrics ORDER BY run_at DESC LIMIT 1) r ),
    'last_batch_run', ( SELECT row_to_json(b) FROM (SELECT started_at, ended_at, batch_size, total_updated, status, details FROM rbac.canon_batch_runs ORDER BY ended_at DESC LIMIT 1) b ),
    'circuit_breaker', ( SELECT row_to_json(cb) FROM (SELECT * FROM rbac.canon_circuit_breaker WHERE id = 1) cb ),
    'status', CASE WHEN v_consistent THEN 'healthy' ELSE 'unhealthy' END
  );
END;
$$ LANGUAGE plpgsql;
