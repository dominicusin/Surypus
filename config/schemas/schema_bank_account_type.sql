-- =============================================================================
-- ТИПЫ БАНКОВСКИХ СЧЁТОВ
-- Соответствуют Core.Finance.BankAccountType
-- Аналог: PPOBJ_BNKACCTYPE
-- =============================================================================

CREATE TABLE IF NOT EXISTS bank_account_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO bank_account_type (id, name, code) VALUES
(1, 'Расчётный счёт', 'CHECKING'),
(2, 'Корреспондентский счёт', 'CORRESPONDENT'),
(3, 'Депозитный счёт', 'DEPOSIT'),
(4, 'Карточный счёт', 'CARD'),
(5, 'Сберегательный счёт', 'SAVINGS')
ON CONFLICT (id) DO NOTHING;
