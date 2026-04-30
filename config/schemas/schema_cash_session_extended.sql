-- ============================================================================
-- SCHEMA: POS Terminals and Cash Sessions (Кассовые операции)
-- Соответствует C++ классам CSessCore в csess.cpp и CPosProcessor в chkpan.cpp
-- ============================================================================

-- Таблица кассовых узлов
CREATE TABLE IF NOT EXISTS cash_node (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    location_id     INTEGER,
    flags           INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT cn_name_not_empty CHECK (LENGTH(TRIM(name)) > 0)
);

-- Таблица кассовых сессий
CREATE TABLE IF NOT EXISTS cash_session (
    id              SERIAL PRIMARY KEY,
    cash_node_id    INTEGER NOT NULL REFERENCES cash_node(id),
    start_time      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time        TIMESTAMP,
    session_number  INTEGER NOT NULL,
    status          VARCHAR(20) DEFAULT 'OPEN',  -- OPEN, CLOSED, CASHED, ZREPORT
    cash_in_start   DECIMAL(18,2) DEFAULT 0,    -- Наличные в начале
    cash_in_end     DECIMAL(18,2),              -- Наличные в конце
    flags           INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT cs_session_number_positive CHECK (session_number > 0),
    CONSTRAINT cs_status_check CHECK (status IN ('OPEN', 'CLOSED', 'CASHED', 'ZREPORT'))
);

-- Таблица чеков
CREATE TABLE IF NOT EXISTS cash_check (
    id              SERIAL PRIMARY KEY,
    session_id      INTEGER NOT NULL REFERENCES cash_session(id) ON DELETE CASCADE,
    number          INTEGER NOT NULL,
    datetime        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total           DECIMAL(18,6) NOT NULL,
    discount        DECIMAL(18,6) DEFAULT 0,
    tax             DECIMAL(18,6) DEFAULT 0,
    flags           INTEGER DEFAULT 0,
    status          VARCHAR(20) DEFAULT 'PROGRESS',  -- PROGRESS, COMPLETED, RETURNED, CANCELLED
    uuid            UUID DEFAULT gen_random_uuid(),
    
    CONSTRAINT cc_number_positive CHECK (number > 0),
    CONSTRAINT cc_total_nonnegative CHECK (total >= 0),
    CONSTRAINT cc_discount_nonnegative CHECK (discount >= 0),
    CONSTRAINT cc_status_check CHECK (status IN ('PROGRESS', 'COMPLETED', 'RETURNED', 'CANCELLED')),
    CONSTRAINT cc_number_unique UNIQUE (session_id, number)
);

-- Таблица строк чеков
CREATE TABLE IF NOT EXISTS cash_check_line (
    id              SERIAL PRIMARY KEY,
    check_id        INTEGER NOT NULL REFERENCES cash_check(id) ON DELETE CASCADE,
    line_no         INTEGER NOT NULL,
    goods_id        INTEGER NOT NULL,
    goods_name      VARCHAR(255),
    quantity        DECIMAL(18,6) NOT NULL,
    price           DECIMAL(18,6) NOT NULL,
    discount        DECIMAL(18,6) DEFAULT 0,
    tax_rate        DECIMAL(5,2) DEFAULT 0,
    flags           INTEGER DEFAULT 0,
    
    CONSTRAINT ccl_check_fk FOREIGN KEY (check_id) REFERENCES cash_check(id),
    CONSTRAINT ccl_quantity_positive CHECK (quantity > 0),
    CONSTRAINT ccl_price_nonnegative CHECK (price >= 0),
    CONSTRAINT ccl_tax_rate_check CHECK (tax_rate >= 0 AND tax_rate <= 100),
    CONSTRAINT ccl_line_unique UNIQUE (check_id, line_no)
);

