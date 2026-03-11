-- ============================================================
-- Attachment Tables - Вложения
-- ============================================================

-- Attachments (вложения)
CREATE TABLE IF NOT EXISTS attachment (
    id BIGSERIAL PRIMARY KEY,
    object_type SMALLINT NOT NULL,  -- 0=GOODS, 1=PERSON, 2=BILL, 3=ORDER, 4=PROJECT, 5=TASK, 6=CONTRACT, 7=QUOTATION
    object_id BIGINT NOT NULL,
    file_name VARCHAR(256) NOT NULL,
    original_name VARCHAR(256),
    mime_type VARCHAR(128) NOT NULL,
    size BIGINT NOT NULL,
    path VARCHAR(512) NOT NULL,
    hash VARCHAR(64),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by BIGINT REFERENCES person(id)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_attachment_object ON attachment(object_type, object_id);
CREATE INDEX IF NOT EXISTS idx_attachment_hash ON attachment(hash);

-- ============================================================
-- Функции
-- ============================================================

-- Получить вложения объекта
CREATE OR REPLACE FUNCTION get_object_attachments(
    p_object_type SMALLINT,
    p_object_id BIGINT
) RETURNS SETOF attachment AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM attachment
    WHERE object_type = p_object_type AND object_id = p_object_id
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Добавить вложение
CREATE OR REPLACE FUNCTION add_attachment(
    p_object_type SMALLINT,
    p_object_id BIGINT,
    p_file_name VARCHAR,
    p_original_name VARCHAR,
    p_mime_type VARCHAR,
    p_size BIGINT,
    p_path VARCHAR,
    p_hash VARCHAR,
    p_created_by BIGINT
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO attachment (object_type, object_id, file_name, original_name, mime_type, size, path, hash, created_by)
    VALUES (p_object_type, p_object_id, p_file_name, p_original_name, p_mime_type, p_size, p_path, p_hash, p_created_by)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления
-- ============================================================

-- Все вложения документа
CREATE VIEW v_bill_attachments AS
SELECT * FROM attachment WHERE object_type = 2;

-- Все вложения товара
CREATE VIEW v_goods_attachments AS
SELECT * FROM attachment WHERE object_type = 0;
