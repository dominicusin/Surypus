-- V010__production.sql
-- Production module: tech cards, work orders

-- Tech cards (технические карты)
CREATE TABLE IF NOT EXISTS tech_card (
    id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL REFERENCES goods(goods_id),
    name VARCHAR(500) NOT NULL,
    version VARCHAR(50) DEFAULT '1.0',
    status SMALLINT NOT NULL DEFAULT 0,  -- 0=draft, 1=active, 2=archived
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255)
);

-- Tech card lines (состав техкарты)
CREATE TABLE IF NOT EXISTS tech_line (
    id SERIAL PRIMARY KEY,
    tech_card_id INT NOT NULL REFERENCES tech_card(id) ON DELETE CASCADE,
    line_num SMALLINT NOT NULL,
    goods_id INT NOT NULL REFERENCES goods(goods_id),
    qty_plan DECIMAL(15, 4) NOT NULL CHECK (qty_plan >= 0),
    unit_id INT,
    scrap_percent DECIMAL(5, 2) DEFAULT 0,
    notes TEXT
);

-- Work orders (производственные заказы)
CREATE TABLE IF NOT EXISTS work_order (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    goods_id INT NOT NULL REFERENCES goods(goods_id),
    tech_card_id INT REFERENCES tech_card(id),
    qty_plan DECIMAL(15, 4) NOT NULL CHECK (qty_plan >= 0),
    qty_released DECIMAL(15, 4) DEFAULT 0 CHECK (qty_released <= qty_plan),
    status SMALLINT NOT NULL DEFAULT 0,  -- 0=pending, 1=in_progress, 2=completed, 3=cancelled, 4=paused
    start_date DATE,
    end_date DATE,
    processor_id INT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(255),
    CONSTRAINT chk_status CHECK (status IN (0, 1, 2, 3, 4))
);

-- Work order lines (материалы по заказу)
CREATE TABLE IF NOT EXISTS work_order_line (
    id SERIAL PRIMARY KEY,
    work_order_id INT NOT NULL REFERENCES work_order(id) ON DELETE CASCADE,
    line_num SMALLINT NOT NULL,
    goods_id INT NOT NULL REFERENCES goods(goods_id),
    qty_needed DECIMAL(15, 4) NOT NULL CHECK (qty_needed >= 0),
    qty_issued DECIMAL(15, 4) DEFAULT 0,
    warehouse_id INT
);

-- Indexes for production queries
CREATE INDEX IF NOT EXISTS idx_tech_card_goods_id ON tech_card(goods_id);
CREATE INDEX IF NOT EXISTS idx_tech_card_status ON tech_card(status);
CREATE INDEX IF NOT EXISTS idx_work_order_status ON work_order(status);
CREATE INDEX IF NOT EXISTS idx_work_order_goods_id ON work_order(goods_id);
CREATE INDEX IF NOT EXISTS idx_work_order_processor ON work_order(processor_id);
CREATE INDEX IF NOT EXISTS idx_work_order_line_work_order ON work_order_line(work_order_id);
