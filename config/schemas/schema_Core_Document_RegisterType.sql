-- =============================================================================
-- ТИПЫ РЕГИСТРАЦИОННЫХ ДОКУМЕНТОВ
-- Соответствуют Core.Document.RegisterType
-- Аналог: PPOBJ_REGISTERTYPE
-- =============================================================================

CREATE TABLE IF NOT EXISTS document_register_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO document_register_type (id, name, code) VALUES
(1, 'Свидетельство о регистрации', 'REG_CERT'),
(2, 'Паспорт', 'PASSPORT'),
(3, 'ИНН', 'INN'),
(4, 'ОГРН', 'OGRN'),
(5, 'ЕГРЮЛ', 'EGRUL'),
(6, 'ЕГРИП', 'EGRIP'),
(7, 'Доверенность', 'PROXY'),
(8, 'Лицензия', 'LICENSE')
ON CONFLICT (id) DO NOTHING;
