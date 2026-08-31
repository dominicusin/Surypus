-- Migration V106: Consolidated event store tenant index and partition enforcement
-- Original files: V106__idx_event_store_tenant_seq.sql, V106__partition_enforcement.sql

-- Event store tenant sequence index
CREATE INDEX IF NOT EXISTS idx_event_store_tenant_seq ON event_store (
    tenant_id,
    sequence_number
);

-- Partition enforcement: Create trigger function for audit log
CREATE OR REPLACE FUNCTION audit_log_partition_check()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tenant_id IS NULL THEN
        RAISE EXCEPTION 'tenant_id cannot be null for audit_log';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS audit_log_partition_trigger ON audit_log;
CREATE TRIGGER audit_log_partition_trigger
    BEFORE INSERT ON audit_log
    FOR EACH ROW EXECUTE FUNCTION audit_log_partition_check();
