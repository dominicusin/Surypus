-- ============================================================================
-- V347a__rbac_stubs.sql
-- Forward-declare RBAC canonicalization functions referenced in
-- later migration files (V348+) BEFORE their defining files run.
--
-- Every function is ultimately defined in its own V3xx/V4xx migration
-- file later in the chain. CREATE OR REPLACE replaces this stub.
-- ============================================================================

-- Boolean helpers
CREATE OR REPLACE FUNCTION rbac.can_run_canon() RETURNS BOOLEAN AS $$ SELECT FALSE; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.can_run_with_backpressure() RETURNS BOOLEAN AS $$ SELECT FALSE; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.concurrent_canon_job(_slot BIGINT DEFAULT 123456789) RETURNS BOOLEAN AS $$ SELECT FALSE; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.canonize_next_via_rr() RETURNS BOOLEAN AS $$ SELECT FALSE; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.canon_round_robin_step() RETURNS BOOLEAN AS $$ SELECT FALSE; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.start_concurrency_session(_slot BIGINT) RETURNS BOOLEAN AS $$ SELECT FALSE; $$ LANGUAGE sql;

-- JSONB helpers
CREATE OR REPLACE FUNCTION rbac.canon_health_snapshot() RETURNS JSONB AS $$ SELECT '{}'::JSONB; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.canon_progress() RETURNS JSONB AS $$ SELECT '{}'::JSONB; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.collect_backlog_metrics() RETURNS JSONB AS $$ SELECT '{}'::JSONB; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.collect_concurrency_status() RETURNS JSONB AS $$ SELECT '{}'::JSONB; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.collect_latency_metrics() RETURNS JSONB AS $$ SELECT '{}'::JSONB; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.compute_round_robin_fairness() RETURNS JSONB AS $$ SELECT '{}'::JSONB; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.get_canon_reconciliation() RETURNS JSONB AS $$ SELECT '{}'::JSONB; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.merge_progress(a JSONB, b JSONB) RETURNS JSONB AS $$ SELECT '{}'::JSONB; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.validate_all_can_paths() RETURNS JSONB AS $$ SELECT '{}'::JSONB; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.backlog_metrics_json() RETURNS JSONB AS $$ SELECT '{}'::JSONB; $$ LANGUAGE sql;

-- TEXT helpers
CREATE OR REPLACE FUNCTION rbac.ci_validate_migrations() RETURNS TEXT AS $$ SELECT 'ok'; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.export_canon_health() RETURNS TEXT AS $$ SELECT 'ok'; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.prometheus_priority_metrics() RETURNS TEXT AS $$ SELECT 'ok'; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.runbooks_header() RETURNS TEXT AS $$ SELECT 'ok'; $$ LANGUAGE sql;

-- INTEGER helpers
CREATE OR REPLACE FUNCTION rbac.canonical_batch_with_savepoints(_max_tables INTEGER DEFAULT 10) RETURNS INTEGER AS $$ SELECT 0; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.canonicalize_all_with_priority(_limit INTEGER DEFAULT 10) RETURNS INTEGER AS $$ SELECT 0; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.canonicalize_table_with_savepoint() RETURNS INTEGER AS $$ SELECT 0; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.broker_run_once(_limit INTEGER DEFAULT 10) RETURNS INTEGER AS $$ SELECT 0; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.purge_completed_canon_queue(_older_days INTEGER DEFAULT 30) RETURNS INTEGER AS $$ SELECT 0; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.purge_config_logs(_older_days INTEGER DEFAULT 90) RETURNS INTEGER AS $$ SELECT 0; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.retry_canon_queue_failed() RETURNS INTEGER AS $$ SELECT 0; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.process_canon_queue_batch(_limit INT) RETURNS INT AS $$ SELECT 0; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.canon_lock_attempts() RETURNS INTEGER AS $$ SELECT 0; $$ LANGUAGE sql;

