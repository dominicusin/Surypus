-- =============================================================================
-- ДОКУМЕНТЫ (Document) с наследованием таблиц PostgreSQL
-- =============================================================================

-- Базовая таблица для всех документов
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    person_id INT NOT NULL,  -- контрагент (ссылка на persons.person)
    type_id INT NOT NULL,    -- тип документа (ссылка на doc_types)
    series VARCHAR(50),
    number VARCHAR(50) NOT NULL,
    issue_date DATE NOT NULL,
    expiry_date DATE,
    issuer VARCHAR(100),
    flags INT DEFAULT 0,
    auto_number BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Комментарий к таблице
COMMENT ON TABLE documents IS 'Базовая таблица для всех документов в системе';

-- Комментарии к колонкам
COMMENT ON COLUMN documents.person_id IS 'Ссылка на контрагента';
COMMENT ON COLUMN documents.type_id IS 'Ссылка на тип документа';
COMMENT ON COLUMN documents.series IS 'Серия документа (может быть пустой)';
COMMENT ON COLUMN documents.number IS 'Номер документа (обязательный)';
COMMENT ON COLUMN documents.issue_date IS 'Дата выдачи документа';
COMMENT ON COLUMN documents.expiry_date IS 'Дата истечения срока действия документа';
COMMENT ON COLUMN documents.issuer IS 'Кем выдан документ';
COMMENT ON COLUMN documents.flags IS 'Флаги документа (битовая маска)';
COMMENT ON COLUMN documents.auto_number IS 'Автоматическая нумерация документа';
COMMENT ON COLUMN documents.created_at IS 'Дата и время создания записи';
COMMENT ON COLUMN documents.updated_at IS 'Дата и время последнего обновления записи';

-- Типы документов
CREATE TABLE IF NOT EXISTS doc_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    op_type_id INT,
    flags INT DEFAULT 0
);

COMMENT ON TABLE doc_types IS 'Справочник типов документов';
COMMENT ON COLUMN doc_types.code IS 'Код типа документа (например, INVOICE, RECEIPT)';
COMMENT ON COLUMN doc_types.name IS 'Название типа документа';
COMMENT ON COLUMN doc_types.op_type_id IS 'Ссылка на тип операции в бухгалтерии';
COMMENT ON COLUMN doc_types.flags IS 'Флаги типа документа (битовая маска)';

-- Заполнение справочника типов документов
INSERT INTO doc_types (code, name, op_type_id) VALUES
    ('GOODS_RECEIPT', 'Приходная накладная', 1),
    ('GOODS_SHIPMENT', 'Расходная накладная', 2),
    ('GOODS_RETURN', 'Возврат поставщику', 3),
    ('SALE_RETURN', 'Возврат от покупателя', 4),
    ('ORDER', 'Заказ', 5),
    ('PREORDER', 'Предзаказ', 6),
    ('WASTE', 'Списание', 7),
    ('PCKGT_RETURN', 'Возврат упаковки', 8),
    ('ACCTURN', 'Бухгалтерская проводка', 9),
    ('CREDIT_NOTE', 'Кредит-нота', 10),
    ('DEBIT_NOTE', 'Дебет-нота', 11),
    ('PAYMENT', 'Платёж', 12),
    ('CASH_ORDER', 'Кассовый ордер', 13),
    ('BANK_ORDER', 'Банковский ордер', 14)
ON CONFLICT (code) DO NOTHING;

-- Таблица счетов-фактур и других коммерческих документов
-- Наследует общие поля документов и добавляет специфичные поля
CREATE TABLE IF NOT EXISTS bills (
    amount NUMERIC(15,2) DEFAULT 0 CHECK (amount >= 0),
    vat NUMERIC(15,2) DEFAULT 0 CHECK (vat >= 0),
    discount NUMERIC(15,2) DEFAULT 0 CHECK (discount >= 0),
    op_id INT NOT NULL,  -- тип операции в бухгалтерии (ссылка на acc_operation_types или аналог)
    location_id INT,     -- ссылка на склад/локацию
    memo TEXT,
    -- Индексы и Constraints будут добавлены ниже
) INHERITS (documents);

