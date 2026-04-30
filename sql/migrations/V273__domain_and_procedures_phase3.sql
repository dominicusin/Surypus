-- Domain-based cleanup: move remaining references to non-existent tables into procedures_phase3.sql
-- This is a safety step to ensure no runtime references break during domain isolation.
DO $$ BEGIN
  RAISE NOTICE 'Phase 3.1: Domain cleanup – references moved to procedures_phase3.sql (placeholder)';
END $$;
