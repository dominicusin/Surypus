-- V424__rbac_backlog_metrics_json_test.sql
DO $$ BEGIN IF EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_schema = 'rbac' AND routine_name = 'backlog_metrics_json') THEN PERFORM rbac.backlog_metrics_json(); END IF; END; $$ LANGUAGE plpgsql;
