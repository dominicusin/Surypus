-- Phase 3: Placeholder procedures and guards for migrating references
-- to domain modules that are not yet present in the current phase.
-- The goal is to provide safe stubs so that calls can be routed without
-- failing on missing objects during transitional migrations.

-- Utility: check if a table exists (safe in migrations and runtime)
CREATE OR REPLACE FUNCTION safe_table_exists(
   p_table_name TEXT
) RETURNS BOOLEAN AS $$
BEGIN
   RETURN EXISTS (
     SELECT 1 FROM information_schema.tables
     WHERE table_name = p_table_name
   );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Guard: if a table is missing, log a notice and allow execution to continue
CREATE OR REPLACE FUNCTION guard_table_missing(
   p_table_name TEXT
) RETURNS BOOLEAN AS $$
BEGIN
   IF NOT safe_table_exists(p_table_name) THEN
     RAISE NOTICE 'Phase3 guard: table % is missing; continuing with no-op', p_table_name;
   END IF;
   RETURN TRUE;
END;
$$ LANGUAGE plpgsql;