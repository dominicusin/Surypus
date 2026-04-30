-- ============================================================================
-- Bulk Operations for High Throughput
-- ============================================================================

-- Bulk insert queue
CREATE TABLE IF NOT EXISTS bulk_insert_queue (
    id BIGSERIAL PRIMARY KEY,
    batch_id UUID NOT NULL,
    table_name TEXT NOT NULL,
    data JSONB NOT NULL,
    status TEXT CHECK (status IN ('pending', 'processing', 'completed', 'failed')) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP WITH TIME ZONE
);

-- Bulk insert processor
CREATE OR REPLACE FUNCTION process_bulk_insert(
    p_batch_id UUID,
    p_batch_size INT DEFAULT 1000
) RETURNS INT AS $$
DECLARE
    v_count INT := 0;
    v_row RECORD;
    v_sql TEXT;
BEGIN
    FOR v_row IN 
        SELECT * FROM bulk_insert_queue 
        WHERE batch_id = p_batch_id AND status = 'pending'
        ORDER BY id LIMIT p_batch_size
    LOOP
        BEGIN
            v_sql := format('INSERT INTO %I VALUES (%L)', 
                v_row.table_name, 
                v_row.data::TEXT);
            EXECUTE v_sql;
            
            UPDATE bulk_insert_queue SET status = 'completed', processed_at = NOW()
            WHERE id = v_row.id;
            
            v_count := v_count + 1;
        EXCEPTION WHEN OTHERS THEN
            UPDATE bulk_insert_queue SET status = 'failed'
            WHERE id = v_row.id;
        END;
    END LOOP;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- Bulk API
CREATE OR REPLACE FUNCTION bulk_insert(
    p_table_name TEXT,
    p_rows JSONB
) RETURNS UUID AS $$
DECLARE
    v_batch_id UUID := gen_random_uuid();
    v_row JSONB;
BEGIN
    FOR v_row IN SELECT * FROM jsonb_array_elements(p_rows)
    LOOP
        INSERT INTO bulk_insert_queue (batch_id, table_name, data, status)
        VALUES (v_batch_id, p_table_name, v_row, 'pending');
    END LOOP;
    
    RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql;