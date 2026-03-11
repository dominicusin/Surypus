-- =============================================================================
-- СЧЁТЧИКИ ДОКУМЕНТОВ
-- Соответствуют Core.Document.OpCounter
-- Аналог: PPOBJ_OPCOUNTER
-- =============================================================================

CREATE TABLE IF NOT EXISTS document_op_counter (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    op_kind_id INT DEFAULT 0,
    prefix VARCHAR(16),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_document_op_counter_op_kind ON document_op_counter(op_kind_id);

-- DEFAULT DATA
INSERT INTO document_op_counter (id, name, op_kind_id, prefix) VALUES
(1, 'Приход', 1, 'ПР-'),
(2, 'Расход', 11, 'РР-'),
(3, 'Перемещение', 21, 'ПЕ-'),
(4, 'Возврат', 12, 'ВЗ-')
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_document_op_counter_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_document_op_counter_update
    BEFORE UPDATE ON document_op_counter
    FOR EACH ROW
    EXECUTE FUNCTION update_document_op_counter_timestamp();

-- FUNCTION: Получить следующий номер документа
CREATE OR REPLACE FUNCTION document_get_next_doc_number(p_counter_id INT)
RETURNS TEXT AS $$
DECLARE
    v_prefix TEXT;
    v_next_num INT;
    v_result TEXT;
BEGIN
    SELECT oc.prefix, COALESCE(MAX(CAST(SUBSTRING(b.number FROM LENGTH(oc.prefix)+1) AS INT)), 0) + 1
    INTO v_prefix, v_next_num
    FROM document_op_counter oc
    LEFT JOIN bill b ON b.op_counter_id = oc.id
    WHERE oc.id = p_counter_id
    GROUP BY oc.prefix;
    
    IF v_prefix IS NULL THEN
        SELECT prefix INTO v_prefix FROM document_op_counter WHERE id = p_counter_id;
        v_next_num := 1;
    END IF;
    
    v_result := v_prefix || LPAD(v_next_num::TEXT, 8, '0');
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;
