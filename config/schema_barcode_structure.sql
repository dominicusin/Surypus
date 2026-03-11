-- =============================================================================
-- СИСТЕМЫ ВНУТРЕННИХ ШТРИХ-КОДОВ
-- Соответствуют Core.Barcode.BCodeStruc
-- Аналог: PPOBJ_BCODESTRUC
-- =============================================================================

CREATE TABLE IF NOT EXISTS barcode_structure (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    format VARCHAR(64),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_barcode_structure_symb ON barcode_structure(symb) WHERE symb IS NOT NULL;

-- DEFAULT DATA
INSERT INTO barcode_structure (id, name, symb, format) VALUES
(1, 'EAN-13', 'EAN13', 'XXXXXXXXXXXXX'),
(2, 'EAN-8', 'EAN8', 'XXXXXXXX'),
(3, 'CODE128', 'CODE128', 'XXXXXXXXXXXX'),
(4, 'CODE39', 'CODE39', 'XXXXXXXXXXXXXX'),
(5, 'Внутренний', 'INTERNAL', 'XXXXX-YYYYY-ZZZ')
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_barcode_structure_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_barcode_structure_update
    BEFORE UPDATE ON barcode_structure
    FOR EACH ROW
    EXECUTE FUNCTION update_barcode_structure_timestamp();
