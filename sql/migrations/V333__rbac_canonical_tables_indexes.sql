-- V333__rbac_canonical_tables_indexes.sql
-- Add indexes for better performance on canonicalization tables
DO $$
BEGIN
    -- Indexes for canon_metrics
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'rbac' AND tablename = 'canon_metrics' AND indexname = 'idx_canon_metrics_run_at') THEN
        CREATE INDEX idx_canon_metrics_run_at ON rbac.canon_metrics(run_at DESC);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'rbac' AND tablename = 'canon_metrics' AND indexname = 'idx_canon_metrics_updated_rows') THEN
        CREATE INDEX idx_canon_metrics_updated_rows ON rbac.canon_metrics(updated_rows);
    END IF;
    
    -- Indexes for canon_events
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'rbac' AND tablename = 'canon_events' AND indexname = 'idx_canon_events_run_at') THEN
        CREATE INDEX idx_canon_events_run_at ON rbac.canon_events(run_at DESC);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'rbac' AND tablename = 'canon_events' AND indexname = 'idx_canon_events_table') THEN
        CREATE INDEX idx_canon_events_table ON rbac.canon_events(table_schema, table_name);
    END IF;
    
    -- Indexes for canon_batch_runs
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'rbac' AND tablename = 'canon_batch_runs' AND indexname = 'idx_canon_batch_runs_ended_at') THEN
        CREATE INDEX idx_canon_batch_runs_ended_at ON rbac.canon_batch_runs(ended_at DESC);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'rbac' AND tablename = 'canon_batch_runs' AND indexname = 'idx_canon_batch_runs_status') THEN
        CREATE INDEX idx_canon_batch_runs_status ON rbac.canon_batch_runs(status);
    END IF;
    
    -- Index for config table
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'rbac' AND tablename = 'config' AND indexname = 'idx_config_key') THEN
        CREATE INDEX idx_config_key ON rbac.config(key);
    END IF;
END;
$$;