-- ============================================================================
-- Advanced Graph Database Features
-- ============================================================================

-- Graph nodes
CREATE TABLE IF NOT EXISTS graph_nodes (
    node_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(tenant_id),
    node_type TEXT NOT NULL,
    properties JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Graph edges
CREATE TABLE IF NOT EXISTS graph_edges (
    edge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_node_id UUID REFERENCES graph_nodes(node_id),
    to_node_id UUID REFERENCES graph_nodes(node_id),
    edge_type TEXT NOT NULL,
    weight FLOAT DEFAULT 1.0,
    properties JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(from_node_id, to_node_id, edge_type)
);

-- Create relationship
CREATE OR REPLACE FUNCTION create_relationship(
    p_from_id UUID,
    p_to_id UUID,
    p_edge_type TEXT,
    p_properties JSONB DEFAULT '{}'
) RETURNS UUID AS $$
DECLARE
    v_edge_id UUID;
BEGIN
    INSERT INTO graph_edges (from_node_id, to_node_id, edge_type, properties)
    VALUES (p_from_id, p_to_id, p_edge_type, p_properties)
    RETURNING edge_id INTO v_edge_id;
    RETURN v_edge_id;
END;
$$ LANGUAGE plpgsql;

-- Find connected nodes (BFS)
CREATE OR REPLACE FUNCTION find_connected_nodes(
    p_start_node_id UUID,
    p_max_depth INT DEFAULT 3
) RETURNS TABLE(depth INT, node_id UUID, node_type TEXT) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE graph AS (
        SELECT 0 as depth, gn.node_id, gn.node_type
        FROM graph_nodes gn WHERE gn.node_id = p_start_node_id
        UNION ALL
        SELECT g.depth + 1, gn.node_id, gn.node_type
        FROM graph g
        JOIN graph_edges ge ON ge.from_node_id = g.node_id
        JOIN graph_nodes gn ON gn.node_id = ge.to_node_id
        WHERE g.depth < p_max_depth
    )
    SELECT DISTINCT depth, node_id, node_type FROM graph;
END;
$$ LANGUAGE plpgsql;