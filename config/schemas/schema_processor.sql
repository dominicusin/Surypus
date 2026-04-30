-- =============================================================================
-- ПРОЦЕССОРЫ
-- Соответствуют Core.Production.Processor
-- Аналог: PPOBJ_PROCESSOR
-- =============================================================================

CREATE TABLE IF NOT EXISTS processor (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    location_id INT NOT NULL,
    flags INT DEFAULT 0,
    config JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_processor_location ON processor(location_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_processor_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_processor_update
    BEFORE UPDATE ON processor
    FOR EACH ROW
    EXECUTE FUNCTION update_processor_timestamp();
