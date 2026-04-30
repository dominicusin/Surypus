-- Canonical projection registry glue (defensive)
CREATE TABLE IF NOT EXISTS canonical_projection_registry (
  projection_name TEXT PRIMARY KEY,
  canonical_handler TEXT NOT NULL
);

CREATE OR REPLACE FUNCTION projection_registry_lookup(p_name TEXT)
RETURNS TEXT AS $$
DECLARE
  v_handler TEXT;
BEGIN
  SELECT canonical_handler INTO v_handler FROM canonical_projection_registry WHERE projection_name = p_name;
  IF v_handler IS NULL THEN
    RETURN p_name;
  ELSE
    RETURN v_handler;
  END IF;
END;
$$ LANGUAGE plpgsql;
