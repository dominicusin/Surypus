-- ============================================================================
-- Advanced Data Virtualization
-- ============================================================================

-- Virtual data sources
CREATE TABLE IF NOT EXISTS virtual_data_sources (
    id SERIAL PRIMARY KEY,
    source_name TEXT UNIQUE NOT NULL,
    source_type TEXT CHECK (source_type IN ('postgres', 'mysql', 'oracle', 'mongo', 'rest_api', 'graphql')),
    connection_config JSONB NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Virtual tables
CREATE TABLE IF NOT EXISTS virtual_tables (
    id SERIAL PRIMARY KEY,
    source_id INT REFERENCES virtual_data_sources(id),
    table_name TEXT NOT NULL,
    remote_schema JSONB,
    sync_strategy TEXT CHECK (sync_strategy IN ('realtime', 'scheduled', 'on_demand')),
    last_synced_at TIMESTAMPTZ
);

-- Virtual join definitions
CREATE TABLE IF NOT EXISTS virtual_joins (
    id SERIAL PRIMARY KEY,
    join_name TEXT NOT NULL,
    left_table TEXT NOT NULL,
    right_table TEXT NOT NULL,
    join_type TEXT CHECK (join_type IN ('inner', 'left', 'right', 'full')),
    join_condition JSONB NOT NULL
);

-- Register virtual source
CREATE OR REPLACE FUNCTION register_virtual_source(
    p_source_name TEXT,
    p_source_type TEXT,
    p_config JSONB
) RETURNS INT AS $$
DECLARE
    v_source_id INT;
BEGIN
    INSERT INTO virtual_data_sources (source_name, source_type, connection_config)
    VALUES (p_source_name, p_source_type, p_config)
    RETURNING id INTO v_source_id;
    RETURN v_source_id;
END;
$$ LANGUAGE plpgsql;