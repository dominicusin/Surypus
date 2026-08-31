-- Database statistics view.
-- projection_audit is created by a later migration; build the view with or
-- without that row so it stays valid at any load order.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'projection_audit') THEN
    EXECUTE 'CREATE OR REPLACE VIEW v_db_stats AS
      SELECT ''event_store'' as table_name, COUNT(*) as row_count, pg_size_pretty(pg_total_relation_size(''event_store'')) as size FROM event_store
      UNION ALL
      SELECT ''aggregate_snapshots'' as table_name, COUNT(*) as row_count, pg_size_pretty(pg_total_relation_size(''aggregate_snapshots'')) as size FROM aggregate_snapshots
      UNION ALL
      SELECT ''event_outbox'' as table_name, COUNT(*) as row_count, pg_size_pretty(pg_total_relation_size(''event_outbox'')) as size FROM event_outbox
      UNION ALL
      SELECT ''projection_audit'' as table_name, COUNT(*) as row_count, pg_size_pretty(pg_total_relation_size(''projection_audit'')) as size FROM projection_audit
      UNION ALL
      SELECT ''aggregates'' as table_name, COUNT(*) as row_count, pg_size_pretty(pg_total_relation_size(''aggregates'')) as size FROM aggregates;';
  ELSE
    EXECUTE 'CREATE OR REPLACE VIEW v_db_stats AS
      SELECT ''event_store'' as table_name, COUNT(*) as row_count, pg_size_pretty(pg_total_relation_size(''event_store'')) as size FROM event_store
      UNION ALL
      SELECT ''aggregate_snapshots'' as table_name, COUNT(*) as row_count, pg_size_pretty(pg_total_relation_size(''aggregate_snapshots'')) as size FROM aggregate_snapshots
      UNION ALL
      SELECT ''event_outbox'' as table_name, COUNT(*) as row_count, pg_size_pretty(pg_total_relation_size(''event_outbox'')) as size FROM event_outbox
      UNION ALL
      SELECT ''aggregates'' as table_name, COUNT(*) as row_count, pg_size_pretty(pg_total_relation_size(''aggregates'')) as size FROM aggregates;';
  END IF;
END $$;

-- Table bloat analysis
CREATE OR REPLACE VIEW v_table_bloat AS
SELECT
    schemaname,
    tablename,
    pg_size_pretty(bloat) as bloat_size,
    bloat
FROM (
    SELECT
        schemaname,
        tablename,
        pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename) as bloat,
        CASE
            WHEN pg_total_relation_size(schemaname||'.'||tablename) > 0
            THEN (pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename))::NUMERIC / pg_total_relation_size(schemaname||'.'||tablename)
            ELSE 0
        END as bloat_ratio
    FROM pg_tables
    WHERE schemaname = 'public'
) sub
WHERE bloat_ratio > 0.1
ORDER BY bloat DESC;
