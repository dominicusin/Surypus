-- V332__rbac_canonical_finalization_dry_run_test.sql
-- Test dry-run function
DO $$
DECLARE
    v_row RECORD;
    v_total INTEGER := 0;
BEGIN
    -- Ensure function exists and can be called
    FOR v_row IN SELECT * FROM rbac.canonicalize_dry_run() LOOP
        v_total := v_total + 1;
        -- Each row should have schema_name, table_name, would_update_count
        IF v_row.schema_name IS NULL OR v_row.table_name IS NULL OR v_row.would_update_count IS NULL THEN
            RAISE EXCEPTION 'dry_run returned NULL column';
        END IF;
        IF v_row.would_update_count < 0 THEN
            RAISE EXCEPTION 'dry_run returned negative count';
        END IF;
    END LOOP;
    -- Optionally, we could assert that if there are inconsistencies, dry_run returns something
    -- But for now, just ensure it runs without error.
END;
$$ LANGUAGE plpgsql;