COMMENT ON TABLE bills IS 'Таблица счетов, накладных и других коммерческих документов';
COMMENT ON COLUMN bills.op_id IS 'Тип операции в бухгалтерии';
COMMENT ON COLUMN bills.amount IS 'Сумма документа без НДС';
COMMENT ON COLUMN bills.vat IS 'Сумма НДС';
COMMENT ON COLUMN bills.discount IS 'Сумма скидки';
COMMENT ON COLUMN bills.location_id IS 'Ссылка на склад/локацию';
COMMENT ON COLUMN bills.memo IS 'Примечание к документу';

-- Таблица строк документов для счетов-фактур
CREATE TABLE IF NOT EXISTS bill_lines (
    id SERIAL PRIMARY KEY,
    bill_id INT NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
    goods_id INT NOT NULL,
    quantity NUMERIC(15,4) NOT NULL CHECK (quantity >= 0),
    price NUMERIC(15,4) NOT NULL CHECK (price >= 0),
    cost NUMERIC(15,4) DEFAULT 0 CHECK (cost >= 0),
    discount NUMERIC(15,2) DEFAULT 0 CHECK (discount >= 0),
    vat_rate NUMERIC(5,2) DEFAULT 0 CHECK (vat_rate >= 0),
    vat_sum NUMERIC(15,2) DEFAULT 0 CHECK (vat_sum >= 0),
    flags INT DEFAULT 0,
    location_id INT,
    warehouse_id INT,
    line_no INT DEFAULT 0
);

COMMENT ON TABLE bill_lines IS 'Таблица строк документов (позиций) для счетов';
COMMENT ON COLUMN bill_lines.bill_id IS 'Ссылка на счет-фактуру';
COMMENT ON COLUMN bill_lines.goods_id IS 'Ссылка на товар/услугу';
COMMENT ON COLUMN bill_lines.quantity IS 'Количество товара';
COMMENT ON COLUMN bill_lines.price IS 'Цена за единицу товара';
COMMENT ON COLUMN bill_lines.cost IS 'Себестоимость единицы товара';
COMMENT ON COLUMN bill_lines.discount IS 'Скидка на строку';
COMMENT ON COLUMN bill_lines.vat_rate IS 'Ставка НДС для строки';
COMMENT ON COLUMN bill_lines.vat_sum IS 'Сумма НДС для строки';
COMMENT ON COLUMN bill_lines.flags IS 'Флаги строки документа';
COMMENT ON COLUMN bill_lines.location_id IS 'Ссылка на локацию (склад) хранения товара';
COMMENT ON COLUMN bill_lines.warehouse_id IS 'Ссылка на warehouse';
COMMENT ON COLUMN bill_lines.line_no IS 'Номер строки в документе';

-- Индексы для таблицы документов
CREATE INDEX IF NOT EXISTS idx_documents_person_id ON documents(person_id);
CREATE INDEX IF NOT EXISTS idx_documents_type_id ON documents(type_id);
CREATE INDEX IF NOT EXISTS idx_documents_issue_date ON documents(issue_date);
CREATE INDEX IF NOT EXISTS idx_documents_updated_at ON documents(updated_at);
CREATE INDEX IF NOT EXISTS idx_documents_series_number ON documents(series, number);

-- Уникальный индекс для номера документа в пределах типа и серии (если автонумерация)
-- Мы создаем частичный уникальный индекс только для тех документов, у которых автонумерация включена
-- и где серия и номер не пустые
CREATE UNIQUE INDEX IF NOT EXISTS idx_documents_unique_number
ON documents(type_id, series, number)
WHERE auto_number = TRUE AND series IS NOT NULL AND number IS NOT NULL AND number <> '';

