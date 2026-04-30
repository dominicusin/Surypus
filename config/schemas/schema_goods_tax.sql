-- =============================================================================
-- НАЛОГОВЫЕ ГРУППЫ ТОВАРОВ
-- Соответствуют Core.Tax.GoodsTax
-- Аналог: PPOBJ_GOODSTAX
-- =============================================================================

CREATE TABLE IF NOT EXISTS goods_tax (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (tax_rate >= 0 AND tax_rate <= 100),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA: Налоговые группы РФ
INSERT INTO goods_tax (id, name, tax_rate) VALUES
(1, 'Без НДС', 0),
(2, 'НДС 10%', 10),
(3, 'НДС 18%', 18),
(4, 'НДС 20%', 20),
(5, 'НДС 10/110', 9.09),
(6, 'НДС 18/118', 15.25),
(7, 'НДС 20/120', 16.67)
ON CONFLICT (id) DO NOTHING;