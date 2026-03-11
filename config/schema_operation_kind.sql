-- =================================================================
-- Operation Kinds Extension - Расширение видов операций
-- =================================================================
-- Analog: OpenPapyrus pplib/objoprk.cpp, pp.h (PPOprKind2)
-- 
-- Содержит:
-- - Полную структуру operation_kinds
-- - Расширения инвентаризации, зачёта, драфта
-- - Триггеры для аудита
-- =================================================================

-- Расширенная таблица видов операций (полная версия)
CREATE TABLE IF NOT EXISTS operation_kind (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    symb VARCHAR(20),                    -- Symbol (short code)
    type SMALLINT NOT NULL DEFAULT 0,    -- Operation type (enum)
    subtype SMALLINT NOT NULL DEFAULT 0, -- Subtype (enum)
    flags INTEGER DEFAULT 0,             -- OPKF_XXX
    acc_sheet_id BIGINT,                 -- Debit account sheet
    acc_sheet2_id BIGINT,                -- Credit account sheet
    link_op_id BIGINT REFERENCES operation_kind(id),
    init_status_id BIGINT,               -- Initial status for new docs
    def_loc_id BIGINT,                   -- Default location
    op_counter_id BIGINT,                -- Counter for numbering
    prn_flags INTEGER DEFAULT 0,         -- Print flags
    rank SMALLINT DEFAULT 0,             -- Display rank
    ext_flags INTEGER DEFAULT 0,         -- Extended flags
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_operation_kind_type ON operation_kind(type);
CREATE INDEX IF NOT EXISTS idx_operation_kind_subtype ON operation_kind(subtype);
CREATE INDEX IF NOT EXISTS idx_operation_kind_flags ON operation_kind(flags);
CREATE INDEX IF NOT EXISTS idx_operation_kind_link ON operation_kind(link_op_id);
CREATE INDEX IF NOT EXISTS idx_operation_kind_name ON operation_kind USING gin(name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_operation_kind_symb ON operation_kind(symb) WHERE symb IS NOT NULL;

-- =================================================================
-- Inventory Operation Extension (Расширение инвентаризации)
-- =================================================================
-- Analog: PPInventoryOpEx

CREATE TABLE IF NOT EXISTS inventory_op_ex (
    id BIGINT PRIMARY KEY REFERENCES operation_kind(id) ON DELETE CASCADE,
    wr_dn_op BIGINT REFERENCES operation_kind(id),      -- Списание недостач
    wr_dn_obj BIGINT,                                    -- Контрагент недостач
    wr_up_op BIGINT REFERENCES operation_kind(id),      -- Оприходование излишков
    wr_up_obj BIGINT,                                    -- Контрагент излишков
    amount_calc_method SMALLINT DEFAULT 0,              -- ACM_XXX (LIFO/FIFO/AVG)
    auto_fill_method SMALLINT DEFAULT 0,                -- AFM_XXX
    on_wr_off_status_id BIGINT,                         -- Статус после списания
    flags INTEGER DEFAULT 0,                            -- INVOPF_XXX
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_inv_op_ex_wrdn ON inventory_op_ex(wr_dn_op);
CREATE INDEX IF NOT EXISTS idx_inv_op_ex_wrup ON inventory_op_ex(wr_up_op);

-- =================================================================
-- Reckon Operation Extension (Расширение зачётной операции)
-- =================================================================
-- Analog: PPReckonOpEx

CREATE TABLE IF NOT EXISTS reckon_op_ex (
    id BIGINT PRIMARY KEY REFERENCES operation_kind(id) ON DELETE CASCADE,
    beg DATE,                                            -- Начало периода
    end DATE,                                            -- Конец периода
    flags INTEGER DEFAULT 0,                            -- ROXF_XXX
    person_rel_type_id BIGINT,                          -- Тип персонального отношения
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Список операций оплат для зачёта (many-to-many)
CREATE TABLE IF NOT EXISTS reckon_op_list (
    reckon_op_id BIGINT NOT NULL REFERENCES reckon_op_ex(id) ON DELETE CASCADE,
    payment_op_id BIGINT NOT NULL REFERENCES operation_kind(id),
    PRIMARY KEY (reckon_op_id, payment_op_id)
);

CREATE INDEX IF NOT EXISTS idx_reckon_op_list_op ON reckon_op_list(payment_op_id);

-- =================================================================
-- Draft Operation Extension (Расширение драфт-операции)
-- =================================================================
-- Analog: структура DROXF_XXX

CREATE TABLE IF NOT EXISTS draft_op_ex (
    id BIGINT PRIMARY KEY REFERENCES operation_kind(id) ON DELETE CASCADE,
    flags INTEGER DEFAULT 0,                            -- DROXF_XXX
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =================================================================
-- Debt Inventory Extension (Инвентаризация задолженности)
-- =================================================================
-- Analog: PPDebtInventOpEx

CREATE TABLE IF NOT EXISTS debt_invent_op_ex (
    id BIGINT PRIMARY KEY REFERENCES operation_kind(id) ON DELETE CASCADE,
    wr_dn_op BIGINT REFERENCES operation_kind(id),      -- Покрытие долга
    wr_up_op BIGINT REFERENCES operation_kind(id),      -- Покрытие переплаты
    wr_dn_goods_id BIGINT,                               -- Товар для долговых док-тов
    wr_up_goods_id BIGINT,                               -- Товар для переплаты
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =================================================================
-- Default Operation Kinds (Справочник видов операций по умолчанию)
-- =================================================================

INSERT INTO operation_kind (name, symb, type, subtype, flags, rank) VALUES
    -- Приход товара
    ('Приход товара', 'REC', 1, 1, 16, 10),
    ('Возврат от покупателя', 'RETC', 7, 3, 16, 20),
    ('Оприходование', 'OPR', 1, 0, 24, 30),
    
    -- Расход товара
    ('Реализация', 'SELL', 2, 2, 144, 100),
    ('Возврат поставщику', 'RETS', 7, 4, 144, 110),
    ('Списание', 'LOSS', 6, 0, 24, 120),
    
    -- Перемещение
    ('Перемещение', 'MOVE', 5, 6, 20, 200),
    
    -- Инвентаризация
    ('Инвентаризация', 'INV', 6, 5, 28, 300),
    
    -- Заказы
    ('Заказ', 'ORDER', 3, 0, 0, 400),
    ('Заказ поставщику', 'PO', 11, 0, 0, 410),
    
    -- Платёж
    ('Приходный кассовый ордер', 'CASHIN', 13, 0, 1, 500),
    ('Расходный кассовый ордер', 'CASHOUT', 13, 0, 1, 510),
    ('Платёжное поручение', 'PAY', 12, 0, 2, 520),
    
    -- Черновики
    ('Чек', 'CHECK', 30, 10, 65, 600),
    ('Чек гостя', 'GUEST', 32, 11, 65, 610)
ON CONFLICT DO NOTHING;

-- =================================================================
-- Functions and Triggers
-- =================================================================

-- Функция обновления timestamp
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для обновления updated_at
CREATE TRIGGER tr_operation_kind_update
    BEFORE UPDATE ON operation_kind
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER tr_inventory_op_ex_update
    BEFORE UPDATE ON inventory_op_ex
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER tr_reckon_op_ex_update
    BEFORE UPDATE ON reckon_op_ex
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp();

-- =================================================================
-- Audit Trigger
-- =================================================================

CREATE OR REPLACE FUNCTION audit_operation_kind()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, record_id, operation, new_data)
        VALUES ('operation_kind', NEW.id, 'I', to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, record_id, operation, old_data, new_data)
        VALUES ('operation_kind', NEW.id, 'U', to_jsonb(OLD), to_jsonb(NEW));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, record_id, operation, old_data)
        VALUES ('operation_kind', OLD.id, 'D', to_jsonb(OLD));
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_audit_operation_kind
    AFTER INSERT OR UPDATE OR DELETE ON operation_kind
    FOR EACH ROW
    EXECUTE FUNCTION audit_operation_kind();

-- =================================================================
-- Views for Application
-- =================================================================

-- Полный вид операции с расширениями
CREATE OR REPLACE VIEW v_operation_kind_full AS
SELECT 
    ok.id,
    ok.name,
    ok.symb,
    ok.type,
    ok.subtype,
    ok.flags,
    ok.acc_sheet_id,
    ok.acc_sheet2_id,
    ok.link_op_id,
    ok.init_status_id,
    ok.def_loc_id,
    ok.op_counter_id,
    ok.prn_flags,
    ok.rank,
    ok.ext_flags,
    ok.is_active,
    
    -- Inventory extension
    inv.wr_dn_op,
    inv.wr_up_op,
    inv.amount_calc_method,
    inv.auto_fill_method,
    inv.on_wr_off_status_id,
    inv.flags as inv_flags,
    
    -- Reckon extension
    reck.beg,
    reck.end,
    reck.flags as reck_flags,
    reck.person_rel_type_id
    
FROM operation_kind ok
LEFT JOIN inventory_op_ex inv ON inv.id = ok.id
LEFT JOIN reckon_op_ex reck ON reck.id = ok.id;

-- =================================================================
-- Comments
-- =================================================================

COMMENT ON TABLE operation_kind IS 'Виды операций (аналог PPOprKind2)';
COMMENT ON TABLE inventory_op_ex IS 'Расширение операций инвентаризации (аналог PPInventoryOpEx)';
COMMENT ON TABLE reckon_op_ex IS 'Расширение зачётных операций (аналог PPReckonOpEx)';
COMMENT ON TABLE draft_op_ex IS 'Расширение драфт-операций';
COMMENT ON TABLE debt_invent_op_ex IS 'Расширение инвентаризации задолженности (аналог PPDebtInventOpEx)';

COMMENT ON COLUMN operation_kind.type IS 'Тип операции (PPOPT_XXX)';
COMMENT ON COLUMN operation_kind.subtype IS 'Подтип операции (OPSUBT_XXX)';
COMMENT ON COLUMN operation_kind.flags IS 'Флаги операции (OPKF_XXX)';
COMMENT ON COLUMN operation_kind.acc_sheet_id IS 'План счетов (дебет)';
COMMENT ON COLUMN operation_kind.acc_sheet2_id IS 'План счетов (кредит)';
COMMENT ON COLUMN operation_kind.link_op_id IS 'Связанная операция';
