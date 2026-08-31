-- Projection performance analysis view.
-- Guarded: projection_audit is created by a later migration; only build the
-- view/function once that table exists (ordering-tolerant, idempotent).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'projection_audit') THEN
    EXECUTE 'CREATE OR REPLACE VIEW v_projection_performance AS
      SELECT
          projection_name,
          event_type,
          COUNT(*) as total_runs,
          AVG(duration_ms) as avg_duration_ms,
          MAX(duration_ms) as max_duration_ms,
          MIN(duration_ms) as min_duration_ms,
          PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_duration_ms,
          SUM(CASE WHEN status = ''failure'' THEN 1 ELSE 0 END) as failure_count,
          COUNT(CASE WHEN status = ''failure'' THEN 1 END) * 100.0 / COUNT(*) as failure_rate_pct
      FROM projection_audit
      WHERE created_at > NOW() - INTERVAL ''24 hours''
      GROUP BY projection_name, event_type;';

    EXECUTE 'CREATE OR REPLACE FUNCTION projection_slow_alert(p_threshold_ms INT DEFAULT 1000)
      RETURNS TABLE(projection_name TEXT, event_type TEXT, max_duration_ms INT)
      AS $func$
      BEGIN
          RETURN QUERY
          SELECT pa.projection_name, pa.event_type, MAX(pa.duration_ms)::INT as max_duration_ms
          FROM projection_audit pa
          WHERE pa.duration_ms > p_threshold_ms
            AND pa.created_at > NOW() - INTERVAL ''1 hour''
          GROUP BY pa.projection_name, pa.event_type;
      END;
      $func$ LANGUAGE plpgsql;';
  END IF;
END $$;
