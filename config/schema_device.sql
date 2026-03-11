-- =============================================================================
-- ПРИНТЕРЫ ШТРИХ-КОДОВ
-- Соответствуют Core.Device.BarcodePrinter
-- Аналог: PPOBJ_BCODEPRINTER
-- =============================================================================

CREATE TABLE IF NOT EXISTS barcode_printer (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    device_type INT DEFAULT 0,  -- 0:Unknown, 1:Citizen, 2:Zebra, 3:Godex, 4:TSC, 5:Generic
    port VARCHAR(128),
    port_ex VARCHAR(256),
    flags INT DEFAULT 0,
    location_id INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_barcode_printer_location ON barcode_printer(location_id);
CREATE UNIQUE INDEX idx_barcode_printer_symb ON barcode_printer(symb) WHERE symb IS NOT NULL;

-- Триггер
CREATE OR REPLACE FUNCTION update_barcode_printer_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_barcode_printer_update
    BEFORE UPDATE ON barcode_printer
    FOR EACH ROW
    EXECUTE FUNCTION update_barcode_printer_timestamp();

-- =============================================================================
-- ВЕСЫ (SCALE)
-- Аналог: PPOBJ_SCALE
-- =============================================================================

CREATE TABLE IF NOT EXISTS scale (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    device_type INT DEFAULT 0,
    port VARCHAR(128),
    ip_address VARCHAR(45),
    flags INT DEFAULT 0,
    location_id INT DEFAULT 0,
    goods_id INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_scale_location ON scale(location_id);

-- Триггер
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

-- =============================================================================
-- ТЕРМИНАЛЫ СБОРА ДАННЫХ (BHT)
-- Аналог: PPOBJ_BHT
-- =============================================================================

CREATE TABLE IF NOT EXISTS bht_terminal (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    device_id VARCHAR(64),
    ip_address VARCHAR(45),
    port INT DEFAULT 0 CHECK (port >= 0 AND port <= 65535),
    flags INT DEFAULT 0,
    location_id INT DEFAULT 0,
    status INT DEFAULT 0,  -- 0:Offline, 1:Online, 2:Syncing, 3:Error
    last_sync TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_bht_terminal_location ON bht_terminal(location_id);
CREATE INDEX idx_bht_terminal_device ON bht_terminal(device_id);

-- Триггер
CREATE OR REPLACE FUNCTION update_bht_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_bht_terminal_update
    BEFORE UPDATE ON bht_terminal
    FOR EACH ROW
    EXECUTE FUNCTION update_bht_timestamp();

-- =============================================================================
-- TOUCH SCREEN
-- Аналог: PPOBJ_TOUCHSCREEN
-- =============================================================================

CREATE TABLE IF NOT EXISTS touch_screen (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    device_id VARCHAR(64),
    flags INT DEFAULT 0,
    location_id INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_touch_screen_location ON touch_screen(location_id);

-- Триггер
CREATE OR REPLACE FUNCTION update_touch_screen_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_touch_screen_update
    BEFORE UPDATE ON touch_screen
    FOR EACH ROW
    EXECUTE FUNCTION update_touch_screen_timestamp();
