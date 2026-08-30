-- Index optimization for billing read paths
-- Guarded: bill_line is created by a later migration, so only create the index
-- once the table exists (ordering-tolerant, idempotent).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bill_line') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_bill_line_bill_id ON bill_line (bill_id)';
  END IF;
END $$;
