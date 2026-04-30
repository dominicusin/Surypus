-- ============================================================================
-- SCHEMA: EDI Documents (Электронный документооборот)
-- Соответствует C++ классам PPEdiProcessor в ppedi.cpp
-- ============================================================================

-- Таблица EDI партнёров
CREATE TABLE IF NOT EXISTS edi_partner (
    id              SERIAL PRIMARY KEY,
    gln             VARCHAR(13) NOT NULL,
    name            VARCHAR(255) NOT NULL,
    partner_type    VARCHAR(20) NOT NULL,  -- SUPPLIER, BUYER, CARRIER, WAREHOUSE
    protocol        VARCHAR(50),            -- FTP, AS2, SFTP, etc.
    address         VARCHAR(500),
    username        VARCHAR(100),
    password_hash   VARCHAR(255),
    enabled         BOOLEAN DEFAULT TRUE,
    flags           INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT ep_gln_unique UNIQUE (gln),
    CONSTRAINT ep_gln_format CHECK (gln ~ '^[0-9]{13}$'),
    CONSTRAINT ep_type_check CHECK (partner_type IN ('SUPPLIER', 'BUYER', 'CARRIER', 'WAREHOUSE'))
);

-- Таблица EDI документов
CREATE TABLE IF NOT EXISTS edi_document (
    id              SERIAL PRIMARY KEY,
    doc_type        VARCHAR(20) NOT NULL,  -- ORDER, ORDER_RESP, INVOICE, DESADV, RECADV, RECEIPT, BILLING
    doc_number      VARCHAR(50) NOT NULL,
    doc_date        DATE NOT NULL,
    sender_gln      VARCHAR(13) NOT NULL,
    receiver_gln    VARCHAR(13) NOT NULL,
    status          VARCHAR(20) DEFAULT 'DRAFT',  -- DRAFT, SENT, RECEIVED, PROCESSED, CONFIRMED, REJECTED, ERROR
    total           DECIMAL(18,6) DEFAULT 0,
    currency        VARCHAR(3) DEFAULT 'RUB',
    filename        VARCHAR(500),
    content         TEXT,
    reference_id    INTEGER,               -- Ссылка на связанный документ
    partner_id      INTEGER REFERENCES edi_partner(id),
    flags           INTEGER DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT ed_type_check CHECK (doc_type IN ('ORDER', 'ORDER_RESP', 'INVOICE', 'DESADV', 'RECADV', 'RECEIPT', 'BILLING')),
    CONSTRAINT ed_status_check CHECK (status IN ('DRAFT', 'SENT', 'RECEIVED', 'PROCESSED', 'CONFIRMED', 'REJECTED', 'ERROR')),
    CONSTRAINT ed_gln_format_sender CHECK (sender_gln ~ '^[0-9]{13}$'),
    CONSTRAINT ed_gln_format_receiver CHECK (receiver_gln ~ '^[0-9]{13}$'),
    CONSTRAINT ed_total_check CHECK (total >= 0),
    CONSTRAINT ed_number_not_empty CHECK (LENGTH(TRIM(doc_number)) > 0)
);

-- Таблица строк EDI документа
CREATE TABLE IF NOT EXISTS edi_line (
    id              SERIAL PRIMARY KEY,
    document_id     INTEGER NOT NULL REFERENCES edi_document(id) ON DELETE CASCADE,
    line_no         INTEGER NOT NULL,
    goods_id        INTEGER,
    goods_code      VARCHAR(50),
    goods_name      VARCHAR(255),
    quantity        DECIMAL(18,6) NOT NULL,
    unit_code       VARCHAR(10),
    price           DECIMAL(18,6) NOT NULL,
    tax_rate        DECIMAL(5,2) DEFAULT 0,
    line_total      DECIMAL(18,6) NOT NULL,
    
    CONSTRAINT el_document_fk FOREIGN KEY (document_id) REFERENCES edi_document(id),
    CONSTRAINT el_quantity_positive CHECK (quantity > 0),
    CONSTRAINT el_price_nonnegative CHECK (price >= 0),
    CONSTRAINT el_tax_rate_check CHECK (tax_rate >= 0 AND tax_rate <= 100),
    CONSTRAINT el_line_total_check CHECK (line_total >= 0),
    CONSTRAINT el_line_unique UNIQUE (document_id, line_no)
);

