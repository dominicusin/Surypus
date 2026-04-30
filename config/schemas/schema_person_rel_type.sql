-- =============================================================================
-- ТИПЫ ПЕРСОНАЛЬНЫХ ОТНОШЕНИЙ
-- Соответствуют Core.People.PersonRelType
-- Аналог: PPOBJ_PERSONRELTYPE
-- =============================================================================

CREATE TABLE IF NOT EXISTS person_rel_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO person_rel_type (id, name, code) VALUES
(1, 'Поставщик', 'SUPPLIER'),
(2, 'Покупатель', 'CUSTOMER'),
(3, 'Контрагент', 'CONTRAGENT'),
(4, 'Подрядчик', 'CONTRACTOR'),
(5, 'Агент', 'AGENT'),
(6, 'Дистрибьютор', 'DISTRIBUTOR'),
(7, 'Дилер', 'DEALER'),
(8, 'Аффилированное лицо', 'AFFILIATE')
ON CONFLICT (id) DO NOTHING;