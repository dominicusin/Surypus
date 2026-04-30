-- =============================================================================
-- ТИПЫ БАНКОВСКИХ СЧЕТОВ
-- Соответствуют Core.Finance.BnkAccType
-- Аналог: PPOBJ_BNKACCTYPE
-- =============================================================================

CREATE TABLE IF NOT EXISTS bnk_acc_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO bnk_acc_type (id, name, symb) VALUES
(1, 'Расчётный счёт', 'CURRENT'),
(2, 'Корреспондентский счёт', 'CORRESPONDENT'),
(3, 'Депозитный счёт', 'DEPOSIT'),
(4, 'Кредитный счёт', 'CREDIT'),
(5, 'Специальный счёт', 'SPECIAL')
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_bnk_acc_type_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_bnk_acc_type_update
    BEFORE UPDATE ON bnk_acc_type
    FOR EACH ROW
    EXECUTE FUNCTION update_bnk_acc_type_timestamp();
