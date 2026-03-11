-- =============================================================================
-- БРЕНДЫ
-- Соответствуют Core.Goods.Brand
-- Аналог: PPOBJ_BRAND
-- =============================================================================

CREATE TABLE IF NOT EXISTS brand (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    owner_id INT DEFAULT 0,
    logo BYTEA,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_brand_code ON brand(code) WHERE code IS NOT NULL;
CREATE INDEX idx_brand_name ON brand(name);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_brand_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_brand_update
    BEFORE UPDATE ON brand
    FOR EACH ROW
    EXECUTE FUNCTION update_brand_timestamp();