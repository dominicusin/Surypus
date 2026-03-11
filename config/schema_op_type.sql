-- =============================================================================
-- ТИПЫ ОПЕРАЦИЙ
-- Соответствуют Core.Operation.OpType
-- Аналог: PPOBJ_OPRTYPE
-- =============================================================================

CREATE TABLE IF NOT EXISTS op_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO op_type (id, name, symb) VALUES
(1, 'Приход', 'INCOME'),
(2, 'Расход', 'OUTCOME'),
(3, 'Перемещение', 'TRANSFER'),
(4, 'Возврат', 'RETURN'),
(5, 'Корректировка', 'ADJUST')
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_op_type_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_op_type_update
    BEFORE UPDATE ON op_type
    FOR EACH ROW
    EXECUTE FUNCTION update_op_type_timestamp();
