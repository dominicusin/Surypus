-- ============================================================================
-- SURYPUS OBJECT-RELATIONAL DATABASE SCHEMA
-- ============================================================================
--  Surypus (Haskell) migration
-- Uses PostgreSQL OOP features: schemas as classes, table inheritance, roles
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "hstore";
-- jsonb is built-in type

-- ============================================================================
-- BASE OBJECT SYSTEM (Abstract base class)
-- ============================================================================

-- Базовый класс для всех объектов системы
CREATE SCHEMA IF NOT EXISTS base;
SET search_path TO base, public;

-- BaseObject - абстрактный базовый класс (наследуется всеми)
CREATE TABLE object (
    id              BIGSERIAL PRIMARY KEY,
    uuid            UUID DEFAULT uuid_generate_v4(),
    code            VARCHAR(50) UNIQUE,
    name            VARCHAR(200) NOT NULL,
    obj_type        VARCHAR(30) NOT NULL,  -- 'goods', 'person', 'bill', etc.
    flags           INTEGER DEFAULT 0,
    status          SMALLINT DEFAULT 0,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by      BIGINT,
    modified_by     BIGINT
);

-- Индексы для базового объекта
CREATE INDEX idx_object_uuid ON object(uuid);
CREATE INDEX idx_object_code ON object(code);
CREATE INDEX idx_object_type ON object(obj_type);
CREATE INDEX idx_object_status ON object(status);

-- Методы базового объекта
CREATE OR REPLACE FUNCTION get_id()
RETURNS BIGINT AS $$ BEGIN RETURN 0; END; $$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_uuid()
RETURNS UUID AS $$ BEGIN RETURN NULL; END; $$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_code()
RETURNS VARCHAR(50) AS $$ BEGIN RETURN NULL; END; $$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_name()
RETURNS VARCHAR(200) AS $$ BEGIN RETURN NULL; END; $$ LANGUAGE SQL;

-- Триггер для обновления updated_at
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_object_timestamp
    BEFORE UPDATE ON object
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================================================
-- ACCESS CONTROL (Roles and Permissions as Classes)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS security;
SET search_path TO security, base, public;

-- Role - роль пользователя (наследует object)
CREATE TABLE role_ (
    LIKE object INCLUDING ALL
) INHERITS (object);

ALTER TABLE role_ ADD COLUMN description TEXT;
ALTER TABLE role_ ADD COLUMN permissions JSONB;

-- Добавление роли
CREATE OR REPLACE FUNCTION add_role(p_name VARCHAR, p_description TEXT)
RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO role_ (name, obj_type, description)
    VALUES (p_name, 'role', p_description)
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Right - право доступа
CREATE TABLE right_ (
    LIKE object INCLUDING ALL
) INHERITS (object);

ALTER TABLE right_ ADD COLUMN resource VARCHAR(50);
ALTER TABLE right_ ADD COLUMN action VARCHAR(30);
ALTER TABLE right_ ADD COLUMN granted BOOLEAN DEFAULT TRUE;

-- UserRole - связь пользователей и ролей
CREATE TABLE user_role (
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    granted_by BIGINT,
    PRIMARY KEY (user_id, role_id)
);

-- Проверка права
CREATE OR REPLACE FUNCTION has_right(p_user_id BIGINT, p_resource VARCHAR, p_action VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_has_right BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM right_ r
        JOIN user_role ur ON ur.role_id = r.id
        WHERE ur.user_id = p_user_id
          AND r.resource = p_resource
          AND r.action = p_action
          AND r.granted = TRUE
    ) INTO v_has_right;
    
    RETURN v_has_right;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PERSONS (Counteragents) - extends object
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS persons;
SET search_path TO persons, base, public;

-- Person - контрагент (юридические/физические лица)
CREATE TABLE person (
    LIKE object INCLUDING ALL
) INHERITS (object);

-- Атрибуты Person
ALTER TABLE person ADD COLUMN inn VARCHAR(12);
ALTER TABLE person ADD COLUMN kpp VARCHAR(9);
ALTER TABLE person ADD COLUMN okpo VARCHAR(10);
ALTER TABLE person ADD COLUMN person_type SMALLINT DEFAULT 0;  -- 0: Company, 1: Individual, 2: Entrepreneur
ALTER TABLE person ADD COLUMN address_id BIGINT;
ALTER TABLE person ADD COLUMN phone VARCHAR(20);
ALTER TABLE person ADD COLUMN email VARCHAR(100);
ALTER TABLE person ADD COLUMN contact_person VARCHAR(200);
ALTER TABLE person ADD COLUMN credit_limit NUMERIC(15,2) DEFAULT 0;
ALTER TABLE person ADD COLUMN discount_percent NUMERIC(5,2) DEFAULT 0;