-- Индексы для таблицы счетов
CREATE INDEX IF NOT EXISTS idx_bills_op_id ON bills(op_id);
CREATE INDEX IF NOT EXISTS idx_bills_location_id ON bills(location_id);
CREATE INDEX IF NOT EXISTS idx_bills_amount ON bills(amount);
CREATE INDEX IF NOT EXISTS idx_bills_created_at ON bills(created_at);

-- Индексы для таблицы строк счетов
CREATE INDEX IF NOT EXISTS idx_bill_lines_bill_id ON bill_lines(bill_id);
CREATE INDEX IF NOT EXISTS idx_bill_lines_goods_id ON bill_lines(goods_id);
CREATE INDEX IF NOT EXISTS idx_bill_lines_location_id ON bill_lines(location_id);

-- Триггер для проверки сумм строк в счетах
CREATE OR REPLACE FUNCTION check_bill_totals()
RETURNS TRIGGER AS $$
DECLARE
    total NUMERIC(15,2);
    line_total NUMERIC(15,2);
BEGIN
    -- Рассчитать сумму строк
    SELECT COALESCE(SUM(quantity * price - discount), 0) + COALESCE(SUM(vat_sum), 0)
    INTO line_total
    FROM bill_lines
    WHERE bill_id = NEW.id;
    
    -- Рассчитать сумму документа
    SELECT amount + vat - discount INTO total 
    FROM bills 
    WHERE id = NEW.id;
    
    -- Проверить совпадение (с точностью до копейки)
    IF ABS(total - line_total) > 0.01 THEN
        RAISE EXCEPTION 'Bill total (%) does not match sum of lines (%)', total, line_total;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Применяем триггер обновления updated_at к таблицам
DROP TRIGGER IF EXISTS update_documents_updated_at ON documents;
CREATE TRIGGER update_documents_updated_at
BEFORE UPDATE ON documents
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_bills_updated_at ON bills;
CREATE TRIGGER update_bills_updated_at
BEFORE UPDATE ON bills
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Кассовые чеки (пример другого типа документа, наследующего от documents)
CREATE TABLE IF NOT EXISTS cash_checks (
    session_id INT NOT NULL,  -- ссылка на кассовую сессию
    -- Индексы и Constraints будут добавлены ниже
) INHERITS (documents);

COMMENT ON TABLE cash_checks IS 'Таблица кассовых чеков';
COMMENT ON COLUMN cash_checks.session_id IS 'Ссылка на кассовую сессию';

-- Индексы для кассовых чеков
CREATE INDEX IF NOT EXISTS idx_cash_checks_session_id ON cash_checks(session_id);
CREATE INDEX IF NOT EXISTS idx_cash_checks_issue_date ON cash_checks(issue_date);

-- Строки кассовых чеков
CREATE TABLE IF NOT EXISTS cash_check_lines (
    id SERIAL PRIMARY KEY,
    check_id INT NOT NULL REFERENCES cash_checks(id) ON DELETE CASCADE,
    goods_id INT NOT NULL,
    quantity NUMERIC(15,4) NOT NULL CHECK (quantity >= 0),
    price NUMERIC(15,4) NOT NULL CHECK (price >= 0),
    discount NUMERIC(15,2) DEFAULT 0 CHECK (discount >= 0),
    flags INT DEFAULT 0,
    line_no INT DEFAULT 0
);

COMMENT ON TABLE cash_check_lines IS 'Таблица строк кассовых чеков';
COMMENT ON COLUMN cash_check_lines.check_id IS 'Ссылка на кассовый чек';
COMMENT ON COLUMN cash_check_lines.goods_id IS 'Ссылка на товар/услугу';
COMMENT ON COLUMN cash_check_lines.quantity IS 'Количество товара';
COMMENT ON COLUMN cash_check_lines.price IS 'Цена за единицу товара';
COMMENT ON COLUMN cash_check_lines.discount IS 'Скидка на строку';
COMMENT ON COLUMN cash_check_lines.line_no IS 'Номер строки в чеке';

