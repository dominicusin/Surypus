-- =============================================================================
-- ИНТЕРНЕТ-МАГАЗИН
-- Соответствуют Core.ECommerce.UhttStore
-- Аналог: PPOBJ_UHTTSTORE
-- =============================================================================

CREATE TABLE IF NOT EXISTS uhtt_store (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    url VARCHAR(512),
    location_id INT NOT NULL,
    flags INT DEFAULT 0,
    config JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_uhtt_store_location ON uhtt_store(location_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_uhtt_store_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_uhtt_store_update
    BEFORE UPDATE ON uhtt_store
    FOR EACH ROW
    EXECUTE FUNCTION update_uhtt_store_timestamp();
