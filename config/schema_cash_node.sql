-- =============================================================================
-- РАСЧЁТНЫЕ КАССОВЫЕ УЗЛЫ
-- Соответствуют Core.Commerce.CashNode
-- Аналог: PPOBJ_CASHNODE
-- =============================================================================

CREATE TABLE IF NOT EXISTS cash_node (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    location_id INT NOT NULL,
    flags INT DEFAULT 0,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cash_node_location ON cash_node(location_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_cash_node_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cash_node_update
    BEFORE UPDATE ON cash_node
    FOR EACH ROW
    EXECUTE FUNCTION update_cash_node_timestamp();
