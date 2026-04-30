-- ============================================================
-- Service Tables - Услуги
-- ============================================================

-- Service types (типы услуг)
CREATE TABLE IF NOT EXISTS service_type (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(64) NOT NULL,
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Services (услуги)
CREATE TABLE IF NOT EXISTS service (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    type_id BIGINT REFERENCES service_type(id),
    unit_id BIGINT NOT NULL REFERENCES unit(id),
    price NUMERIC(18,4) NOT NULL DEFAULT 0,
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_service_code ON service(code);
CREATE INDEX IF NOT EXISTS idx_service_type ON service(type_id);

-- ============================================================
-- Представления
-- ============================================================

-- Услуги по типам
CREATE VIEW v_services_by_type AS
SELECT 
    s.id, s.code, s.name, st.name AS type_name, u.name AS unit_name, s.price
FROM service s
LEFT JOIN service_type st ON st.id = s.type_id
JOIN unit u ON u.id = s.unit_id
ORDER BY st.name, s.name;
