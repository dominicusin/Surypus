-- =============================================================================
-- СИСТЕМЫ ВНУТРЕННИХ ШТРИХ-КОДОВ
-- Соответствуют Core.Barcode.BCodeStruc
-- Аналог: PPOBJ_BCODESTRUC
-- =============================================================================

CREATE TABLE IF NOT EXISTS bcode_struc (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    format VARCHAR(128),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO bcode_struc (id, name, format) VALUES
(1, 'EAN-13', 'NNNNNNNNNNNNN'),
(2, 'EAN-8', 'NNNNNNNN'),
(3, 'UPC-A', 'NNNNNNNNNNNN'),
(4, 'Code 128', 'AAAAAAAAAA'),
(5, 'Code 39', 'AAAAAAAAAA'),
(6, 'Внутренний', 'XXXXXXYYYYYY')
ON CONFLICT (id) DO NOTHING;
