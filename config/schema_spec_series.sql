-- =============================================================================
-- СПЕЦИАЛЬНЫЕ СЕРИИ
-- Соответствуют Core.Common.SpecSeries
-- Аналог: PPOBJ_SPECSERIES
-- =============================================================================

CREATE TABLE IF NOT EXISTS spec_series (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    obj_type INT NOT NULL,  -- PPOBJ_*
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_spec_series_obj_type ON spec_series(obj_type);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_spec_series_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_spec_series_update
    BEFORE UPDATE ON spec_series
    FOR EACH ROW
    EXECUTE FUNCTION update_spec_series_timestamp();
