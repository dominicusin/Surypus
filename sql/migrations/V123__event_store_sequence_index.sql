-- Add index on event_store.sequence_number to speed up range scans
DO $$ BEGIN
  CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_event_store_sequence ON event_store(sequence_number);
EXCEPTION WHEN OTHERS THEN
  -- Ignore if index cannot be created in certain environments
  NULL;
END $$;
