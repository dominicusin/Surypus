-- =============================================================================
-- ПОСТРОЕНИЕ ТАБЛИЦЫ ПРОДАЖ
-- Соответствуют Core.Analytics.TSalesBuild
-- Аналог: PPOBJ_TSALESBUILD
-- =============================================================================

CREATE TABLE IF NOT EXISTS tsales_build (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    location_id INT DEFAULT 0,
    date_from DATE NOT NULL,
    date_to DATE NOT NULL,
    flags INT DEFAULT 0,
    config JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_tsales_build_dates CHECK (date_from <= date_to)
);

CREATE INDEX idx_tsales_build_location ON tsales_build(location_id);
CREATE INDEX idx_tsales_build_dates ON tsales_build(date_from, date_to);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_tsales_build_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_tsales_build_update
    BEFORE UPDATE ON tsales_build
    FOR EACH ROW
    EXECUTE FUNCTION update_tsales_build_timestamp();
