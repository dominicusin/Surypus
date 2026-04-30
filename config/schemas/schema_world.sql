-- =================================================================
-- World Objects - Географические объекты
-- =================================================================
-- Analog:  pplib/objworld.cpp, pp.h (PPObjWorld)
-- 
-- Содержит:
-- - Страны, регионы, города, улицы
-- - Иерархическая структура
-- =================================================================

-- Country (справочник стран)
CREATE TABLE IF NOT EXISTS country (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    abbr VARCHAR(50),
    code BIGINT,                     -- Цифровой код (ISO 3166-1)
    iso_code VARCHAR(2) UNIQUE,      -- Буквенный код (ISO 3166-1 alpha-2)
    phone_code VARCHAR(10),          -- Телефонный код
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_country_iso ON country(iso_code);
CREATE INDEX IF NOT EXISTS idx_country_code ON country(code);
CREATE INDEX IF NOT EXISTS idx_country_name ON country USING gin(name gin_trgm_ops);

-- World Object (географические объекты)
CREATE TABLE IF NOT EXISTS world_object (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    abbr VARCHAR(50),
    kind SMALLINT NOT NULL,          -- WORLDOBJ_XXX (1=Continent, 3=Country, 5=City, etc)
    code BIGINT DEFAULT 0,           -- ОКАТО для городов
    parent_id BIGINT REFERENCES world_object(id),  -- Родительский объект
    country_id BIGINT REFERENCES country(id),      -- Страна (для регионов/городов)
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_world_object_kind ON world_object(kind);
CREATE INDEX IF NOT EXISTS idx_world_object_parent ON world_object(parent_id);
CREATE INDEX IF NOT EXISTS idx_world_object_country ON world_object(country_id);
CREATE INDEX IF NOT EXISTS idx_world_object_code ON world_object(code) WHERE code != 0;
CREATE INDEX IF NOT EXISTS idx_world_object_name ON world_object USING gin(name gin_trgm_ops);

-- Street (улицы)
CREATE TABLE IF NOT EXISTS street (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type SMALLINT DEFAULT 0,         -- STREET_TYPE_XXX
    city_id BIGINT NOT NULL REFERENCES world_object(id),
    code BIGINT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_street_city ON street(city_id);
CREATE INDEX IF NOT EXISTS idx_street_name ON street USING gin(name gin_trgm_ops);

-- =================================================================
-- Default Countries (основные страны)
-- =================================================================

INSERT INTO country (name, abbr, code, iso_code, phone_code) VALUES
    ('Россия', 'РФ', 643, 'RU', '+7'),
    ('Украина', 'УКР', 804, 'UA', '+380'),
    ('Беларусь', 'БЕЛ', 112, 'BY', '+375'),
    ('Казахстан', 'КЗ', 398, 'KZ', '+7'),
    ('Германия', 'ГЕР', 276, 'DE', '+49'),
    ('Франция', 'ФР', 250, 'FR', '+33'),
    ('США', 'США', 840, 'US', '+1'),
    ('Китай', 'КНР', 156, 'CN', '+86'),
    ('Япония', 'ЯП', 392, 'JP', '+81'),
    ('Великобритания', 'ВБ', 826, 'GB', '+44')
ON CONFLICT DO NOTHING;

-- =================================================================
-- Russia Regions (субъекты РФ)
-- =================================================================

INSERT INTO world_object (name, kind, code, parent_id, country_id) VALUES
    ('Москва', 5, 45000000000, NULL, (SELECT id FROM country WHERE iso_code = 'RU')),
    ('Московская область', 4, 50000000000, NULL, (SELECT id FROM country WHERE iso_code = 'RU')),
    ('Санкт-Петербург', 5, 40000000000, NULL, (SELECT id FROM country WHERE iso_code = 'RU')),
    ('Ленинградская область', 4, 47000000000, NULL, (SELECT id FROM country WHERE iso_code = 'RU')),
    ('Краснодарский край', 4, 23000000000, NULL, (SELECT id FROM country WHERE iso_code = 'RU')),
    ('Свердловская область', 4, 66000000000, NULL, (SELECT id FROM country WHERE iso_code = 'RU')),
    ('Республика Татарстан', 4, 16000000000, NULL, (SELECT id FROM country WHERE iso_code = 'RU')),
    ('Новосибирская область', 4, 54000000000, NULL, (SELECT id FROM country WHERE iso_code = 'RU')),
    ('Ростовская область', 4, 60000000000, NULL, (SELECT id FROM country WHERE iso_code = 'RU')),
    ('Челябинская область', 4, 75000000000, NULL, (SELECT id FROM country WHERE iso_code = 'RU'))
ON CONFLICT DO NOTHING;

-- =================================================================
-- Functions and Triggers
-- =================================================================

-- Function to get full address path
CREATE OR REPLACE FUNCTION get_full_address_path(BIGINT)
RETURNS TEXT AS $$
DECLARE
    obj_id ALIAS FOR $1;
    result TEXT;
BEGIN
    WITH RECURSIVE address_path AS (
        SELECT id, name, kind, parent_id, 1 as level
        FROM world_object
        WHERE id = obj_id
        
        UNION ALL
        
        SELECT w.id, w.name, w.kind, w.parent_id, ap.level + 1
        FROM world_object w
        JOIN address_path ap ON w.id = ap.parent_id
    )
    SELECT string_agg(name, ', ' ORDER BY level DESC)
    INTO result
    FROM address_path;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql STABLE;

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_world_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_country_update
    BEFORE UPDATE ON country
    FOR EACH ROW EXECUTE FUNCTION update_world_timestamp();

CREATE TRIGGER tr_world_object_update
    BEFORE UPDATE ON world_object
    FOR EACH ROW EXECUTE FUNCTION update_world_timestamp();

CREATE TRIGGER tr_street_update
    BEFORE UPDATE ON street
    FOR EACH ROW EXECUTE FUNCTION update_world_timestamp();

-- =================================================================
-- Views
-- =================================================================

-- Countries list
CREATE OR REPLACE VIEW v_countries AS
SELECT id, name, abbr, code, iso_code, phone_code
FROM country
ORDER BY name;

-- Regions by country
CREATE OR REPLACE VIEW v_regions AS
SELECT w.id, w.name, w.code, w.country_id, c.name as country_name
FROM world_object w
JOIN country c ON c.id = w.country_id
WHERE w.kind = 4  -- WorldObjRegion
ORDER BY c.name, w.name;

-- Cities by region
CREATE OR REPLACE VIEW v_cities AS
SELECT w.id, w.name, w.code, w.parent_id as region_id, 
       w.country_id, w.parent_id,
       (SELECT name FROM world_object WHERE id = w.parent_id) as region_name
FROM world_object w
WHERE w.kind = 5  -- WorldObjCity
ORDER BY region_name, w.name;

-- =================================================================
-- Comments
-- =================================================================

COMMENT ON TABLE country IS 'Справочник стран (аналог CountryTbl)';
COMMENT ON TABLE world_object IS 'Географические объекты (аналог WorldTbl)';
COMMENT ON TABLE street IS 'Улицы (аналог StreetTbl)';

COMMENT ON COLUMN world_object.kind IS 'Тип объекта: 1=Континент, 2=Георегион, 3=Страна, 4=Регион, 5=Город, 6=Улица, 7=Район';
COMMENT ON COLUMN world_object.code IS 'ОКАТО для городов и регионов';
