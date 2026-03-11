-- =============================================================================
-- MRP-ТАБЛИЦЫ
-- Соответствуют Core.Production.MRPTab
-- Аналог: PPOBJ_MRPTAB
-- =============================================================================

CREATE TABLE IF NOT EXISTS mrp_tab (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    tech_id INT NOT NULL,
    date DATE NOT NULL,
    status INT DEFAULT 0,  -- 0:Draft, 1:Calculated, 2:Approved, 3:Closed
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_mrp_tab_tech ON mrp_tab(tech_id);
CREATE INDEX idx_mrp_tab_date ON mrp_tab(date);
CREATE INDEX idx_mrp_tab_status ON mrp_tab(status);

CREATE TABLE IF NOT EXISTS mrp_tab_line (
    id SERIAL PRIMARY KEY,
    tab_id INT NOT NULL REFERENCES mrp_tab(id) ON DELETE CASCADE,
    goods_id INT NOT NULL,
    qty_need NUMERIC(18,6) DEFAULT 0,
    qty_stock NUMERIC(18,6) DEFAULT 0,
    qty_order NUMERIC(18,6) DEFAULT 0,
    qty_plan NUMERIC(18,6) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_mrp_tab_line_tab ON mrp_tab_line(tab_id);
CREATE INDEX idx_mrp_tab_line_goods ON mrp_tab_line(goods_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_mrp_tab_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_mrp_tab_update
    BEFORE UPDATE ON mrp_tab
    FOR EACH ROW
    EXECUTE FUNCTION update_mrp_tab_timestamp();

CREATE TRIGGER trigger_mrp_tab_line_update
    BEFORE UPDATE ON mrp_tab_line
    FOR EACH ROW
    EXECUTE FUNCTION update_mrp_tab_timestamp();

-- VIEW: Потребности MRP
CREATE OR REPLACE VIEW v_mrp_needs AS
SELECT 
    mt.id,
    mt.name AS tab_name,
    mt.date,
    mt.status,
    mt.goods_id,
    g.name AS goods_name,
    g.code AS goods_code,
    mtl.qty_need,
    mtl.qty_stock,
    mtl.qty_order,
    mtl.qty_plan,
    (mtl.qty_need - mtl.qty_stock - mtl.qty_order) AS qty_to_produce
FROM mrp_tab mt
JOIN mrp_tab_line mtl ON mtl.tab_id = mt.id
JOIN goods g ON g.id = mtl.goods_id
WHERE mt.status IN (1, 2)  -- Calculated или Approved
ORDER BY mt.date, g.name;
