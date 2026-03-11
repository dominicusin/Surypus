-- ============================================================================
-- Хранимые процедуры для расчёта НДС и налогов
-- Реализация бизнес-логики  на PostgreSQL
-- ============================================================================

-- ============================================================================
-- ТАБЛИЦЫ СПРАВОЧНИКОВ
-- ============================================================================

-- Налоговые группы
CREATE TABLE IF NOT EXISTS tax_groups (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    vat_rate NUMERIC(5,4) NOT NULL,  -- Ставка НДС (0.20 = 20%)
    excise NUMERIC(15,2) DEFAULT 0,   -- Акциз
    sales_tax NUMERIC(5,4) DEFAULT 0, -- Налог с продаж
    flags INTEGER DEFAULT 0,          -- Флаги (GTAXF_SPCVAT, GTAXF_GENERALVAT)
    valid_from DATE DEFAULT '1970-01-01',
    valid_to DATE DEFAULT '2099-12-31'
);

-- Индекс для поиска по ставке
CREATE INDEX IF NOT EXISTS idx_tax_groups_vat_rate ON tax_groups(vat_rate);
CREATE INDEX IF NOT EXISTS idx_tax_groups_valid_dates ON tax_groups(valid_from, valid_to);

-- Статьи аналитики (контрагенты)
CREATE TABLE IF NOT EXISTS articles (
    id SERIAL PRIMARY KEY,
    article_group_id INTEGER,  -- Группа статей
    name VARCHAR(255) NOT NULL,
    flags INTEGER DEFAULT 0,
    -- Флаги: PSNF_NOVATAX - освобождён от НДС
    extended_id VARCHAR(100)   -- Внешний идентификатор
);

-- Склады
CREATE TABLE IF NOT EXISTS locations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    address TEXT,
    flags INTEGER DEFAULT 0,
    -- Флаги: LOCF_VATFREE - склад освобождён от НДС
    parent_id INTEGER REFERENCES locations(id)
);

-- ============================================================================
-- ТАБЛИЦЫ ДОКУМЕНТОВ
-- ============================================================================

