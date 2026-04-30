-- =============================================================================
-- ГЕО-ТРЕКИНГ
-- Соответствуют Core.Location.Geotracking
-- Аналог: PPOBJ_GEOTRACKING
-- =============================================================================

CREATE TABLE IF NOT EXISTS geotrack (
    id SERIAL PRIMARY KEY,
    obj_type INT NOT NULL,
    obj_id INT NOT NULL,
    lat DOUBLE PRECISION NOT NULL CHECK (lat >= -90 AND lat <= 90),
    lon DOUBLE PRECISION NOT NULL CHECK (lon >= -180 AND lon <= 180),
    timestamp TIMESTAMP NOT NULL,
    accuracy DOUBLE PRECISION DEFAULT 0,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_geotrack_object ON geotrack(obj_type, obj_id);
CREATE INDEX idx_geotrack_timestamp ON geotrack(timestamp);

-- FUNCTION: Получить последнюю позицию
CREATE OR REPLACE FUNCTION get_last_position(p_obj_type INT, p_obj_id INT)
RETURNS TABLE (lat DOUBLE PRECISION, lon DOUBLE PRECISION, timestamp TIMESTAMP) AS $$
BEGIN
    RETURN QUERY
    SELECT gt.lat, gt.lon, gt.timestamp
    FROM geotrack gt
    WHERE gt.obj_type = p_obj_type AND gt.obj_id = p_obj_id
    ORDER BY gt.timestamp DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;
