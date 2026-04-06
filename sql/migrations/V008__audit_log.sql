-- V008__audit_log.sql
-- Audit trail for mutations and access-control events

CREATE TABLE IF NOT EXISTS audit_log (
    id BIGSERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_id BIGINT,
    username TEXT NOT NULL DEFAULT '',
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id BIGINT,
    before_state JSONB,
    after_state JSONB,
    changes TEXT,
    ip_address TEXT,
    description TEXT NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON audit_log(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action);

CREATE OR REPLACE FUNCTION cleanup_old_audit_log(keep_latest INTEGER)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    IF keep_latest IS NULL OR keep_latest <= 0 THEN
        DELETE FROM audit_log;
    ELSE
        DELETE FROM audit_log
        WHERE id IN (
            SELECT id
            FROM audit_log
            ORDER BY timestamp DESC, id DESC
            OFFSET keep_latest
        );
    END IF;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;
