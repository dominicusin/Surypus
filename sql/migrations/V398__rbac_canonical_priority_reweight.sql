-- V398__rbac_canonical_priority_reweight.sql
-- Reweight canonical queue items by a simple heuristic to enable prioritization
CREATE OR REPLACE FUNCTION rbac.reweight_queue_priority() RETURNS VOID AS $$
BEGIN
  UPDATE rbac.canon_queue
  SET priority = CASE
      WHEN priority IS NULL THEN 1
      ELSE 1 + (char_length(coalesce(table_name, '')) + char_length(coalesce(table_schema, ''))) % 10
    END
  WHERE status = 'pending';
END;
$$ LANGUAGE plpgsql;
