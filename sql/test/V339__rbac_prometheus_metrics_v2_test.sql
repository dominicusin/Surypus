-- V339__rbac_prometheus_metrics_v2_test.sql
DO $$
DECLARE
  v_metrics TEXT;
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'prometheus_canon_metrics_v2') THEN
    v_metrics := rbac.prometheus_canon_metrics_v2();
    IF v_metrics IS NULL THEN
      RAISE EXCEPTION 'prometheus_canon_metrics_v2 returned NULL';
    END IF;
    IF position('rbac_canon_inconsistencies_total' IN v_metrics) = 0 THEN
      RAISE EXCEPTION 'prometheus metric missing: rbac_canon_inconsistencies_total';
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;
