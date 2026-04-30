-- =============================================================================
-- КОМПЬЮТЕРЫ И ПРОГРАММЫ (WSCTL)
-- Соответствуют Core.Device.Computer
-- Аналог: PPOBJ_COMPUTER, PPOBJ_SWPROGRAM, PPOBJ_COMPUTERCATEGORY
-- =============================================================================

-- =============================================================================
-- Computer Category (Категория компьютера)
-- =============================================================================
CREATE TABLE IF NOT EXISTS computer_category (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- Computer (Компьютер)
-- =============================================================================
CREATE TABLE IF NOT EXISTS computer (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    category_id INT REFERENCES computer_category(id),
    ip_address VARCHAR(45),
    mac_address VARCHAR(17),
    host_name VARCHAR(256),
    location_id INT DEFAULT 0,
    flags INT DEFAULT 0,
    last_ping TIMESTAMP,
    status INT DEFAULT 0,  -- 0:Unknown, 1:Online, 2:Offline, 3:Busy, 4:Error
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_computer_location ON computer(location_id);
CREATE INDEX idx_computer_ip ON computer(ip_address);
CREATE INDEX idx_computer_mac ON computer(mac_address);
CREATE INDEX idx_computer_status ON computer(status);

-- =============================================================================
-- Software Program Category (Категория программы)
-- =============================================================================
CREATE TABLE IF NOT EXISTS software_program_category (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- Software Program (Программа)
-- =============================================================================
CREATE TABLE IF NOT EXISTS software_program (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    version VARCHAR(64),
    category_id INT REFERENCES software_program_category(id),
    path VARCHAR(512),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sw_program_category ON software_program(category_id);

-- =============================================================================
-- Computer Software (Программы на компьютере)
-- =============================================================================
CREATE TABLE IF NOT EXISTS computer_software (
    id SERIAL PRIMARY KEY,
    computer_id INT NOT NULL REFERENCES computer(id) ON DELETE CASCADE,
    program_id INT NOT NULL REFERENCES software_program(id),
    install_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used TIMESTAMP,
    flags INT DEFAULT 0,
    UNIQUE(computer_id, program_id)
);

CREATE INDEX idx_computer_software_computer ON computer_software(computer_id);
CREATE INDEX idx_computer_software_program ON computer_software(program_id);

-- =============================================================================
-- Computer Event (Событие)
-- =============================================================================
CREATE TABLE IF NOT EXISTS computer_event (
    id SERIAL PRIMARY KEY,
    computer_id INT NOT NULL REFERENCES computer(id) ON DELETE CASCADE,
    event_type INT NOT NULL,  -- 1:Login, 2:Logout, 3:Error, 4:StatusChange
    event_data TEXT,
    event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    flags INT DEFAULT 0
);

CREATE INDEX idx_computer_event_computer ON computer_event(computer_id);
CREATE INDEX idx_computer_event_time ON computer_event(event_time);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

CREATE OR REPLACE FUNCTION update_computer_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_computer_update
    BEFORE UPDATE ON computer
    FOR EACH ROW
    EXECUTE FUNCTION update_computer_timestamp();

CREATE OR REPLACE FUNCTION update_software_program_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_software_program_update
    BEFORE UPDATE ON software_program
    FOR EACH ROW
    EXECUTE FUNCTION update_software_program_timestamp();

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Получить список программ на компьютере
CREATE OR REPLACE FUNCTION get_computer_programs(p_computer_id INT)
RETURNS TABLE (
    program_id INT,
    program_name TEXT,
    version TEXT,
    install_date TIMESTAMP,
    last_used TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sp.id,
        sp.name,
        sp.version,
        cs.install_date,
        cs.last_used
    FROM computer_software cs
    JOIN software_program sp ON sp.id = cs.program_id
    WHERE cs.computer_id = p_computer_id
    ORDER BY sp.name;
END;
$$ LANGUAGE plpgsql;

-- Обновить статус компьютера
CREATE OR REPLACE FUNCTION update_computer_status(p_computer_id INT, p_status INT)
RETURNS VOID AS $$
BEGIN
    UPDATE computer 
    SET status = p_status, 
        last_ping = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_computer_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- VIEWS
-- =============================================================================

-- Статус компьютеров
CREATE OR REPLACE VIEW v_computer_status AS
SELECT 
    c.id,
    c.name,
    c.ip_address,
    c.mac_address,
    c.host_name,
    c.location_id,
    l.name AS location_name,
    c.status,
    CASE c.status 
        WHEN 0 THEN 'Unknown'
        WHEN 1 THEN 'Online'
        WHEN 2 THEN 'Offline'
        WHEN 3 THEN 'Busy'
        WHEN 4 THEN 'Error'
    END AS status_text,
    c.last_ping,
    AGE(NOW(), c.last_ping) AS time_since_ping
FROM computer c
LEFT JOIN location l ON l.id = c.location_id;

-- Статистика использования программ
CREATE OR REPLACE VIEW v_software_usage_stats AS
SELECT 
    sp.id,
    sp.name,
    sp.version,
    COUNT(cs.id) AS install_count,
    COUNT(cs.last_used) AS use_count,
    MAX(cs.last_used) AS last_used
FROM software_program sp
LEFT JOIN computer_software cs ON cs.program_id = sp.id
GROUP BY sp.id, sp.name, sp.version;
