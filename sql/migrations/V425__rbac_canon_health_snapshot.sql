- V425__rbac_canon_health_snapshot.sql
- Health snapshot for canonicalization
CREATE OR REPLACE FUNCTION rbac.canon_health_snapshot() RETURNS JSONB AS $$
DECLARE
  v_health JSONB;
BEGIN
  v_health := rbac.canon_health_detailed();
  RETURN v_health;
END;
$$ LANGUAGE plpgsql;
