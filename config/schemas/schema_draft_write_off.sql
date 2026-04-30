-- =============================================================================
-- КОНФИГУРАЦИЯ СПИСАНИЯ ДРАФТ-ДОКУМЕНТОВ
-- Соответствуют Core.Accounting.DraftWriteOff
-- Аналог: PPOBJ_DRAFTWROFF
-- =============================================================================

CREATE TABLE IF NOT EXISTS draft_write_off (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    op_kind_id INT NOT NULL,
    acc_sheet_id INT NOT NULL,
    write_off_pct NUMERIC(5,2) DEFAULT 0 CHECK (write_off_pct >= 0 AND write_off_pct <= 100),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_draft_write_off_op_kind ON draft_write_off(op_kind_id);
CREATE INDEX idx_draft_write_off_acc_sheet ON draft_write_off(acc_sheet_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_draft_write_off_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_draft_write_off_update
    BEFORE UPDATE ON draft_write_off
    FOR EACH ROW
    EXECUTE FUNCTION update_draft_write_off_timestamp();
