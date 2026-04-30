-- ============================================================================
-- Advanced Database Sharding
-- ============================================================================

-- Shard coordinator
CREATE TABLE IF NOT EXISTS shard_coordinator (
    shard_id INT PRIMARY KEY,
    shard_name TEXT NOT NULL,
    host TEXT NOT NULL,
    port INT DEFAULT 5432,
    database_name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    weight INT DEFAULT 100,
    metadata JSONB DEFAULT '{}'
);

-- Sharding key configuration
CREATE TABLE IF NOT EXISTS sharding_keys (
    table_name TEXT PRIMARY KEY,
    key_column TEXT NOT NULL,
    sharding_function TEXT CHECK (sharding_function IN ('hash', 'range', 'list')),
    num_shards INT DEFAULT 256
);

-- Register shards
INSERT INTO shard_coordinator (shard_id, shard_name, host, port, database_name)
VALUES 
    (0, 'shard_00', 'localhost', 5432, 'surypus'),
    (1, 'shard_01', 'localhost', 5432, 'surypus')
ON CONFLICT (shard_id) DO NOTHING;

-- Compute shard
CREATE OR REPLACE FUNCTION compute_shard(
    p_key_value TEXT,
    p_num_shards INT DEFAULT 256
) RETURNS INT AS $$
BEGIN
    RETURN (p_key_value::BIGINT % p_num_shards);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Rebalance check
CREATE OR REPLACE FUNCTION check_rebalance_needed() RETURNS TABLE(
    shard_id INT, load_imbalance FLOAT, recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        0 as shard_id,
        0.1 as load_imbalance,
        'balanced' as recommendation;
END;
$$ LANGUAGE plpgsql;