-- Таблица оплат чеков
CREATE TABLE IF NOT EXISTS cash_check_payment (
    id              SERIAL PRIMARY KEY,
    check_id        INTEGER NOT NULL REFERENCES cash_check(id) ON DELETE CASCADE,
    payment_type    VARCHAR(20) NOT NULL,  -- CASH, CARD, CARD_ONLINE, GIFT_CARD, BONUS, CREDIT
    amount          DECIMAL(18,6) NOT NULL,
    flags           INTEGER DEFAULT 0,
    
    CONSTRAINT ccp_check_fk FOREIGN KEY (check_id) REFERENCES cash_check(id),
    CONSTRAINT ccp_amount_positive CHECK (amount > 0),
    CONSTRAINT ccp_type_check CHECK (payment_type IN ('CASH', 'CARD', 'CARD_ONLINE', 'GIFT_CARD', 'BONUS', 'CREDIT', 'CASHBACK'))
);

-- Таблица итогов сессии
CREATE TABLE IF NOT EXISTS cash_session_total (
    id              SERIAL PRIMARY KEY,
    session_id      INTEGER NOT NULL REFERENCES cash_session(id) ON DELETE CASCADE,
    check_count     INTEGER DEFAULT 0,
    total_sales     DECIMAL(18,6) DEFAULT 0,
    total_returns   DECIMAL(18,6) DEFAULT 0,
    total_discount  DECIMAL(18,6) DEFAULT 0,
    total_tax       DECIMAL(18,6) DEFAULT 0,
    cash_in         DECIMAL(18,6) DEFAULT 0,
    cash_out        DECIMAL(18,6) DEFAULT 0,
    card_total      DECIMAL(18,6) DEFAULT 0,
    gift_card_total DECIMAL(18,6) DEFAULT 0,
    bonus_total     DECIMAL(18,6) DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT cst_check_count CHECK (check_count >= 0),
    CONSTRAINT cst_totals_nonnegative CHECK (
        total_sales >= 0 AND total_returns >= 0 AND total_discount >= 0 AND
        total_tax >= 0 AND cash_in >= 0 AND cash_out >= 0
    )
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_cc_session ON cash_check(session_id);
CREATE INDEX IF NOT EXISTS idx_cc_datetime ON cash_check(datetime DESC);
CREATE INDEX IF NOT EXISTS idx_cc_number ON cash_check(session_id, number);
CREATE INDEX IF NOT EXISTS idx_ccl_check ON cash_check_line(check_id);
CREATE INDEX IF NOT EXISTS idx_ccl_goods ON cash_check_line(goods_id);
CREATE INDEX IF NOT EXISTS idx_ccp_check ON cash_check_payment(check_id);
CREATE INDEX IF NOT EXISTS idx_cs_node_time ON cash_session(cash_node_id, start_time DESC);

-- Функция: Рассчитать сумму чека
CREATE OR REPLACE FUNCTION calculate_check_total(p_check_id INTEGER)
RETURNS DECIMAL(18,6) AS $$
BEGIN
    RETURN COALESCE((
        SELECT SUM(quantity * price - discount)
        FROM cash_check_line
        WHERE check_id = p_check_id
    ), 0);
END;
$$ LANGUAGE plpgsql;

-- Функция: Рассчитать налог чека
CREATE OR REPLACE FUNCTION calculate_check_tax(p_check_id INTEGER)
RETURNS DECIMAL(18,6) AS $$
DECLARE
    v_subtotal DECIMAL(18,6);
    v_tax_rate DECIMAL(5,2);
BEGIN
    v_subtotal := calculate_check_total(p_check_id);
    
    SELECT COALESCE(MAX(tax_rate), 0)
    INTO v_tax_rate
    FROM cash_check_line
    WHERE check_id = p_check_id;
    
    RETURN v_subtotal * (v_tax_rate / 100);
END;
$$ LANGUAGE plpgsql;

-- Функция: Рассчитать сдачу
CREATE OR REPLACE FUNCTION calculate_change(p_check_id INTEGER)
RETURNS DECIMAL(18,6) AS $$
DECLARE
    v_total DECIMAL(18,6);
    v_paid DECIMAL(18,6);
    v_change DECIMAL(18,6);
BEGIN
    v_total := calculate_check_total(p_check_id);
    
    SELECT COALESCE(SUM(amount), 0)
    INTO v_paid
    FROM cash_check_payment
    WHERE check_id = p_check_id
      AND payment_type != 'CASHBACK';
    
    v_change := v_paid - v_total;
    RETURN GREATEST(v_change, 0);
END;
$$ LANGUAGE plpgsql;

-- Функция: Рассчитать итоги сессии
CREATE OR REPLACE FUNCTION calculate_session_total(p_session_id INTEGER)
RETURNS TABLE (
    check_count INTEGER,
    total_sales DECIMAL(18,6),
    total_returns DECIMAL(18,6),
    total_discount DECIMAL(18,6),
    total_tax DECIMAL(18,6),
    cash_total DECIMAL(18,6),
    card_total DECIMAL(18,6)
) AS $$
BEGIN
    RETURN QUERY
    WITH sales_checks AS (
        SELECT id, total, discount, tax
        FROM cash_check
        WHERE session_id = p_session_id AND status = 'COMPLETED'
    ),
    return_checks AS (
        SELECT id, total
        FROM cash_check
        WHERE session_id = p_session_id AND status = 'RETURNED'
    ),
    payments AS (
        SELECT ccp.check_id, ccp.payment_type, ccp.amount
        FROM cash_check_payment ccp
        JOIN cash_check cc ON cc.id = ccp.check_id
        WHERE cc.session_id = p_session_id
    )
    SELECT 
        (SELECT COUNT(*) FROM sales_checks)::INTEGER AS check_count,
        (SELECT COALESCE(SUM(total), 0) FROM sales_checks)::DECIMAL(18,6) AS total_sales,
        (SELECT COALESCE(SUM(total), 0) FROM return_checks)::DECIMAL(18,6) AS total_returns,
        (SELECT COALESCE(SUM(discount), 0) FROM sales_checks)::DECIMAL(18,6) AS total_discount,
        (SELECT COALESCE(SUM(tax), 0) FROM sales_checks)::DECIMAL(18,6) AS total_tax,
        (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payment_type = 'CASH')::DECIMAL(18,6) AS cash_total,
        (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE payment_type = 'CARD')::DECIMAL(18,6) AS card_total;
END;
$$ LANGUAGE plpgsql;

-- Процедура: Открыть кассовую сессию
CREATE OR REPLACE PROCEDURE open_cash_session(
    p_cash_node_id INTEGER,
    p_cash_in_start DECIMAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_number INTEGER;
    v_session_id INTEGER;
BEGIN
    -- Получить номер сессии
    SELECT COALESCE(MAX(session_number), 0) + 1
    INTO v_session_number
    FROM cash_session
    WHERE cash_node_id = p_cash_node_id;
    
    -- Создать сессию
    INSERT INTO cash_session (cash_node_id, session_number, cash_in_start, status)
    VALUES (p_cash_node_id, v_session_number, p_cash_in_start, 'OPEN')
    RETURNING id INTO v_session_id;
    
    -- Создать итоги
    INSERT INTO cash_session_total (session_id)
    VALUES (v_session_id);
    
    RAISE NOTICE 'Session % opened with number %', v_session_id, v_session_number;
END;
$$;

-- Процедура: Закрыть кассовую сессию
CREATE OR REPLACE PROCEDURE close_cash_session(
    p_session_id INTEGER,
    p_cash_in_end DECIMAL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Обновить сессию
    UPDATE cash_session
    SET end_time = CURRENT_TIMESTAMP,
        status = 'CLOSED',
        cash_in_end = p_cash_in_end
    WHERE id = p_session_id;
    
    -- Обновить итоги
    UPDATE cash_session_total cst
    SET check_count = t.check_count,
        total_sales = t.total_sales,
        total_returns = t.total_returns,
        total_discount = t.total_discount,
        total_tax = t.total_tax,
        cash_total = t.cash_total,
        card_total = t.card_total
    FROM calculate_session_total(p_session_id) t
    WHERE cst.session_id = p_session_id;
    
    RAISE NOTICE 'Session % closed', p_session_id;
END;
$$;

-- Процедура: Создать чек
CREATE OR REPLACE PROCEDURE create_check(
    p_session_id INTEGER,
    p_goods_id INTEGER,
    p_quantity DECIMAL,
    p_price DECIMAL,
    p_check_id OUT INTEGER,
    p_line_no OUT INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_check_number INTEGER;
    v_check_id INTEGER;
    v_line_no INTEGER;
BEGIN
    -- Получить номер чека
    SELECT COALESCE(MAX(number), 0) + 1
    INTO v_check_number
    FROM cash_check
    WHERE session_id = p_session_id;
    
    -- Создать чек
    INSERT INTO cash_check (session_id, number, status)
    VALUES (p_session_id, v_check_number, 'PROGRESS')
    RETURNING id INTO v_check_id;
    
    -- Получить номер строки
    SELECT COALESCE(MAX(line_no), 0) + 1
    INTO v_line_no
    FROM cash_check_line
    WHERE check_id = v_check_id;
    
    -- Добавить строку
    INSERT INTO cash_check_line (check_id, line_no, goods_id, quantity, price)
    VALUES (v_check_id, v_line_no, p_goods_id, p_quantity, p_price);
    
    p_check_id := v_check_id;
    p_line_no := v_line_no;
END;
$$;

-- Процедура: Завершить чек
CREATE OR REPLACE PROCEDURE complete_check(p_check_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total DECIMAL(18,6);
    v_tax DECIMAL(18,6);
BEGIN
    v_total := calculate_check_total(p_check_id);
    v_tax := calculate_check_tax(p_check_id);
    
    UPDATE cash_check
    SET total = v_total,
        tax = v_tax,
        status = 'COMPLETED'
    WHERE id = p_check_id;
    
    RAISE NOTICE 'Check % completed with total %', p_check_id, v_total;
END;
$$;

-- Представление: Активная сессия
CREATE OR REPLACE VIEW v_active_cash_session AS
SELECT 
    cs.id,
    cs.cash_node_id,
    cn.name AS cash_node_name,
    cs.start_time,
    cs.session_number,
    cs.status,
    cs.cash_in_start,
    cst.check_count,
    cst.total_sales,
    cst.total_tax,
    cst.cash_total,
    cst.card_total
FROM cash_session cs
JOIN cash_node cn ON cn.id = cs.cash_node_id
LEFT JOIN cash_session_total cst ON cst.session_id = cs.id
WHERE cs.status = 'OPEN';

-- Представление: Последние чеки
CREATE OR REPLACE VIEW v_recent_checks AS
SELECT 
    cc.id,
    cc.session_id,
    cc.number,
    cc.datetime,
    cc.total,
    cc.discount,
    cc.tax,
    cc.status,
    cc.uuid
FROM cash_check cc
ORDER BY cc.datetime DESC
LIMIT 100;

-- Представление: Продажи по товарам
CREATE OR REPLACE VIEW v_goods_sales AS
SELECT 
    ccl.goods_id,
    ccl.goods_name,
    SUM(ccl.quantity) AS total_quantity,
    SUM(ccl.quantity * ccl.price) AS total_amount,
    COUNT(DISTINCT cc.id) AS check_count
FROM cash_check_line ccl
JOIN cash_check cc ON cc.id = ccl.check_id
WHERE cc.status = 'COMPLETED'
GROUP BY ccl.goods_id, ccl.goods_name
ORDER BY total_amount DESC;

-- Представление: Оплаты по типам
CREATE TABLE IF NOT EXISTS v_payment_summary AS
SELECT 
    cc.session_id,
    cs.session_number,
    ccp.payment_type,
    SUM(ccp.amount) AS total_amount,
    COUNT(*) AS payment_count
FROM cash_check_payment ccp
JOIN cash_check cc ON cc.id = ccp.check_id
JOIN cash_session cs ON cs.id = cc.session_id
WHERE cc.status = 'COMPLETED'
GROUP BY cc.session_id, cs.session_number, ccp.payment_type;