-- VOID helpers (no args)
CREATE OR REPLACE FUNCTION rbac.canon_concurrency_alert(_msg TEXT) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.concurrency_stress_run() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.concurrent_batch_heavy_simulation() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.end_concurrency_session(_slot BIGINT) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.enqueue_canon_table(_schema TEXT, _table TEXT) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.enqueue_multiple_can_tables(_n INTEGER DEFAULT 50) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.ensure_config_backpressure_defaults() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.ensure_config_dynamic_limits() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.log_cb_transition(_old TEXT, _new TEXT, _details JSONB DEFAULT '{}'::JSONB) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.log_concurrency_guard_event() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.log_config_change(_key TEXT, _old TEXT, _new TEXT, _by TEXT, _reason TEXT) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.log_rbac_metric() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.notify_canon_health_dashboard() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.notify_external_alert(_payload JSONB) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.reweight_queue_priority() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.record_lock_attempt() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.run_canon_queue_worker() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.run_concurrency_benchmark(_loops INTEGER DEFAULT 3, _batch INTEGER DEFAULT 10) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.run_concurrency_guarded() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.run_concurrency_stress(_cycles INTEGER DEFAULT 5, _delay_ms INTEGER DEFAULT 100) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.self_heal_adaptive() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.self_heal_advanced() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.self_heal_incremental() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.self_heal_policy() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.set_canon_lock_timeout() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.set_concurrency_allowed() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.set_concurrency_scope() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.backlog_alerts() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.backlog_skew_alert(_threshold INT DEFAULT 50) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.canon_backlog() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.update_canon_circuit_breaker(success BOOLEAN) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;

-- TABLE-returning helpers
CREATE OR REPLACE FUNCTION rbac.dequeue_canon_batch(_limit INT) RETURNS TABLE(id BIGINT, schema_name TEXT, table_name TEXT) AS $$ SELECT NULL::BIGINT, NULL::TEXT, NULL::TEXT; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.dequeue_canon_batch_priority(_limit INT) RETURNS TABLE(id BIGINT, schema_name TEXT, table_name TEXT) AS $$ SELECT NULL::BIGINT, NULL::TEXT, NULL::TEXT; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.dequeue_next_can_table() RETURNS TABLE(schema_name TEXT, table_name TEXT) AS $$ SELECT NULL::TEXT, NULL::TEXT; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.next_canon_table_round_robin() RETURNS TABLE(schema_name TEXT, table_name TEXT) AS $$ SELECT NULL::TEXT, NULL::TEXT; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.next_canon_table_weighted_round_robin() RETURNS TABLE(schema_name TEXT, table_name TEXT) AS $$ SELECT NULL::TEXT, NULL::TEXT; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.notification_get_digest() RETURNS TABLE(id TEXT, subject TEXT, body TEXT, status_text TEXT, created_at TIMESTAMPTZ) AS $$ SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TIMESTAMPTZ; $$ LANGUAGE sql;

-- CANON helpers
CREATE OR REPLACE FUNCTION rbac.canonicalize_all_batch(batch_size INTEGER DEFAULT 1000) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.canonicalize_table(p_schema TEXT, p_table TEXT) RETURNS INTEGER AS $$ SELECT 0; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.canonicalize_all_safe() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.canonicalize_all_rate_limited() RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.canonicalize_all_with_priority(_limit INTEGER DEFAULT 10) RETURNS INTEGER AS $$ SELECT 0; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.canonicalize_table_with_savepoint() RETURNS INTEGER AS $$ SELECT 0; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.set_config_int(_key TEXT, _value INTEGER) RETURNS VOID AS $$ SELECT NULL; $$ LANGUAGE sql;

-- Notification helpers (V1003 external notifications module)
CREATE OR REPLACE FUNCTION rbac.notification_create() RETURNS TABLE(id TEXT, subject TEXT, body TEXT, status_text TEXT) AS $$ SELECT NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT; $$ LANGUAGE sql;
CREATE OR REPLACE FUNCTION rbac.notify_event() RETURNS SETOF BIGINT AS $$ SELECT NULL::BIGINT; $$ LANGUAGE sql;