-- Индексы
CREATE INDEX idx_person_inn ON person(inn);
CREATE INDEX idx_person_kpp ON person(kpp);
CREATE INDEX idx_person_type ON person(person_type);

-- Employee - сотрудник (наследует Person)
CREATE TABLE employee (
    LIKE person INCLUDING ALL
) INHERITS (person);

ALTER TABLE employee ADD COLUMN position_id BIGINT;
ALTER TABLE employee ADD COLUMN hire_date DATE;
ALTER TABLE employee ADD COLUMN fire_date DATE;
ALTER TABLE employee ADD COLUMN salary NUMERIC(15,2);
ALTER TABLE employee ADD COLUMN department VARCHAR(100);

-- Manager - менеджер (наследует Employee)
CREATE TABLE manager (
    LIKE employee INCLUDING ALL
) INHERITS (employee);

ALTER TABLE manager ADD COLUMN team_id BIGINT;
ALTER TABLE manager ADD COLUMN quota NUMERIC(15,2);

-- ============================================================================
-- GOODS (Products) - extends object
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS goods;
SET search_path TO goods, base, public;

-- Goods - товар
CREATE TABLE goods (
    LIKE object INCLUDING ALL
) INHERITS (object);

ALTER TABLE goods ADD COLUMN barcode VARCHAR(50);
ALTER TABLE goods ADD COLUMN unit_id BIGINT;
ALTER TABLE goods ADD COLUMN parent_id BIGINT;
ALTER TABLE goods ADD COLUMN goods_type SMALLINT DEFAULT 0;  -- 0: Item, 1: Service, 2: Bundle
ALTER TABLE goods ADD COLUMN tax_id BIGINT;
ALTER TABLE goods ADD COLUMN country_id BIGINT;
ALTER TABLE goods ADD COLUMN manufacturer_id BIGINT;
ALTER TABLE goods ADD COLUMN weight NUMERIC(10,3);
ALTER TABLE goods ADD COLUMN volume NUMERIC(10,3);
ALTER TABLE goods ADD COLUMN min_stock NUMERIC(15,3) DEFAULT 0;
ALTER TABLE goods ADD COLUMN max_stock NUMERIC(15,3);
ALTER TABLE goods ADD COLUMN reorder_point NUMERIC(15,3);

CREATE INDEX idx_goods_barcode ON goods(barcode);
CREATE INDEX idx_goods_unit ON goods(unit_id);
CREATE INDEX idx_goods_parent ON goods(parent_id);
CREATE INDEX idx_goods_type ON goods(goods_type);

