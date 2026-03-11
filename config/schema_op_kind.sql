-- =============================================================================
-- ВИДЫ ОПЕРАЦИЙ
-- Соответствуют Core.Document.OpKind
-- Аналог: PPOBJ_OPRKIND
-- =============================================================================

CREATE TABLE IF NOT EXISTS op_kind (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type_id INT NOT NULL,
    symb VARCHAR(32),
    flags INT DEFAULT 0,
    def_acc_sheet INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_op_kind_type ON op_kind(type_id);
CREATE UNIQUE INDEX idx_op_kind_symb ON op_kind(symb) WHERE symb IS NOT NULL;

-- DEFAULT DATA: Основные виды операций
INSERT INTO op_kind (id, name, type_id, symb, def_acc_sheet) VALUES
-- Приходные операции (type_id = 1)
(1, 'Приходный документ', 1, 'ACCEPT', 1),
(2, 'Возврат от покупателя', 1, 'RETURNCUST', 1),
(3, 'Оприходование', 1, 'RECEIPT', 1),
-- Расходные операции (type_id = 2)
(11, 'Расходный документ', 2, 'ISSUE', 1),
(12, 'Возврат поставщику', 2, 'RETURNSUPPL', 1),
(13, 'Списание', 2, 'WRITE OFF', 1),
-- Перемещение (type_id = 3)
(21, 'Перемещение', 3, 'TRANSFER', 1),
-- Комплектация (type_id = 4)
(31, 'Комплектация', 4, 'ASSEMBLY', 1),
(32, 'Разукомплектация', 4, 'DISASSEMBLY', 1)
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_op_kind_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_op_kind_update
    BEFORE UPDATE ON op_kind
    FOR EACH ROW
    EXECUTE FUNCTION update_op_kind_timestamp();