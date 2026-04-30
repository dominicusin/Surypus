-- Ensure automated snapshot policy is available and integrated
DO $$ BEGIN
  -- If the function doesn't exist (older DBs), create a minimal version
  IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name = 'maybe_create_snapshot') THEN
    CREATE OR REPLACE FUNCTION maybe_create_snapshot(
      p_aggregate_id UUID,
      p_threshold INT DEFAULT 50
    ) RETURNS VOID AS $$ BEGIN END; $$ LANGUAGE plpgsql;
  END IF;
END $$;
