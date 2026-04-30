-- =============================================================================
-- СПРАВОЧНИКИ СИСТЕМЫ (REFERENCES)
-- Соответствуют Core.Reference
-- Аналог:  pplib/objref.cpp, objartcl.cpp, objggrp.cpp
-- =============================================================================

-- =============================================================================
-- Person Status (Юридические статусы персоналий)
-- Аналог: PPOBJ_PRSNSTATUS
-- =============================================================================
CREATE TABLE IF NOT EXISTS person_status (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16) NOT NULL UNIQUE,
    kind INT DEFAULT 0,  -- 0:ЮЛ, 1:ИП, 2:ФЛ, 3:Иностранное
    flags INT DEFAULT 0,
    parent_id INT REFERENCES person_status(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_person_status_symb ON person_status(symb);
CREATE INDEX idx_person_status_parent ON person_status(parent_id);

-- =============================================================================
-- Person Kind (Виды персоналий)
-- Аналог: PPOBJ_PERSONKIND
-- =============================================================================
CREATE TABLE IF NOT EXISTS person_kind (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16) NOT NULL UNIQUE,
    flags INT DEFAULT 0,
    parent_id INT REFERENCES person_kind(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_person_kind_symb ON person_kind(symb);
CREATE INDEX idx_person_kind_parent ON person_kind(parent_id);

-- =============================================================================
-- Operation Kind (Виды операций)
-- Аналог: PPOBJ_OPRKIND
-- =============================================================================
CREATE TABLE IF NOT EXISTS op_kind (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    type INT NOT NULL DEFAULT 0,  -- 0:Товарная, 1:Бухгалтерская, 2:Персональная, 3:Кадровая, 4,Сервисная, 5:Разное
    flags INT DEFAULT 0,
    acc_sheet_id INT,
    main_org_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_op_kind_type ON op_kind(type);
-- CREATE INDEX idx_op_kind_acc_sheet ON op_kind(acc_sheet_id);

-- =============================================================================
-- Account Sheet (Таблицы аналитических статей)
-- Аналог: PPOBJ_ACCSHEET
-- =============================================================================
CREATE TABLE IF NOT EXISTS acc_sheet (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16) NOT NULL UNIQUE,
    kind INT DEFAULT 0,  -- 0:Товарная, 1:Бухгалтерская, 2:Персональная
    flags INT DEFAULT 0,
    assoc INT DEFAULT 0,  -- 0:Нет, 1:Person, 2:Location, 3:Account
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_acc_sheet_symb ON acc_sheet(symb);

-- =============================================================================
-- Goods Type (Типы товаров)
-- Аналог: PPOBJ_GOODSTYPE
-- =============================================================================
CREATE TABLE IF NOT EXISTS goods_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(16),
    flags INT DEFAULT 0,
    parent_id INT REFERENCES goods_type(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_type_parent ON goods_type(parent_id);
CREATE INDEX idx_goods_type_code ON goods_type(code) WHERE code IS NOT NULL;

-- =============================================================================
-- Quotation Kind (Виды котировок)
-- Аналог: PPOBJ_QUOTKIND
-- =============================================================================
CREATE TABLE IF NOT EXISTS quot_kind (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    flags INT DEFAULT 0,
    currency_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- CREATE INDEX idx_quot_kind_currency ON quot_kind(currency_id);

-- =============================================================================
-- Tag (Теги объектов)
-- Аналог: PPOBJ_TAG
-- =============================================================================
CREATE TABLE IF NOT EXISTS tag (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    type INT NOT NULL DEFAULT 0,  -- 0:String, 1:Number, 2:Date, 3:DateTime, 4:Bool, 5:Enum, 6:Link
    obj_type INT NOT NULL,  -- PPOBJ_XXX
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tag_obj_type ON tag(obj_type);
CREATE INDEX idx_tag_symb ON tag(symb) WHERE symb IS NOT NULL;

-- =============================================================================
-- Cash Node (Кассовые узлы)
-- Аналог: PPOBJ_CASHNODE
-- =============================================================================
CREATE TABLE IF NOT EXISTS cash_node (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    location_id INT,
    flags INT DEFAULT 0,
    currency_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- CREATE INDEX idx_cash_node_location ON cash_node(location_id);
-- CREATE INDEX idx_cash_node_currency ON cash_node(currency_id);

-- =============================================================================
-- Staff Calendar (Штатные календари)
-- Аналог: PPOBJ_STAFFCAL
-- =============================================================================
CREATE TABLE IF NOT EXISTS staff_calendar (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    year INT NOT NULL CHECK (year >= 2000 AND year <= 2100),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_staff_calendar_year ON staff_calendar(year);

-- =============================================================================
-- Staff Calendar Day (Дни штатного календаря)
-- =============================================================================
CREATE TABLE IF NOT EXISTS staff_calendar_day (
    id SERIAL PRIMARY KEY,
    calendar_id INT NOT NULL REFERENCES staff_calendar(id) ON DELETE CASCADE,
    month INT NOT NULL CHECK (month >= 1 AND month <= 12),
    day INT NOT NULL CHECK (day >= 1 AND day <= 31),
    hours DECIMAL(4,2) DEFAULT 8 CHECK (hours >= 0 AND hours <= 24),
    flags INT DEFAULT 0,  -- 0:Рабочий, 1:Выходной, 2: Праздник
    UNIQUE(calendar_id, month, day)
);

CREATE INDEX idx_staff_calendar_day ON staff_calendar_day(calendar_id, month, day);

-- =============================================================================
-- Salary Charge (Схемы начисления зарплаты)
-- Аналог: PPOBJ_SALCHARGE
-- =============================================================================
CREATE TABLE IF NOT EXISTS salary_charge (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- Amount Type (Типы сумм документов)
-- Аналог: PPOBJ_AMOUNTTYPE
-- =============================================================================
CREATE TABLE IF NOT EXISTS amount_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(16) NOT NULL UNIQUE,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- Counter (Счетчики)
-- Аналог: PPOBJ_OPCOUNTER
-- =============================================================================
CREATE TABLE IF NOT EXISTS counter (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    obj_type INT NOT NULL DEFAULT 0,  -- PPOBJ_XXX (0 = OpKind)
    value INT DEFAULT 0,
    step INT DEFAULT 1,
    prefix VARCHAR(10),
    suffix VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_counter_obj_type ON counter(obj_type);

-- =============================================================================
-- DateTime Period (Периодичность)
-- Аналог: PPOBJ_DATETIMEREP
-- =============================================================================
CREATE TABLE IF NOT EXISTS datetime_period (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(16) NOT NULL UNIQUE,
    kind INT NOT NULL,  -- 0:Раз в, 1:Каждый
    period INT NOT NULL,  -- 1,2,3,...
    unit INT NOT NULL,  -- 0:День, 1:Неделя, 2:Месяц, 3:Квартал, 4:Год
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- Duty Schedule (Расписание дежурств)
-- Аналог: PPOBJ_DUTYSCHED
-- =============================================================================
CREATE TABLE IF NOT EXISTS duty_schedule (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    staff_calendar_id INT,
    person_id INT,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- CREATE INDEX idx_duty_schedule_calendar ON duty_schedule(staff_calendar_id);
-- CREATE INDEX idx_duty_schedule_person ON duty_schedule(person_id);

-- =============================================================================
-- Freight Package Type (Типы транспортной упаковки)
-- Аналог: PPOBJ_FREIGHTPACKAGETYPE
-- =============================================================================
CREATE TABLE IF NOT EXISTS freight_package_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(16) NOT NULL UNIQUE,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- Tax System Kind (Виды систем налогообложения)
-- Аналог: PPOBJ_TAXSYSTEMKIND
-- =============================================================================
CREATE TABLE IF NOT EXISTS tax_system_kind (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(16) NOT NULL UNIQUE,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- Обновление updated_at при изменении записи
CREATE OR REPLACE FUNCTION update_reference_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггеры для всех справочников
CREATE TRIGGER trigger_person_status_update
    BEFORE UPDATE ON person_status FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_person_kind_update
    BEFORE UPDATE ON person_kind FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_op_kind_update
    BEFORE UPDATE ON op_kind FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_acc_sheet_update
    BEFORE UPDATE ON acc_sheet FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_goods_type_update
    BEFORE UPDATE ON goods_type FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_quot_kind_update
    BEFORE UPDATE ON quot_kind FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_tag_update
    BEFORE UPDATE ON tag FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_cash_node_update
    BEFORE UPDATE ON cash_node FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_staff_calendar_update
    BEFORE UPDATE ON staff_calendar FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_salary_charge_update
    BEFORE UPDATE ON salary_charge FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_amount_type_update
    BEFORE UPDATE ON amount_type FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_counter_update
    BEFORE UPDATE ON counter FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_datetime_period_update
    BEFORE UPDATE ON datetime_period FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_duty_schedule_update
    BEFORE UPDATE ON duty_schedule FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_freight_package_type_update
    BEFORE UPDATE ON freight_package_type FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

CREATE TRIGGER trigger_tax_system_kind_update
    BEFORE UPDATE ON tax_system_kind FOR EACH ROW
    EXECUTE FUNCTION update_reference_timestamp();

-- =============================================================================
-- INITIAL DATA
-- =============================================================================

-- Валюты по умолчанию (если ещё не существуют)
INSERT INTO currency (code, name, symbol, rate, scale, flags) VALUES
    ('RUB', 'Российский рубль', '₽', 1.0, 2, 1),
    ('USD', 'Доллар США', '$', 75.0, 2, 0),
    ('EUR', 'Евро', '€', 85.0, 2, 0)
ON CONFLICT (code) DO NOTHING;

-- Единицы измерения по умолчанию
INSERT INTO unit (code, name, sym_code, kind, ratio, flags) VALUES
    ('PC', 'Штука', 'шт', 0, 1.0, 0),
    ('KG', 'Килограмм', 'кг', 1, 1.0, 0),
    ('G', 'Грамм', 'г', 1, 0.001, 0),
    ('L', 'Литр', 'л', 3, 1.0, 0),
    ('M', 'Метр', 'м', 2, 1.0, 0),
    ('M2', 'Квадратный метр', 'м²', 2, 1.0, 0),
    ('M3', 'Кубический метр', 'м³', 3, 1.0, 0),
    ('HR', 'Час', 'ч', 5, 1.0, 0),
    ('DAY', 'День', 'дн', 5, 1.0, 0)
ON CONFLICT (code) DO NOTHING;

-- Виды персоналий
INSERT INTO person_kind (name, symb, flags) VALUES
    ('Юридическое лицо', 'ORGANISATION', 0),
    ('Физическое лицо', 'PERSON', 0),
    ('Индивидуальный предприниматель', 'INDIVIDUAL', 0),
    ('Частное лицо', 'PRIVATE_ENTITY', 0)
ON CONFLICT (symb) DO NOTHING;

-- Статусы персоналий
INSERT INTO person_status (name, symb, kind, flags) VALUES
    ('Действующий', 'ACTIVE', 0, 0),
    ('Заблокирован', 'BLOCKED', 0, 0),
    ('В архиве', 'ARCHIVED', 0, 0),
    ('Непроверенный', 'UNVERIFIED', 0, 0)
ON CONFLICT (symb) DO NOTHING;

-- Типы сумм
INSERT INTO amount_type (name, symb, flags) VALUES
    ('Сумма без НДС', 'NET', 0),
    ('Сумма с НДС', 'VAT', 0),
    ('НДС', 'VATAMT', 0),
    ('Скидка', 'DISC', 0),
    ('Стоимость', 'COST', 0),
    ('Цена', 'PRICE', 0)
ON CONFLICT (symb) DO NOTHING;

-- Периодичность
INSERT INTO datetime_period (name, code, kind, period, unit, flags) VALUES
    ('Ежедневно', 'DAILY', 1, 1, 0, 0),
    ('Еженедельно', 'WEEKLY', 1, 1, 1, 0),
    ('Ежемесячно', 'MONTHLY', 1, 1, 2, 0),
    ('Ежеквартально', 'QUARTERLY', 1, 1, 3, 0),
    ('Ежегодно', 'YEARLY', 1, 1, 4, 0)
ON CONFLICT (code) DO NOTHING;
