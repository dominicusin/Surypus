-- =============================================================================
-- Production Technology (Tech Cards & Hardware counters)
-- =============================================================================

CREATE TABLE IF NOT EXISTS tech_card (
    id SERIAL PRIMARY KEY,
    processor_id BIGINT NOT NULL,
    goods_group_id BIGINT NOT NULL REFERENCES goods_group(id) ON DELETE CASCADE,
    kind SMALLINT NOT NULL CHECK (kind IN (0,1)), -- 0=manual,1=auto
    code VARCHAR(32) UNIQUE NOT NULL,
    flags INT DEFAULT 0,
    formula TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tech_line (
    tech_card_id BIGINT NOT NULL REFERENCES tech_card(id) ON DELETE CASCADE,
    line_no INT NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    qty NUMERIC(18,6) NOT NULL CHECK (qty >= 0),
    sign INT NOT NULL CHECK (sign IN (-1,0,1)),
    formula TEXT,
    line_time NUMERIC(12,4) DEFAULT 0 CHECK (line_time >= 0),
    line_cost NUMERIC(18,4) DEFAULT 0 CHECK (line_cost >= 0),
    PRIMARY KEY (tech_card_id, line_no)
);

CREATE TABLE IF NOT EXISTS tech_counter (
    id SERIAL PRIMARY KEY,
    counter_name TEXT UNIQUE NOT NULL,
    counter_value BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tech_card_processor_code ON tech_card(processor_id, code);
CREATE INDEX IF NOT EXISTS idx_tech_card_processor ON tech_card(processor_id);
CREATE INDEX IF NOT EXISTS idx_tech_card_group ON tech_card(goods_group_id);
CREATE INDEX IF NOT EXISTS idx_tech_line_goods ON tech_line(goods_id);

-- =============================================================================
-- Stored procedures for tech cards
-- =============================================================================

CREATE OR REPLACE FUNCTION generate_tech_code(p_kind INT)
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT := CASE WHEN p_kind = 1 THEN 'TLNG' ELSE 'TECH' END;
    v_value BIGINT;
BEGIN
    UPDATE tech_counter
    SET counter_value = counter_value + 1, updated_at = NOW()
    WHERE counter_name = 'tech';
    IF NOT FOUND THEN
        INSERT INTO tech_counter(counter_name, counter_value) VALUES('tech', 1);
        v_value := 1;
    ELSE
        SELECT counter_value INTO v_value FROM tech_counter WHERE counter_name = 'tech';
    END IF;
    RETURN v_prefix || '-' || LPAD(v_value::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_tech_card(
    p_processor_id BIGINT,
    p_goods_group_id BIGINT,
    p_kind INT,
    p_formula TEXT
)
RETURNS BIGINT AS $$
DECLARE
    v_code TEXT;
BEGIN
    v_code := generate_tech_code(p_kind);
    INSERT INTO tech_card(processor_id, goods_group_id, kind, code, formula)
    VALUES (p_processor_id, p_goods_group_id, p_kind, v_code, p_formula)
    RETURNING id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION add_tech_line(
    p_tech_card_id BIGINT,
    p_line_no INT DEFAULT NULL,
    p_goods_id BIGINT,
    p_qty NUMERIC,
    p_sign INT,
    p_formula TEXT,
    p_line_time NUMERIC DEFAULT 0,
    p_line_cost NUMERIC DEFAULT 0
)
RETURNS VOID AS $$
DECLARE
    v_line_no INT;
BEGIN
    IF p_line_no IS NULL THEN
        SELECT COALESCE(MAX(line_no), 0) + 1 INTO v_line_no FROM tech_line WHERE tech_card_id = p_tech_card_id;
    ELSE
        v_line_no := p_line_no;
    END IF;

    INSERT INTO tech_line(tech_card_id, line_no, goods_id, qty, sign, formula, line_time, line_cost)
    VALUES (p_tech_card_id, v_line_no, p_goods_id, p_qty, p_sign, p_formula, p_line_time, p_line_cost);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calculate_tech_time(p_tech_id BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(line_time), 0) INTO v_total FROM tech_line WHERE tech_card_id = p_tech_id;
    RETURN v_total;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION calculate_tech_cost(p_tech_id BIGINT, p_material_cost NUMERIC)
RETURNS NUMERIC AS $$
DECLARE
    v_line_cost NUMERIC;
BEGIN
    SELECT COALESCE(SUM(line_cost), 0) INTO v_line_cost FROM tech_line WHERE tech_card_id = p_tech_id;
    RETURN v_line_cost + COALESCE(p_material_cost, 0);
END;
$$ LANGUAGE plpgsql IMMUTABLE;
