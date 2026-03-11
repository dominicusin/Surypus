-- =============================================================================
-- СИСТЕМЫ НАЛОГООБЛОЖЕНИЯ
-- Соответствуют Core.Finance.TaxSystem
-- Аналог: PPOBJ_TAXSYSTEMKIND
-- =============================================================================

CREATE TABLE IF NOT EXISTS tax_system (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA: Системы налогообложения РФ
INSERT INTO tax_system (id, name, code) VALUES
(1, 'Общая система налогообложения (ОСНО)', 'OSNO'),
(2, 'Упрощённая система налогообложения (УСН)', 'USN'),
(3, 'Единый налог на вменённый доход (ЕНВД)', 'ENVD'),
(4, 'Единый сельскохозяйственный налог (ЕСХН)', 'ESXN'),
(5, 'Патентная система налогообложения (ПСН)', 'PSN'),
(6, 'Налог на профессиональный доход (НПД)', 'NPD')
ON CONFLICT (id) DO NOTHING;