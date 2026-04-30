-- =================================================================
-- Personal Card System - Персональные карты
-- =================================================================
-- Analog:  pplib/objscard.cpp (PPObjSCard)

-- Card Series (серии карт)
CREATE TABLE IF NOT EXISTS card_series (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(20) NOT NULL UNIQUE,
    type SMALLINT NOT NULL DEFAULT 0,   -- SCARDTYP_XXX (0=Discount, 1=Bonus, 2=Credit, 3=Gift)
    flags INTEGER DEFAULT 0,             -- SCF_XXX
    discount DOUBLE PRECISION DEFAULT 0, -- Базовая скидка (%)
    min_summ NUMERIC(18,4),              -- Минимальная сумма для начисления
    max_bonus NUMERIC(18,4),             -- Максимальный бонус
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_card_series_code ON card_series(code);
CREATE INDEX IF NOT EXISTS idx_card_series_type ON card_series(type);

-- Personal Card (персональные карты)
CREATE TABLE IF NOT EXISTS personal_card (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,    -- Номер карты
    series_id BIGINT NOT NULL REFERENCES card_series(id),
    owner_id BIGINT,                     -- Владелец (Person)
    person_id BIGINT,                    -- Дополнительная персоналия
    discount DOUBLE PRECISION DEFAULT 0, -- Индивидуальная скидка
    bonus NUMERIC(18,4) DEFAULT 0,       -- Текущий бонус
    flags INTEGER DEFAULT 0,             -- SCF_XXX
    issued DATE NOT NULL DEFAULT CURRENT_DATE,
    expires DATE,                        -- Срок действия
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_personal_card_code ON personal_card(code);
CREATE INDEX IF NOT EXISTS idx_personal_card_series ON personal_card(series_id);
CREATE INDEX IF NOT EXISTS idx_personal_card_owner ON personal_card(owner_id);

-- Card Operations (операции по картам)
CREATE TABLE IF NOT EXISTS card_op (
    id BIGSERIAL PRIMARY KEY,
    card_id BIGINT NOT NULL REFERENCES personal_card(id) ON DELETE CASCADE,
    dt TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    type SMALLINT NOT NULL,              -- 0=AddBonus, 1=SpendBonus, 2=AddDiscount, 3=SetDiscount
    amount NUMERIC(18,4) NOT NULL,       -- Сумма бонуса или размер скидки
    bill_id BIGINT,                      -- Связанный документ
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_card_op_card ON card_op(card_id);
CREATE INDEX IF NOT EXISTS idx_card_op_dt ON card_op(dt);
CREATE INDEX IF NOT EXISTS idx_card_op_bill ON card_op(bill_id) WHERE bill_id IS NOT NULL;

-- =================================================================
-- Default Card Series (базовые серии)
-- =================================================================

INSERT INTO card_series (name, code, type, flags, discount) VALUES
    ('Дисконтная 5%', 'DISC5', 0, 0, 5.0),
    ('Дисконтная 10%', 'DISC10', 0, 0, 10.0),
    ('Дисконтная 15%', 'DISC15', 0, 0, 15.0),
    ('Бонусная', 'BONUS', 1, 1, 0.0),   -- Auto bonus
    ('Серебряная', 'SILVER', 4, 1, 7.0),
    ('Золотая', 'GOLD', 4, 1, 10.0),
    ('Платиновая', 'PLATINUM', 4, 1, 15.0)
ON CONFLICT DO NOTHING;

-- =================================================================
-- Functions
-- =================================================================

-- Get card by code
CREATE OR REPLACE FUNCTION get_card_by_code(TEXT)
RETURNS TABLE (id BIGINT, code TEXT, series_id BIGINT, series_name TEXT,
               owner_id BIGINT, discount DOUBLE PRECISION, bonus NUMERIC(18,4),
               flags INTEGER, issued DATE, expires DATE) AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.code, c.series_id, s.name, c.owner_id,
           c.discount, c.bonus, c.flags, c.issued, c.expires
    FROM personal_card c
    JOIN card_series s ON s.id = c.series_id
    WHERE c.code = $1
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

-- Get card operations
CREATE OR REPLACE FUNCTION get_card_operations(BIGINT, DATE, DATE)
RETURNS TABLE (id BIGINT, dt TIMESTAMPTZ, type SMALLINT, amount NUMERIC(18,4),
               bill_id BIGINT, flags INTEGER) AS $$
BEGIN
    RETURN QUERY
    SELECT co.id, co.dt, co.type, co.amount, co.bill_id, co.flags
    FROM card_op co
    WHERE co.card_id = $1
      AND ($2 IS NULL OR co.dt::DATE >= $2)
      AND ($3 IS NULL OR co.dt::DATE <= $3)
    ORDER BY co.dt DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Add bonus to card
CREATE OR REPLACE FUNCTION add_card_bonus(BIGINT, NUMERIC(18,4), BIGINT)
RETURNS VOID AS $$
DECLARE
    p_card_id ALIAS FOR $1;
    p_amount ALIAS FOR $2;
    p_bill_id ALIAS FOR $3;
BEGIN
    UPDATE personal_card
    SET bonus = bonus + p_amount,
        updated_at = NOW()
    WHERE id = p_card_id;
    
    INSERT INTO card_op (card_id, type, amount, bill_id)
    VALUES (p_card_id, 0, p_amount, p_bill_id);
END;
$$ LANGUAGE plpgsql;

-- Spend bonus from card
CREATE OR REPLACE FUNCTION spend_card_bonus(BIGINT, NUMERIC(18,4), BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    p_card_id ALIAS FOR $1;
    p_amount ALIAS FOR $2;
    p_bill_id ALIAS FOR $3;
    v_bonus NUMERIC(18,4);
    v_flags INTEGER;
BEGIN
    SELECT bonus, flags INTO v_bonus, v_flags
    FROM personal_card
    WHERE id = p_card_id;
    
    -- Check if card is active and not blocked
    IF (v_flags & 1) = 0 OR (v_flags & 4) != 0 THEN
        RETURN FALSE;
    END IF;
    
    -- Check if negative bonus is allowed
    IF v_bonus < p_amount AND (v_flags & 2) = 0 THEN
        RETURN FALSE;
    END IF;
    
    UPDATE personal_card
    SET bonus = bonus - p_amount,
        updated_at = NOW()
    WHERE id = p_card_id;
    
    INSERT INTO card_op (card_id, type, amount, bill_id)
    VALUES (p_card_id, 1, p_amount, p_bill_id);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =================================================================
-- Triggers
-- =================================================================

CREATE OR REPLACE FUNCTION update_card_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_card_series_update
    BEFORE UPDATE ON card_series
    FOR EACH ROW EXECUTE FUNCTION update_card_timestamp();

CREATE TRIGGER tr_personal_card_update
    BEFORE UPDATE ON personal_card
    FOR EACH ROW EXECUTE FUNCTION update_card_timestamp();

-- =================================================================
-- Comments
-- =================================================================

COMMENT ON TABLE card_series IS 'Серии персональных карт (аналог SCardSeriesTbl)';
COMMENT ON TABLE personal_card IS 'Персональные карты (аналог SCardTbl)';
COMMENT ON TABLE card_op IS 'Операции по картам (аналог SCardOpTbl)';
COMMENT ON COLUMN card_series.type IS 'Тип: 0=Дисконт, 1=Бонус, 2=Кредит, 3=Подарочная, 4=Лояльность';
COMMENT ON COLUMN personal_card.flags IS 'Флаги: 1=Активна, 2=Владелец подтверждён, 4=Заблокирована, 8=Персональная';