-- GoodsPrice - цены товаров
CREATE TABLE goods_price (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    price_type SMALLINT DEFAULT 0,  -- 0: Retail, 1: Wholesale, 2: Cost
    price NUMERIC(15,2) NOT NULL,
    currency_id BIGINT,
    min_qtty NUMERIC(15,3) DEFAULT 1,
    valid_from DATE,
    valid_to DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Service - услуга (наследует Goods)
CREATE TABLE service (
    LIKE goods INCLUDING ALL
) INHERITS (goods);

ALTER TABLE service ADD COLUMN duration_minutes INTEGER;
ALTER TABLE service ADD COLUMN warranty_days INTEGER;

-- Bundle - комплект (наследует Goods)
CREATE TABLE bundle (
    LIKE goods INCLUDING ALL
) INHERITS (goods);

ALTER TABLE bundle ADD COLUMN items JSONB;  -- [{goods_id, qtty}]

-- ============================================================================
-- WAREHOUSE & STOCK
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS warehouse;
SET search_path TO warehouse, base, public;

-- Location - место хранения (склад/магазин)
CREATE TABLE location (
    LIKE object INCLUDING ALL
) INHERITS (object);

ALTER TABLE location ADD COLUMN location_type SMALLINT DEFAULT 0;  -- 0: Warehouse, 1: Store, 2: Office
ALTER TABLE location ADD COLUMN address_id BIGINT;
ALTER TABLE location ADD COLUMN capacity NUMERIC(15,2);
ALTER TABLE location ADD COLUMN is_active BOOLEAN DEFAULT TRUE;

-- Stock - остатки товаров
CREATE TABLE stock (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    location_id BIGINT NOT NULL REFERENCES location(id),
    qtty NUMERIC(15,3) DEFAULT 0,
    resrv_qtty NUMERIC(15,3) DEFAULT 0,
    cost NUMERIC(15,2) DEFAULT 0,
    price NUMERIC(15,2) DEFAULT 0,
    batch_number VARCHAR(50),
    expiry_date DATE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(goods_id, location_id, batch_number)
);

CREATE INDEX idx_stock_goods ON stock(goods_id);
CREATE INDEX idx_stock_location ON stock(location_id);
CREATE INDEX idx_stock_expiry ON stock(expiry_date);

-- Stock movement - движение товаров
CREATE TABLE stock_movement (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    location_from_id BIGINT REFERENCES location(id),
    location_to_id BIGINT REFERENCES location(id),
    qtty NUMERIC(15,3) NOT NULL,
    movement_type SMALLINT NOT NULL,  -- 0: Receipt, 1: Issue, 2: Transfer, 3: Adjustment
    bill_id BIGINT,
    movement_date DATE NOT NULL,
    user_id BIGINT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_stock_movement_date ON stock_movement(movement_date);
CREATE INDEX idx_stock_movement_goods ON stock_movement(goods_id);

-- ============================================================================
-- DOCUMENTS
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS documents;
SET search_path TO documents, base, public;

-- Document - базовый класс документов
CREATE TABLE document (
    LIKE object INCLUDING ALL
) INHERITS (object);

ALTER TABLE document ADD COLUMN doc_date DATE NOT NULL;
ALTER TABLE document ADD COLUMN person_id BIGINT;
ALTER TABLE document ADD COLUMN location_id BIGINT;
ALTER TABLE document ADD COLUMN total NUMERIC(15,2) DEFAULT 0;
ALTER TABLE document ADD COLUMN tax_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE document ADD COLUMN discount_amount NUMERIC(15,2) DEFAULT 0;
ALTER TABLE document ADD COLUMN currency_id BIGINT;
ALTER TABLE document ADD COLUMN user_id BIGINT;
ALTER TABLE document ADD COLUMN posted_at TIMESTAMP;
ALTER TABLE document ADD COLUMN doc_status SMALLINT DEFAULT 0;  -- 0: Draft, 1: Registered, 2: Posted, 3: Annulled

CREATE INDEX idx_document_date ON document(doc_date);
CREATE INDEX idx_document_status ON document(doc_status);
CREATE INDEX idx_document_person ON document(person_id);

-- Bill - документ (накладная/чек)
CREATE TABLE bill (
    LIKE document INCLUDING ALL
) INHERITS (document);

ALTER TABLE bill ADD COLUMN bill_type SMALLINT DEFAULT 0;  -- 0: Sale, 1: Purchase, 2: Return
ALTER TABLE bill ADD COLUMN payment_method SMALLINT DEFAULT 0;
ALTER TABLE bill ADD COLUMN terminal_id BIGINT;

-- BillLine - строка документа
CREATE TABLE bill_line (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL REFERENCES bill(id),
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(15,3) NOT NULL,
    price NUMERIC(15,2) NOT NULL,
    discount_percent NUMERIC(5,2) DEFAULT 0,
    discount_amount NUMERIC(15,2) DEFAULT 0,
    tax_rate NUMERIC(5,2) DEFAULT 0,
    tax_amount NUMERIC(15,2) DEFAULT 0,
    amount NUMERIC(15,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_bill_line_bill ON bill_line(bill_id);

-- Order - заказ
CREATE TABLE order_head (
    LIKE document INCLUDING ALL
) INHERITS (document);

ALTER TABLE order_head ADD COLUMN delivery_address TEXT;
ALTER TABLE order_head ADD COLUMN delivery_date DATE;
ALTER TABLE order_head ADD COLUMN priority SMALLINT DEFAULT 0;

-- ============================================================================
-- ACCOUNTING
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS accounting;
SET search_path TO accounting, base, public;

-- AccPlan - план счетов
CREATE TABLE acc_plan (
    LIKE object INCLUDING ALL
) INHERITS (object);

ALTER TABLE acc_plan ADD COLUMN acc_type SMALLINT NOT NULL;  -- 0: Asset, 1: Liability, 2: Equity, 3: Revenue, 4: Expense
ALTER TABLE acc_plan ADD COLUMN parent_code VARCHAR(20);
ALTER TABLE acc_plan ADD COLUMN kind SMALLINT DEFAULT 0;
ALTER TABLE acc_plan ADD COLUMN is_analytical BOOLEAN DEFAULT FALSE;

CREATE INDEX idx_acc_plan_type ON acc_plan(acc_type);
CREATE INDEX idx_acc_plan_code ON acc_plan(code);

-- AccTurn - проводка
CREATE TABLE acc_turn (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT,
    dbt_acc_id BIGINT NOT NULL REFERENCES acc_plan(id),
    crd_acc_id BIGINT NOT NULL REFERENCES acc_plan(id),
    amount NUMERIC(15,2) NOT NULL,
    currency_id BIGINT,
    date DATE NOT NULL,
    memos TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_acc_turn_date ON acc_turn(date);
CREATE INDEX idx_acc_turn_bill ON acc_turn(bill_id);

-- Balance - остатки по счетам
CREATE TABLE acc_balance (
    acc_id BIGINT NOT NULL REFERENCES acc_plan(id),
    date DATE NOT NULL,
    debit_amount NUMERIC(15,2) DEFAULT 0,
    credit_amount NUMERIC(15,2) DEFAULT 0,
    PRIMARY KEY (acc_id, date)
);

-- ============================================================================
-- HR & SALARY
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS hr;
SET search_path TO hr, persons, base, public;

-- Position - должность
CREATE TABLE position (
    LIKE object INCLUDING ALL
) INHERITS (object);

ALTER TABLE position ADD COLUMN salary_from NUMERIC(15,2);
ALTER TABLE position ADD COLUMN salary_to NUMERIC(15,2);
ALTER TABLE position ADD COLUMN department VARCHAR(100);

-- Salary - зарплата
CREATE TABLE salary (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL,
    period DATE NOT NULL,  -- первый день месяца
    base_salary NUMERIC(15,2) DEFAULT 0,
    bonus NUMERIC(15,2) DEFAULT 0,
    penalty NUMERIC(15,2) DEFAULT 0,
    tax NUMERIC(15,2) DEFAULT 0,
    net_salary NUMERIC(15,2) DEFAULT 0,
    paid_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, period)
);

-- ============================================================================
-- PAYMENTS
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS payments;
SET search_path TO payments, documents, base, public;

-- Payment - платеж
CREATE TABLE payment (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT REFERENCES bill(id),
    date DATE NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    payment_method SMALLINT DEFAULT 0,  -- 0: Cash, 1: Card, 2: Transfer
    payment_status SMALLINT DEFAULT 0,  -- 0: Pending, 1: Completed, 2: Failed, 3: Refunded
    currency_id BIGINT,
    exchange_rate NUMERIC(15,6) DEFAULT 1,
    user_id BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Currency - валюта
CREATE TABLE currency (
    LIKE object INCLUDING ALL
) INHERITS (object);

ALTER TABLE currency ADD COLUMN symbol VARCHAR(5);
ALTER TABLE currency ADD COLUMN rate_to_base NUMERIC(15,6) DEFAULT 1;
ALTER TABLE currency ADD COLUMN is_base BOOLEAN DEFAULT FALSE;

-- ============================================================================
-- TAXES
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS taxes;
SET search_path TO taxes, base, public;

-- Tax - налог
CREATE TABLE tax (
    LIKE object INCLUDING ALL
) INHERITS (object);

ALTER TABLE tax ADD COLUMN rate NUMERIC(5,2) NOT NULL;
ALTER TABLE tax ADD COLUMN tax_type SMALLINT DEFAULT 0;  -- 0: VAT, 1: Excise, 2: Property
ALTER TABLE tax ADD COLUMN is_included BOOLEAN DEFAULT FALSE;  -- включен в цену или нет
ALTER TABLE tax ADD COLUMN tax_account_id BIGINT;  -- счет для начисления

-- ============================================================================
-- REPORTS
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS reports;
SET search_path TO reports, base, public;

-- ReportTemplate - шаблон отчета
CREATE TABLE report_template (
    LIKE object INCLUDING ALL
) INHERITS (object);

ALTER TABLE report_template ADD COLUMN report_type SMALLINT DEFAULT 0;
ALTER TABLE report_template ADD COLUMN jasper_file VARCHAR(200);
ALTER TABLE report_template ADD COLUMN parameters JSONB;
ALTER TABLE report_template ADD COLUMN output_format VARCHAR(20) DEFAULT 'PDF';

-- ReportHistory - история отчетов
CREATE TABLE report_history (
    id BIGSERIAL PRIMARY KEY,
    template_id BIGINT REFERENCES report_template(id),
    user_id BIGINT,
    parameters JSONB,
    status SMALLINT DEFAULT 0,
    file_path VARCHAR(500),
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- ============================================================================
-- AUDIT & LOGGING
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS audit;
SET search_path TO audit, base, public;

-- AuditLog - журнал аудита
CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT,
    action SMALLINT NOT NULL,  -- 0: Create, 1: Update, 2: Delete, 3: View
    table_name VARCHAR(50) NOT NULL,
    record_id BIGINT,
    old_values JSONB,
    new_values JSONB,
    ip_address VARCHAR(45),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_timestamp ON audit_log(timestamp);
CREATE INDEX idx_audit_table ON audit_log(table_name, record_id);

-- SystemLog - системный журнал
CREATE TABLE system_log (
    id BIGSERIAL PRIMARY KEY,
    level SMALLINT DEFAULT 0,  -- 0: Debug, 1: Info, 2: Warning, 3: Error
    module VARCHAR(50),
    message TEXT,
    details JSONB,
    user_id BIGINT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_system_log_timestamp ON system_log(timestamp);
CREATE INDEX idx_system_log_level ON system_log(level);

-- Функция логирования
CREATE OR REPLACE FUNCTION log_action(
    p_action SMALLINT,
    p_table VARCHAR,
    p_record_id BIGINT,
    p_old_values JSONB,
    p_new_values JSONB
) RETURNS VOID AS $$
BEGIN
    INSERT INTO audit_log (action, table_name, record_id, old_values, new_values)
    VALUES (p_action, p_table, p_record_id, p_old_values, p_new_values);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- UNIT OF WORK (Transaction Management)
-- ============================================================================

-- Начало транзакции с логированием
CREATE OR REPLACE FUNCTION begin_work(p_user_id BIGINT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO audit.system_log (level, module, message, user_id)
    VALUES (1, 'Transaction', 'Transaction started', p_user_id);
END;
$$ LANGUAGE plpgsql;

-- Фиксация транзакции
CREATE OR REPLACE FUNCTION commit_work(p_user_id BIGINT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO audit.system_log (level, module, message, user_id)
    VALUES (1, 'Transaction', 'Transaction committed', p_user_id);
END;
$$ LANGUAGE plpgsql;

-- Откат транзакции
CREATE OR REPLACE FUNCTION rollback_work(p_user_id BIGINT, p_reason TEXT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO audit.system_log (level, module, message, user_id, details)
    VALUES (2, 'Transaction', 'Transaction rolled back: ' || p_reason, p_user_id);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DATA EXPORT/IMPORT
-- ============================================================================

-- Экспорт данных в JSON
CREATE OR REPLACE FUNCTION export_table(p_table_name VARCHAR)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    EXECUTE format('SELECT jsonb_agg(row_to_json(t)) FROM %I t', p_table_name)
    INTO v_result;
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SEQUENCES FOR CODE GENERATION
-- ============================================================================

CREATE SEQUENCE goods_code_seq START WITH 100000;
CREATE SEQUENCE bill_code_seq START WITH 100000;
CREATE SEQUENCE order_code_seq START WITH 100000;
CREATE SEQUENCE person_code_seq START WITH 100000;

-- Генерация кода
CREATE OR REPLACE FUNCTION generate_code(p_prefix VARCHAR, p_seq_name VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    v_next BIGINT;
    v_code VARCHAR;
BEGIN
    EXECUTE format('SELECT nextval(%L)', p_seq_name) INTO v_next;
    v_code := p_prefix || v_next;
    RETURN v_code;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ACCESS RIGHTS (Encapsulation)
-- ============================================================================

-- Создание ролей
DO $$
BEGIN
    -- Роль для чтения
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'surypus_reader') THEN
        CREATE ROLE surypus_reader;
    END IF;
    
    -- Роль для записи
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'surypus_writer') THEN
        CREATE ROLE surypus_writer;
    END IF;
    
    -- Роль для администрирования
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'surypus_admin') THEN
        CREATE ROLE surypus_admin;
    END IF;
END
$$;

-- Назначение прав на схемы
GRANT USAGE ON SCHEMA base TO surypus_reader;
GRANT USAGE ON SCHEMA base TO surypus_writer;
GRANT ALL ON SCHEMA base TO surypus_admin;

GRANT SELECT ON ALL TABLES IN SCHEMA base TO surypus_reader;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA base TO surypus_writer;
GRANT ALL ON ALL TABLES IN SCHEMA base TO surypus_admin;

-- Права на последовательности
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA base TO surypus_writer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA base TO surypus_admin;

-- ============================================================================
-- FINALIZE
-- ============================================================================

RESET search_path;

-- Вывод информации
DO $$
BEGIN
    RAISE NOTICE 'Surypus Database Schema created successfully!';
    RAISE NOTICE 'Schemas: base, security, persons, goods, warehouse, documents, accounting, hr, payments, taxes, reports, audit';
    RAISE NOTICE 'Roles: surypus_reader, surypus_writer, surypus_admin';
END
$$;