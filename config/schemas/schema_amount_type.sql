-- =============================================================================
-- ТИПЫ СУММ ДОКУМЕНТОВ
-- Соответствуют Core.Finance.AmountType
-- Аналог: PPOBJ_AMOUNTTYPE
-- =============================================================================

CREATE TABLE IF NOT EXISTS amount_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO amount_type (id, name, code) VALUES
(1, 'Сумма без НДС', 'NET'),
(2, 'НДС', 'VAT'),
(3, 'Сумма с НДС', 'GROSS'),
(4, 'Сумма в валюте', 'CURRENCY'),
(5, 'Сумма документа', 'DOC'),
(6, 'Скидка', 'DISCOUNT')
ON CONFLICT (id) DO NOTHING;