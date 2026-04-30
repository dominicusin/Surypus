-- ============================================================================
-- GraphQL Support Layer
-- ============================================================================

-- GraphQL schema registry
CREATE TABLE IF NOT EXISTS graphql_schemas (
    id SERIAL PRIMARY KEY,
    type_name TEXT UNIQUE NOT NULL,
    table_name TEXT NOT NULL,
    columns JSONB NOT NULL,  -- {field_name: {type: "String", column: "column_name"}}
    relationships JSONB DEFAULT '[]',  -- [{type: "hasMany", target: "TableName", field: "field"}]
    is_queryable BOOLEAN DEFAULT TRUE,
    is_mutable BOOLEAN DEFAULT TRUE
);

-- Register GraphQL types
INSERT INTO graphql_schemas (type_name, table_name, columns, relationships)
VALUES 
    ('EventStore', 'event_store', 
     '{"id": {"type": "ID", "column": "event_id"}, "type": {"type": "String", "column": "event_type"}, "data": {"type": "JSON", "column": "event_data"}}'::JSONB,
     '[]'::JSONB),
    ('Aggregate', 'aggregates',
     '{"id": {"type": "ID", "column": "aggregate_id"}, "type": {"type": "String", "column": "aggregate_type"}, "version": {"type": "Int", "column": "current_version"}}'::JSONB,
     '[{"type": "hasMany", "target": "EventStore", "field": "events"}]'::JSONB)
ON CONFLICT (type_name) DO NOTHING;

-- GraphQL resolver
CREATE OR REPLACE FUNCTION graphql_resolve(
    p_operation_type TEXT,
    p_type_name TEXT,
    p_args JSONB DEFAULT '{}',
    p_selection JSONB DEFAULT '[]'
) RETURNS JSONB AS $$
DECLARE
    v_schema RECORD;
    v_sql TEXT;
    v_result JSONB;
BEGIN
    SELECT * INTO v_schema FROM graphql_schemas WHERE type_name = p_type_name;
    
    IF v_schema IS NULL THEN
        RETURN '{"error": "Type not found"}'::JSONB;
    END IF;
    
    IF p_operation_type = 'query' AND v_schema.is_queryable THEN
        -- Build SELECT query from args and selection
        v_sql := 'SELECT row_to_json(t) FROM ' || v_schema.table_name || ' t WHERE 1=1';
        
        -- Add filters from args
        IF p_args ? 'id' THEN
            v_sql := v_sql || ' AND id = ' || quote_literal(p_args->>'id');
        END IF;
        
        EXECUTE v_sql INTO v_result;
    END IF;
    
    RETURN COALESCE(v_result, '{}'::JSONB);
END;
$$ LANGUAGE plpgsql;