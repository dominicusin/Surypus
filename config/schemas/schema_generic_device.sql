-- =============================================================================
-- ОБОБЩЁННЫЕ УСТРОЙСТВА
-- Соответствуют Core.Device.GenericDevice
-- Аналог: PPOBJ_GENERICDEVICE
-- =============================================================================

CREATE TABLE IF NOT EXISTS generic_device (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    device_type VARCHAR(64),
    location_id INT DEFAULT 0,
    ip_address VARCHAR(45),
    mac_address VARCHAR(17),
    config JSONB,
    status INT DEFAULT 0,  -- 0:Unknown, 1:Online, 2:Offline, 3:Error
    last_ping TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_generic_device_location ON generic_device(location_id);
CREATE INDEX idx_generic_device_type ON generic_device(device_type);
CREATE INDEX idx_generic_device_status ON generic_device(status);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_generic_device_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generic_device_update
    BEFORE UPDATE ON generic_device
    FOR EACH ROW
    EXECUTE FUNCTION update_generic_device_timestamp();

-- VIEW: Статус устройств
CREATE OR REPLACE VIEW v_generic_device_status AS
SELECT 
    gd.id,
    gd.name,
    gd.device_type,
    gd.location_id,
    l.name AS location_name,
    gd.ip_address,
    gd.status,
    gd.last_ping,
    CASE gd.status
        WHEN 0 THEN 'Unknown'
        WHEN 1 THEN 'Online'
        WHEN 2 THEN 'Offline'
        WHEN 3 THEN 'Error'
    END AS status_text,
    AGE(NOW(), gd.last_ping) AS time_since_ping
FROM generic_device gd
LEFT JOIN location l ON l.id = gd.location_id;
