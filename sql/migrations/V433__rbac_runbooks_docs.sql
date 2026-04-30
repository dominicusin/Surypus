-- V433__rbac_runbooks_docs.sql
-- Extended runbooks documentation skeleton for concurrency/self-heal
CREATE OR REPLACE FUNCTION rbac.runbooks_header() RETURNS TEXT AS $$
BEGIN
  RETURN 'Surypus Runbooks: Concurrent Canonicalization, Self-heal, Observability';
END;
$$ LANGUAGE plpgsql;
