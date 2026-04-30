-- Maintenance: cleanup old outbox entries
CREATE OR REPLACE FUNCTION outbox_cleanup(
    p_retention_days INT DEFAULT 30
) RETURNS INT AS $$
DECLARE
    v_deleted INT;
BEGIN
    DELETE FROM event_outbox
    WHERE published = TRUE
      AND created_at < NOW() - (p_retention_days || ' days')::INTERVAL;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;

-- Maintenance: analyze tables for optimizer
CREATE OR REPLACE FUNCTION maintenance_analyze() RETURNS VOID AS $$
BEGIN
    ANALYZE event_store;
    ANALYZE aggregate_snapshots;
    ANALYZE event_outbox;
    ANALYZE projection_audit;
    RAISE NOTICE 'Maintenance analyze completed';
END;
$$ LANGUAGE plpgsql;