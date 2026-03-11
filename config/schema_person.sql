-- ============================================================
-- Person Tables - Персоны (контрагенты, сотрудники)
-- ============================================================

-- Основная таблица персон
CREATE TABLE IF NOT EXISTS person (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    full_name VARCHAR(512),
    inn VARCHAR(12),
    kpp VARCHAR(9),
    ogrn VARCHAR(15),
    okpo VARCHAR(10),
    ptype SMALLINT NOT NULL DEFAULT 0,  -- 0=PERSON, 1=JURIDICAL, 2=INDIVIDUAL_ENTR, 3=BANK, 4=AGENT
    category SMALLINT DEFAULT 0,         -- 0=CLIENT, 1=SUPPLIER, 2=EMPLOYEE, 3=PARTNER, 4=COMPETITOR, 5=OTHER
    status SMALLINT DEFAULT 0,           -- 0=ACTIVE, 1=BLOCKED, 2=CLOSED, 3=ARCHIVED
    flags INTEGER DEFAULT 0,
    address TEXT,
    phone VARCHAR(32),
    email VARCHAR(128),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    credit_limit NUMERIC(18,4) DEFAULT 0,
    discount NUMERIC(6,2) DEFAULT 0,
    UNIQUE(code)
);

-- Адреса персон
CREATE TABLE IF NOT EXISTS personaddress (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id),
    atype SMALLINT DEFAULT 0,            -- 0=REGISTRY, 1=FACTUAL, 2=POSTAL, 3=DELIVERY
    country_id BIGINT REFERENCES country(id),
    region_id BIGINT REFERENCES region(id),
    district VARCHAR(128),
    city VARCHAR(128),
    town VARCHAR(128),
    street VARCHAR(256),
    house VARCHAR(32),
    flat VARCHAR(32),
    zip VARCHAR(16),
    is_default BOOLEAN DEFAULT FALSE
);

-- Контакты персон
CREATE TABLE IF NOT EXISTS personcontact (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id),
    phone VARCHAR(32),
    phone_add VARCHAR(32),
    email VARCHAR(128),
    email_add VARCHAR(128),
    website VARCHAR(256),
    fax VARCHAR(32),
    telegram VARCHAR(64),
    whatsapp VARCHAR(32),
    is_default BOOLEAN DEFAULT FALSE
);

-- Банковские счета
CREATE TABLE IF NOT EXISTS personbankaccount (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id),
    bank_name VARCHAR(256) NOT NULL,
    bank_bik VARCHAR(9) NOT NULL,
    account VARCHAR(34) NOT NULL,
    corr_account VARCHAR(34),
    is_default BOOLEAN DEFAULT FALSE
);

-- Сотрудники
CREATE TABLE IF NOT EXISTS employee (
    person_id BIGINT PRIMARY KEY REFERENCES person(id),
    tab_num VARCHAR(16) NOT NULL,
    position_id BIGINT,
    department_id BIGINT,
    hire_date DATE NOT NULL,
    dismiss_date DATE,
    salary DECIMAL(18,4),
    staff_list_id BIGINT,
    flags INTEGER DEFAULT 0
);

-- Должности
CREATE TABLE IF NOT EXISTS position (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(128) NOT NULL,
    category SMALLINT DEFAULT 0,         -- 0=MANAGER, 1=SPECIALIST, 2=WORKER, 3=SERVICE
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Подразделения
CREATE TABLE IF NOT EXISTS department (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(128) NOT NULL,
    parent_id BIGINT REFERENCES department(id),
    head_id BIGINT REFERENCES employee(person_id),
    UNIQUE(code)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_person_inn ON person(inn);
CREATE INDEX IF NOT EXISTS idx_person_kpp ON person(kpp);
CREATE INDEX IF NOT EXISTS idx_person_type ON person(ptype);
CREATE INDEX IF NOT EXISTS idx_person_category ON person(category);
CREATE INDEX IF NOT EXISTS idx_personaddress_person ON personaddress(person_id);
CREATE INDEX IF NOT EXISTS idx_personcontact_person ON personcontact(person_id);
CREATE INDEX IF NOT EXISTS idx_personbankaccount_person ON personbankaccount(person_id);
CREATE INDEX IF NOT EXISTS idx_employee_tab ON employee(tab_num);
