-- =============================================================================
-- ВИДЫ КОТИРОВОК
-- Соответствуют Core.Pricing.QuotKind
-- Аналог: PPOBJ_QUOTKIND
-- =============================================================================

CREATE TABLE IF NOT EXISTS quot_kind (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO quot_kind (id, name, code) VALUES
(1, 'Розничная цена', 'RETAIL'),
(2, 'Оптовая цена', 'WHOLESALE'),
(3, 'Закупочная цена', 'PURCHASE'),
(4, 'Специальная цена', 'SPECIAL'),
(5, 'Минимальная цена', 'MINIMUM'),
(6, 'Максимальная цена', 'MAXIMUM')
ON CONFLICT (id) DO NOTHING;