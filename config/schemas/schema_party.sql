-- =============================================================================
-- КОНТРАГЕНТЫ (Party)
-- Соответствуют Core.Party.Party
-- =============================================================================

-- Таблица видов контрагентов
CREATE TABLE IF NOT EXISTS person_kinds (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    flags INT DEFAULT 0
);

INSERT INTO person_kinds (code, name) VALUES
    ('ORGANISATION', 'Юридическое лицо'),
    ('PERSON', 'Физическое лицо'),
    ('INDIVIDUAL', 'Индивидуальный предприниматель'),
    ('PRIVATE_ENTITY', 'Частное лицо')
ON CONFLICT DO NOTHING;

-- Таблица статусов контрагентов
CREATE TABLE IF NOT EXISTS person_statuses (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    flags INT DEFAULT 0
);

INSERT INTO person_statuses (code, name) VALUES
    ('PRIVATE', 'Частный'),
    ('LEGAL', 'Юридическое лицо')
ON CONFLICT DO NOTHING;

-- Таблица контрагентов (основная)
CREATE TABLE IF NOT EXISTS parties (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    inn VARCHAR(12) CHECK (LENGTH(inn) = 10 OR LENGTH(inn) = 12 OR inn = ''),
    kpp VARCHAR(9) CHECK (LENGTH(kpp) = 9 OR kpp = ''),
    ogrn VARCHAR(15) CHECK (LENGTH(ogrn) = 13 OR LENGTH(ogrn) = 15 OR ogrn = ''),
    okpo VARCHAR(10) CHECK (LENGTH(okpo) = 8 OR LENGTH(okpo) = 10 OR okpo = ''),
    kind_id INT REFERENCES person_kinds(id),
    status_id INT REFERENCES person_statuses(id),
    country_id INT DEFAULT 643,  -- Россия
    region_id INT,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Проверка ИНН при вставке
CREATE OR REPLACE FUNCTION check_party_inn()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.inn IS NOT NULL AND NEW.inn != '' THEN
        IF NOT validate_inn(NEW.inn) THEN
            RAISE EXCEPTION 'Invalid INN: %', NEW.inn;
        END IF;
    END IF;
    
    IF NEW.kpp IS NOT NULL AND NEW.kpp != '' THEN
        IF NOT validate_kpp(NEW.kpp) THEN
            RAISE EXCEPTION 'Invalid KPP: %', NEW.kpp;
        END IF;
    END IF;
    
    IF NEW.ogrn IS NOT NULL AND NEW.ogrn != '' THEN
        IF NOT validate_ogrn(NEW.ogrn) THEN
            RAISE EXCEPTION 'Invalid OGRN: %', NEW.ogrn;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_party_inn
    BEFORE INSERT OR UPDATE ON parties
    FOR EACH ROW
    EXECUTE FUNCTION check_party_inn();

-- Индексы для быстрого поиска
CREATE INDEX idx_parties_inn ON parties(inn) WHERE inn != '';
CREATE INDEX idx_parties_name ON parties(name);
CREATE INDEX idx_parties_kind ON parties(kind_id);
CREATE INDEX idx_parties_status ON parties(status_id);

-- Таблица типов отношений между контрагентами
CREATE TABLE IF NOT EXISTS person_relation_types (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    flags INT DEFAULT 0
);

INSERT INTO person_relation_types (code, name) VALUES
    ('EMPLOYEE', 'Работник'),
    ('OWNER', 'Владелец'),
    ('CLIENT', 'Клиент'),
    ('SUPPLIER', 'Поставщик'),
    ('PARTNER', 'Партнёр'),
    ('AGENT', 'Агент'),
    ('CONTRACTOR', 'Подрядчик'),
    ('CARRIER', 'Перевозчик')
ON CONFLICT DO NOTHING;

-- Таблица отношений между контрагентами
CREATE TABLE IF NOT EXISTS person_relations (
    id SERIAL PRIMARY KEY,
    owner_id INT NOT NULL REFERENCES parties(id),
    related_id INT NOT NULL REFERENCES parties(id),
    rel_type_id INT NOT NULL REFERENCES person_relation_types(id),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_person_relations_unique 
    ON person_relations(owner_id, related_id, rel_type_id);

-- Таблица контактов
CREATE TABLE IF NOT EXISTS contacts (
    id SERIAL PRIMARY KEY,
    party_id INT NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL,  -- 'PHONE', 'EMAIL', 'ADDRESS', 'WEBSITE', 'FAX', 'TELEGRAM', 'WHATSAPP'
    value VARCHAR(500) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_contacts_party ON contacts(party_id);
CREATE INDEX idx_contacts_type ON contacts(type);

-- Таблица адресов
CREATE TABLE IF NOT EXISTS addresses (
    id SERIAL PRIMARY KEY,
    party_id INT NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL,  -- 'LEGAL', 'PHYSICAL', 'MAILING', 'DELIVERY'
    country_id INT DEFAULT 643,
    region_id INT,
    city VARCHAR(100),
    street VARCHAR(200),
    building VARCHAR(50),
    office VARCHAR(50),
    zip_code VARCHAR(6) CHECK (LENGTH(zip_code) = 6 OR zip_code = ''),
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_addresses_party ON addresses(party_id);

-- Таблица статей (для расчётов)
CREATE TABLE IF NOT EXISTS articles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    party_id INT REFERENCES parties(id),
    acc_sheet_id INT NOT NULL,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_articles_party ON articles(party_id);
CREATE INDEX idx_articles_acc_sheet ON articles(acc_sheet_id);

-- Функция поиска контрагента по ИНН
CREATE OR REPLACE FUNCTION find_party_by_inn(search_inn TEXT)
RETURNS SETOF parties AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM parties
    WHERE inn = search_inn
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Функция поиска контрагентов по наименованию
CREATE OR REPLACE FUNCTION find_parties_by_name(search_name TEXT)
RETURNS SETOF parties AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM parties
    WHERE name ILIKE '%' || search_name || '%'
    ORDER BY name;
END;
$$ LANGUAGE plpgsql;
