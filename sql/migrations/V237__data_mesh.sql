-- ============================================================================
-- Advanced Federation & Data Mesh
-- ============================================================================

-- Data mesh domain
CREATE TABLE IF NOT EXISTS data_mesh_domains (
    id SERIAL PRIMARY KEY,
    domain_name TEXT UNIQUE NOT NULL,
    domain_owner UUID REFERENCES users(id),
    data_products JSONB DEFAULT '[]',
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Data product
CREATE TABLE IF NOT EXISTS data_products (
    id BIGSERIAL PRIMARY KEY,
    domain_id INT REFERENCES data_mesh_domains(id),
    product_name TEXT NOT NULL,
    product_type TEXT CHECK (product_type IN ('table', 'view', 'api', 'stream')),
    schema_definition JSONB,
    access_policy JSONB,
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Data product usage
CREATE TABLE IF NOT EXISTS data_product_usage (
    id BIGSERIAL PRIMARY KEY,
    product_id INT REFERENCES data_products(id),
    consumer_id UUID,
    usage_type TEXT,
    accessed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Register domain
CREATE OR REPLACE FUNCTION register_domain(
    p_domain_name TEXT,
    p_owner_id UUID
) RETURNS INT AS $$
DECLARE
    v_domain_id INT;
BEGIN
    INSERT INTO data_mesh_domains (domain_name, domain_owner)
    VALUES (p_domain_name, p_owner_id)
    RETURNING id INTO v_domain_id;
    RETURN v_domain_id;
END;
$$ LANGUAGE plpgsql;

-- Publish data product
CREATE OR REPLACE FUNCTION publish_data_product(
    p_domain_id INT,
    p_product_name TEXT,
    p_product_type TEXT,
    p_schema JSONB
) RETURNS INT AS $$
DECLARE
    v_product_id INT;
BEGIN
    INSERT INTO data_products (domain_id, product_name, product_type, schema_definition, is_published)
    VALUES (p_domain_id, p_product_name, p_product_type, p_schema, TRUE)
    RETURNING id INTO v_product_id;
    RETURN v_product_id;
END;
$$ LANGUAGE plpgsql;