-- =============================================================================
-- СТАТУСЫ ДОКУМЕНТОВ
-- Соответствуют Core.Accounting.BillStatus
-- Аналог: PPOBJ_BILLSTATUS
-- =============================================================================

CREATE TABLE IF NOT EXISTS bill_status (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    flags INT DEFAULT 0,
    priority INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO bill_status (id, name, symb, priority) VALUES
(1, 'Черновик', 'DRAFT', 1),
(2, 'Подготовлен', 'PREPARED', 2),
(3, 'Проведён', 'APPROVED', 3),
(4, 'Отменён', 'CANCELLED', 4),
(5, 'Архивный', 'ARCHIVED', 5)
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_bill_status_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_bill_status_update
    BEFORE UPDATE ON bill_status
    FOR EACH ROW
    EXECUTE FUNCTION update_bill_status_timestamp();
