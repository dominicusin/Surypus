-- Vacuum and analyze maintenance
CREATE OR REPLACE FUNCTION maintenance_vacuum_analyze(
    p_tables TEXT[] DEFAULT ARRAY['event_store', 'aggregate_snapshots', 'event_outbox', 'projection_audit']
) RETURNS TABLE(table_name TEXT, rows_affected BIGINT) AS $$
DECLARE
    v_table TEXT;
    v_estimated_rows BIGINT;
BEGIN
    FOREACH v_table IN ARRAY p_tables
    LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = v_table) THEN
            EXECUTE format('VACUUM ANALYZE %I', v_table);
            EXECUTE format('SELECT pg_total_relation_size(%L)', v_table) INTO v_estimated_rows;
            table_name := v_table;
            rows_affected := v_estimated_rows;
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Reindex maintenance
CREATE OR REPLACE FUNCTION maintenance_reindex(
    p_tables TEXT[] DEFAULT ARRAY['event_store', 'aggregates']
) RETURNS VOID AS $$
DECLARE
    v_table TEXT;
BEGIN
    FOREACH v_table IN ARRAY p_tables
    LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = v_table) THEN
            EXECUTE format('REINDEX TABLE %I', v_table);
        END IF;
    END LOOP;
    RAISE NOTICE 'Reindex completed for % tables', array_length(p_tables, 1);
END;
$$ LANGUAGE plpgsql;

-- Get table statistics
CREATE OR REPLACE FUNCTION table_stats(p_table_name TEXT) RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    EXECUTE format('SELECT to_jsonb(t) FROM (SELECT 
        pg_total_relation_size(%L) as total_size,
        pg_relation_size(%L) as table_size,
        pg_indexes_size(%L) as index_size,
        (SELECT COUNT(*) FROM %I) as row_count
    ) t', p_table_name, p_table_name, p_table_name, p_table_name) INTO v_result;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;