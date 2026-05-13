-- ============================================================
-- Performance Indexes for Surypus
-- ============================================================

-- Composite indexes for frequently used filters in paginated queries

-- Person table: filters on name and inn (from getPersonsPaginated)
-- Query filters: name ILIKE '%' || $1 || '%', inn = $2
CREATE INDEX IF NOT EXISTS idx_person_name_inn ON person(name, inn);

-- Goods table: filters on name, barcode, code (from getGoodsPaginated)
-- Query filters: name ILIKE '%' || $1 || '%', barcode = $2, code = $3
CREATE INDEX IF NOT EXISTS idx_goods_name_barcode_code ON goods(name, barcode, code);

-- Bill table: filters on doc_date and person_id (from getBillsPaginated)
-- Query filters: doc_date >= $4, doc_date <= $5, person_id = $3
CREATE INDEX IF NOT EXISTS idx_bill_doc_date_person_id ON bill(doc_date, person_id);

-- Order table: filters on doc_date, person_id, status (from getOrdersPaginated)
-- Query filters: doc_status = $1, person_id = $2, doc_date >= $3, doc_date <= $4
CREATE INDEX IF NOT EXISTS idx_order_head_doc_date_person_status ON order_head(doc_date, person_id, doc_status);

-- TechCard table: filters on goods_id (from getTechCards)
-- Query filters: ? IS NULL OR goods_id = ?
CREATE INDEX IF NOT EXISTS idx_tech_card_goods_id ON tech_card(goods_id);

-- WorkOrder table: filters on goods_id (from getWorkOrders)
-- Query filters: ? IS NULL OR goods_id = ?
CREATE INDEX IF NOT EXISTS idx_work_order_goods_id ON work_order(goods_id);

-- Partial indexes for status filters (common pattern across tables)

-- Bills table: partial index for active bills (status_id != 0 assuming 0 is draft/cancelled)
CREATE INDEX IF NOT EXISTS idx_bill_status_active ON bill(status_id) 
WHERE status_id IS NOT NULL AND status_id != 0;

-- Persons table: partial index for active persons (status != 0 assuming 0 is inactive)
CREATE INDEX IF NOT EXISTS idx_person_status_active ON person(status) 
WHERE status IS NOT NULL AND status != 0;

-- Goods table: partial index for active goods (kind != 0 assuming 0 is inactive)
CREATE INDEX IF NOT EXISTS idx_goods_status_active ON goods(kind) 
WHERE kind IS NOT NULL AND kind != 0;

-- Orders table: partial index for active orders (status not in cancelled/completed)
CREATE INDEX IF NOT EXISTS idx_order_head_status_active ON order_head(status) 
WHERE status IS NOT NULL AND status NOT IN (0, 5, 6); -- Assuming 0=draft, 5=completed, 6=cancelled

-- TechCard table: partial index for active tech cards (status = 1 assuming 1 is active)
CREATE INDEX IF NOT EXISTS idx_tech_card_status_active ON tech_card(status) 
WHERE status = 1;

-- WorkOrder table: partial index for active work orders (status in [0,1,2] assuming 0=pending,1=in_progress,2=completed)
CREATE INDEX IF NOT EXISTS idx_work_order_status_active ON work_order(status) 
WHERE status IS NOT NULL AND status IN (0, 1, 2);

-- Additional performance improvements for common join patterns

-- Indexes for foreign key joins that are frequently queried
CREATE INDEX IF NOT EXISTS idx_bill_loc_id ON bill(loc_id);
CREATE INDEX IF NOT EXISTS idx_bill_op_id ON bill(op_id);

-- Configure autovacuum settings for better performance on frequently updated tables
-- These settings can be adjusted based on workload patterns

-- Set more aggressive autovacuum for heavily updated tables
ALTER TABLE person SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05,
    autovacuum_vacuum_cost_delay = 2ms,
    autovacuum_vacuum_cost_limit = 1000
);

ALTER TABLE goods SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05,
    autovacuum_vacuum_cost_delay = 2ms,
    autovacuum_vacuum_cost_limit = 1000
);

ALTER TABLE bill SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05,
    autovacuum_vacuum_cost_delay = 2ms,
    autovacuum_vacuum_cost_limit = 1000
);

ALTER TABLE order_head SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05,
    autovacuum_vacuum_cost_delay = 2ms,
    autovacuum_vacuum_cost_limit = 1000
);

-- For production tables that might have different usage patterns
ALTER TABLE tech_card SET (
    autovacuum_vacuum_scale_factor = 0.2,
    autovacuum_analyze_scale_factor = 0.1,
    autovacuum_vacuum_cost_delay = 2ms,
    autovacuum_vacuum_cost_limit = 1000
);

ALTER TABLE work_order SET (
    autovacuum_vacuum_scale_factor = 0.2,
    autovacuum_analyze_scale_factor = 0.1,
    autovacuum_vacuum_cost_delay = 2ms,
    autovacuum_vacuum_cost_limit = 1000
);

-- ============================================================
-- Indexes for our newly added production tables (from V010__production.sql)
-- ============================================================

-- TechCard table indexes (based on our queries)
CREATE INDEX IF NOT EXISTS idx_tech_card_goods_id ON tech_card(goods_id);
CREATE INDEX IF NOT EXISTS idx_tech_card_status ON tech_card(status);

-- TechLine table indexes
CREATE INDEX IF NOT EXISTS idx_tech_line_tech_card_id ON tech_line(tech_card_id);
CREATE INDEX IF NOT EXISTS idx_tech_line_goods_id ON tech_line(goods_id);

-- WorkOrder table indexes (based on our queries)
CREATE INDEX IF NOT EXISTS idx_work_order_goods_id ON work_order(goods_id);
CREATE INDEX IF NOT EXISTS idx_work_order_tech_card_id ON work_order(tech_card_id);
CREATE INDEX IF NOT EXISTS idx_work_order_status ON work_order(status);
CREATE INDEX IF NOT EXISTS idx_work_order_processor_id ON work_order(processor_id);

-- WorkOrderLine table indexes
CREATE INDEX IF NOT EXISTS idx_work_order_line_work_order_id ON work_order_line(work_order_id);
CREATE INDEX IF NOT EXISTS idx_work_order_line_goods_id ON work_order_line(goods_id);
CREATE INDEX IF NOT EXISTS idx_work_order_line_warehouse_id ON work_order_line(warehouse_id);