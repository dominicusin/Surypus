-- ============================================================
-- Loyalty Tables - Программы лояльности
-- Соответствует C++ scard.cpp
-- ============================================================

-- Discount card types (типы дисконтных карт)
CREATE TABLE IF NOT EXISTS discount_card_type (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(64) NOT NULL,
    discount NUMERIC(5,2) DEFAULT 0,    -- Базовая скидка %
    min_sum NUMERIC(18,2) DEFAULT 0,    -- Мин. сумма для начисления
    bonus_percent NUMERIC(5,2) DEFAULT 0,  -- % начисления баллов
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Discount cards (дисконтные карты)
CREATE TABLE IF NOT EXISTS discount_card (
    id BIGSERIAL PRIMARY KEY,
    number VARCHAR(32) NOT NULL,
    owner_id BIGINT NOT NULL REFERENCES person(id),
    card_type_id BIGINT NOT NULL REFERENCES discount_card_type(id),
    discount NUMERIC(5,2) DEFAULT 0,    -- Индивидуальная скидка
    status SMALLINT DEFAULT 0,  -- 0=ACTIVE, 1=BLOCKED, 2=EXPIRED, 3=CLOSED
    issued_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at DATE,
    flags INTEGER DEFAULT 0,
    UNIQUE(number)
);

-- Bonus points (бонусные баллы)
CREATE TABLE IF NOT EXISTS bonus_points (
    id BIGSERIAL PRIMARY KEY,
    card_id BIGINT NOT NULL REFERENCES discount_card(id),
    amount NUMERIC(18,2) NOT NULL,
    earned_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at DATE,
    status SMALLINT DEFAULT 0,  -- 0=ACTIVE, 1=USED, 2=EXPIRED
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Bonus transactions (операции с баллами)
CREATE TABLE IF NOT EXISTS bonus_transaction (
    id BIGSERIAL PRIMARY KEY,
    card_id BIGINT NOT NULL REFERENCES discount_card(id),
    sale_id BIGINT REFERENCES sale(id),
    btype SMALLINT NOT NULL,  -- 0=ACCRUAL, 1=USAGE, 2=EXPIRY, 3=ADJUSTMENT
    amount NUMERIC(18,2) NOT NULL,
    description TEXT,
    dt TIMESTAMPTZ DEFAULT NOW()
);

-- Gift cards (подарочные карты)
CREATE TABLE IF NOT EXISTS gift_card (
    id BIGSERIAL PRIMARY KEY,
    number VARCHAR(32) NOT NULL,
    nominal NUMERIC(18,2) NOT NULL,
    balance NUMERIC(18,2) NOT NULL,
    status SMALLINT DEFAULT 0,  -- 0=ACTIVE, 1=USED, 2=EXPIRED
    issued_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at DATE,
    UNIQUE(number)
);

-- Gift card transactions (использование подарочных карт)
CREATE TABLE IF NOT EXISTS gift_card_transaction (
    id BIGSERIAL PRIMARY KEY,
    gift_card_id BIGINT NOT NULL REFERENCES gift_card(id),
    sale_id BIGINT REFERENCES sale(id),
    amount NUMERIC(18,2) NOT NULL,
    dt TIMESTAMPTZ DEFAULT NOW()
);

-- Loyalty programs (программы лояльности)
CREATE TABLE IF NOT EXISTS loyalty_program (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    dt_from DATE NOT NULL,
    dt_to DATE,
    bonus_percent NUMERIC(5,2) DEFAULT 0,
    status SMALLINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для лояльности
CREATE INDEX IF NOT EXISTS idx_discount_card_number ON discount_card(number);
CREATE INDEX IF NOT EXISTS idx_discount_card_owner ON discount_card(owner_id);
CREATE INDEX IF NOT EXISTS idx_discount_card_type ON discount_card(card_type_id);
CREATE INDEX IF NOT EXISTS idx_discount_card_status ON discount_card(status);

CREATE INDEX IF NOT EXISTS idx_bonus_points_card ON bonus_points(card_id);
CREATE INDEX IF NOT EXISTS idx_bonus_points_status ON bonus_points(status);

CREATE INDEX IF NOT EXISTS idx_bonus_transaction_card ON bonus_transaction(card_id);
CREATE INDEX IF NOT EXISTS idx_bonus_transaction_sale ON bonus_transaction(sale_id);

CREATE INDEX IF NOT EXISTS idx_gift_card_number ON gift_card(number);
CREATE INDEX IF NOT EXISTS idx_gift_card_status ON gift_card(status);

-- ============================================================
-- Функции для лояльности
-- ============================================================

-- Расчёт начисления баллов
CREATE OR REPLACE FUNCTION calc_bonus_accrual(p_amount NUMERIC(18,2), p_bonus_percent NUMERIC(5,2))
RETURNS NUMERIC(18,2) AS $$
BEGIN
    RETURN p_amount * p_bonus_percent / 100;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Расчёт скидки
CREATE OR REPLACE FUNCTION calc_card_discount(p_amount NUMERIC(18,2), p_discount NUMERIC(5,2))
RETURNS NUMERIC(18,2) AS $$
BEGIN
    RETURN p_amount * p_discount / 100;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Начислить баллы
CREATE OR REPLACE FUNCTION accrue_bonus_points(
    p_card_id BIGINT,
    p_amount NUMERIC(18,2),
    p_expires_at DATE
) RETURNS BIGINT AS $$
DECLARE
    v_bp_id BIGINT;
BEGIN
    INSERT INTO bonus_points (card_id, amount, expires_at, status)
    VALUES (p_card_id, p_amount, p_expires_at, 0)
    RETURNING id INTO v_bp_id;
    
    -- Записать транзакцию
    INSERT INTO bonus_transaction (card_id, btype, amount, description)
    VALUES (p_card_id, 0, p_amount, 'Начисление баллов');
    
    RETURN v_bp_id;
END;
$$ LANGUAGE plpgsql;

-- Списать баллы
CREATE OR REPLACE FUNCTION use_bonus_points(
    p_card_id BIGINT,
    p_amount NUMERIC(18,2),
    p_sale_id BIGINT
) RETURNS BOOLEAN AS $$
DECLARE
    v_available NUMERIC(18,2);
BEGIN
    -- Проверить доступные баллы
    SELECT COALESCE(SUM(amount), 0) INTO v_available
    FROM bonus_points
    WHERE card_id = p_card_id AND status = 0
        AND (expires_at IS NULL OR expires_at >= CURRENT_DATE);
    
    IF v_available < p_amount THEN
        RETURN FALSE;
    END IF;
    
    -- Списать баллы (сначала старые)
    UPDATE bonus_points
    SET status = 1
    WHERE id IN (
        SELECT id FROM bonus_points
        WHERE card_id = p_card_id AND status = 0
            AND (expires_at IS NULL OR expires_at >= CURRENT_DATE)
        ORDER BY earned_at
        LIMIT 1
    );
    
    -- Записать транзакцию
    INSERT INTO bonus_transaction (card_id, sale_id, btype, amount, description)
    VALUES (p_card_id, p_sale_id, 1, p_amount, 'Списание баллов');
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Использовать подарочную карту
CREATE OR REPLACE FUNCTION use_gift_card(
    p_gift_card_id BIGINT,
    p_amount NUMERIC(18,2),
    p_sale_id BIGINT
) RETURNS BOOLEAN AS $$
DECLARE
    v_balance NUMERIC(18,2);
BEGIN
    SELECT balance INTO v_balance FROM gift_card WHERE id = p_gift_card_id;
    
    IF v_balance < p_amount THEN
        RETURN FALSE;
    END IF;
    
    UPDATE gift_card 
    SET balance = balance - p_amount,
        status = CASE WHEN balance - p_amount <= 0 THEN 1 ELSE status END
    WHERE id = p_gift_card_id;
    
    INSERT INTO gift_card_transaction (gift_card_id, sale_id, amount)
    VALUES (p_gift_card_id, p_sale_id, p_amount);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- Активные дисконтные карты
CREATE OR REPLACE VIEW v_active_discount_cards AS
SELECT 
    dc.id, dc.number, dc.discount,
    p.id AS owner_id, p.name AS owner_name,
    dct.name AS card_type_name,
    dc.issued_at, dc.expires_at,
    COALESCE((SELECT SUM(amount) FROM bonus_points bp 
              WHERE bp.card_id = dc.id AND bp.status = 0), 0) AS available_bonus
FROM discount_card dc
JOIN person p ON p.id = dc.owner_id
JOIN discount_card_type dct ON dct.id = dc.card_type_id
WHERE dc.status = 0  -- ACTIVE
ORDER BY dc.number;

-- Баллы для списания
CREATE TABLE IF NOT EXISTS v_expiring_bonus_points AS
SELECT 
    bp.id, bp.card_id, bp.amount, bp.expires_at,
    p.name AS owner_name, dc.number AS card_number
FROM bonus_points bp
JOIN discount_card dc ON dc.id = bp.card_id
JOIN person p ON p.id = dc.owner_id
WHERE bp.status = 0  -- ACTIVE
    AND bp.expires_at IS NOT NULL
    AND bp.expires_at <= CURRENT_DATE + INTERVAL '30 days'
ORDER BY bp.expires_at;

-- Пополнение подарочных карт
CREATE OR REPLACE VIEW v_gift_cards_active AS
SELECT 
    gc.id, gc.number, gc.nominal, gc.balance,
    gc.issued_at, gc.expires_at,
    gc.nominal - gc.balance AS used_amount
FROM gift_card gc
WHERE gc.status = 0  -- ACTIVE
ORDER BY gc.number;

-- Статистика лояльности
CREATE OR REPLACE VIEW v_loyalty_stats AS
SELECT 
    dct.id AS card_type_id, dct.name AS card_type_name,
    COUNT(dc.id) AS card_count,
    COUNT(CASE WHEN dc.status = 0 THEN 1 END) AS active_count,
    SUM(COALESCE((SELECT SUM(bp.amount) FROM bonus_points bp 
                  WHERE bp.card_id = dc.id AND bp.status = 0), 0)) AS total_bonus
FROM discount_card_type dct
LEFT JOIN discount_card dc ON dc.card_type_id = dct.id
GROUP BY dct.id, dct.name
ORDER BY dct.name;

-- Транзакции баллов
CREATE OR REPLACE VIEW v_bonus_transactions AS
SELECT 
    bt.id, bt.dt, bt.card_id, dc.number AS card_number,
    bt.btype, 
    CASE bt.btype 
        WHEN 0 THEN 'Начисление'
        WHEN 1 THEN 'Списание'
        WHEN 2 THEN 'Сгорели'
        WHEN 3 THEN 'Корректировка'
    END AS btype_name,
    bt.amount, bt.description
FROM bonus_transaction bt
JOIN discount_card dc ON dc.id = bt.card_id
ORDER BY bt.dt DESC;