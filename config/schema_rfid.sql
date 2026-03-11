-- =============================================================================
-- RFID УСТРОЙСТВА
-- Соответствуют Core.Device.RFIDDevice
-- Аналог: PPOBJ_RFIDDEVICE
-- =============================================================================

CREATE TABLE IF NOT EXISTS rfid_device (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    serial_num VARCHAR(64),
    type INT NOT NULL,  -- 0:Reader, 1:Antenna, 2:Printer, 3:Gate
    location_id INT DEFAULT 0,
    ip_address VARCHAR(45),
    port INT DEFAULT 0 CHECK (port >= 0 AND port <= 65535),
    status INT DEFAULT 0,  -- 0:Unknown, 1:Online, 2:Offline, 3:Error
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_rfid_device_location ON rfid_device(location_id);
CREATE INDEX idx_rfid_device_status ON rfid_device(status);

-- TABLE: RFID метки
CREATE TABLE IF NOT EXISTS rfid_tag (
    id SERIAL PRIMARY KEY,
    epc VARCHAR(96) NOT NULL,
    tid VARCHAR(96),
    goods_id INT DEFAULT 0,
    location_id INT DEFAULT 0,
    read_time TIMESTAMP NOT NULL DEFAULT NOW(),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_rfid_tag_epc ON rfid_tag(epc);
CREATE INDEX idx_rfid_tag_goods ON rfid_tag(goods_id);
CREATE INDEX idx_rfid_tag_location ON rfid_tag(location_id);
CREATE INDEX idx_rfid_tag_read_time ON rfid_tag(read_time);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_rfid_device_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_rfid_device_update
    BEFORE UPDATE ON rfid_device
    FOR EACH ROW
    EXECUTE FUNCTION update_rfid_device_timestamp();