-- =============================================================================
-- СЕРИЙНЫЕ НОМЕРА
-- Соответствуют Core.Goods.Serial
-- Аналог: PPOBJ_SERIAL
-- =============================================================================

CREATE TABLE IF NOT EXISTS serial (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    number VARCHAR(128) NOT NULL,
    lot_id INT DEFAULT 0,
    location_id INT DEFAULT 0,
    status INT DEFAULT 0,  -- 0:Available, 1:InTransit, 2:Sold, 3:Returned, 4:Reserved
    expiry TIMESTAMP,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_serial_goods ON serial(goods_id);
CREATE INDEX idx_serial_number ON serial(number);
CREATE INDEX idx_serial_lot ON serial(lot_id);
CREATE UNIQUE INDEX idx_serial_unique ON serial(goods_id, number);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_serial_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_serial_update
    BEFORE UPDATE ON serial
    FOR EACH ROW
    EXECUTE FUNCTION update_serial_timestamp();

-- FUNCTION: Проверить доступность серийника
CREATE OR REPLACE FUNCTION check_serial_available(p_goods_id INT, p_number TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_status INT;
BEGIN
    SELECT status INTO v_status
    FROM serial
    WHERE goods_id = p_goods_id AND number = p_number;
    
    RETURN v_status = 0;  -- Available
END;
$$ LANGUAGE plpgsql;
