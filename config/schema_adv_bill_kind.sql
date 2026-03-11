-- =============================================================================
-- ВИДЫ ПЕРВИЧНЫХ ДОКУМЕНТОВ
-- Соответствуют Core.Accounting.AdvBillKind
-- Аналог: PPOBJ_ADVBILLKIND
-- =============================================================================

CREATE TABLE IF NOT EXISTS adv_bill_kind (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(16),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO adv_bill_kind (id, name, code) VALUES
(1, 'Авансовый отчёт', 'ADVANCE'),
(2, 'Индивидуальный', 'INDIVIDUAL'),
(3, 'Спецификация', 'SPECIFICATION')
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_adv_bill_kind_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_adv_bill_kind_update
    BEFORE UPDATE ON adv_bill_kind
    FOR EACH ROW
    EXECUTE FUNCTION update_adv_bill_kind_timestamp();
