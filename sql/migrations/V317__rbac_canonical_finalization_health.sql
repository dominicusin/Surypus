-- V317__rbac_canonical_finalization_health.sql
-- Health check function for canonicalization status
CREATE OR REPLACE FUNCTION rbac.canon_health() RETURNS TEXT AS $$
DECLARE
  cnt INTEGER;
BEGIN
  cnt := rbac.count_canon_inconsistencies();
  IF cnt > 0 THEN
    RETURN format('INCONSISTENT: %s remaining inconsistencies', cnt);
  ELSE
    RETURN 'OK';
  END IF;
END;
$$ LANGUAGE plpgsql;
