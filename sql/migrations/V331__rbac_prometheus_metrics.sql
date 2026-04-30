-- V331__rbac_prometheus_metrics.sql
-- Prometheus metrics exporter for RBAC canonicalization
CREATE OR REPLACE FUNCTION rbac.prometheus_canon_metrics()
RETURNS TEXT AS $$
DECLARE
    v_result TEXT := '';
    v_inconsistencies INTEGER;
    v_latest_metrics RECORD;
    v_latest_event RECORD;
    v_latest_batch RECORD;
    v_lock_held BOOLEAN := FALSE; -- Placeholder - actual lock check would be more complex
    v_last_run_timestamp TIMESTAMPTZ;
    v_last_run_updated_rows INTEGER;
    v_last_batch_duration INTERVAL;
    v_last_batch_updated INTEGER;
BEGIN
    -- Get inconsistency count
    v_inconsistencies := rbac.count_canon_inconsistencies();
    
    -- Get latest metrics
    SELECT * INTO v_latest_metrics
    FROM rbac.canon_metrics
    ORDER BY run_at DESC
    LIMIT 1;
    
    IF v_latest_metrics IS NOT NULL THEN
        v_last_run_timestamp := v_latest_metrics.run_at;
        v_last_run_updated_rows := v_latest_metrics.updated_rows;
    END IF;
    
    -- Get latest completed batch for duration and updated rows
    SELECT * INTO v_latest_batch
    FROM rbac.canon_batch_runs
    WHERE ended_at IS NOT NULL
    ORDER BY ended_at DESC
    LIMIT 1;
    
    IF v_latest_batch IS NOT NULL THEN
        v_last_batch_duration := v_latest_batch.ended_at - v_latest_batch.started_at;
        v_last_batch_updated := v_latest_batch.total_updated;
    END IF;
    
    -- Build Prometheus metrics
    v_result := v_result ||
        '# HELP rbac_canon_inconsistencies_total Number of canonicalization inconsistencies (path != canonical_path)' || E'\n' ||
        '# TYPE rbac_canon_inconsistencies_total gauge' || E'\n' ||
        'rbac_canon_inconsistencies_total ' || v_inconsistencies || E'\n' || E'\n';
    
    v_result := v_result ||
        '# HELP rbac_canon_last_run_timestamp_seconds Unix timestamp of last canonicalization metrics run' || E'\n' ||
        '# TYPE rbac_canon_last_run_timestamp_seconds gauge' || E'\n' ||
        'rbac_canon_last_run_timestamp_seconds ' || 
        CASE WHEN v_last_run_timestamp IS NOT NULL THEN 
            EXTRACT(EPOCH FROM v_last_run_timestamp) 
        ELSE 
            '0' 
        END || E'\n' || E'\n';
    
    v_result := v_result ||
        '# HELP rbac_canon_last_run_updated_rows Number of rows updated in last canonicalization metrics run' || E'\n' ||
        '# TYPE rbac_canon_last_run_updated_rows gauge' || E'\n' ||
        'rbac_canon_last_run_updated_rows ' || COALESCE(v_last_run_updated_rows, 0) || E'\n' || E'\n';
    
    v_result := v_result ||
        '# HELP rbac_canon_last_batch_duration_seconds Duration of last completed batch canonicalization run' || E'\n' ||
        '# TYPE rbac_canon_last_batch_duration_seconds gauge' || E'\n' ||
        'rbac_canon_last_batch_duration_seconds ' || 
        CASE WHEN v_last_batch_duration IS NOT NULL THEN 
            EXTRACT(EPOCH FROM v_last_batch_duration) 
        ELSE 
            '0' 
        END || E'\n' || E'\n';
    
    v_result := v_result ||
        '# HELP rbac_canon_last_batch_updated_rows Number of rows updated in last completed batch canonicalization run' || E'\n' ||
        '# TYPE rbac_canon_last_batch_updated_rows gauge' || E'\n' ||
        'rbac_canon_last_batch_updated_rows ' || COALESCE(v_last_batch_updated, 0) || E'\n' || E'\n';
    
    v_result := v_result ||
        '# HELP rbac_canon_lock_held Indicator if canonicalization lock is currently held (1) or not (0)' || E'\n' ||
        '# TYPE rbac_canon_lock_held gauge' || E'\n' ||
        'rbac_canon_lock_held ' || CASE WHEN v_lock_held THEN '1' ELSE '0' END || E'\n' || E'\n';
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;