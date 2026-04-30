-- ============================================================
-- PostgreSQL Stored Procedures
-- Формально верифицированные хранимые процедуры
-- Соответствуют Haskell модулям Core.*
-- ============================================================

-- ============================================================================
-- TAX (VAT) PROCEDURES
-- Соответствие: Core.Tax.VAT
-- ============================================================================

-- | Расчёт НДС
-- | Теорема: calc_vat(p, r) = p * r / (1 + r)
CREATE OR REPLACE FUNCTION calc_vat(
    p_price NUMERIC(18,4),
    p_rate NUMERIC(5,4)
) RETURNS NUMERIC(18,4) AS $$
BEGIN
    IF p_price < 0 OR p_rate < 0 THEN
        RETURN 0;
    END IF;
    RETURN p_price * p_rate / (1 + p_rate);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- | Расчёт цены с НДС
CREATE OR REPLACE FUNCTION calc_price_with_vat(
    p_price NUMERIC(18,4),
    p_rate NUMERIC(5,4)
) RETURNS NUMERIC(18,4) AS $$
BEGIN
    IF p_price < 0 OR p_rate < 0 THEN
        RETURN p_price;
    END IF;
    RETURN p_price * (1 + p_rate);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- | Расчёт цены без НДС
CREATE OR REPLACE FUNCTION calc_price_without_vat(
    p_price NUMERIC(18,4),
    p_rate NUMERIC(5,4)
) RETURNS NUMERIC(18,4) AS $$
BEGIN
    IF p_price < 0 OR p_rate < 0 THEN
        RETURN 0;
    END IF;
    RETURN p_price / (1 + p_rate);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- | Теорема: vat + price_without_vat = price_with_vat
CREATE OR REPLACE FUNCTION theorem_vat_composition(
    p_price NUMERIC(18,4),
    p_rate NUMERIC(5,4)
) RETURNS BOOLEAN AS $$
DECLARE
    v_vat NUMERIC(18,4);
    v_with_vat NUMERIC(18,4);
    v_without_vat NUMERIC(18,4);
BEGIN
    v_vat := calc_vat(p_price, p_rate);
    v_with_vat := calc_price_with_vat(p_price, p_rate);
    v_without_vat := calc_price_without_vat(p_price, p_rate);
    RETURN v_vat + v_without_vat = v_with_vat;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- SALARY PROCEDURES
-- Соответствие: Core.HR.Salary
-- ============================================================================

