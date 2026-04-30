-- V339__rbac_prometheus_metrics_v2.sql
-- Prometheus metrics exporter (version 2) for RBAC canonicalization including circuit breaker status
CREATE OR REPLACE FUNCTION rbac.prometheus_canon_metrics_v2()
RETURNS TEXT AS $$
DECLARE
  v_out TEXT := '';
  v_state TEXT;
  v_incons INTEGER;
  v_last_run TIMESTAMPTZ;
  v_last_updated INTEGER;
  v_last_batch_started TIMESTAMPTZ;
  v_cb_state VARCHAR(20);
BEGIN
  -- Inconsistencies
  v_incons := rbac.count_canon_inconsistencies();
  -- Circuit breaker state
  SELECT state INTO v_state FROM rbac.canon_circuit_breaker WHERE id = 1;
  -- Last metrics
  IF EXISTS (SELECT 1 FROM rbac.canon_metrics ORDER BY run_at DESC LIMIT 1) THEN
    SELECT run_at, updated_rows INTO v_last_run, v_last_updated FROM rbac.canon_metrics ORDER BY run_at DESC LIMIT 1;
  END IF;
  -- Last batch (if any)
  IF EXISTS (SELECT 1 FROM rbac.canon_batch_runs WHERE ended_at IS NOT NULL ORDER BY ended_at DESC LIMIT 1) THEN
    SELECT ended_at - started_at INTO v_last_batch_started FROM rbac.canon_batch_runs WHERE ended_at IS NOT NULL ORDER BY ended_at DESC LIMIT 1;
  END IF;
  -- Canonical circuit-breaker status
  SELECT state INTO v_cb_state FROM rbac.canon_circuit_breaker WHERE id = 1;

  v_out := '# HELP rbac_canon_prometheus_health Health status of RBAC canonicalization' || E'\n' ||
           '# TYPE rbac_canon_prometheus_health gauge' || E'\n' ||
           'rbac_canon_prometheus_health ' || CASE WHEN v_state = 'CLOSED' THEN '1' ELSE '0' END || E'\n' ||
           E'\n' ||
           '# HELP rbac_canon_inconsistencies_total Total canonicalization inconsistencies' || E'\n' ||
           '# TYPE rbac_canon_inconsistencies_total gauge' || E'\n' ||
           'rbac_canon_inconsistencies_total ' || v_incons::text || E'\n' || E'\n' ||
           '# HELP rbac_canon_last_run_updated_rows The updated rows count in the last canonicalization run' || E'\n' ||
           '# TYPE rbac_canon_last_run_updated_rows gauge' || E'\n' ||
           'rbac_canon_last_run_updated_rows ' || coalesce(v_last_updated::text, '0') || E'\n' || E'\n' ||
           '# HELP rbac_canon_lock_state Canonicalization lock state 0/1' || E'\n' ||
           '# TYPE rbac_canon_lock_state gauge' || E'\n' ||
           'rbac_canon_lock_state ' || CASE WHEN v_cb_state = 'LOCK_HELD' THEN '1' ELSE '0' END || E'\n';

  RETURN v_out;
END;
$$ LANGUAGE plpgsql;
