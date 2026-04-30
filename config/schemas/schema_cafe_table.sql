-- =============================================================================
-- СТОЛЫ HORECA
-- Соответствуют Core.Horeca.CafeTable
-- Аналог: PPOBJ_CAFETABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS cafe_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    location_id INT NOT NULL,
    capacity INT NOT NULL DEFAULT 2 CHECK (capacity > 0),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cafe_table_location ON cafe_table(location_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_cafe_table_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cafe_table_update
    BEFORE UPDATE ON cafe_table
    FOR EACH ROW
    EXECUTE FUNCTION update_cafe_table_timestamp();
