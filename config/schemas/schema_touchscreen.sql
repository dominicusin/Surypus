-- =============================================================================
-- TOUCHSCREEN
-- Соответствуют Core.Device.TouchScreen
-- Аналог: PPOBJ_TOUCHSCREEN
-- =============================================================================

CREATE TABLE IF NOT EXISTS touchscreen (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    serial_num VARCHAR(64),
    location_id INT DEFAULT 0,
    resolution_x INT NOT NULL DEFAULT 1920,
    resolution_y INT NOT NULL DEFAULT 1080,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_touchscreen_location ON touchscreen(location_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_touchscreen_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_touchscreen_update
    BEFORE UPDATE ON touchscreen
    FOR EACH ROW
    EXECUTE FUNCTION update_touchscreen_timestamp();
