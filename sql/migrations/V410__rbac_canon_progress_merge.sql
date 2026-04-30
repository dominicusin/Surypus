-- V410__rbac_canon_progress_merge.sql
-- Merge two canon_progress JSON arrays for aggregation
CREATE OR REPLACE FUNCTION rbac.merge_progress(a JSONB, b JSONB) RETURNS JSONB AS $$
BEGIN
  RETURN COALESCE(a, '[]'::JSONB) || COALESCE(b, '[]'::JSONB);
END;
$$ LANGUAGE plpgsql;
