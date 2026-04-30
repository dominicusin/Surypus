-- =============================================================================
-- ТОВАРНЫЕ ПАКЕТЫ
-- Соответствуют Core.Logistics.Package
-- Аналог: PPOBJ_PACKAGE
-- =============================================================================

CREATE TABLE IF NOT EXISTS package (
    id SERIAL PRIMARY KEY,
    code VARCHAR(64) NOT NULL,
    type_id INT NOT NULL,
    location_id INT NOT NULL,
    goods_id INT NOT NULL,
    qty NUMERIC(18,6) NOT NULL DEFAULT 1 CHECK (qty > 0),
    weight NUMERIC(18,4) DEFAULT 0,
    volume NUMERIC(18,6) DEFAULT 0,
    status INT DEFAULT 0,  -- 0:Packing, 1:Packed, 2:Shipped, 3:Delivered, 4:Returned
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_package_code ON package(code);
CREATE INDEX idx_package_location ON package(location_id);
CREATE INDEX idx_package_goods ON package(goods_id);
CREATE INDEX idx_package_status ON package(status);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_package_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_package_update
    BEFORE UPDATE ON package
    FOR EACH ROW
    EXECUTE FUNCTION update_package_timestamp();

-- VIEW: Активные пакеты
CREATE OR REPLACE VIEW v_active_packages AS
SELECT 
    p.id,
    p.code,
    p.type_id,
    pt.name AS type_name,
    p.location_id,
    l.name AS location_name,
    p.goods_id,
    g.name AS goods_name,
    p.qty,
    p.status,
    CASE p.status
        WHEN 0 THEN 'Packing'
        WHEN 1 THEN 'Packed'
        WHEN 2 THEN 'Shipped'
        WHEN 3 THEN 'Delivered'
        WHEN 4 THEN 'Returned'
    END AS status_text
FROM package p
JOIN package_type pt ON pt.id = p.type_id
JOIN location l ON l.id = p.location_id
JOIN goods g ON g.id = p.goods_id
WHERE p.status IN (0, 1, 2)
ORDER BY p.code;
