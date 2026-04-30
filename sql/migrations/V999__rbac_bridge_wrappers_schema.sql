-- V999__rbac_bridge_wrappers_schema.sql
-- Create a bridged wrapper schema for canonicalization function wrappers
CREATE SCHEMA IF NOT EXISTS rbac_core;

CREATE OR REPLACE FUNCTION rbac_core.canonicalize_all() RETURNS VOID AS $$
BEGIN
  PERFORM public.rbac.canonicalize_all();
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rbac_core.canonicalize_all_batch(_batch_size INTEGER) RETURNS VOID AS $$
BEGIN
  PERFORM public.rbac.canonicalize_all_batch(_batch_size);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION rbac_core.next_round_robin_table() RETURNS TABLE (schema_name TEXT, table_name TEXT) AS $$
BEGIN
  RETURN QUERY SELECT * FROM public.rbac.next_canon_table_round_robin();
END;
$$ LANGUAGE plpgsql;
