-- Improve read performance for projection audit logs
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_projection_audit_event ON projection_audit(event_type, projection_name);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_projection_audit_created ON projection_audit(created_at);
