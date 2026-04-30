-- =============================================================================
-- ВИДЫ ПЕРСОНАЛИЙ
-- Соответствуют Core.People.PersonKind
-- Аналог: PPOBJ_PERSONKIND
-- =============================================================================

CREATE TABLE IF NOT EXISTS person_kind (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO person_kind (id, name, code) VALUES
(1, 'Юридическое лицо', 'LEGAL'),
(2, 'Физическое лицо', 'PERSON'),
(3, 'Индивидуальный предприниматель', 'IE'),
(4, 'Нерезидент', 'NONRESIDENT'),
(5, 'Государственное учреждение', 'GOVERNMENT')
ON CONFLICT (id) DO NOTHING;