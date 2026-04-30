-- Cleanup old dead-letter queues (maintenance)
CREATE OR REPLACE FUNCTION event_dlq_cleanup(
  p_retention_interval INTERVAL DEFAULT INTERVAL '90 days'
 ) RETURNS VOID AS $$
BEGIN
  DELETE FROM event_dlq
  WHERE resolved = TRUE AND last_error_at < (NOW() - p_retention_interval);
  -- Also remove irreversible failed entries older than retention, even if not resolved (safety window)
  -- Do not fail cleanup if table is empty
  RETURN;
END;
$$ LANGUAGE plpgsql;
