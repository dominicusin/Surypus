-- Database statistics view
CREATE OR REPLACE VIEW v_db_stats AS
SELECT 
    'event_store' as table_name,
    COUNT(*) as row_count,
    pg_size_pretty(pg_total_relation_size('event_store')) as size
UNION ALL
SELECT 
    'aggregate_snapshots' as table_name,
    COUNT(*) as row_count,
    pg_size_pretty(pg_total_relation_size('aggregate_snapshots')) as size
UNION ALL
SELECT 
    'event_outbox' as table_name,
    COUNT(*) as row_count,
    pg_size_pretty(pg_total_relation_size('event_outbox')) as size
UNION ALL
SELECT 
    'projection_audit' as table_name,
    COUNT(*) as row_count,
    pg_size_pretty(pg_total_relation_size('projection_audit')) as size
UNION ALL
SELECT 
    'aggregates' as table_name,
    COUNT(*) as row_count,
    pg_size_pretty(pg_total_relation_size('aggregates')) as size;

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