-- Partition maintenance: list partitions
CREATE OR REPLACE FUNCTION list_partitions(p_parent_table TEXT)
RETURNS TABLE(partition_name TEXT, partition_bounds TEXT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.relname::TEXT as partition_name,
        pg_get_expr(c.relcheck, c.oid)::TEXT as partition_bounds
    FROM pg_inherits h
    JOIN pg_class c ON h.inhrelid = c.oid
    JOIN pg_class p ON h.inhparent = p.oid
    WHERE p.relname = p_parent_table;
END;
$$ LANGUAGE plpgsql;

-- Drop old partition
CREATE OR REPLACE FUNCTION drop_partition(
    p_partition_name TEXT
) RETURNS BOOLEAN AS $$
BEGIN
    EXECUTE format('DROP TABLE IF EXISTS %I', p_partition_name);
    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Failed to drop partition: %', SQLERRM;
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Create future partition
CREATE OR REPLACE FUNCTION create_future_partition(
    p_parent_table TEXT,
    p_partition_value TEXT,
    p_partition_type TEXT DEFAULT 'LIST'
) RETURNS VOID AS $$
DECLARE
    v_partition_name TEXT;
BEGIN
    v_partition_name := p_parent_table || '_' || replace(p_partition_value, '-', '_');
    
    IF p_partition_type = 'LIST' THEN
        EXECUTE format('CREATE TABLE %I PARTITION OF %I FOR VALUES IN (%L)',
            v_partition_name, p_parent_table, p_partition_value);
    END IF;
    
    RAISE NOTICE 'Created partition: %', v_partition_name;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Partition creation skipped: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;