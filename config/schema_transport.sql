-- =============================================================================
-- ТРАНСПОРТНЫЕ СРЕДСТВА
-- Соответствуют Core.Logistics.Transport
-- Аналог: PPOBJ_TRANSPORT
-- =============================================================================

CREATE TABLE IF NOT EXISTS transport (
    id SERIAL PRIMARY KEY,
    reg_num VARCHAR(32) NOT NULL,
    model_id INT DEFAULT 0,
    owner_id INT DEFAULT 0,
    driver_id INT DEFAULT 0,
    capacity NUMERIC(18,4) DEFAULT 0 CHECK (capacity >= 0),
    fuel_type INT DEFAULT 0,  -- 0:Gasoline, 1:Diesel, 2:Gas, 3:Electric, 4:Hybrid
    status INT DEFAULT 0,  -- 0:Available, 1:InTransit, 2:Maintenance, 3:OutOfService
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_transport_reg_num ON transport(reg_num);
CREATE INDEX idx_transport_model ON transport(model_id);
CREATE INDEX idx_transport_status ON transport(status);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_transport_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_transport_update
    BEFORE UPDATE ON transport
    FOR EACH ROW
    EXECUTE FUNCTION update_transport_timestamp();

-- VIEW: Доступный транспорт
CREATE OR REPLACE VIEW v_available_transport AS
SELECT 
    t.id,
    t.reg_num,
    t.model_id,
    tm.name AS model_name,
    t.owner_id,
    p.name AS owner_name,
    t.driver_id,
    d.name AS driver_name,
    t.capacity,
    t.fuel_type,
    t.status,
    CASE t.status
        WHEN 0 THEN 'Available'
        WHEN 1 THEN 'In Transit'
        WHEN 2 THEN 'Maintenance'
        WHEN 3 THEN 'Out of Service'
    END AS status_text
FROM transport t
LEFT JOIN transport_model tm ON tm.id = t.model_id
LEFT JOIN person p ON p.id = t.owner_id
LEFT JOIN person d ON d.id = t.driver_id
WHERE t.status = 0
ORDER BY t.reg_num;