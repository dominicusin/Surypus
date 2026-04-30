-- =============================================================================
-- EDI (Электронный документооборот)
-- Соответствуют Core.EDI.EDI
-- =============================================================================

-- Типы EDI документов
CREATE TABLE IF NOT EXISTS edi_doc_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    edifact_code VARCHAR(10),
    flags INT DEFAULT 0
);

INSERT INTO edi_doc_types (code, name, edifact_code) VALUES
    ('ORDER', 'Заказ', 'ORDERS'),
    ('INVOICE', 'Счёт-фактура', 'INVOIC'),
    ('TRANSPORT', 'Транспортная накладная', 'DESADV'),
    ('RECEIPT', 'Приёмка', 'RECADV'),
    ('PRICE_CATALOG', 'Прайс-лист', 'PRICAT'),
    ('INVENTORY', 'Инвентаризация', 'INVRPT')
ON CONFLICT DO NOTHING;

-- Статусы EDI документов
CREATE TABLE IF NOT EXISTS edi_statuses (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL
);

INSERT INTO edi_statuses (code, name) VALUES
    ('NEW', 'Новый'),
    ('SENT', 'Отправлен'),
    ('RECEIVED', 'Получен'),
    ('PROCESSED', 'Обработан'),
    ('ERROR', 'Ошибка'),
    ('CANCELLED', 'Отменён')
ON CONFLICT DO NOTHING;

-- Провайдеры EDI
CREATE TABLE IF NOT EXISTS edi_providers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    ident VARCHAR(50) NOT NULL UNIQUE,
    gln VARCHAR(13) CHECK (LENGTH(gln) = 13),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_edi_providers_ident ON edi_providers(ident);

-- Проверка GLN при вставке
CREATE OR REPLACE FUNCTION check_edi_gln()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gln IS NOT NULL AND NEW.gln != '' THEN
        IF NOT validate_gln(NEW.gln) THEN
            RAISE EXCEPTION 'Invalid GLN: %', NEW.gln;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_edi_gln
    BEFORE INSERT OR UPDATE ON edi_providers
    FOR EACH ROW
    EXECUTE FUNCTION check_edi_gln();

-- Настройки EDI обмена
CREATE TABLE IF NOT EXISTS edi_configs (
    id SERIAL PRIMARY KEY,
    provider_id INT NOT NULL REFERENCES edi_providers(id),
    acc_sheet_id INT NOT NULL,
    op_id INT NOT NULL,
    doc_type_id INT NOT NULL REFERENCES edi_doc_types(id),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- EDI документы
CREATE TABLE IF NOT EXISTS edi_documents (
    id SERIAL PRIMARY KEY,
    doc_type_id INT NOT NULL REFERENCES edi_doc_types(id),
    msg_id VARCHAR(100) NOT NULL,
    ref_id VARCHAR(100),
    sender_id VARCHAR(100) NOT NULL,
    receiver_id VARCHAR(100) NOT NULL,
    doc_dt DATE NOT NULL,
    recv_dt TIMESTAMP NOT NULL,
    status_id INT NOT NULL REFERENCES edi_statuses(id),
    content TEXT,
    total NUMERIC(15,2) DEFAULT 0,
    vat_sum NUMERIC(15,2) DEFAULT 0,
    bill_id INT REFERENCES bills(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_edi_documents_msg ON edi_documents(msg_id);
CREATE INDEX idx_edi_documents_dt ON edi_documents(doc_dt);
CREATE INDEX idx_edi_documents_status ON edi_documents(status_id);
CREATE INDEX idx_edi_documents_sender ON edi_documents(sender_id);
CREATE INDEX idx_edi_documents_receiver ON edi_documents(receiver_id);

-- Проверка валидности GLN
CREATE OR REPLACE FUNCTION validate_gln(gln TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    digits INT[];
    i INT;
    sum_val INT;
    check_digit INT;
BEGIN
    IF gln IS NULL OR LENGTH(gln) != 13 THEN
        RETURN FALSE;
    END IF;
    
    IF NOT gln ~ '^[0-9]+$' THEN
        RETURN FALSE;
    END IF;
    
    digits := ARRAY(
        SELECT (SUBSTRING(gln FROM i FOR 1))::INT 
        FROM generate_series(1, 12) i
    );
    
    sum_val := 0;
    FOR i IN 1..12 LOOP
        IF i % 2 = 1 THEN
            sum_val := sum_val + digits[i] * 3;
        ELSE
            sum_val := sum_val + digits[i];
        END IF;
    END LOOP;
    
    check_digit := (10 - (sum_val % 10)) % 10;
    
    RETURN check_digit = (SUBSTRING(gln FROM 13 FOR 1))::INT;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Функция обновления статуса EDI
CREATE OR REPLACE FUNCTION update_edi_status(p_doc_id INT, p_status_code VARCHAR)
RETURNS VOID AS $$
DECLARE
    status_id INT;
BEGIN
    SELECT id INTO status_id FROM edi_statuses WHERE code = p_status_code;
    
    IF status_id IS NULL THEN
        RAISE EXCEPTION 'Unknown EDI status: %', p_status_code;
    END IF;
    
    UPDATE edi_documents 
    SET status_id = status_id, updated_at = CURRENT_TIMESTAMP
    WHERE id = p_doc_id;
END;
$$ LANGUAGE plpgsql;