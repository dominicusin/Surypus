-- =============================================================================
-- ЭЛЕКТРОННЫЕ ВЕСЫ
-- Соответствуют Core.Device.Scale
-- Аналог: PPOBJ_SCALE
-- =============================================================================

CREATE TABLE IF NOT EXISTS scale (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    serial_num VARCHAR(64),
    model_id INT DEFAULT 0,
    location_id INT DEFAULT 0,
    ip_address VARCHAR(45),
    port INT DEFAULT 0 CHECK (port >= 0 AND port <= 65535),
    status INT DEFAULT 0,  -- 0:Unknown, 1:Online, 2:Offline, 3:Error
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_scale_location ON scale(location_id);
CREATE INDEX idx_scale_status ON scale(status);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_scale_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_scale_update
    BEFORE UPDATE ON scale
    FOR EACH ROW
    EXECUTE FUNCTION update_scale_timestamp();
