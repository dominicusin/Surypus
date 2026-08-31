-- V332__rbac_canonical_finalization_dry_run.sql
-- Dry-run function to preview canonicalization updates without applying them
CREATE OR REPLACE FUNCTION rbac.canonicalize_dry_run()
RETURNS TABLE(schema_name TEXT, table_name TEXT, would_update_count BIGINT) AS $$
DECLARE
    t RECORD;
    cnt INTEGER;
BEGIN
    FOR t IN
        SELECT c1.table_schema, c1.table_name
        FROM information_schema.columns c1
        JOIN information_schema.columns c2 ON c1.table_schema = c2.table_schema AND c1.table_name = c2.table_name
          AND c1.column_name = 'path' AND c2.column_name = 'canonical_path'
        WHERE c1.table_schema = 'rbac'
        GROUP BY c1.table_schema, c1.table_name
        HAVING SUM(CASE WHEN column_name = 'path' THEN 1 ELSE 0 END) > 0
           AND SUM(CASE WHEN column_name = 'canonical_path' THEN 1 ELSE 0 END) > 0
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM %I.%I WHERE canonical_path IS NULL OR canonical_path <> path', t.table_schema, t.table_name) INTO cnt;
        IF cnt > 0 THEN
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;