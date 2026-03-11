-- =============================================================================
-- BHT ТЕРМИНАЛЫ
-- Соответствуют Core.Device.BHTTerminal
-- Аналог: PPOBJ_BHT
-- =============================================================================

CREATE TABLE IF NOT EXISTS bht_terminal (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    serial_num VARCHAR(64),
    ip_address VARCHAR(45),
    mac_address VARCHAR(17),
    location_id INT DEFAULT 0,
    status INT DEFAULT 0,  -- 0:Unknown, 1:Online, 2:Offline, 3:Error
    last_sync TIMESTAMP,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_bht_terminal_serial ON bht_terminal(serial_num);
CREATE INDEX idx_bht_terminal_location ON bht_terminal(location_id);
CREATE INDEX idx_bht_terminal_status ON bht_terminal(status);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_bht_terminal_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_bht_terminal_update
    BEFORE UPDATE ON bht_terminal
    FOR EACH ROW
    EXECUTE FUNCTION update_bht_terminal_timestamp();