-- Индексы для строк кассовых чеков
CREATE INDEX IF NOT EXISTS idx_cash_check_lines_check_id ON cash_check_lines(check_id);
CREATE INDEX IF NOT EXISTS idx_cash_check_lines_goods_id ON cash_check_lines(goods_id);

-- Кассовые сессии
CREATE TABLE IF NOT EXISTS cash_sessions (
    id SERIAL PRIMARY KEY,
    code VARCHAR(48),
    dt DATE NOT NULL,
    cash_node_id INT NOT NULL,
    user_id INT NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    cash_in NUMERIC(15,2) DEFAULT 0,
    cash_out NUMERIC(15,2) DEFAULT 0,
    total_sales NUMERIC(15,2) DEFAULT 0,
    total_return NUMERIC(15,2) DEFAULT 0,
    checks_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE cash_sessions IS 'Таблица кассовых сессий';
COMMENT ON COLUMN cash_sessions.code IS 'Код сессии';
COMMENT ON COLUMN cash_sessions.dt IS 'Дата сессии';
COMMENT ON COLUMN cash_sessions.cash_node_id IS 'Ссылка на кассовый узел';
COMMENT ON COLUMN cash_sessions.user_id IS 'Ссылка на пользователя';
COMMENT ON COLUMN cash_sessions.start_time IS 'Время начала сессии';
COMMENT ON COLUMN cash_sessions.end_time IS 'Время окончания сессии';
COMMENT ON COLUMN cash_sessions.cash_in IS 'Наличные при ingreso';
COMMENT ON COLUMN cash_sessions.cash_out IS 'Наличные при расходе';
COMMENT ON COLUMN cash_sessions.total_sales IS 'Общая сумма продаж';
COMMENT ON COLUMN cash_sessions.total_return IS 'Общая сумма возвратов';
COMMENT ON COLUMN cash_sessions.checks_count IS 'Количество чеков в сессии';
COMMENT ON COLUMN cash_sessions.created_at IS 'Дата и время создания записи';

-- Индексы для кассовых сессий
CREATE INDEX IF NOT EXISTS idx_cash_sessions_dt ON cash_sessions(dt);
CREATE INDEX IF NOT EXISTS idx_cash_sessions_cash_node ON cash_sessions(cash_node_id);
CREATE INDEX IF NOT EXISTS idx_cash_sessions_user_id ON cash_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_cash_sessions_dt ON cash_sessions(dt);

-- Функция расчёта итогов документа (универсальная для всех типов документов)
-- Эта функция должна быть переопределена для каждого конкретного типа документа
-- но мы оставляем базовую реализацию как заглушку
CREATE OR REPLACE FUNCTION calc_document_total(p_document_id INT)
RETURNS TABLE(total NUMERIC(15,2), vat NUMERIC(15,2), discount NUMERIC(15,2)) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(amount, 0) + COALESCE(vat, 0) - COALESCE(discount, 0) AS total,
        COALESCE(vat, 0) AS vat,
        COALESCE(discount, 0) AS discount
    FROM documents
    WHERE id = p_document_id;
END;
$$ LANGUAGE plpgsql;

-- Специализированная функция для расчета итогов счетов (переопределяем для bills)
CREATE OR REPLACE FUNCTION calc_bill_total(p_bill_id INT)
RETURNS TABLE(total NUMERIC(15,2), vat NUMERIC(15,2), discount NUMERIC(15,2)) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(b.amount, 0) + COALESCE(b.vat, 0) - COALESCE(b.discount, 0) AS total,
        COALESCE(b.vat, 0) AS vat,
        COALESCE(b.discount, 0) AS discount
    FROM bills b
    WHERE b.id = p_bill_id;
END;
$$ LANGUAGE plpgsql;
