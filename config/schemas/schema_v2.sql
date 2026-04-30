-- =============================================================================
-- Surypus - PostgreSQL Schema
-- =============================================================================
-- Перепроектировано с использованием возможностей PostgreSQL:
-- - Partitioning для больших таблиц
-- - Materialized Views для аналитики
-- - Row Level Security для безопасности
-- - JSONB для гибких данных
-- - Event Triggers для аудита
-- =============================================================================

-- ============================================================
-- Extensions
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "hstore";
CREATE EXTENSION IF NOT EXISTS "postgis";  -- Для геоданных
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";  -- Для мониторинга

-- ============================================================
-- Core Tables - Основные таблицы
-- ============================================================

-- | Parties (контрагенты) - нормализованная схема
CREATE TABLE parties (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    kind SMALLINT NOT NULL DEFAULT 0,  -- 0=Person, 1=Org, 2=Employee и т.д.
    status SMALLINT NOT NULL DEFAULT 0, -- 0=Active
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Полная информация в JSONB для гибкости
    extra JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_parties_name ON parties USING gin(name gin_trgm_ops);
CREATE INDEX idx_parties_kind ON parties(kind);
CREATE INDEX idx_parties_status ON parties(status);

-- | Registrations (регистрации - ИНН, КПП и т.д.)
CREATE TABLE party_registrations (
    id BIGSERIAL PRIMARY KEY,
    party_id BIGINT NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
    reg_type_id SMALLINT NOT NULL,  -- 1=INN, 2=KPP, 3=OGRN и т.д.
    number VARCHAR(64) NOT NULL,
    flags INTEGER DEFAULT 0,
    issued_date DATE,
    expiry_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(party_id, reg_type_id)
);

CREATE INDEX idx_party_registrations_party ON party_registrations(party_id);
CREATE INDEX idx_party_registrations_inn ON party_registrations(number) 
    WHERE reg_type_id = 1;

-- | Electronic links (телефоны, email)
CREATE TABLE party_contacts (
    id BIGSERIAL PRIMARY KEY,
    party_id BIGINT NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
    contact_type SMALLINT NOT NULL,  -- 1=Phone, 2=Email, 3=WWW, 4=Telegram
    address VARCHAR(256) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_party_contacts_party ON party_contacts(party_id);

-- | Addresses (адреса)
CREATE TABLE party_addresses (
    id BIGSERIAL PRIMARY KEY,
    party_id BIGINT NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
    address_type SMALLINT NOT NULL DEFAULT 0,  -- 0=Legal, 1=Postal, 2=Delivery
    country VARCHAR(64),
    region VARCHAR(128),
    city VARCHAR(128),
    district VARCHAR(128),
    street VARCHAR(256),
    house VARCHAR(32),
    building VARCHAR(32),
    flat VARCHAR(32),
    zip_code VARCHAR(16),
    coordinates POINT,  -- PostGIS
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_party_addresses_party ON party_addresses(party_id);

-- ============================================================
-- Goods - Товары
-- ============================================================

CREATE TABLE goods (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(16),  -- Артикул
    barcode VARCHAR(64),
    kind SMALLINT NOT NULL DEFAULT 0,  -- 0=Goods, 1=Service, 2=Composite
    parent_id BIGINT REFERENCES goods(id),
    flags INTEGER DEFAULT 0,
    unit_id BIGINT,
    tax_group_id BIGINT,
    brand_id BIGINT,
    manuf_id BIGINT REFERENCES parties(id),
    goods_class_id BIGINT,
    is_phantom BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    extra JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_goods_name ON goods USING gin(name gin_trgm_ops);
CREATE INDEX idx_goods_code ON goods(code);
CREATE INDEX idx_goods_barcode ON goods(barcode);
CREATE INDEX idx_goods_parent ON goods(parent_id);
CREATE INDEX idx_goods_class ON goods(goods_class_id);

-- | Goods Barcodes
CREATE TABLE goods_barcodes (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE CASCADE,
    barcode VARCHAR(64) NOT NULL,
    barcode_type SMALLINT DEFAULT 0,  -- 0=EAN13, 1=Code128, 2=QR
    qtty NUMERIC(18,4) DEFAULT 1,  -- Для весовых штрих-кодов
    UNIQUE(barcode)
);

CREATE INDEX idx_goods_barcodes_goods ON goods_barcodes(goods_id);

-- | Goods Prices - Цены
CREATE TABLE goods_prices (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE CASCADE,
    price_list_id BIGINT NOT NULL,
    price NUMERIC(18,4) NOT NULL,
    min_qtty NUMERIC(18,4) DEFAULT 1,
    discount_percent NUMERIC(6,2) DEFAULT 0,
    valid_from DATE,
    valid_to DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_goods_prices_goods ON goods_prices(goods_id);
CREATE INDEX idx_goods_prices_list ON goods_prices(price_list_id);

-- | Goods Class - Классы товаров
CREATE TABLE goods_classes (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES goods_classes(id),
    kind SMALLINT DEFAULT 0,
    flags INTEGER DEFAULT 0,
    properties JSONB DEFAULT '{}'::jsonb
);

-- | Composite Structure (спецификации/BOM)
CREATE TABLE goods_composition (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    component_goods_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 1,
    yield_percent NUMERIC(6,2),
    UNIQUE(goods_id, component_goods_id)
);

-- ============================================================
-- Locations - Склады/Местоположения
-- ============================================================

CREATE TABLE locations (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,  -- 0=Warehouse, 1=Address, 2=Terminal
    parent_id BIGINT REFERENCES locations(id),
    flags INTEGER DEFAULT 0,
    address_id BIGINT REFERENCES party_addresses(id),
    timezone VARCHAR(64) DEFAULT 'UTC',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_locations_parent ON locations(parent_id);

-- ============================================================
-- Documents - Документы (Partitioned by month)
-- =================================================================
-- Используем partitioning для производительности при большом объеме

CREATE TABLE documents (
    id BIGSERIAL,
    code VARCHAR(16) NOT NULL,
    doc_date DATE NOT NULL,
    op_kind_id BIGINT NOT NULL,
    party_id BIGINT REFERENCES parties(id),
    party2_id BIGINT REFERENCES parties(id),
    location_id BIGINT NOT NULL REFERENCES locations(id),
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    currency_id BIGINT NOT NULL DEFAULT 1,
    c_rate NUMERIC(18,9) NOT NULL DEFAULT 1,
    flags INTEGER DEFAULT 0,
    status SMALLINT NOT NULL DEFAULT 0,
    link_doc_id BIGINT,
    due_date DATE,
    scard_id BIGINT,
    memo TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (id, doc_date)
) PARTITION BY RANGE (doc_date);

-- | Partition for current year
CREATE TABLE documents_2026 PARTITION OF documents
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

-- | Document Lines
CREATE TABLE document_lines (
    id BIGSERIAL PRIMARY KEY,
    doc_id BIGINT NOT NULL,
    doc_date DATE NOT NULL,
    line_num SMALLINT NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    price NUMERIC(18,4) NOT NULL DEFAULT 0,
    discount NUMERIC(18,4) NOT NULL DEFAULT 0,
    tax_percent NUMERIC(6,2) NOT NULL DEFAULT 0,
    tax_amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    total NUMERIC(18,4) NOT NULL DEFAULT 0,
    unit_id BIGINT,
    lot_id BIGINT,
    
    FOREIGN KEY (doc_id, doc_date) REFERENCES documents(id, doc_date) ON DELETE CASCADE
);

CREATE INDEX idx_document_lines_doc ON document_lines(doc_id, doc_date);
CREATE INDEX idx_document_lines_goods ON document_lines(goods_id);

-- | Document Amounts
CREATE TABLE document_amounts (
    id BIGSERIAL PRIMARY KEY,
    doc_id BIGINT NOT NULL,
    doc_date DATE NOT NULL,
    amount_type SMALLINT NOT NULL,  -- 0=Total, 1=Payment, 2=Discount и т.д.
    currency_id BIGINT NOT NULL DEFAULT 1,
    amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    
    FOREIGN KEY (doc_id, doc_date) REFERENCES documents(id, doc_date) ON DELETE CASCADE
);

-- ============================================================
-- Inventory - Складской учет
-- =================================================================

-- | Stock (остатки) - материализованные
CREATE TABLE stock (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    location_id BIGINT NOT NULL REFERENCES locations(id),
    qtty NUMERIC(18,4) NOT NULL DEFAULT 0,
    price NUMERIC(18,4),  -- Цена реализации
    cost NUMERIC(18,4),   -- Себестоимость
    last_movement_date DATE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(goods_id, location_id)
);

CREATE INDEX idx_stock_goods ON stock(goods_id);
CREATE INDEX idx_stock_location ON stock(location_id);

-- | Lots (партии)
CREATE TABLE lots (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    doc_id BIGINT NOT NULL,
    doc_date DATE NOT NULL,
    qtty NUMERIC(18,4) NOT NULL,
    rest NUMERIC(18,4) NOT NULL,
    price NUMERIC(18,4),
    cost NUMERIC(18,4),
    serial VARCHAR(64),
    expiry DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_lots_goods ON lots(goods_id);
CREATE INDEX idx_lots_expiry ON lots(expiry) WHERE expiry IS NOT NULL;

-- | Goods Movements (движения) - partitioned
CREATE TABLE goods_movements (
    id BIGSERIAL,
    dt DATE NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    location_id BIGINT NOT NULL REFERENCES locations(id),
    doc_id BIGINT,
    op_kind_id BIGINT,
    qtty_in NUMERIC(18,4) DEFAULT 0,
    qtty_out NUMERIC(18,4) DEFAULT 0,
    price NUMERIC(18,4),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (id, dt)
) PARTITION BY RANGE (dt);

CREATE TABLE goods_movements_2026 PARTITION OF goods_movements
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

-- | Min Stock / Reorder Points
CREATE TABLE min_stock_levels (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    location_id BIGINT NOT NULL REFERENCES locations(id),
    min_qty NUMERIC(18,4) NOT NULL DEFAULT 0,
    reorder_qty NUMERIC(18,4),
    UNIQUE(goods_id, location_id)
);

-- ============================================================
-- Operation Kinds - Виды операций
-- =================================================================

CREATE TABLE operation_kinds (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type SMALLINT NOT NULL DEFAULT 0,  -- 1=Receipt, 2=Issue и т.д.
    flags INTEGER DEFAULT 0,
    acc_sheet_id BIGINT,  -- Дебет
    acc_sheet2_id BIGINT, -- Кредит
    link_op_id BIGINT REFERENCES operation_kinds(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- Materialized Views - Материализованные представления
-- =================================================================

-- | Актуальные остатки (обновляется по триггеру)
CREATE MATERIALIZED VIEW mv_current_stock AS
SELECT 
    s.goods_id,
    s.location_id,
    s.qtty,
    s.price,
    s.cost,
    g.name as goods_name,
    g.code as goods_code,
    l.name as location_name
FROM stock s
JOIN goods g ON g.id = s.goods_id
JOIN locations l ON l.id = s.location_id
WHERE s.qtty > 0;

CREATE UNIQUE INDEX idx_mv_current_stock ON mv_current_stock(goods_id, location_id);

-- | Обороты за текущий месяц
CREATE MATERIALIZED VIEW mv_monthly_turnover AS
SELECT 
    gm.goods_id,
    gm.location_id,
    DATE_TRUNC('month', gm.dt) as month,
    SUM(gm.qtty_in) as total_in,
    SUM(gm.qtty_out) as total_out,
    SUM(gm.qtty_in * gm.price) as amount_in,
    SUM(gm.qtty_out * gm.price) as amount_out,
    COUNT(DISTINCT gm.doc_id) as movement_count
FROM goods_movements gm
WHERE gm.dt >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY gm.goods_id, gm.location_id, DATE_TRUNC('month', gm.dt);

CREATE INDEX idx_mv_monthly_turnover ON mv_monthly_turnover(goods_id, location_id, month);

-- | Дебиторская задолженность
CREATE MATERIALIZED VIEW mv_receivables AS
SELECT 
    d.party_id,
    p.name as party_name,
    SUM(d.amount) as total_amount,
    SUM(COALESCE(da.amount, 0)) as paid_amount,
    SUM(d.amount) - SUM(COALESCE(da.amount, 0)) as debt,
    MIN(d.due_date) as oldest_due_date,
    COUNT(*) as doc_count
FROM documents d
LEFT JOIN document_amounts da ON da.doc_id = d.id AND da.doc_date = d.doc_date AND da.amount_type = 1
JOIN parties p ON p.id = d.party_id
WHERE d.op_kind_id IN (SELECT id FROM operation_kinds WHERE type = 2)
  AND d.status != 3
  AND d.due_date <= CURRENT_DATE
GROUP BY d.party_id, p.name
HAVING SUM(d.amount) > SUM(COALESCE(da.amount, 0));

CREATE INDEX idx_mv_receivables ON mv_receivables(party_id);

-- ============================================================
-- Audit - Аудит изменений
-- =================================================================

CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id BIGINT NOT NULL,
    operation CHAR(1) NOT NULL,  -- I=Insert, U=Update, D=Delete
    old_data JSONB,
    new_data JSONB,
    user_id BIGINT,
    ip_address INET,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_table ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_log_changed ON audit_log(changed_at DESC);

-- ============================================================
-- Triggers - Триггеры
-- =================================================================

-- | Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_parties_updated
    BEFORE UPDATE ON parties
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_goods_updated
    BEFORE UPDATE ON goods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- | Audit trigger
CREATE OR REPLACE FUNCTION audit_trigger()
RETURNS TRIGGER AS $
DECLARE
    v_operation CHAR(1);
    v_old_data JSONB;
    v_new_data JSONB;
    v_record_id BIGINT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_operation := 'I';
        v_new_data := to_jsonb(NEW);
        v_record_id := NEW.id;
    ELSIF TG_OP = 'UPDATE' THEN
        v_operation := 'U';
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);
        v_record_id := NEW.id;
    ELSIF TG_OP = 'DELETE' THEN
        v_operation := 'D';
        v_old_data := to_jsonb(OLD);
        v_record_id := OLD.id;
    END IF;
    
    INSERT INTO audit_log (table_name, record_id, operation, old_data, new_data, changed_at)
    VALUES (TG_TABLE_NAME, v_record_id, v_operation, v_old_data, v_new_data, NOW());
    
    RETURN NEW;
END;
$ LANGUAGE plpgsql;

-- Apply audit to key tables
CREATE TRIGGER trigger_parties_audit
    AFTER INSERT OR UPDATE OR DELETE ON parties
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

CREATE TRIGGER trigger_documents_audit
    AFTER INSERT OR UPDATE OR DELETE ON documents
    FOR EACH ROW EXECUTE FUNCTION audit_trigger();

-- | Refresh materialized views daily
CREATE OR REPLACE FUNCTION refresh_materialized_views()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_current_stock;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_turnover;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_receivables;
END;
$$ LANGUAGE plpgsql;

-- Schedule: refresh every day at 2 AM
-- SELECT cron.schedule('0 2 * * *', $$SELECT refresh_materialized_views()$$);

-- ============================================================
-- Row Level Security - Безопасность на уровне строк
-- =================================================================

-- User parties mapping (для RLS)
CREATE TABLE IF NOT EXISTS user_parties (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    party_id BIGINT NOT NULL REFERENCES parties(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, party_id)
);

-- Пример RLS для документов
CREATE POLICY documents_own_policy ON documents
    FOR ALL
    USING (
        party_id IN (
            SELECT id FROM parties WHERE flags & 1 = 1  -- user's company
        )
        OR party_id IN (
            SELECT party_id FROM user_parties WHERE user_id = (SELECT id FROM users WHERE login = current_user)
        )
    );

-- ============================================================
-- Default Data - Начальные данные
-- =================================================================

-- Currency
INSERT INTO currency (code, name, symbol, rate, is_base) VALUES
    ('RUB', 'Российский рубль', '₽', 1, TRUE),
    ('USD', 'US Dollar', '$', 75.5, FALSE),
    ('EUR', 'Euro', '€', 85.0, FALSE)
ON CONFLICT (code) DO NOTHING;

-- Main organization
INSERT INTO parties (name, kind, status) VALUES
    ('Основная организация', 1, 0)
ON CONFLICT DO NOTHING;

-- Main warehouse
INSERT INTO locations (name, type, flags) VALUES
    ('Основной склад', 0, 2)
ON CONFLICT DO NOTHING;

-- Operation types
INSERT INTO operation_kinds (name, type, flags) VALUES
    ('Приход товара', 1, 0),
    ('Расход товара', 2, 0),
    ('Возврат поставщику', 3, 0),
    ('Возврат покупателя', 4, 0),
    ('Инвентаризация', 5, 0),
    ('Списание', 6, 0),
    ('Перемещение', 7, 0)
ON CONFLICT DO NOTHING;
