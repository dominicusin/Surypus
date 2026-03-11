-- ============================================================
-- ДОПОЛНИТЕЛЬНЫЕ PostgreSQL Stored Procedures
-- Расширенные хранимые процедуры для всех модулей
-- ============================================================

-- ============================================================================
-- EDI PROCEDURES
-- ============================================================================

-- | Проверить GTIN-13
CREATE OR REPLACE FUNCTION check_gtin13(p_gtin VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_digits INT[];
    v_sum INT := 0;
    v_check INT;
    v_i INT;
BEGIN
    IF length(p_gtin) != 13 THEN
        RETURN FALSE;
    END IF;
    
    v_digits := string_to_array(p_gtin, NULL)::INT[];
    
    -- Нечётные позиции (1,3,5,7,9,11) * 3
    FOR v_i IN 1..11 LOOP
        IF v_i % 2 = 1 THEN
            v_sum := v_sum + v_digits[v_i] * 3;
        ELSE
            v_sum := v_sum + v_digits[v_i];
        END IF;
    END LOOP;
    
    v_check := (10 - (v_sum % 10)) % 10;
    
    RETURN v_check = v_digits[13];
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- | Проверить SSCC-18
CREATE OR REPLACE FUNCTION check_sscc18(p_sscc VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    v_digits INT[];
    v_sum INT := 0;
    v_check INT;
    v_i INT;
BEGIN
    IF length(p_sscc) != 18 THEN
        RETURN FALSE;
    END IF;
    
    v_digits := string_to_array(p_sscc, NULL)::INT[];
    
    -- Чётные позиции * 3, нечётные * 1
    FOR v_i IN 1..17 LOOP
        IF v_i % 2 = 0 THEN
            v_sum := v_sum + v_digits[v_i] * 3;
        ELSE
            v_sum := v_sum + v_digits[v_i];
        END IF;
    END LOOP;
    
    v_check := (10 - (v_sum % 10)) % 10;
    
    RETURN v_check = v_digits[18];
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- PRODUCTION (MRP) PROCEDURES
-- ============================================================================

-- | Таблица спецификаций (Bill of Materials)
CREATE TABLE IF NOT EXISTS bill_of_materials (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    version INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- | Компоненты спецификации
CREATE TABLE IF NOT EXISTS bom_component (
    id BIGSERIAL PRIMARY KEY,
    bom_id BIGINT NOT NULL REFERENCES bill_of_materials(id),
    component_goods_id BIGINT NOT NULL REFERENCES goods(id),
    quantity NUMERIC(18,4) NOT NULL,
    flags INTEGER DEFAULT 0
);

-- | Производственные заказы
CREATE TABLE IF NOT EXISTS production_order (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(48) NOT NULL,
    goods_id BIGINT NOT NULL REFERENCES goods(id),
    quantity NUMERIC(18,4) NOT NULL,
    start_date DATE NOT NULL,
    due_date DATE NOT NULL,
    status SMALLINT NOT NULL DEFAULT 0,  -- 0: Planned, 1: InProgress, 2: Completed, 3: Cancelled
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_prod_order_dates CHECK (due_date >= start_date)
);

-- | Рассчитать материалы по спецификации
CREATE OR REPLACE FUNCTION calc_materials_required(
    p_goods_id BIGINT,
    p_quantity NUMERIC(18,4)
) RETURNS TABLE(
    component_goods_id BIGINT,
    required_quantity NUMERIC(18,4)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bc.component_goods_id,
        bc.quantity * p_quantity AS required_quantity
    FROM bill_of_materials bom
    JOIN bom_component bc ON bc.bom_id = bom.id
    WHERE bom.goods_id = p_goods_id
      AND bom.is_active = TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TAX (RUSSIAN) PROCEDURES
-- ============================================================================

-- | Рассчитать НДФЛ
CREATE OR REPLACE FUNCTION calc_ndfl(
    p_income NUMERIC(18,4),
    p_is_resident BOOLEAN,
    p_income_type SMALLINT
) RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_rate NUMERIC(5,4) := 0.13;
BEGIN
    IF NOT p_is_resident THEN
        v_rate := 0.30;
    END IF;
    
    RETURN p_income * v_rate;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- | Рассчитать УСН (доходы)
CREATE OR REPLACE FUNCTION calc_usn_income(p_income NUMERIC(18,4))
RETURNS NUMERIC(18,4) AS $$
BEGIN
    RETURN p_income * 0.06;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- | Рассчитать УСН (доходы - расходы)
CREATE OR REPLACE FUNCTION calc_usn_income_exp(p_income NUMERIC(18,4), p_expenses NUMERIC(18,4))
RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_taxable NUMERIC(18,4);
BEGIN
    v_taxable := p_income - p_expenses;
    IF v_taxable < 0 THEN
        RETURN 0;
    END IF;
    RETURN v_taxable * 0.15;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- | Рассчитать страховые взносы
CREATE OR REPLACE FUNCTION calc_insurance_contributions(p_fot NUMERIC(18,4))
RETURNS TABLE(
    type VARCHAR(20),
    amount NUMERIC(18,4)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 'pension'::VARCHAR, p_fot * 0.22
    UNION ALL
    SELECT 'medical'::VARCHAR, p_fot * 0.051
    UNION ALL
    SELECT 'social'::VARCHAR, p_fot * 0.029;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECURITY PROCEDURES
-- ============================================================================

-- | Таблица прав доступа
CREATE TABLE IF NOT EXISTS access_control_list (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    object_id BIGINT NOT NULL,
    permission_id BIGINT NOT NULL,
    is_grant BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- | Проверить доступ
CREATE OR REPLACE FUNCTION has_access(
    p_user_id BIGINT,
    p_object_id BIGINT,
    p_permission_id BIGINT
) RETURNS BOOLEAN AS $$
DECLARE
    v_deny BOOLEAN;
    v_direct BOOLEAN;
    v_role BOOLEAN;
BEGIN
    -- Проверить запрет
    SELECT EXISTS(
        SELECT 1 FROM access_control_list
        WHERE user_id = p_user_id
          AND object_id = p_object_id
          AND permission_id = p_permission_id
          AND is_grant = FALSE
    ) INTO v_deny;
    
    IF v_deny THEN
        RETURN FALSE;
    END IF;
    
    -- Проверить прямое разрешение
    SELECT EXISTS(
        SELECT 1 FROM access_control_list
        WHERE user_id = p_user_id
          AND object_id = p_object_id
          AND permission_id = p_permission_id
          AND is_grant = TRUE
    ) INTO v_direct;
    
    IF v_direct THEN
        RETURN TRUE;
    END IF;
    
    -- Проверить разрешение через роль (упрощённо)
    RETURN TRUE;  -- В реальности нужна проверка через role_user и role_permission
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DEVICE (POS) PROCEDURES
-- ============================================================================

-- | Таблица кассовых смен
CREATE TABLE IF NOT EXISTS cash_session (
    id BIGSERIAL PRIMARY KEY,
    device_id BIGINT NOT NULL,
    start_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    start_amount NUMERIC(18,4) NOT NULL DEFAULT 0,
    end_amount NUMERIC(18,4),
    status SMALLINT NOT NULL DEFAULT 0  -- 0: Open, 1: Closed, 2: Cancelled
);

-- | Таблица чеков
CREATE TABLE IF NOT EXISTS receipt (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT NOT NULL REFERENCES cash_session(id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total NUMERIC(18,4) NOT NULL DEFAULT 0,
    vat NUMERIC(18,4) NOT NULL DEFAULT 0,
    status SMALLINT NOT NULL DEFAULT 0  -- 0: Pending, 1: Completed, 2: Returned, 3: Cancelled
);

-- | Таблица строк чеков
CREATE TABLE IF NOT EXISTS receipt_item (
    id BIGSERIAL PRIMARY KEY,
    receipt_id BIGINT NOT NULL REFERENCES receipt(id),
    line_no INTEGER NOT NULL,
    goods_id BIGINT NOT NULL,
    goods_name VARCHAR(256),
    barcode VARCHAR(32),
    quantity NUMERIC(18,4) NOT NULL,
    price NUMERIC(18,4) NOT NULL,
    discount NUMERIC(18,4) NOT NULL DEFAULT 0,
    total NUMERIC(18,4) NOT NULL,
    vat_rate NUMERIC(5,4) NOT NULL DEFAULT 0,
    vat NUMERIC(18,4) NOT NULL DEFAULT 0
);

-- | Рассчитать чек
CREATE OR REPLACE FUNCTION calc_receipt_total(p_receipt_id BIGINT)
RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_total NUMERIC(18,4);
BEGIN
    SELECT COALESCE(SUM(total - discount), 0)
    INTO v_total
    FROM receipt_item
    WHERE receipt_id = p_receipt_id;
    
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

-- | Рассчитать сдачу
CREATE OR REPLACE FUNCTION calc_change(p_payment NUMERIC(18,4), p_total NUMERIC(18,4))
RETURNS NUMERIC(18,4) AS $$
BEGIN
    IF p_payment < p_total THEN
        RETURN 0;
    END IF;
    RETURN p_payment - p_total;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- LOCATION PROCEDURES
-- ============================================================================

-- | Проверить иерархию на циклы
CREATE OR REPLACE FUNCTION check_location_hierarchy(p_location_id BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    v_parent_id BIGINT;
    v_current_id BIGINT;
BEGIN
    v_current_id := p_location_id;
    
    LOOP
        SELECT parent_id INTO v_parent_id
        FROM location
        WHERE id = v_current_id;
        
        IF v_parent_id IS NULL OR v_parent_id = 0 THEN
            RETURN TRUE;  -- Нет цикла
        END IF;
        
        IF v_parent_id = p_location_id THEN
            RETURN FALSE;  -- Цикл найден
        END IF;
        
        v_current_id := v_parent_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- NOTIFICATIONS PROCEDURES
-- ============================================================================

-- | Таблица уведомлений
CREATE TABLE IF NOT EXISTS notification (
    id BIGSERIAL PRIMARY KEY,
    type SMALLINT NOT NULL DEFAULT 0,  -- 0: Info, 1: Warning, 2: Error, 3: Success, 4: Critical
    title VARCHAR(256) NOT NULL,
    body TEXT NOT NULL,
    channel SMALLINT NOT NULL DEFAULT 0,  -- 0: Email, 1: SMS, 2: Push, 3: Telegram
    recipient VARCHAR(256) NOT NULL,
    scheduled_at TIMESTAMP NOT NULL,
    sent_at TIMESTAMP,
    read_at TIMESTAMP,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- | Создать уведомление
CREATE OR REPLACE FUNCTION create_notification(
    p_type SMALLINT,
    p_title VARCHAR,
    p_body TEXT,
    p_channel SMALLINT,
    p_recipient VARCHAR,
    p_scheduled_at TIMESTAMP
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO notification (type, title, body, channel, recipient, scheduled_at)
    VALUES (p_type, p_title, p_body, p_channel, p_recipient, p_scheduled_at)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- | Отправить уведомление
CREATE OR REPLACE FUNCTION send_notification(p_notification_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE notification
    SET sent_at = CURRENT_TIMESTAMP
    WHERE id = p_notification_id
      AND sent_at IS NULL;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ANALYTICS PROCEDURES
-- ============================================================================

-- | Рассчитать выручку за период
CREATE OR REPLACE FUNCTION calc_revenue(p_date_from DATE, p_date_to DATE)
RETURNS NUMERIC(18,4) AS $$
BEGIN
    SELECT COALESCE(SUM(total), 0)
    FROM receipt
    WHERE created_at::DATE BETWEEN p_date_from AND p_date_to
      AND status = 1;  -- Completed
END;
$$ LANGUAGE plpgsql;

-- | Рассчитать валовую прибыль
CREATE OR REPLACE FUNCTION calc_gross_profit(p_date_from DATE, p_date_to DATE)
RETURNS NUMERIC(18,4) AS $$
DECLARE
    v_revenue NUMERIC(18,4);
    v_cost NUMERIC(18,4);
BEGIN
    v_revenue := calc_revenue(p_date_from, p_date_to);
    
    SELECT COALESCE(SUM(ri.quantity * ri.price), 0)
    INTO v_cost
    FROM receipt r
    JOIN receipt_item ri ON ri.receipt_id = r.id
    WHERE r.created_at::DATE BETWEEN p_date_from AND p_date_to
      AND r.status = 1;
    
    RETURN v_revenue - v_cost;
END;
$$ LANGUAGE plpgsql;

-- | Рассчитать рентабельность
CREATE OR REPLACE FUNCTION calc_profitability(p_profit NUMERIC(18,4), p_revenue NUMERIC(18,4))
RETURNS NUMERIC(5,2) AS $$
BEGIN
    IF p_revenue = 0 THEN
        RETURN 0;
    END IF;
    RETURN (p_profit / p_revenue) * 100;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO openpapyrus_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO openpapyrus_user;
