-- V366__rbac_concurrency_rate_limit.sql
-- Rate limiting wrapper for canonicalization
CREATE OR REPLACE FUNCTION rbac.canonicalize_all_rate_limited() RETURNS VOID AS $$
DECLARE
  d_ms INTEGER := 0;
BEGIN
  BEGIN
    SELECT COALESCE(value::int,0) INTO d_ms FROM rbac.config WHERE key = 'canonical_rate_limit_ms' LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    d_ms := 0;
  END;
  IF d_ms > 0 THEN
    PERFORM pg_sleep(d_ms / 1000.0);
  END IF;
  PERFORM rbac.canonicalize_all();
END;
$$ LANGUAGE plpgsql;
