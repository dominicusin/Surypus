-- =============================================================================
-- ЛОТЫ
-- Соответствуют Core.Warehouse.Lot
-- Аналог: PPOBJ_LOT
-- =============================================================================

CREATE TABLE IF NOT EXISTS lot (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    location_id INT NOT NULL,
    bill_id INT NOT NULL,
    qty NUMERIC(18,6) NOT NULL DEFAULT 0 CHECK (qty >= 0),
    rest NUMERIC(18,6) NOT NULL DEFAULT 0 CHECK (rest >= 0),
    price NUMERIC(18,4) DEFAULT 0,
    expiry TIMESTAMP,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_lot_rest CHECK (rest <= qty)
);

CREATE INDEX idx_lot_goods ON lot(goods_id);
CREATE INDEX idx_lot_location ON lot(location_id);
CREATE INDEX idx_lot_bill ON lot(bill_id);
CREATE INDEX idx_lot_expiry ON lot(expiry) WHERE expiry IS NOT NULL;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_lot_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_lot_update
    BEFORE UPDATE ON lot
    FOR EACH ROW
    EXECUTE FUNCTION update_lot_timestamp();

-- FUNCTION: Списать с лота
CREATE OR REPLACE FUNCTION write_off_lot(p_lot_id INT, p_qty NUMERIC(18,6))
RETURNS BOOLEAN AS $$
DECLARE
    v_rest NUMERIC(18,6);
BEGIN
    SELECT rest INTO v_rest FROM lot WHERE id = p_lot_id;
    
    IF v_rest < p_qty THEN
        RETURN FALSE;
    END IF;
    
    UPDATE lot SET rest = rest - p_qty, updated_at = CURRENT_TIMESTAMP WHERE id = p_lot_id;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- VIEW: Действующие лоты
CREATE OR REPLACE VIEW v_active_lots AS
SELECT 
    l.id,
    l.goods_id,
    g.name AS goods_name,
    g.code AS goods_code,
    l.location_id,
    loc.name AS location_name,
    l.bill_id,
    l.qty,
    l.rest,
    l.price,
    l.expiry,
    l.flags
FROM lot l
JOIN goods g ON g.id = l.goods_id
JOIN location loc ON loc.id = l.location_id
WHERE l.rest > 0
ORDER BY l.expiry, l.id;
