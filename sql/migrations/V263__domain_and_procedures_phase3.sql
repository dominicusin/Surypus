-- Domain-based stubs and cleanup for non-existent tables
-- This migration consolidates placeholders and marks TODOs for later completion.

-- Placeholder: common TODO function to indicate work required
CREATE OR REPLACE FUNCTION todo_return_text()
RETURNS TEXT AS $$ BEGIN RETURN 'TODO'; END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION todo_return_int()
RETURNS INT AS $$ BEGIN RETURN 0; END; $$ LANGUAGE plpgsql;

-- Documented TODOs for missing domain objects
DO $$ BEGIN
   RAISE NOTICE 'TODO: migrate domain-specific objects to proper modules';
END $$;