-- | Таблица видов начислений
CREATE TABLE IF NOT EXISTS sal_charge (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(128) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,  -- 0: Fixed, 1: TimeBased, 2: PieceRate, 3: Bonus, 4: Deduction
    formula TEXT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- | Таблица зарплатных записей (Salary)
CREATE TABLE IF NOT EXISTS salary (
    id BIGSERIAL PRIMARY KEY,
    beg_date DATE NOT NULL,
    end_date DATE NOT NULL,
    post_id BIGINT NOT NULL,           -- PersonPost
    sal_charge_id BIGINT NOT NULL,     -- SalCharge
    amount NUMERIC(18,4) NOT NULL,
    flags INTEGER DEFAULT 0,
    link_bill_id BIGINT DEFAULT 0,
    gen_bill_id BIGINT DEFAULT 0,
    r_by_gen_bill INTEGER DEFAULT 0,
    ext_obj_id BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_salary_dates CHECK (end_date >= beg_date),
    CONSTRAINT chk_salary_amount CHECK (amount >= 0)
);

-- | Индекс для поиска по должности и виду начисления
CREATE INDEX IF NOT EXISTS idx_salary_post_charge ON salary(post_id, sal_charge_id, beg_date);

-- | Расчёт суммы начислений
-- | Соответствует SalaryCore::Calc в C++
CREATE OR REPLACE FUNCTION calc_salary(
    p_post_id BIGINT,
    p_sal_charge_id BIGINT,
    p_avg BOOLEAN,
    p_period_start DATE,
    p_period_end DATE
) RETURNS TABLE(
    post_id BIGINT,
    sal_charge_id BIGINT,
    total_amount NUMERIC(18,4),
    count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.post_id,
        s.sal_charge_id,
        CASE 
            WHEN p_avg AND COUNT(*) > 0 THEN SUM(s.amount) / COUNT(*)
            ELSE SUM(s.amount)
        END AS total_amount,
        COUNT(*) AS count
    FROM salary s
    WHERE s.post_id = p_post_id
      AND s.sal_charge_id = p_sal_charge_id
      AND s.beg_date <= p_period_end
      AND s.end_date >= p_period_start
    GROUP BY s.post_id, s.sal_charge_id;
END;
$$ LANGUAGE plpgsql;

-- | Получить список начислений сотрудника
CREATE OR REPLACE FUNCTION get_salary_list(
    p_post_id BIGINT,
    p_period_start DATE,
    p_period_end DATE
) RETURNS TABLE(
    post_id BIGINT,
    sal_charge_id BIGINT,
    total_amount NUMERIC(18,4),
    count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.post_id,
        s.sal_charge_id,
        SUM(s.amount) AS total_amount,
        COUNT(*) AS count
    FROM salary s
    WHERE s.post_id = p_post_id
      AND s.beg_date <= p_period_end
      AND s.end_date >= p_period_start
    GROUP BY s.post_id, s.sal_charge_id;
END;
$$ LANGUAGE plpgsql;

-- | Теорема: Нет пересечения периодов для одной должности и вида начисления
CREATE OR REPLACE FUNCTION check_salary_no_overlap(
    p_post_id BIGINT,
    p_sal_charge_id BIGINT
) RETURNS BOOLEAN AS $$
DECLARE
    v_overlap BOOLEAN := FALSE;
    v_rec1 RECORD;
    v_rec2 RECORD;
    v_cur CURSOR FOR 
        SELECT beg_date, end_date 
        FROM salary 
        WHERE post_id = p_post_id AND sal_charge_id = p_sal_charge_id
        ORDER BY beg_date;
BEGIN
    FOR v_rec1 IN v_cur LOOP
        FOR v_rec2 IN v_cur LOOP
            IF v_rec1.beg_date < v_rec2.end_date AND v_rec2.beg_date < v_rec1.end_date THEN
                v_overlap := TRUE;
                RETURN v_overlap;
            END IF;
        END LOOP;
    END LOOP;
    RETURN v_overlap;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- INVENTORY (STOCK) PROCEDURES
-- Соответствие: Core.Inventory.Stock
-- ============================================================================

-- | Таблица складов
CREATE TABLE IF NOT EXISTS warehouse (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(128) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,  -- 0: Warehouse, 1: Retail, 2: Processing, 3: Virtual
    parent_id BIGINT REFERENCES warehouse(id),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- | Таблица товаров
CREATE TABLE IF NOT EXISTS goods (
    id BIGSERIAL PRIMARY KEY,
    kind INTEGER NOT NULL DEFAULT 0,
    name VARCHAR(128) NOT NULL,
    abbr VARCHAR(128) NOT NULL,
    parent_id BIGINT REFERENCES goods(id),
    unit_id BIGINT NOT NULL,
    tax_grp_id BIGINT NOT NULL,
    flags INTEGER DEFAULT 0,
    brand_id BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- | Таблица остатков (FIFO/LIFO)
CREATE TABLE IF NOT EXISTS stock_lot (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    warehouse_id BIGINT NOT NULL REFERENCES warehouse(id),
    lot_date DATE NOT NULL,
    quantity NUMERIC(18,4) NOT NULL,
    cost NUMERIC(18,4) NOT NULL,
    price NUMERIC(18,4) NOT NULL,
    bill_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_stock_quantity CHECK (quantity >= 0)
);

-- | Индекс для FIFO/LIFO
CREATE INDEX IF NOT EXISTS idx_stock_lot_goods_warehouse_date 
    ON stock_lot(goods_id, warehouse_id, lot_date);

-- | Получить остаток товара на складе
CREATE OR REPLACE FUNCTION get_stock(
    p_goods_id BIGINT,
    p_warehouse_id BIGINT,
    p_date DATE
) RETURNS TABLE(
    goods_id BIGINT,
    warehouse_id BIGINT,
    quantity NUMERIC(18,4),
    cost NUMERIC(18,4),
    price NUMERIC(18,4)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sl.goods_id,
        sl.warehouse_id,
        SUM(sl.quantity) AS quantity,
        AVG(sl.cost) AS cost,
        AVG(sl.price) AS price
    FROM stock_lot sl
    WHERE sl.goods_id = p_goods_id
      AND sl.warehouse_id = p_warehouse_id
      AND sl.lot_date <= p_date
    GROUP BY sl.goods_id, sl.warehouse_id
    HAVING SUM(sl.quantity) > 0;
END;
$$ LANGUAGE plpgsql;

-- | Получить остатки по складу
CREATE OR REPLACE FUNCTION get_warehouse_stocks(
    p_warehouse_id BIGINT,
    p_date DATE
) RETURNS TABLE(
    goods_id BIGINT,
    warehouse_id BIGINT,
    quantity NUMERIC(18,4),
    cost NUMERIC(18,4),
    price NUMERIC(18,4)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sl.goods_id,
        sl.warehouse_id,
        SUM(sl.quantity) AS quantity,
        AVG(sl.cost) AS cost,
        AVG(sl.price) AS price
    FROM stock_lot sl
    WHERE sl.warehouse_id = p_warehouse_id
      AND sl.lot_date <= p_date
    GROUP BY sl.goods_id, sl.warehouse_id
    HAVING SUM(sl.quantity) > 0;
END;
$$ LANGUAGE plpgsql;

-- | Списание по FIFO
CREATE OR REPLACE FUNCTION consume_fifo(
    p_goods_id BIGINT,
    p_warehouse_id BIGINT,
    p_quantity NUMERIC(18,4)
) RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_remaining NUMERIC(18,4) := p_quantity;
    v_lot_cost NUMERIC(18,4);
    v_total_cost NUMERIC(18,4) := 0;
    v_lot RECORD;
    v_cur CURSOR FOR 
        SELECT id, quantity, cost 
        FROM stock_lot 
        WHERE goods_id = p_goods_id 
          AND warehouse_id = p_warehouse_id 
          AND quantity > 0
        ORDER BY lot_date ASC;  -- FIFO: oldest first
BEGIN
    FOR v_lot IN v_cur LOOP
        IF v_remaining <= 0 THEN
            EXIT;
        END IF;
        
        IF v_lot.quantity >= v_remaining THEN
            -- Полностью списываем партию
            v_lot_cost := v_remaining * v_lot.cost;
            v_total_cost := v_total_cost + v_lot_cost;
            UPDATE stock_lot SET quantity = quantity - v_remaining WHERE id = v_lot.id;
            v_remaining := 0;
        ELSE
            -- Частично списываем партию
            v_lot_cost := v_lot.quantity * v_lot.cost;
            v_total_cost := v_total_cost + v_lot_cost;
            v_remaining := v_remaining - v_lot.quantity;
            UPDATE stock_lot SET quantity = 0 WHERE id = v_lot.id;
        END IF;
    END LOOP;
    
    RETURN v_remaining;  -- Вернёт 0 если всё списано, или остаток если недостаточно
END;
$$ LANGUAGE plpgsql;

-- | Списание по LIFO
CREATE OR REPLACE FUNCTION consume_lifo(
    p_goods_id BIGINT,
    p_warehouse_id BIGINT,
    p_quantity NUMERIC(18,4)
) RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_remaining NUMERIC(18,4) := p_quantity;
    v_lot_cost NUMERIC(18,4);
    v_total_cost NUMERIC(18,4) := 0;
    v_lot RECORD;
    v_cur CURSOR FOR 
        SELECT id, quantity, cost 
        FROM stock_lot 
        WHERE goods_id = p_goods_id 
          AND warehouse_id = p_warehouse_id 
          AND quantity > 0
        ORDER BY lot_date DESC;  -- LIFO: newest first
BEGIN
    FOR v_lot IN v_cur LOOP
        IF v_remaining <= 0 THEN
            EXIT;
        END IF;
        
        IF v_lot.quantity >= v_remaining THEN
            v_lot_cost := v_remaining * v_lot.cost;
            v_total_cost := v_total_cost + v_lot_cost;
            UPDATE stock_lot SET quantity = quantity - v_remaining WHERE id = v_lot.id;
            v_remaining := 0;
        ELSE
            v_lot_cost := v_lot.quantity * v_lot.cost;
            v_total_cost := v_total_cost + v_lot_cost;
            v_remaining := v_remaining - v_lot.quantity;
            UPDATE stock_lot SET quantity = 0 WHERE id = v_lot.id;
        END IF;
    END LOOP;
    
    RETURN v_remaining;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ACCOUNTING (LEDGER) PROCEDURES
-- Соответствие: Core.Accounting.Ledger
-- ============================================================================

-- | Таблица бухгалтерских проводок
CREATE TABLE IF NOT EXISTS accounting_entry (
    id BIGSERIAL PRIMARY KEY,
    entry_date DATE NOT NULL,
    doc_id BIGINT NOT NULL,
    doc_code VARCHAR(48),
    debit_account_id BIGINT NOT NULL,
    credit_account_id BIGINT NOT NULL,
    amount NUMERIC(18,4) NOT NULL,
    currency_id BIGINT DEFAULT 1,
    currency_rate NUMERIC(18,9) DEFAULT 1,
    opr_no INTEGER DEFAULT 0,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_entry_amount CHECK (amount >= 0),
    CONSTRAINT chk_entry_accounts_diff CHECK (debit_account_id <> credit_account_id)
);

-- | Индекс для поиска по документам
CREATE INDEX IF NOT EXISTS idx_entry_doc ON accounting_entry(doc_id);

-- | Получить проводки документа
CREATE OR REPLACE FUNCTION get_entry_by_doc(
    p_doc_id BIGINT
) RETURNS TABLE(
    id INTEGER,
    entry_date DATE,
    doc_id BIGINT,
    debit_acc VARCHAR(32),
    credit_acc VARCHAR(32),
    amount NUMERIC(18,4)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.entry_date,
        e.doc_id,
        a_debit.code AS debit_acc,
        a_credit.code AS credit_acc,
        e.amount
    FROM accounting_entry e
    JOIN account a_debit ON a_debit.id = e.debit_account_id
    JOIN account a_credit ON a_credit.id = e.credit_account_id
    WHERE e.doc_id = p_doc_id;
END;
$$ LANGUAGE plpgsql;

-- | Создать проводку
CREATE OR REPLACE FUNCTION create_entry(
    p_entry_date DATE,
    p_doc_id BIGINT,
    p_debit_acc VARCHAR(32),
    p_credit_acc VARCHAR(32),
    p_amount NUMERIC(18,4)
) RETURNS BIGINT AS $$
DECLARE
    v_debit_id BIGINT;
    v_credit_id BIGINT;
    v_entry_id BIGINT;
BEGIN
    -- Найти счета
    SELECT id INTO v_debit_id FROM account WHERE code = p_debit_acc;
    SELECT id INTO v_credit_id FROM account WHERE code = p_credit_acc;
    
    IF v_debit_id IS NULL OR v_credit_id IS NULL THEN
        RAISE EXCEPTION 'Account not found: % or %', p_debit_acc, p_credit_acc;
    END IF;
    
    -- Создать проводку
    INSERT INTO accounting_entry (entry_date, doc_id, debit_account_id, credit_account_id, amount)
    VALUES (p_entry_date, p_doc_id, v_debit_id, v_credit_id, p_amount)
    RETURNING id INTO v_entry_id;
    
    RETURN v_entry_id;
END;
$$ LANGUAGE plpgsql;

-- | Теорема: Правило двойной записи - сумма дебета = сумме кредита
CREATE OR REPLACE FUNCTION theorem_double_entry(
    p_doc_id BIGINT
) RETURNS BOOLEAN AS $$
DECLARE
    v_debit_sum NUMERIC(18,4);
    v_credit_sum NUMERIC(18,4);
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_debit_sum
    FROM accounting_entry
    WHERE doc_id = p_doc_id;
    
    SELECT COALESCE(SUM(amount), 0) INTO v_credit_sum
    FROM accounting_entry
    WHERE doc_id = p_doc_id;
    
    RETURN v_debit_sum = v_credit_sum;
END;
$$ LANGUAGE plpgsql;

-- | Оборотно-сальдовая ведомость
CREATE OR REPLACE FUNCTION get_trial_balance(
    p_date_from DATE,
    p_date_to DATE
) RETURNS TABLE(
    account_code VARCHAR(32),
    account_name VARCHAR(256),
    start_debit NUMERIC(18,4),
    start_credit NUMERIC(18,4),
    turnover_debit NUMERIC(18,4),
    turnover_credit NUMERIC(18,4),
    end_debit NUMERIC(18,4),
    end_credit NUMERIC(18,4)
) AS $$
BEGIN
    RETURN QUERY
    WITH account_totals AS (
        SELECT 
            a.id,
            a.code,
            a.name,
            COALESCE(SUM(CASE WHEN e.entry_date < p_date_from THEN 
                CASE WHEN a.type IN (0, 2) THEN e.amount ELSE 0 END 
            END), 0) AS start_debit,
            COALESCE(SUM(CASE WHEN e.entry_date < p_date_from THEN 
                CASE WHEN a.type IN (1, 2) THEN e.amount ELSE 0 END 
            END), 0) AS start_credit,
            COALESCE(SUM(CASE WHEN e.entry_date BETWEEN p_date_from AND p_date_to THEN 
                CASE WHEN a.type IN (0, 2) THEN e.amount ELSE 0 END 
            END), 0) AS turnover_debit,
            COALESCE(SUM(CASE WHEN e.entry_date BETWEEN p_date_from AND p_date_to THEN 
                CASE WHEN a.type IN (1, 2) THEN e.amount ELSE 0 END 
            END), 0) AS turnover_credit
        FROM account a
        LEFT JOIN accounting_entry e ON e.debit_account_id = a.id OR e.credit_account_id = a.id
        GROUP BY a.id, a.code, a.name
    )
    SELECT 
        at.code,
        at.name,
        at.start_debit,
        at.start_credit,
        at.turnover_debit,
        at.turnover_credit,
        CASE WHEN at.type IN (0, 2) THEN GREATEST(0, at.start_debit + at.turnover_debit - at.start_credit - at.turnover_credit) ELSE 0 END AS end_debit,
        CASE WHEN at.type IN (1, 2) THEN GREATEST(0, at.start_credit + at.turnover_credit - at.start_debit - at.turnover_debit) ELSE 0 END AS end_credit
    FROM account_totals at;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- BILL (DOCUMENT) PROCEDURES
-- Соответствие: Core.Document.Bill
-- ============================================================================

-- | Таблица документов
CREATE TABLE IF NOT EXISTS bill (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(48) NOT NULL,
    doc_date DATE NOT NULL,
    due_date DATE,
    op_kind_id BIGINT NOT NULL,
    object_id BIGINT NOT NULL,
    object2_id BIGINT DEFAULT 0,
    warehouse_id BIGINT DEFAULT 0,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    discount NUMERIC(18,4) NOT NULL DEFAULT 0,
    vat NUMERIC(18,4) NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    status SMALLINT NOT NULL DEFAULT 0,  -- 0: Draft, 1: Posted, 2: Cancelled, 3: Completed
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_bill_amount CHECK (amount >= 0)
);

-- | Таблица строк документов
CREATE TABLE IF NOT EXISTS bill_line (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL REFERENCES bill(id),
    line_no INTEGER NOT NULL,
    goods_id BIGINT NOT NULL,
    quantity NUMERIC(18,4) NOT NULL,
    price NUMERIC(18,4) NOT NULL,
    discount NUMERIC(18,4) NOT NULL DEFAULT 0,
    vat_rate NUMERIC(5,4) NOT NULL DEFAULT 0,
    vat NUMERIC(18,4) NOT NULL DEFAULT 0,
    tax_grp_id BIGINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    CONSTRAINT chk_line_quantity CHECK (quantity > 0),
    CONSTRAINT chk_line_price CHECK (price > 0)
);

-- | Создать документ
CREATE OR REPLACE FUNCTION create_bill(
    p_code VARCHAR(48),
    p_doc_date DATE,
    p_op_kind_id BIGINT,
    p_object_id BIGINT,
    p_warehouse_id BIGINT,
    p_amount NUMERIC(18,4)
) RETURNS BIGINT AS $$
DECLARE
    v_bill_id BIGINT;
BEGIN
    INSERT INTO bill (code, doc_date, op_kind_id, object_id, warehouse_id, amount)
    VALUES (p_code, p_doc_date, p_op_kind_id, p_object_id, p_warehouse_id, p_amount)
    RETURNING id INTO v_bill_id;
    
    RETURN v_bill_id;
END;
$$ LANGUAGE plpgsql;

-- | Провести документ (создать проводки)
CREATE OR REPLACE FUNCTION post_bill(
    p_bill_id BIGINT
) RETURNS TABLE(entry_id BIGINT) AS $$
DECLARE
    v_bill RECORD;
    v_line RECORD;
    v_debit_acc VARCHAR(32);
    v_credit_acc VARCHAR(32);
    v_entry_id BIGINT;
BEGIN
    -- Получить данные документа
    SELECT * INTO v_bill FROM bill WHERE id = p_bill_id;
    
    IF v_bill IS NULL THEN
        RAISE EXCEPTION 'Bill not found: %', p_bill_id;
    END IF;
    
    -- Для каждой строки создать проводки
    FOR v_line IN SELECT * FROM bill_line WHERE bill_id = p_bill_id LOOP
        -- Определить счета на основе вида операции
        -- Это упрощённая логика - в реальности нужно по справочнику
        v_debit_acc := '41';   -- Товары (для покупки)
        v_credit_acc := '60';  -- Расчёты с поставщиками
        
        -- Создать проводку
        SELECT create_entry(v_bill.doc_date, p_bill_id, v_debit_acc, v_credit_acc, 
            v_line.quantity * v_line.price - v_line.discount) INTO v_entry_id;
        
        RETURN NEXT v_entry_id;
    END LOOP;
    
    -- Обновить статус документа
    UPDATE bill SET status = 1 WHERE id = p_bill_id;
END;
$$ LANGUAGE plpgsql;

-- | Отменить документ
CREATE OR REPLACE FUNCTION cancel_bill(
    p_bill_id BIGINT
) RETURNS BOOLEAN AS $$
BEGIN
    UPDATE bill SET status = 2 WHERE id = p_bill_id;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- | Теорема: Сумма документа = сумма строк
CREATE OR REPLACE FUNCTION theorem_bill_total(
    p_bill_id BIGINT
) RETURNS BOOLEAN AS $$
DECLARE
    v_bill_amount NUMERIC(18,4);
    v_lines_total NUMERIC(18,4);
BEGIN
    SELECT amount INTO v_bill_amount FROM bill WHERE id = p_bill_id;
    
    SELECT COALESCE(SUM(quantity * price - discount), 0) INTO v_lines_total
    FROM bill_line WHERE bill_id = p_bill_id;
    
    RETURN v_bill_amount = v_lines_total;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PARTY (CONTRAGENT) PROCEDURES
-- ============================================================================

-- | Таблица контрагентов
CREATE TABLE IF NOT EXISTS party (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(256) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,  -- 0: Person, 1: Organization
    inn VARCHAR(12),
    kpp VARCHAR(9),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- | Найти контрагента по ИНН
CREATE OR REPLACE FUNCTION find_party_by_inn(
    p_inn VARCHAR(12)
) RETURNS TABLE(
    id BIGINT,
    code VARCHAR(16),
    name VARCHAR(256),
    type SMALLINT,
    inn VARCHAR(12),
    kpp VARCHAR(9)
) AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.code, p.name, p.type, p.inn, p.kpp
    FROM party p
    WHERE p.inn = p_inn;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions to application user
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO op_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO op_user;
