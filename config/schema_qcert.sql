-- =============================================================================
-- СЕРТИФИКАТЫ КАЧЕСТВА
-- Соответствуют Core.Quality.QCert
-- Аналог: PPOBJ_QCERT
-- =============================================================================

CREATE TABLE IF NOT EXISTS qcert (
    id SERIAL PRIMARY KEY,
    number VARCHAR(128) NOT NULL,
    goods_id INT NOT NULL,
    issuer VARCHAR(256),
    issue_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    file VARCHAR(512),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_qcert_dates CHECK (issue_date <= expiry_date)
);

CREATE INDEX idx_qcert_goods ON qcert(goods_id);
CREATE INDEX idx_qcert_number ON qcert(number);
CREATE INDEX idx_qcert_expiry ON qcert(expiry_date);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_qcert_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_qcert_update
    BEFORE UPDATE ON qcert
    FOR EACH ROW
    EXECUTE FUNCTION update_qcert_timestamp();

-- VIEW: Действующие сертификаты
CREATE OR REPLACE VIEW v_valid_qcerts AS
SELECT 
    qc.id,
    qc.number,
    qc.goods_id,
    g.name AS goods_name,
    qc.issuer,
    qc.issue_date,
    qc.expiry_date,
    qc.file
FROM qcert qc
JOIN goods g ON g.id = qc.goods_id
WHERE qc.expiry_date >= CURRENT_DATE
ORDER BY qc.expiry_date;
