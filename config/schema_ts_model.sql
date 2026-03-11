-- =============================================================================
-- МОДЕЛИ РАСЧЁТА СТРАТЕГИЙ
-- Соответствуют Core.Analytics.TSSModel
-- Аналог: PPOBJ_TSSMODEL
-- =============================================================================

CREATE TABLE IF NOT EXISTS ts_model (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    ts_table_id INT NOT NULL,
    config JSONB,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_ts_model_table ON ts_model(ts_table_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_ts_model_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_ts_model_update
    BEFORE UPDATE ON ts_model
    FOR EACH ROW
    EXECUTE FUNCTION update_ts_model_timestamp();
