-- =============================================================================
-- КАТЕГОРИИ ПЕРСОНАЛИЙ
-- Соответствуют Core.People.PersonCategory
-- Аналог: PPOBJ_PRSNCATEGORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS person_category (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO person_category (id, name, symb) VALUES
(1, 'Физическое лицо', 'INDIVIDUAL'),
(2, 'Юридическое лицо', 'LEGAL'),
(3, 'Индивидуальный предприниматель', 'ENTREPRENEUR'),
(4, 'Нерезидент', 'NONRESIDENT')
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_person_category_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_person_category_update
    BEFORE UPDATE ON person_category
    FOR EACH ROW
    EXECUTE FUNCTION update_person_category_timestamp();
