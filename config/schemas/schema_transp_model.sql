-- =============================================================================
-- МОДЕЛИ ТРАНСПОРТНЫХ СРЕДСТВ
-- Соответствуют Core.Transport.TranspModel
-- Аналог: PPOBJ_TRANSPMODEL
-- =============================================================================

CREATE TABLE IF NOT EXISTS transp_model (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    brand VARCHAR(128),
    flags INT DEFAULT 0,
    capacity NUMERIC(18,4) DEFAULT 0,
    volume NUMERIC(18,4) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_transp_model_brand ON transp_model(brand);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_transp_model_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_transp_model_update
    BEFORE UPDATE ON transp_model
    FOR EACH ROW
    EXECUTE FUNCTION update_transp_model_timestamp();