-- Документы
CREATE TABLE IF NOT EXISTS bills (
    id SERIAL PRIMARY KEY,
    bill_type INTEGER NOT NULL,    -- PPOPT_xxx
    op_id INTEGER NOT NULL,         -- Вид операции
    object_id INTEGER,              -- Контрагент (статья)
    object2_id INTEGER,             -- Второй контрагент
    loc_id INTEGER,                 -- Склад
    date DATE NOT NULL,
    due_date DATE,
    amount NUMERIC(15,2) DEFAULT 0,
    flags INTEGER DEFAULT 0,
    status INTEGER DEFAULT 0,
    memo TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Строки документа (товарные позиции)
CREATE TABLE IF NOT EXISTS bill_lines (
    id SERIAL PRIMARY KEY,
    bill_id INTEGER NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
    line_no INTEGER NOT NULL,
    goods_id INTEGER NOT NULL,
    quantity NUMERIC(15,4) NOT NULL,
    price NUMERIC(15,4) NOT NULL,
    cost NUMERIC(15,4) NOT NULL,
    discount NUMERIC(15,4) DEFAULT 0,
    tax_group_id INTEGER REFERENCES tax_groups(id),
    location_id INTEGER REFERENCES locations(id),
    lot_id INTEGER,                 -- Партия
    supplier_id INTEGER,            -- Поставщик (статья)
    flags INTEGER DEFAULT 0,
    -- Флаги: PPTFR_COSTWOVAT - себестоимость без НДС
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_bills_date ON bills(date);
CREATE INDEX IF NOT EXISTS idx_bills_object ON bills(object_id);
CREATE INDEX IF NOT EXISTS idx_bills_op ON bills(op_id);
CREATE INDEX IF NOT EXISTS idx_bill_lines_bill ON bill_lines(bill_id);
CREATE INDEX IF NOT EXISTS idx_bill_lines_goods ON bill_lines(goods_id);

-- ============================================================================
-- ТАБЛИЦЫ ОСТАТКОВ
-- ============================================================================

-- Партии (остатки товаров)
CREATE TABLE IF NOT EXISTS lots (
    id SERIAL PRIMARY KEY,
    goods_id INTEGER NOT NULL,
    location_id INTEGER NOT NULL,
    receipt_date DATE NOT NULL,
    quantity NUMERIC(15,4) NOT NULL,
    rest NUMERIC(15,4) NOT NULL,
    price NUMERIC(15,4) NOT NULL,
    cost NUMERIC(15,4) NOT NULL,
    supplier_id INTEGER,
    tax_group_id INTEGER REFERENCES tax_groups(id),
    flags INTEGER DEFAULT 0,
    -- Флаги: LOTF_COSTWOVAT - цена без НДС
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_lots_goods_location ON lots(goods_id, location_id);
CREATE INDEX IF NOT EXISTS idx_lots_receipt_date ON lots(receipt_date);

-- ============================================================================
-- ТИПЫ СУММ
-- ============================================================================

-- Типы сумм (для хранения НДС, себестоимости и т.д.)
CREATE TABLE IF NOT EXISTS amount_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    flags INTEGER DEFAULT 0,
    -- Флаги: AMTF_TAX - это налог
    tax_type INTEGER DEFAULT 0  -- GTAX_VAT, GTAX_EXCISE, GTAX_SALES
);

-- Суммы документов
CREATE TABLE IF NOT EXISTS bill_amounts (
    id SERIAL PRIMARY KEY,
    bill_id INTEGER NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
    amount_type_id INTEGER NOT NULL REFERENCES amount_types(id),
    currency_id INTEGER DEFAULT 0,
    amount NUMERIC(15,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_bill_amounts_bill ON bill_amounts(bill_id);
CREATE INDEX IF NOT EXISTS idx_bill_amounts_type ON bill_amounts(amount_type_id);

-- ============================================================================
-- ХРАНИМЫЕ ПРОЦЕДУРЫ
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Получение налоговой ставки для товара на дату
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_goods_vat_rate(
    p_goods_id INTEGER,
    p_date DATE DEFAULT CURRENT_DATE,
    p_tax_payer_id INTEGER DEFAULT NULL
)
RETURNS NUMERIC(5,4) AS $$
DECLARE
    v_rate NUMERIC(5,4);
    v_tax_group_id INTEGER;
BEGIN
    -- Получаем налоговую группу товара
    SELECT tg.vat_rate INTO v_rate
    FROM tax_groups tg
    WHERE tg.id = p_tax_payer_id
      AND p_date BETWEEN tg.valid_from AND tg.valid_to
    ORDER BY tg.valid_from DESC
    LIMIT 1;
    
    RETURN COALESCE(v_rate, 0.20);  -- По умолчанию 20%
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Проверка освобождения контрагента от НДС
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION is_agent_vat_free(p_agent_id INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    v_flags INTEGER;
BEGIN
    SELECT a.flags INTO v_flags
    FROM articles a
    WHERE a.id = p_agent_id;
    
    RETURN (v_flags & 1) = 1;  -- PSNF_NOVATAX
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Проверка освобождения склада от НДС
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION is_location_vat_free(p_location_id INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
    v_flags INTEGER;
BEGIN
    SELECT l.flags INTO v_flags
    FROM locations l
    WHERE l.id = p_location_id;
    
    RETURN (v_flags & 1) = 1;  -- LOCF_VATFREE
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Расчёт НДС для суммы
-- Основная теорема: VAT = PriceWithVAT * Rate / (1 + Rate)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calc_vat(
    p_price NUMERIC,      -- Цена с НДС
    p_rate NUMERIC        -- Ставка НДС (0.20 = 20%)
)
RETURNS NUMERIC(15,2) AS $$
BEGIN
    IF p_rate <= 0 OR p_price < 0 THEN
        RETURN 0;
    END IF;
    
    RETURN round(p_price * p_rate / (1 + p_rate), 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ----------------------------------------------------------------------------
-- Расчёт цены без НДС
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calc_price_wo_vat(
    p_price NUMERIC,      -- Цена с НДС
    p_rate NUMERIC        -- Ставка НДС
)
RETURNS NUMERIC(15,2) AS $$
BEGIN
    IF p_rate <= 0 OR p_price < 0 THEN
        RETURN p_price;
    END IF;
    
    RETURN round(p_price / (1 + p_rate), 4);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ----------------------------------------------------------------------------
-- Расчёт цены с НДС
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calc_price_with_vat(
    p_price NUMERIC,      -- Цена без НДС
    p_rate NUMERIC        -- Ставка НДС
)
RETURNS NUMERIC(15,2) AS $$
BEGIN
    IF p_rate <= 0 OR p_price < 0 THEN
        RETURN p_price;
    END IF;
    
    RETURN round(p_price * (1 + p_rate), 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ----------------------------------------------------------------------------
-- Теорема: calc_vat(p_price, p_rate) = calc_price_with_vat(p_price, p_rate) - calc_price_wo_vat(p_price_with_vat, p_rate)
-- Проверка корректности расчёта НДС
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION verify_vat_calculation(
    p_price_with_vat NUMERIC,
    p_rate NUMERIC
)
RETURNS BOOLEAN AS $$
DECLARE
    v_vat NUMERIC(15,2);
    v_price_wo_vat NUMERIC(15,2);
    v_price_with_vat_calc NUMERIC(15,2);
BEGIN
    v_vat := calc_vat(p_price_with_vat, p_rate);
    v_price_wo_vat := calc_price_wo_vat(p_price_with_vat, p_rate);
    v_price_with_vat_calc := calc_price_with_vat(v_price_wo_vat, p_rate);
    
    RETURN v_price_with_vat_calc = p_price_with_vat;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ----------------------------------------------------------------------------
-- Расчёт НДС для строки документа
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calc_line_vat(
    p_line_id INTEGER
)
RETURNS NUMERIC(15,2) AS $$
DECLARE
    v_quantity NUMERIC(15,4);
    v_price NUMERIC(15,4);
    v_cost NUMERIC(15,4);
    v_rate NUMERIC(5,4);
    v_flags INTEGER;
    v_is_vat_free BOOLEAN;
    v_vat NUMERIC(15,2) := 0;
BEGIN
    -- Получаем данные строки
    SELECT bl.quantity, bl.price, bl.cost, bl.flags, bl.tax_group_id
    INTO v_quantity, v_price, v_cost, v_flags, v_rate
    FROM bill_lines bl
    WHERE bl.id = p_line_id;
    
    IF NOT FOUND THEN
        RETURN 0;
    END IF;
    
    -- Проверяем флаг "Цена без НДС"
    IF (v_flags & 1) = 1 THEN  -- PPTFR_COSTWOVAT
        -- Цена уже без НДС, нужно добавить НДС
        v_rate := COALESCE(v_rate, 0.20);
        v_vat := calc_vat(v_cost * v_quantity, v_rate);
    ELSE
        -- Обычный расчёт
        v_rate := COALESCE(v_rate, 0.20);
        v_vat := calc_vat(v_price * v_quantity, v_rate);
    END IF;
    
    RETURN COALESCE(v_vat, 0);
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Расчёт всех сумм документа (основная процедура)
--相当于 C++ 中的 CalcTotal
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calc_bill_totals(p_bill_id INTEGER)
RETURNS TABLE (
    amount_type_id INTEGER,
    amount NUMERIC(15,2)
) AS $$
DECLARE
    v_bill_date DATE;
    v_op_id INTEGER;
    v_object_id INTEGER;
    v_loc_id INTEGER;
    v_flags INTEGER;
    
    v_total_price NUMERIC(15,2) := 0;
    v_total_cost NUMERIC(15,2) := 0;
    v_total_discount NUMERIC(15,2) := 0;
    v_vat NUMERIC(15,2) := 0;
    v_cvat NUMERIC(15,2) := 0;
    v_pvat NUMERIC(15,2) := 0;
    
    v_line RECORD;
BEGIN
    -- Получаем данные заголовка документа
    SELECT b.date, b.op_id, b.object_id, b.loc_id, b.flags
    INTO v_bill_date, v_op_id, v_object_id, v_loc_id, v_flags
    FROM bills b
    WHERE b.id = p_bill_id;
    
    IF NOT FOUND THEN
        RETURN;
    END IF;
    
    -- Проверяем освобождение контрагента от НДС
    IF is_agent_vat_free(v_object_id) OR is_location_vat_free(v_loc_id) THEN
        -- Освобождён от НДС
        FOR v_line IN
            SELECT bl.quantity, bl.price, bl.cost, bl.flags
            FROM bill_lines bl
            WHERE bl.bill_id = p_bill_id
        LOOP
            v_total_price := v_total_price + v_line.quantity * v_line.price;
            v_total_cost := v_total_cost + v_line.quantity * v_line.cost;
        END LOOP;
        
        RETURN QUERY SELECT 1::INTEGER, v_total_price;  -- Основная сумма
        RETURN QUERY SELECT 2::INTEGER, v_total_cost;   -- Себестоимость
        RETURN;
    END IF;
    
    -- Стандартный расчёт
    FOR v_line IN
        SELECT bl.quantity, bl.price, bl.cost, bl.flags, bl.tax_group_id
        FROM bill_lines bl
        WHERE bl.bill_id = p_bill_id
    LOOP
        DECLARE
            v_rate NUMERIC(5,4);
            v_is_wo_vat BOOLEAN;
            v_line_vat NUMERIC(15,2);
        BEGIN
            -- Получаем ставку НДС
            SELECT COALESCE(tg.vat_rate, 0.20)
            INTO v_rate
            FROM tax_groups tg
            WHERE tg.id = v_line.tax_group_id
              AND v_bill_date BETWEEN tg.valid_from AND tg.valid_to
            LIMIT 1;
            
            v_is_wo_vat := (v_line.flags & 1) = 1;
            
            -- Расчёт суммы строки
            v_total_price := v_total_price + v_line.quantity * v_line.price;
            v_total_cost := v_total_cost + v_line.quantity * v_line.cost;
            
            -- Расчёт НДС
            IF v_is_wo_vat THEN
                -- Цена без НДС - добавляем НДС
                v_line_vat := calc_vat(v_line.quantity * v_line.cost, v_rate);
                v_cvat := v_cvat + v_line_vat;
            ELSE
                -- Цена с НДС - выделяем НДС
                v_line_vat := calc_vat(v_line.quantity * v_line.price, v_rate);
                v_pvat := v_pvat + v_line_vat;
            END IF;
            
            v_vat := v_vat + v_line_vat;
        END;
    END LOOP;
    
    -- Возвращаем суммы
    RETURN QUERY SELECT 1::INTEGER, round(v_total_price, 2);  -- PPAMT_MAIN
    RETURN QUERY SELECT 2::INTEGER, round(v_total_cost, 2);   -- PPAMT_COST
    RETURN QUERY SELECT 3::INTEGER, round(v_vat, 2);          -- PPAMT_VATAX
    RETURN QUERY SELECT 4::INTEGER, round(v_cvat, 2);         -- PPAMT_CVAT
    RETURN QUERY SELECT 5::INTEGER, round(v_pvat, 2);         -- PPAMT_PVAT
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- Пересчёт остатков партии
--相当于 C++ 中的 GetBounds
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_lot_bounds(
    p_lot_id INTEGER,
    p_date DATE DEFAULT CURRENT_DATE,
    p_oprno INTEGER DEFAULT -1
)
RETURNS TABLE (
    minus_delta NUMERIC(15,4),
    plus_delta NUMERIC(15,4)
) AS $$
DECLARE
    v_initial_rest NUMERIC(15,4);
    v_current_rest NUMERIC(15,4);
    v_minus NUMERIC(15,4) := 0;
    v_plus NUMERIC(15,4) := 0;
    
    v_movement RECORD;
BEGIN
    -- Получаем начальный остаток
    SELECT rest INTO v_initial_rest
    FROM lots
    WHERE id = p_lot_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT 0.0, 0.0;
        RETURN;
    END IF;
    
    -- Считаем расход до даты
    SELECT COALESCE(SUM(bl.quantity), 0) INTO v_minus
    FROM bill_lines bl
    JOIN bills b ON b.id = bl.bill_id
    WHERE bl.lot_id = p_lot_id
      AND b.date <= p_date
      AND b.bill_type IN (3, 4);  -- Реализация, списание
    
    -- Считаем приход до даты
    SELECT COALESCE(SUM(bl.quantity), 0) INTO v_plus
    FROM bill_lines bl
    JOIN bills b ON b.id = bl.bill_id
    WHERE bl.lot_id = p_lot_id
      AND b.date <= p_date
      AND b.bill_type IN (1, 2);  -- Поступление, возврат
    
    v_current_rest := v_initial_rest + v_plus - v_minus;
    
    RETURN QUERY SELECT v_minus, v_current_rest;
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- Расчёт книг покупок/продаж (НДС)
--相当于 C++ 中的 VATBook
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calc_vat_book(
    p_period_start DATE,
    p_period_end DATE,
    p_kind VARCHAR  -- 'sell' или 'buy'
)
RETURNS TABLE (
    vat_rate NUMERIC(5,4),
    vat_amount NUMERIC(15,2),
    vat_sum NUMERIC(15,2)
) AS $$
DECLARE
    v_op_type_ids INTEGER[];
BEGIN
    -- Определяем типы операций
    IF p_kind = 'sell' THEN
        v_op_type_ids := ARRAY[3, 4];  -- Реализация
    ELSE
        v_op_type_ids := ARRAY[1, 2];  -- Поступление
    END IF;
    
    RETURN QUERY
    SELECT 
        tg.vat_rate,
        SUM(bl.quantity * bl.price) AS vat_amount,
        SUM(calc_vat(bl.quantity * bl.price, tg.vat_rate)) AS vat_sum
    FROM bill_lines bl
    JOIN bills b ON b.id = bl.bill_id
    JOIN tax_groups tg ON tg.id = bl.tax_group_id
    WHERE b.date BETWEEN p_period_start AND p_period_end
      AND b.op_id = ANY(v_op_type_ids)
    GROUP BY tg.vat_rate
    ORDER BY tg.vat_rate;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- ИНИЦИАЛИЗАЦИЯ ДАННЫХ
-- ============================================================================

-- Вставка стандартных налоговых групп
INSERT INTO tax_groups (name, vat_rate, flags, valid_from, valid_to) VALUES
    ('НДС 20%', 0.20, 0, '2019-01-01', '2099-12-31'),
    ('НДС 18%', 0.18, 0, '2004-01-01', '2018-12-31'),
    ('НДС 10%', 0.10, 0, '2004-01-01', '2099-12-31'),
    ('НДС 0% (не облагается)', 0.00, 1, '1970-01-01', '2099-12-31'),
    ('НДС 7%', 0.07, 0, '2015-01-01', '2099-12-31'),
    ('НДС 5%', 0.05, 0, '2015-01-01', '2099-12-31')
ON CONFLICT DO NOTHING;

-- Вставка типов сумм
INSERT INTO amount_types (name, flags, tax_type) VALUES
    ('Основная сумма', 0, 0),
    ('Себестоимость', 0, 0),
    ('НДС', 1, 1),        -- GTAX_VAT
    ('НДС по себестоимости', 1, 1),
    ('НДС по цене реализации', 1, 1),
    ('Акциз', 1, 2),      -- GTAX_EXCISE
    ('Налог с продаж', 1, 3)  -- GTAX_SALES
ON CONFLICT DO NOTHING;

DO $$
BEGIN
    RAISE NOTICE 'Database schema and stored procedures created successfully';
END $$;
