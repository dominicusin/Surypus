-- ============================================================
-- BizScore Tables - Бизнес-показатели (KPI)
-- ============================================================

-- Основная таблица показателей
CREATE TABLE IF NOT EXISTS bizscore (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    description TEXT,
    formula VARCHAR(1024),           -- Формула расчёта
    unit VARCHAR(32),                 -- Единица измерения
    weight DECIMAL(5,4) DEFAULT 1,   -- Вес (0-1)
    target_value DECIMAL(18,4),      -- Целевое значение
    threshold DECIMAL(18,4),         -- Пороговое значение
    lower_bound DECIMAL(18,4) DEFAULT 0,
    upper_bound DECIMAL(18,4),
    direction SMALLINT DEFAULT 0,    -- 0=HIGHER_BETTER, 1=LOWER_BETTER, 2=TARGET, 3=STABLE
    calc_frequency SMALLINT DEFAULT 3, -- 0=REALTIME, 1=HOURLY, 2=DAILY, 3=WEEKLY, 4=MONTHLY, 5=QUARTERLY, 6=YEARLY
    status SMALLINT DEFAULT 0,       -- 0=DRAFT, 1=ACTIVE, 2=PAUSED, 3=ARCHIVED
    group_id BIGINT,
    parent_id BIGINT,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

-- Значения показателей по периодам
CREATE TABLE IF NOT EXISTS scorevalue (
    id BIGSERIAL PRIMARY KEY,
    score_id BIGINT NOT NULL REFERENCES bizscore(id),
    period DATE NOT NULL,
    value DECIMAL(18,4) NOT NULL,
    target_value DECIMAL(18,4),
    threshold DECIMAL(18,4),
    trend SMALLINT DEFAULT 3,         -- 0=GROWING, 1=DECLINING, 2=STABLE, 3=UNKNOWN
    completion_pct DECIMAL(8,2),      -- Процент выполнения
    status SMALLINT DEFAULT 0,        -- 0=NORMAL, 1=WARNING, 2=CRITICAL, 3=ACHIEVED
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(score_id, period)
);

-- Группы показателей
CREATE TABLE IF NOT EXISTS scoregroup (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    parent_id BIGINT REFERENCES scoregroup(id),
    aggregation SMALLINT DEFAULT 0,   -- 0=WEIGHTED_SUM, 1=WEIGHTED_AVG, 2=MAX, 3=MIN, 4=SUM
    weight_sum DECIMAL(5,4) DEFAULT 0,
    UNIQUE(code)
);

-- Настройки алертов
CREATE TABLE IF NOT EXISTS scorealert (
    id BIGSERIAL PRIMARY KEY,
    score_id BIGINT NOT NULL REFERENCES bizscore(id),
    alert_type SMALLINT NOT NULL,     -- 0=THRESHOLD, 1=TREND, 2=TARGET
    threshold_pct DECIMAL(5,2),       -- Порог в процентах
    notification_channel VARCHAR(64), -- Email, SMS, Webhook
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_bizscore_group ON bizscore(group_id);
CREATE INDEX IF NOT EXISTS idx_bizscore_status ON bizscore(status);
CREATE INDEX IF NOT EXISTS idx_scorevalue_score ON scorevalue(score_id);
CREATE INDEX IF NOT EXISTS idx_scorevalue_period ON scorevalue(period);
CREATE INDEX IF NOT EXISTS idx_scoregroup_parent ON scoregroup(parent_id);
