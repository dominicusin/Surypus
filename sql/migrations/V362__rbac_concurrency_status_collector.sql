-- V362__rbac_concurrency_status_collector.sql
-- Gather runtime concurrency metrics into JSON
CREATE OR REPLACE FUNCTION rbac.collect_concurrency_status() RETURNS JSONB AS $$
DECLARE
  v_out JSONB := '{}'::JSONB;
BEGIN
  SELECT count(*) INTO STRICT v_out FROM pg_stat_activity;
  v_out := jsonb_build_object('connections_active', (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active'), 'connections_idle', (SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'idle'));
  RETURN v_out;
END;
$$ LANGUAGE plpgsql;
