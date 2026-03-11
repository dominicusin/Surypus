-- =================================================================
-- Association System - Связи между объектами
-- =================================================================
-- Analog:  pplib/objassoc.cpp (ObjAssoc)

-- Association Type (типы связей)
CREATE TABLE IF NOT EXISTS assoc_type (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    primary_obj_type BIGINT NOT NULL,  -- PPOBJ_XXX
    secondary_obj_type BIGINT NOT NULL, -- PPOBJ_XXX
    flags INTEGER DEFAULT 0,            -- ASSOCF_XXX
    limit_count INT DEFAULT 0,          -- 0 = unlimited
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assoc_type_objtypes ON assoc_type(primary_obj_type, secondary_obj_type);

-- Association (связи)
CREATE TABLE IF NOT EXISTS association (
    id BIGSERIAL PRIMARY KEY,
    type_id BIGINT NOT NULL REFERENCES assoc_type(id) ON DELETE CASCADE,
    primary_obj_id BIGINT NOT NULL,
    secondary_obj_id BIGINT NOT NULL,
    order_num INT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(type_id, primary_obj_id, secondary_obj_id)
);

CREATE INDEX IF NOT EXISTS idx_association_type ON association(type_id);
CREATE INDEX IF NOT EXISTS idx_association_primary ON association(primary_obj_id);
CREATE INDEX IF NOT EXISTS idx_association_secondary ON association(secondary_obj_id);

-- =================================================================
-- Default Association Types (базовые типы связей)
-- =================================================================

INSERT INTO assoc_type (name, primary_obj_type, secondary_obj_type, flags, limit_count) VALUES
    ('Товар-Категория', 12, 25, 0, 0),        -- Goods -> GoodsGroup
    ('Товар-Бренд', 12, 27, 0, 1),            -- Goods -> Brand (уникальная)
    ('Товар-Единица', 12, 38, 0, 0),          -- Goods -> Unit
    ('Товар-Налоговая группа', 12, 29, 0, 1), -- Goods -> TaxGroup
    ('Документ-Товар', 32, 12, 0, 0),         -- Bill -> Goods
    ('Контрагент-Контакт', 2, 2, 0, 0),       -- Person -> Person
    ('Сотрудник-Должность', 2, 45, 0, 1),    -- Person -> Position
    ('Склад-Организация', 26, 2, 0, 0),       -- Location -> Person
    ('Счет-Контрагент', 19, 2, 0, 0),         -- Account -> Person
    ('Бюджет-Статья', 1001, 1002, 0, 0)       -- Budget -> BudgetItem
ON CONFLICT DO NOTHING;

-- =================================================================
-- Functions
-- =================================================================

-- Get associations for object (both as primary and secondary)
CREATE OR REPLACE FUNCTION get_object_associations(BIGINT)
RETURNS TABLE (id BIGINT, type_id BIGINT, type_name TEXT, 
               primary_obj_id BIGINT, secondary_obj_id BIGINT, 
               order_num INT, flags INTEGER) AS $$
BEGIN
    RETURN QUERY
    SELECT a.id, a.type_id, at.name, a.primary_obj_id, a.secondary_obj_id,
           a.order_num, a.flags
    FROM association a
    JOIN assoc_type at ON at.id = a.type_id
    WHERE (a.primary_obj_id = $1 OR a.secondary_obj_id = $1)
      AND a.flags & 1 = 1  -- Active
    ORDER BY a.type_id, a.order_num;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get primary associations only
CREATE OR REPLACE FUNCTION get_primary_associations(BIGINT)
RETURNS TABLE (type_id BIGINT, type_name TEXT, secondary_obj_id BIGINT, 
               order_num INT) AS $$
BEGIN
    RETURN QUERY
    SELECT a.type_id, at.name, a.secondary_obj_id, a.order_num
    FROM association a
    JOIN assoc_type at ON at.id = a.type_id
    WHERE a.primary_obj_id = $1 AND a.flags & 1 = 1
    ORDER BY a.order_num;
END;
$$ LANGUAGE plpgsql STABLE;

-- Check if association exists
CREATE OR REPLACE FUNCTION check_association(BIGINT, BIGINT, BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    p_type_id ALIAS FOR $1;
    p_primary ALIAS FOR $2;
    p_secondary ALIAS FOR $3;
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM association
        WHERE type_id = p_type_id 
          AND primary_obj_id = p_primary 
          AND secondary_obj_id = p_secondary
          AND flags & 1 = 1
    ) INTO v_exists;
    
    RETURN v_exists;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get association count for primary object
CREATE OR REPLACE FUNCTION get_association_count(BIGINT)
RETURNS BIGINT AS $$
DECLARE
    p_type_id ALIAS FOR $1;
    v_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM association
    WHERE type_id = p_type_id AND flags & 1 = 1;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql STABLE;

-- =================================================================
-- Triggers
-- =================================================================

CREATE OR REPLACE FUNCTION update_association_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_assoc_type_update
    BEFORE UPDATE ON assoc_type
    FOR EACH ROW EXECUTE FUNCTION update_association_timestamp();

CREATE TRIGGER tr_association_update
    BEFORE UPDATE ON association
    FOR EACH ROW EXECUTE FUNCTION update_association_timestamp();

-- =================================================================
-- Comments
-- =================================================================

COMMENT ON TABLE assoc_type IS 'Типы связей между объектами (аналог AssocTypeTbl)';
COMMENT ON TABLE association IS 'Связи между объектами (аналог ObjAssocTbl)';
COMMENT ON assoc_type.flags IS 'Флаги: 1=Уникальная, 2=Пассивная, 4=Обязательная, 8=Иерархическая';
COMMENT ON association.flags IS 'Флаги: 1=Активна';
