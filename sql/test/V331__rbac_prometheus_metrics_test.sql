-- V331__rbac_prometheus_metrics_test.sql
-- Test Prometheus metrics exporter function
DO $$
DECLARE
    v_metrics TEXT;
BEGIN
    -- Test that the function returns valid Prometheus format
    v_metrics := rbac.prometheus_canon_metrics();
    
    -- Basic checks: should not be NULL and should contain expected metric names
    IF v_metrics IS NULL THEN
        RAISE EXCEPTION 'prometheus_canon_metrics returned NULL';
    END IF;
    
    IF v_metrics NOT LIKE '%rbac_canon_inconsistencies_total%' THEN
        RAISE EXCEPTION 'Missing rbac_canon_inconsistencies_total metric';
    END IF;
    
    IF v_metrics NOT LIKE '%rbac_canon_last_run_timestamp_seconds%' THEN
        RAISE EXCEPTION 'Missing rbac_canon_last_run_timestamp_seconds metric';
    END IF;
    
    IF v_metrics NOT LIKE '%rbac_canon_last_run_updated_rows%' THEN
        RAISE EXCEPTION 'Missing rbac_canon_last_run_updated_rows metric';
    END IF;
    
    IF v_metrics NOT LIKE '%rbac_canon_last_batch_duration_seconds%' THEN
        RAISE EXCEPTION 'Missing rbac_canon_last_batch_duration_seconds metric';
    END IF;
    
    IF v_metrics NOT LIKE '%rbac_canon_last_batch_updated_rows%' THEN
        RAISE EXCEPTION 'Missing rbac_canon_last_batch_updated_rows metric';
    END IF;
    
    IF v_metrics NOT LIKE '%rbac_canon_lock_held%' THEN
        RAISE EXCEPTION 'Missing rbac_canon_lock_held metric';
    END IF;
    
    -- Check that it has proper Prometheus format (starts with # HELP or # TYPE or metric)
    IF v_metrics !~ '(^# HELP|^# TYPE|^rbac_canon_)' THEN
        RAISE EXCEPTION 'Does not appear to be valid Prometheus format';
    END IF;
END;
$$ LANGUAGE plpgsql;