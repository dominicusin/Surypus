-- =============================================================================
-- ТАБЛИЦЫ АНАЛИТИЧЕСКИХ СТАТЕЙ
-- Соответствуют Core.Finance.AccSheet
-- Аналог: PPOBJ_ACCSHEET
-- =============================================================================

CREATE TABLE IF NOT EXISTS acc_sheet_finance (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO acc_sheet_finance (id, name, code) VALUES
(1, 'Основная', 'MAIN'),
(2, 'Вспомогательная', 'AUX'),
(3, 'Налоги', 'TAX'),
(4, 'Зарплата', 'SALARY')
ON CONFLICT (id) DO NOTHING;