-- Таблица транзакций EDI
CREATE TABLE IF NOT EXISTS edi_transaction (
    id              SERIAL PRIMARY KEY,
    document_id     INTEGER REFERENCES edi_document(id) ON DELETE SET NULL,
    direction       VARCHAR(10) NOT NULL,  -- INBOUND, OUTBOUND
    timestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status          VARCHAR(20) NOT NULL,
    message         TEXT,
    error_code      VARCHAR(50),
    
    CONSTRAINT et_direction_check CHECK (direction IN ('INBOUND', 'OUTBOUND')),
    CONSTRAINT et_status_check CHECK (status IN ('DRAFT', 'SENT', 'RECEIVED', 'PROCESSED', 'CONFIRMED', 'REJECTED', 'ERROR'))
);

-- Таблица настроек EDI провайдера
CREATE TABLE IF NOT EXISTS edi_provider_config (
    id              SERIAL PRIMARY KEY,
    provider_name   VARCHAR(100) NOT NULL,
    config_key      VARCHAR(100) NOT NULL,
    config_value    TEXT,
    is_secret       BOOLEAN DEFAULT FALSE,
    
    CONSTRAINT epc_provider_key_unique UNIQUE (provider_name, config_key)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_ed_doc_type ON edi_document(doc_type);
CREATE INDEX IF NOT EXISTS idx_ed_status ON edi_document(status);
CREATE INDEX IF NOT EXISTS idx_ed_date ON edi_document(doc_date DESC);
CREATE INDEX IF NOT EXISTS idx_ed_gln ON edi_document(sender_gln, receiver_gln);
CREATE INDEX IF NOT EXISTS idx_el_document ON edi_line(document_id);
CREATE INDEX IF NOT EXISTS idx_el_goods ON edi_line(goods_id);
CREATE INDEX IF NOT EXISTS idx_et_document ON edi_transaction(document_id);
CREATE INDEX IF NOT EXISTS idx_et_timestamp ON edi_transaction(timestamp DESC);

-- Функция: Проверить GLN код (контрольная цифра)
CREATE OR REPLACE FUNCTION validate_gln(p_gln VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_digits VARCHAR(12);
    v_check_digit INTEGER;
    v_sum INTEGER := 0;
    v_i INTEGER;
    v_calc_digit INTEGER;
BEGIN
    -- Проверить формат
    IF p_gln !~ '^[0-9]{13}$' THEN
        RETURN FALSE;
    END IF;
    
    v_digits := SUBSTRING(p_gln FROM 1 FOR 12);
    v_check_digit := SUBSTRING(p_gln FROM 13 FOR 1)::INTEGER;
    
    -- Рассчитать контрольную цифру
    FOR v_i IN 1..12 LOOP
        IF v_i % 2 = 1 THEN
            v_sum := v_sum + SUBSTRING(v_digits FROM v_i FOR 1)::INTEGER;
        ELSE
            v_sum := v_sum + SUBSTRING(v_digits FROM v_i FOR 1)::INTEGER * 3;
        END IF;
    END LOOP;
    
    v_calc_digit := (10 - (v_sum % 10)) % 10;
    
    RETURN v_calc_digit = v_check_digit;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция: Рассчитать сумму документа
CREATE OR REPLACE FUNCTION calculate_document_total(p_document_id INTEGER)
RETURNS DECIMAL(18,6) AS $$
BEGIN
    RETURN COALESCE((
        SELECT SUM(quantity * price)
        FROM edi_line
        WHERE document_id = p_document_id
    ), 0);
END;
$$ LANGUAGE plpgsql;

-- Функция: Обновить итоги документа
CREATE OR REPLACE FUNCTION update_document_total(p_document_id INTEGER)
RETURNS VOID AS $$
DECLARE
    v_total DECIMAL(18,6);
BEGIN
    v_total := calculate_document_total(p_document_id);
    
    UPDATE edi_document
    SET total = v_total, updated_at = CURRENT_TIMESTAMP
    WHERE id = p_document_id;
END;
$$ LANGUAGE plpgsql;

-- Триггер: Обновить итоги при изменении строк
CREATE OR REPLACE FUNCTION trigger_update_document_total()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        PERFORM update_document_total(NEW.document_id);
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM update_document_total(OLD.document_id);
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_edi_line_total
    AFTER INSERT OR UPDATE OR DELETE ON edi_line
    FOR EACH ROW
    EXECUTE FUNCTION trigger_update_document_total();

-- Процедура: Создать EDI документ
CREATE OR REPLACE PROCEDURE create_edi_document(
    p_doc_type VARCHAR,
    p_doc_number VARCHAR,
    p_doc_date DATE,
    p_sender_gln VARCHAR,
    p_receiver_gln VARCHAR,
    p_partner_id INTEGER,
    p_document_id OUT INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Проверить GLN
    IF NOT validate_gln(p_sender_gln) THEN
        RAISE EXCEPTION 'Invalid sender GLN';
    END IF;
    
    IF NOT validate_gln(p_receiver_gln) THEN
        RAISE EXCEPTION 'Invalid receiver GLN';
    END IF;
    
    INSERT INTO edi_document (
        doc_type, doc_number, doc_date, sender_gln, receiver_gln, partner_id, status
    ) VALUES (
        p_doc_type, p_doc_number, p_doc_date, p_sender_gln, p_receiver_gln, p_partner_id, 'DRAFT'
    )
    RETURNING id INTO p_document_id;
    
    RAISE NOTICE 'EDI document % created', p_document_id;
END;
$$;

-- Процедура: Отправить EDI документ
CREATE OR REPLACE PROCEDURE send_edi_document(p_document_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE edi_document
    SET status = 'SENT', updated_at = CURRENT_TIMESTAMP
    WHERE id = p_document_id;
    
    INSERT INTO edi_transaction (document_id, direction, status, message)
    VALUES (p_document_id, 'OUTBOUND', 'SENT', 'Document sent');
    
    RAISE NOTICE 'EDI document % sent', p_document_id;
END;
$$;

-- Процедура: Обработать входящий EDI документ
CREATE OR REPLACE PROCEDURE process_inbound_edi(
    p_document_id INTEGER,
    p_status VARCHAR,
    p_message TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE edi_document
    SET status = p_status, updated_at = CURRENT_TIMESTAMP
    WHERE id = p_document_id;
    
    INSERT INTO edi_transaction (document_id, direction, status, message)
    VALUES (p_document_id, 'INBOUND', p_status, p_message);
    
    RAISE NOTICE 'EDI document % processed with status %', p_document_id, p_status;
END;
$$;

-- Представление: Документы ожидающие обработки
CREATE OR REPLACE VIEW v_edi_pending AS
SELECT 
    ed.id,
    ed.doc_type,
    ed.doc_number,
    ed.doc_date,
    ed.sender_gln,
    ed.receiver_gln,
    ed.total,
    ed.currency,
    ep.name AS partner_name,
    ed.created_at
FROM edi_document ed
LEFT JOIN edi_partner ep ON ep.id = ed.partner_id
WHERE ed.status IN ('RECEIVED', 'DRAFT')
ORDER BY ed.doc_date DESC;

-- Представление: Статистика EDI
CREATE OR REPLACE VIEW v_edi_statistics AS
SELECT 
    doc_type,
    status,
    COUNT(*) AS count,
    SUM(total) AS total_amount,
    MIN(doc_date) AS earliest_date,
    MAX(doc_date) AS latest_date
FROM edi_document
GROUP BY doc_type, status;

-- Представление: Транзакции по документам
CREATE TABLE IF NOT EXISTS v_edi_transactions AS
SELECT 
    ed.id AS document_id,
    ed.doc_number,
    et.direction,
    et.timestamp,
    et.status,
    et.message,
    et.error_code
FROM edi_transaction et
JOIN edi_document ed ON ed.id = et.document_id
ORDER BY et.timestamp DESC;

-- Представление: Связанные документы
CREATE OR REPLACE VIEW v_edi_related AS
SELECT 
    ed.id AS document_id,
    ed.doc_type,
    ed.doc_number,
    ed.ref_id AS reference_document_id,
    ref.doc_type AS ref_doc_type,
    ref.doc_number AS ref_doc_number
FROM edi_document ed
LEFT JOIN edi_document ref ON ref.id = ed.reference_id
WHERE ed.ref_id IS NOT NULL;
