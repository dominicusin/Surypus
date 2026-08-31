-- ============================================================================
-- Change Data Capture (CDC)
-- ============================================================================

-- CDC Log table
CREATE TABLE IF NOT EXISTS cdc_log (
    id BIGSERIAL PRIMARY KEY,
    lsn pg_lsn,
    txid BIGINT,
    captured_at TIMESTAMPTZ NOT NULL,
    operation TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    table_name TEXT NOT NULL,
    primary_key JSONB
);

-- Create trigger for CDC
CREATE OR REPLACE FUNCTION cdc_capture() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO cdc_log (txid, captured_at, operation, old_data, new_data, table_name, primary_key)
    VALUES (
        txid_current(),
        NOW(),
        TG_OP,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) END,
        TG_TABLE_NAME,
        CASE 
            WHEN TG_TABLE_NAME = 'event_store' THEN jsonb_build_object('event_id', NEW.event_id)
            WHEN TG_TABLE_NAME = 'aggregates' THEN jsonb_build_object('aggregate_id', NEW.aggregate_id)
            ELSE jsonb_build_object('id', NEW.id)
        END
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- CDC consumer offset
CREATE TABLE IF NOT EXISTS cdc_consumer_offset (
    consumer_group TEXT PRIMARY KEY,
    last_lsn pg_lsn,
    processed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Get CDC changes since LSN
CREATE OR REPLACE FUNCTION cdc_get_changes(
    p_consumer_group TEXT,
    p_limit INT DEFAULT 1000
) RETURNS TABLE(
    id BIGINT,
    operation TEXT,
    table_name TEXT,
    old_data JSONB,
    new_data JSONB,
    captured_at TIMESTAMPTZ
) AS $$
DECLARE
    v_last_lsn pg_lsn;
BEGIN
    SELECT last_lsn INTO v_last_lsn FROM cdc_consumer_offset WHERE consumer_group = p_consumer_group;
    
    RETURN QUERY
    SELECT cdc.id, cdc.operation, cdc.table_name, cdc.old_data, cdc.new_data, cdc.captured_at
    FROM cdc_log cdc
    WHERE v_last_lsn IS NULL OR cdc.lsn > v_last_lsn
    ORDER BY cdc.lsn
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;