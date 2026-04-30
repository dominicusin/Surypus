-- V396__rbac_canon_backlog_view_test.sql
DO $$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'rbac' AND table_name = 'vw_canon_backlog') THEN PERFORM 1; END IF; END $$ LANGUAGE plpgsql;
