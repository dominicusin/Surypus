-- ============================================================
-- Asset Tables - Основные средства
-- ============================================================

-- Asset groups (группы ОС)
CREATE TABLE IF NOT EXISTS asset_group (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(128) NOT NULL,
    parent_id BIGINT REFERENCES asset_group(id),
    useful_life_default INT,  -- Срок полезного использования по умолчанию
    depreciation_rate NUMERIC(5,2),  -- Норма амортизации
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

-- Assets (основные средства)
CREATE TABLE IF NOT EXISTS asset (
    id BIGSERIAL PRIMARY KEY,
    inv_no VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    atype SMALLINT NOT NULL,  -- 0=BUILDING, 1=VEHICLE, 2=EQUIPMENT, 3=FURNITURE, 4=COMPUTER, 5=TOOL, 6=LAND, 7=INTANGIBLE
    group_id BIGINT REFERENCES asset_group(id),
    location_id BIGINT REFERENCES location(id),
    owner_id BIGINT REFERENCES person(id),
    status SMALLINT DEFAULT 0,  -- 0=PURCHASING, 1=OPERATING, 2=RECONSTRUCTION, 3=CONSERVATION, 4=SOLD, 5=WRITTEN_OFF, 6=LEASED
    cost NUMERIC(18,2) NOT NULL DEFAULT 0,  -- Первоначальная стоимость
    depreciation NUMERIC(18,2) DEFAULT 0,  -- Накопленная амортизация
    salvage_value NUMERIC(18,2) DEFAULT 0,  -- Ликвидационная стоимость
    useful_life INT NOT NULL DEFAULT 0,  -- Срок полезного использования (мес)
    purchase_date DATE,
    commissioning_date DATE,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(inv_no)
);

-- Depreciation (амортизация)
CREATE TABLE IF NOT EXISTS asset_depreciation (
    id BIGSERIAL PRIMARY KEY,
    asset_id BIGINT NOT NULL REFERENCES asset(id),
    period DATE NOT NULL,  -- Месяц
    amount NUMERIC(18,2) NOT NULL,
    accumulated NUMERIC(18,2) NOT NULL,
    method SMALLINT DEFAULT 0,  -- 0=LINEAR, 1=DECLINING, 2=SUM_OF_YEARS, 3=UNITS
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(asset_id, period)
);

-- Asset events (события ОС)
CREATE TABLE IF NOT EXISTS asset_event (
    id BIGSERIAL PRIMARY KEY,
    asset_id BIGINT NOT NULL REFERENCES asset(id),
    etype SMALLINT NOT NULL,  -- 0=PURCHASE, 1=COMMISSION, 2=TRANSFER, 3=REPAIR, 4=DEPREC, 5=SELL, 6=WRITE_OFF
    dt DATE NOT NULL,
    amount NUMERIC(18,2),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы для ОС
CREATE INDEX IF NOT EXISTS idx_asset_inv_no ON asset(inv_no);
CREATE INDEX IF NOT EXISTS idx_asset_type ON asset(atype);
CREATE INDEX IF NOT EXISTS idx_asset_group ON asset(group_id);
CREATE INDEX IF NOT EXISTS idx_asset_status ON asset(status);
CREATE INDEX IF NOT EXISTS idx_asset_location ON asset(location_id);

CREATE INDEX IF NOT EXISTS idx_depreciation_asset ON asset_depreciation(asset_id);
CREATE INDEX IF NOT EXISTS idx_depreciation_period ON asset_depreciation(period);

CREATE INDEX IF NOT EXISTS idx_asset_event_asset ON asset_event(asset_id);

-- ============================================================
-- Функции для ОС
-- ============================================================

-- Расчёт остаточной стоимости
CREATE OR REPLACE FUNCTION calc_residual_value(p_asset_id BIGINT)
RETURNS NUMERIC(18,2) AS $$
DECLARE
    v_cost NUMERIC(18,2);
    v_dep NUMERIC(18,2);
    v_salvage NUMERIC(18,2);
BEGIN
    SELECT a.cost, a.depreciation, a.salvage_value 
    INTO v_cost, v_dep, v_salvage
    FROM asset a WHERE a.id = p_asset_id;
    
    RETURN GREATEST(0, v_cost - v_dep - v_salvage);
END;
$$ LANGUAGE plpgsql;

-- Расчёт ежемесячной амортизации (линейный метод)
CREATE OR REPLACE FUNCTION calc_monthly_depreciation(
    p_cost NUMERIC(18,2),
    p_salvage NUMERIC(18,2),
    p_useful_life INT
) RETURNS NUMERIC(18,2) AS $$
BEGIN
    IF p_useful_life = 0 THEN
        RETURN 0;
    END IF;
    
    RETURN (p_cost - p_salvage) / p_useful_life;
END;
$$ LANGUAGE plpgsql;

-- Начисление амортизации за месяц
CREATE OR REPLACE FUNCTION depreciate_asset_month(
    p_asset_id BIGINT,
    p_period DATE
) RETURNS BOOLEAN AS $$
DECLARE
    v_cost NUMERIC(18,2);
    v_salvage NUMERIC(18,2);
    v_useful_life INT;
    v_current_dep NUMERIC(18,2);
    v_monthly_dep NUMERIC(18,2);
BEGIN
    SELECT a.cost, a.salvage_value, a.useful_life, a.depreciation
    INTO v_cost, v_salvage, v_useful_life, v_current_dep
    FROM asset a WHERE a.id = p_asset_id;
    
    v_monthly_dep := calc_monthly_depreciation(v_cost, v_salvage, v_useful_life);
    
    -- Проверить не превышает ли стоимость
    IF v_current_dep + v_monthly_dep > v_cost - v_salvage THEN
        v_monthly_dep := v_cost - v_salvage - v_current_dep;
    END IF;
    
    IF v_monthly_dep <= 0 THEN
        RETURN FALSE;
    END IF;
    
    -- Начислить амортизацию
    UPDATE asset SET depreciation = depreciation + v_monthly_dep WHERE id = p_asset_id;
    
    -- Записать в регистр
    INSERT INTO asset_depreciation (asset_id, period, amount, accumulated, method)
    VALUES (p_asset_id, p_period, v_monthly_dep, v_current_dep + v_monthly_dep, 0);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Ввод в эксплуатацию
CREATE OR REPLACE FUNCTION commission_asset(p_asset_id BIGINT, p_date DATE)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE asset 
    SET status = 1, commissioning_date = p_date, updated_at = NOW()
    WHERE id = p_asset_id AND status = 0;
    
    -- Записать событие
    INSERT INTO asset_event (asset_id, etype, dt, description)
    VALUES (p_asset_id, 1, p_date, 'Ввод в эксплуатацию');
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления для отчётов
-- ============================================================

-- ОС в эксплуатации
CREATE OR REPLACE VIEW v_operating_assets AS
SELECT 
    a.id, a.inv_no, a.name, a.atype, ag.name AS group_name,
    a.cost, a.depreciation, a.salvage_value,
    calc_residual_value(a.id) AS residual_value,
    a.useful_life, a.commissioning_date,
    l.name AS location_name
FROM asset a
LEFT JOIN asset_group ag ON ag.id = a.group_id
LEFT JOIN location l ON l.id = a.location_id
WHERE a.status = 1  -- OPERATING
ORDER BY a.inv_no;

-- Ведомость ОС
CREATE OR REPLACE VIEW v_asset_register AS
SELECT 
    a.inv_no, a.name, a.atype,
    ag.name AS group_name,
    a.cost, a.depreciation, calc_residual_value(a.id) AS residual_value,
    a.useful_life,
    CASE a.atype
        WHEN 0 THEN 'Здание'
        WHEN 1 THEN 'Транспорт'
        WHEN 2 THEN 'Оборудование'
        WHEN 3 THEN 'Мебель'
        WHEN 4 THEN 'Компьютер'
        WHEN 5 THEN 'Инструмент'
        WHEN 6 THEN 'Земля'
        WHEN 7 THEN 'Нематериальный'
    END AS atype_name,
    CASE a.status
        WHEN 0 THEN 'В процессе приобретения'
        WHEN 1 THEN 'В эксплуатации'
        WHEN 2 THEN 'На реконструкции'
        WHEN 3 THEN 'На консервации'
        WHEN 4 THEN 'Продано'
        WHEN 5 THEN 'Списано'
        WHEN 6 THEN 'В аренде'
    END AS status_name
FROM asset a
LEFT JOIN asset_group ag ON ag.id = a.group_id
ORDER BY a.inv_no;

-- Амортизация за период
CREATE OR REPLACE VIEW v_depreciation_report AS
SELECT 
    ad.asset_id, a.inv_no, a.name,
    ad.period, ad.amount, ad.accumulated,
    CASE ad.method
        WHEN 0 THEN 'Линейный'
        WHEN 1 THEN 'Уменьшаемого остатка'
        WHEN 2 THEN 'Суммы чисел лет'
        WHEN 3 THEN 'Пропорционально выпуску'
    END AS method_name
FROM asset_depreciation ad
JOIN asset a ON a.id = ad.asset_id
ORDER BY ad.period DESC, a.inv_no;

-- Стоимость ОС по группам
CREATE OR REPLACE VIEW v_asset_value_by_group AS
SELECT 
    ag.id, ag.name AS group_name,
    COUNT(a.id) AS asset_count,
    SUM(a.cost) AS total_cost,
    SUM(a.depreciation) AS total_depreciation,
    SUM(calc_residual_value(a.id)) AS total_residual
FROM asset_group ag
LEFT JOIN asset a ON a.group_id = ag.id AND a.status IN (1, 2, 3, 6)
GROUP BY ag.id, ag.name
ORDER BY ag.name;
