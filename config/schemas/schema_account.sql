-- =============================================================================
-- БУХГАЛТЕРСКИЕ СЧЁТА
-- Соответствуют Core.Accounting.Account
-- Аналог: PPOBJ_ACCOUNT (устаревший, заменён на ACCOUNT2)
-- =============================================================================

CREATE TABLE IF NOT EXISTS account (
    id SERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(256) NOT NULL,
    kind INT NOT NULL,  -- 1:Актив, 2Пассив, 3Активно-пассивный
    type INT NOT NULL,  -- 1:Балансовый, 2Внебалансовый, 3Агрегирующий
    parent_id INT DEFAULT 0,
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX idx_account_code ON account(code);
CREATE INDEX idx_account_parent ON account(parent_id);
CREATE INDEX idx_account_kind ON account(kind);

-- DEFAULT DATA: План счетов РФ (базовый)
INSERT INTO account (id, code, name, kind, type, parent_id) VALUES
(1, '01', 'Основные средства', 1, 1, 0),
(2, '02', 'Амортизация основных средств', 2, 1, 1),
(3, '04', 'Нематериальные активы', 1, 1, 0),
(4, '05', 'Амортизация нематериальных активов', 2, 1, 3),
(5, '10', 'Материалы', 1, 1, 0),
(6, '20', 'Основное производство', 1, 1, 0),
(7, '26', 'Общехозяйственные расходы', 3, 1, 0),
(8, '41', 'Товары', 1, 1, 0),
(9, '43', 'Готовая продукция', 1, 1, 0),
(10, '50', 'Касса', 1, 1, 0),
(11, '51', 'Расчётные счёта', 1, 1, 0),
(12, '52', 'Валютные счёта', 1, 1, 0),
(13, '60', 'Расчёты с поставщиками', 2, 1, 0),
(14, '62', 'Расчёты с покупателями', 2, 1, 0),
(15, '66', 'Расчёты по кредитам', 2, 1, 0),
(16, '68', 'Расчёты по налогам', 2, 1, 0),
(17, '69', 'Расчёты по социальному страхованию', 2, 1, 0),
(18, '70', 'Расчёты с персоналом по оплате труда', 2, 1, 0),
(19, '80', 'Уставный капитал', 3, 1, 0),
(20, '84', 'Нераспределённая прибыль', 3, 1, 0),
(21, '90', 'Продажи', 3, 1, 0),
(22, '91', 'Прочие доходы и расходы', 3, 1, 0),
(23, '99', 'Прибыли и убытки', 3, 1, 0)
ON CONFLICT (id) DO NOTHING;

-- TRIGGER
CREATE OR REPLACE FUNCTION update_account_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_account_update
    BEFORE UPDATE ON account
    FOR EACH ROW
    EXECUTE FUNCTION update_account_timestamp();
