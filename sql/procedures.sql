-- ============================================================================
-- PostgreSQL Stored Procedures for Surypus
-- ============================================================================
-- These procedures implement critical business logic in the database
-- for performance and data integrity
-- ============================================================================

-- ============================================================================
-- WAREHOUSE / INVENTORY PROCEDURES
-- ============================================================================

-- Calculate stock balance for goods at location
CREATE OR REPLACE FUNCTION calc_stock_balance(
    p_goods_id BIGINT,
    p_location_id BIGINT,
    p_initial_qty NUMERIC DEFAULT 0
)
RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(
        CASE 
            WHEN sm_qty > 0 THEN sm_qty
            ELSE -ABS(sm_qty)
        END
    ), 0)
    INTO v_total
    FROM stock_movement
    WHERE sm_goods_id = p_goods_id 
      AND sm_location_id = p_location_id;
    
    RETURN p_initial_qty + v_total;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- FIFO write-off: select lots for goods issue
CREATE OR REPLACE FUNCTION fifo_select_lots(
    p_goods_id BIGINT,
    p_location_id BIGINT,
    p_qty_needed NUMERIC
)
RETURNS TABLE (
    lot_id BIGINT,
    lot_date DATE,
    qty_used NUMERIC,
    cost NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.lot_id,
        l.lot_date,
        CASE 
            WHEN l.lot_qty >= p_qty_needed THEN p_qty_needed
            ELSE l.lot_qty
        END AS qty_used,
        l.lot_cost
    FROM lot l
    WHERE l.lot_goods_id = p_goods_id
      AND l.lot_location_id = p_location_id
      AND l.lot_qty > 0
    ORDER BY l.lot_date ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Get lot bounds (min/max dates for goods)
CREATE OR REPLACE FUNCTION get_lot_bounds(
    p_goods_id BIGINT,
    p_location_id BIGINT
)
RETURNS TABLE (
    min_date DATE,
    max_date DATE,
    total_qty NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        MIN(l.lot_date) AS min_date,
        MAX(l.lot_date) AS max_date,
        SUM(l.lot_qty) AS total_qty
    FROM lot l
    WHERE l.lot_goods_id = p_goods_id
      AND l.lot_location_id = p_location_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TAX CALCULATION PROCEDURES
-- ============================================================================

-- Calculate VAT amount
CREATE OR REPLACE FUNCTION calc_vat(
    p_amount NUMERIC,
    p_rate NUMERIC
)
RETURNS NUMERIC AS $$
BEGIN
    RETURN CASE 
        WHEN p_amount < 0 OR p_rate < 0 THEN 0
        ELSE ROUND(p_amount * p_rate / (100 + p_rate), 2)
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculate VAT from inclusive price
CREATE OR REPLACE FUNCTION calc_vat_inclusive(
    p_inclusive NUMERIC,
    p_rate NUMERIC
)
RETURNS NUMERIC AS $$
BEGIN
    RETURN CASE 
        WHEN p_inclusive < 0 OR p_rate < 0 THEN 0
        ELSE ROUND(p_inclusive * p_rate / (100 + p_rate), 2)
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculate price without VAT
CREATE OR REPLACE FUNCTION calc_price_without_vat(
    p_inclusive NUMERIC,
    p_rate NUMERIC
)
RETURNS NUMERIC AS $$
BEGIN
    RETURN CASE 
        WHEN p_inclusive < 0 OR p_rate < 0 THEN 0
        ELSE ROUND(p_inclusive * 100 / (100 + p_rate), 2)
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculate line totals (price, discount, tax, total)
CREATE OR REPLACE FUNCTION calc_line_totals(
    p_qty NUMERIC,
    p_price NUMERIC,
    p_discount NUMERIC,
    p_vat_rate NUMERIC
)
RETURNS TABLE (
    amount NUMERIC,
    discount NUMERIC,
    vat_amount NUMERIC,
    total NUMERIC
) AS $$
DECLARE
    v_amount NUMERIC;
    v_discount NUMERIC;
    v_before_vat NUMERIC;
    v_vat NUMERIC;
    v_total NUMERIC;
BEGIN
    v_amount := ROUND(p_qty * p_price, 2);
    v_discount := GREATEST(p_discount, 0);
    v_before_vat := GREATEST(v_amount - v_discount, 0);
    v_vat := calc_vat(v_before_vat, p_vat_rate);
    v_total := v_before_vat + v_vat;
    
    RETURN QUERY SELECT v_amount, v_discount, v_vat, v_total;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Calculate bill totals
CREATE OR REPLACE FUNCTION calc_bill_totals(
    p_bill_id BIGINT
)
RETURNS TABLE (
    total NUMERIC,
    discount NUMERIC,
    vat_amount NUMERIC,
    total_with_vat NUMERIC
) AS $$
DECLARE
    v_total NUMERIC;
    v_discount NUMERIC;
    v_vat NUMERIC;
    v_total_with_vat NUMERIC;
BEGIN
    SELECT COALESCE(SUM(amount), 0),
           COALESCE(SUM(discount), 0),
           COALESCE(SUM(vat_amount), 0),
           COALESCE(SUM(line_total), 0)
    INTO v_total, v_discount, v_vat, v_total_with_vat
    FROM bill_line
    WHERE bill_id = p_bill_id;
    
    RETURN QUERY SELECT v_total, v_discount, v_vat, v_total_with_vat;
END;
$$ LANGUAGE plpgsql;

-- HR PAYROLL PROCEDURES
CREATE OR REPLACE FUNCTION create_salary_record(
    p_employee_id BIGINT,
    p_charge_id BIGINT,
    p_period_start DATE,
    p_period_end DATE,
    p_amount NUMERIC,
    p_ext_obj_id BIGINT DEFAULT 0,
    p_link_bill_id BIGINT DEFAULT 0,
    p_gen_bill_id BIGINT DEFAULT 0
)
RETURNS BIGINT AS $$
DECLARE
    v_conflict BIGINT;
BEGIN
    IF p_period_start > p_period_end THEN
        RAISE EXCEPTION 'period mismatch: % > %', p_period_start, p_period_end;
    END IF;
    IF p_amount < 0 THEN
        RAISE EXCEPTION 'amount must be non-negative';
    END IF;
    SELECT id INTO v_conflict
    FROM hr_salary
    WHERE employee_id = p_employee_id
      AND charge_id = p_charge_id
      AND NOT (period_end < p_period_start OR period_start > p_period_end)
    LIMIT 1;
    IF v_conflict IS NOT NULL THEN
        RAISE EXCEPTION 'overlapping salary record % for employee % and charge %', v_conflict, p_employee_id, p_charge_id;
    END IF;
    INSERT INTO hr_salary (employee_id, charge_id, period_start, period_end, amount, ext_obj_id, link_bill_id, gen_bill_id)
    VALUES (p_employee_id, p_charge_id, p_period_start, p_period_end, p_amount, p_ext_obj_id, p_link_bill_id, p_gen_bill_id)
    RETURNING id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION calc_salary_sum(
    p_employee_id BIGINT,
    p_charge_id BIGINT,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS NUMERIC AS $$
DECLARE
    v_sum NUMERIC;
BEGIN
    SELECT COALESCE(SUM(amount), 0)
    INTO v_sum
    FROM hr_salary
    WHERE employee_id = p_employee_id
      AND charge_id = p_charge_id
      AND period_start >= p_period_start
      AND period_end <= p_period_end;
    RETURN v_sum;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION hr_payroll_summary(
    p_period_start DATE,
    p_period_end DATE
) RETURNS TABLE (
    employee_id BIGINT,
    employee_name TEXT,
    position_name TEXT,
    total_salary NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.id,
        p.name,
        pos.name,
        COALESCE(SUM(s.amount), 0)
    FROM employee e
    JOIN person p ON p.id = e.person_id
    JOIN position pos ON pos.id = e.position_id
    LEFT JOIN hr_salary s ON s.employee_id = e.id
      AND s.period_start >= p_period_start
      AND s.period_end <= p_period_end
    WHERE e.status = 0
    GROUP BY e.id, p.name, pos.name
    ORDER BY total_salary DESC;
END;
$$ LANGUAGE plpgsql;

-- Insert bill line with validation
CREATE OR REPLACE FUNCTION create_bill_line(
    p_bill_id BIGINT,
    p_goods_id BIGINT,
    p_quantity NUMERIC,
    p_price NUMERIC,
    p_discount NUMERIC,
    p_vat_rate NUMERIC,
    p_vat_amount NUMERIC,
    p_line_total NUMERIC
)
RETURNS BIGINT AS $$
DECLARE
    v_net NUMERIC;
    v_expected_tax NUMERIC;
    v_total NUMERIC;
    v_line_num INT;
    v_line_id BIGINT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'quantity must be positive';
    END IF;
    IF p_price < 0 OR p_discount < 0 OR p_vat_rate < 0 THEN
        RAISE EXCEPTION 'invalid price/discount/vat';
    END IF;
    v_net := GREATEST(p_quantity * p_price - p_discount, 0);
    v_expected_tax := calc_vat(v_net, p_vat_rate);
    IF ABS(v_expected_tax - p_vat_amount) > 0.01 THEN
        RAISE EXCEPTION 'vat amount mismatch';
    END IF;
    v_total := v_net + v_expected_tax;
    IF ABS(v_total - p_line_total) > 0.01 THEN
        RAISE EXCEPTION 'line total mismatch';
    END IF;
    SELECT COALESCE(MAX(line_num), 0) + 1 INTO v_line_num FROM bill_line WHERE bill_id = p_bill_id;
    INSERT INTO bill_line (bill_id, line_num, goods_id, quantity, price, discount, vat_rate, amount, vat_amount, line_total)
    VALUES (p_bill_id, v_line_num, p_goods_id, p_quantity, p_price, p_discount, p_vat_rate, v_net, v_expected_tax, v_total)
    RETURNING id INTO v_line_id;
    RETURN v_line_id;
END;
$$ LANGUAGE plpgsql;

-- Recalculate header totals
CREATE OR REPLACE FUNCTION recalc_bill_totals(
    p_bill_id BIGINT
)
RETURNS VOID AS $$
DECLARE
    v_total NUMERIC;
    v_discount NUMERIC;
    v_vat NUMERIC;
    v_total_with_vat NUMERIC;
BEGIN
    SELECT total, discount, vat_amount, total_with_vat
    INTO v_total, v_discount, v_vat, v_total_with_vat
    FROM calc_bill_totals(p_bill_id);

    UPDATE bill
    SET amount = v_total_with_vat,
        vat_sum = v_vat
    WHERE id = p_bill_id;
END;
$$ LANGUAGE plpgsql;

-- Update EDI statuses
CREATE OR REPLACE FUNCTION set_bill_edi_status(
    p_bill_id BIGINT,
    p_status INT,
    p_conf_status INT
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE bill
    SET edi_status = p_status,
        edi_conf_status = p_conf_status
    WHERE id = p_bill_id;
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DOCUMENT REGISTERS
-- ============================================================================

CREATE OR REPLACE FUNCTION create_document_register_entry(
    p_person_id INT,
    p_type_id INT,
    p_series TEXT,
    p_number TEXT,
    p_issue_date DATE,
    p_expiry_date DATE,
    p_issuer TEXT,
    p_flags INT,
    p_auto_number BOOLEAN
)
RETURNS BIGINT AS $$
DECLARE
    v_type_flags INT;
    v_number TEXT := p_number;
    v_next_number TEXT;
    v_allow_duplicates BOOLEAN;
    v_id BIGINT;
BEGIN
    SELECT flags INTO v_type_flags FROM document_register_type WHERE id = p_type_id;
    v_allow_duplicates := (v_type_flags & 64) <> 0;
    IF p_auto_number OR v_number IS NULL OR TRIM(v_number) = '' THEN
        v_number := document_get_next_register_number(p_type_id);
    ELSIF NOT v_allow_duplicates AND document_register_number_exists(p_type_id, v_number) THEN
        RAISE EXCEPTION 'register number % already exists for type %', v_number, p_type_id;
    END IF;

    INSERT INTO document_register (person_id, type_id, series, number, issue_date, expiry_date, issuer, flags, auto_number)
    VALUES (p_person_id, p_type_id, p_series, v_number, p_issue_date, p_expiry_date, p_issuer, p_flags, p_auto_number)
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_document_register_entry(
    p_register_id BIGINT,
    p_person_id INT,
    p_type_id INT,
    p_series TEXT,
    p_number TEXT,
    p_issue_date DATE,
    p_expiry_date DATE,
    p_issuer TEXT,
    p_flags INT,
    p_auto_number BOOLEAN
)
RETURNS BOOLEAN AS $$
DECLARE
    v_type_flags INT;
    v_number TEXT := p_number;
    v_allow_duplicates BOOLEAN;
    v_found INT;
BEGIN
    SELECT flags INTO v_type_flags FROM document_register_type WHERE id = p_type_id;
    v_allow_duplicates := (v_type_flags & 64) <> 0;

    IF p_auto_number OR v_number IS NULL OR TRIM(v_number) = '' THEN
        v_number := document_get_next_register_number(p_type_id);
    ELSIF NOT v_allow_duplicates THEN
        SELECT COUNT(1) INTO v_found FROM document_register
        WHERE type_id = p_type_id AND number = v_number AND id <> p_register_id;
        IF v_found > 0 THEN
            RAISE EXCEPTION 'register number % already exists for type %', v_number, p_type_id;
        END IF;
    END IF;

    UPDATE document_register
    SET person_id = p_person_id,
        type_id = p_type_id,
        series = p_series,
        number = v_number,
        issue_date = p_issue_date,
        expiry_date = p_expiry_date,
        issuer = p_issuer,
        flags = p_flags,
        auto_number = p_auto_number,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_register_id;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- GOODS PROCEDURES
-- ============================================================================

-- Get goods by barcode
CREATE OR REPLACE FUNCTION get_goods_by_barcode(p_barcode TEXT)
RETURNS TABLE (
    goods_id BIGINT,
    goods_code TEXT,
    goods_name TEXT,
    goods_price NUMERIC,
    goods_cost NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        g.id,
        g.code,
        g.name,
        g.price,
        g.cost
    FROM goods g
    WHERE g.barcode = p_barcode
      AND g.status = 0;
END;
$$ LANGUAGE plpgsql;

-- Calculate goods average cost
CREATE OR REPLACE FUNCTION calc_goods_avg_cost(p_goods_id BIGINT, p_location_id BIGINT)
RETURNS NUMERIC AS $$
DECLARE
    v_avg_cost NUMERIC;
BEGIN
    SELECT COALESCE(SUM(l.lot_qty * l.lot_cost) / NULLIF(SUM(l.lot_qty), 0), 0)
    INTO v_avg_cost
    FROM lot l
    WHERE l.goods_id = p_goods_id
      AND l.location_id = p_location_id
      AND l.qty > 0;
    
    RETURN v_avg_cost;
END;
$$ LANGUAGE plpgsql;

-- Check reorder point
CREATE OR REPLACE FUNCTION check_reorder_needed(p_goods_id BIGINT, p_location_id BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    v_current_qty NUMERIC;
    v_reorder_point NUMERIC;
BEGIN
    SELECT COALESCE(SUM(lot_qty), 0), g.reorder_point
    INTO v_current_qty, v_reorder_point
    FROM lot l
    JOIN goods g ON g.id = l.goods_id
    WHERE l.goods_id = p_goods_id
      AND l.location_id = p_location_id
    GROUP BY g.reorder_point;
    
    RETURN v_current_qty <= v_reorder_point;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PERSON PROCEDURES
-- ============================================================================

-- Validate INN (Russian Tax ID)
CREATE OR REPLACE FUNCTION validate_inn(p_inn TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_inn_len INT;
    v_checksum INT;
    v_digits INT[];
    v_i INT;
    v_sum INT := 0;
BEGIN
    v_inn_len := LENGTH(p_inn);
    
    IF v_inn_len NOT IN (10, 12) THEN
        RETURN FALSE;
    END IF;
    
    -- Check if all characters are digits
    IF p_inn !~ '^[0-9]+$' THEN
        RETURN FALSE;
    END IF;
    
    -- For 10-digit INN: check control digit
    IF v_inn_len = 10 THEN
        v_digits := string_to_array(p_inn, NULL)::INT[];
        v_sum := (v_digits[1] * 2 + v_digits[2] * 4 + v_digits[3] * 10 + 
                  v_digits[4] * 3 + v_digits[5] * 5 + v_digits[6] * 9 + 
                  v_digits[7] * 4 + v_digits[8] * 6 + v_digits[9] * 8) % 11;
        RETURN v_sum = v_digits[10];
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DOCUMENT PROCEDURES
-- ============================================================================

-- Create bill with lines
CREATE OR REPLACE FUNCTION create_bill(
    p_code TEXT,
    p_date DATE,
    p_op_kind_id BIGINT,
    p_person_id BIGINT,
    p_location_id BIGINT,
    p_amount NUMERIC
)
RETURNS BIGINT AS $$
DECLARE
    v_bill_id BIGINT;
BEGIN
    INSERT INTO bill (code, date, op_kind_id, person_id, location_id, amount, status)
    VALUES (p_code, p_date, p_op_kind_id, p_person_id, p_location_id, p_amount, 0)
    RETURNING id INTO v_bill_id;
    
    RETURN v_bill_id;
END;
$$ LANGUAGE plpgsql;

-- Post bill (create accounting entries)
CREATE OR REPLACE FUNCTION post_bill(p_bill_id BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    v_bill_amount NUMERIC;
    v_vat_amount NUMERIC;
    v_status INT;
BEGIN
    SELECT status
    INTO v_status
    FROM bill
    WHERE id = p_bill_id;

    IF v_status != 0 THEN
        RETURN FALSE;
    END IF;

    PERFORM recalc_bill_totals(p_bill_id);

    SELECT amount, COALESCE(vat_sum, 0)
    INTO v_bill_amount, v_vat_amount
    FROM bill
    WHERE id = p_bill_id;

    INSERT INTO acc_turn (bill_id, dbt_acc_id, crd_acc_id, amount, date)
    SELECT p_bill_id, 1, 2, GREATEST(v_bill_amount - v_vat_amount, 0), NOW()::DATE
    WHERE v_bill_amount - v_vat_amount > 0;

    INSERT INTO acc_turn (bill_id, dbt_acc_id, crd_acc_id, amount, date)
    SELECT p_bill_id, 1, 3, v_vat_amount, NOW()::DATE
    WHERE v_vat_amount > 0;

    UPDATE bill SET status = 1 WHERE id = p_bill_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- REPORT PROCEDURES
-- ============================================================================

-- Get sales report by period
CREATE OR REPLACE FUNCTION get_sales_report(
    p_date_from DATE,
    p_date_to DATE
)
RETURNS TABLE (
    goods_id BIGINT,
    goods_name TEXT,
    total_qty NUMERIC,
    total_amount NUMERIC,
    total_vat NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        bl.goods_id,
        g.name,
        SUM(bl.qty) AS total_qty,
        SUM(bl.amount) AS total_amount,
        SUM(bl.vat_amount) AS total_vat
    FROM bill_line bl
    JOIN bill b ON b.id = bl.bill_id
    JOIN goods g ON g.id = bl.goods_id
    WHERE b.date BETWEEN p_date_from AND p_date_to
      AND b.status = 1
    GROUP BY bl.goods_id, g.name;
END;
$$ LANGUAGE plpgsql;

-- Get inventory report
CREATE OR REPLACE FUNCTION get_inventory_report(p_location_id BIGINT)
RETURNS TABLE (
    goods_id BIGINT,
    goods_name TEXT,
    lot_qty NUMERIC,
    lot_cost NUMERIC,
    lot_price NUMERIC,
    rest_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.goods_id,
        g.name,
        l.lot_qty,
        l.lot_cost,
        l.lot_price,
        l.lot_qty * l.lot_cost AS rest_value
    FROM lot l
    JOIN goods g ON g.id = l.goods_id
    WHERE l.location_id = p_location_id
      AND l.lot_qty > 0
    ORDER BY g.name;
END;
$$ LANGUAGE plpgsql;

-- Validate double entry: total debit = total credit
CREATE OR REPLACE FUNCTION validate_double_entry(
    p_bill_id BIGINT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_debit NUMERIC;
    v_credit NUMERIC;
BEGIN
    SELECT COALESCE(SUM(at_amount), 0)
    INTO v_debit
    FROM acc_turn
    WHERE at_bill_id = p_bill_id
      AND at_dbt_acc_id IS NOT NULL;
    
    SELECT COALESCE(SUM(at_amount), 0)
    INTO v_credit
    FROM acc_turn
    WHERE at_bill_id = p_bill_id
      AND at_crd_acc_id IS NOT NULL;
    
    RETURN v_debit = v_credit;
END;
$$ LANGUAGE plpgsql;

-- Calculate account balance
CREATE OR REPLACE FUNCTION calc_account_balance(
    p_account_id BIGINT,
    p_date_from DATE DEFAULT NULL,
    p_date_to DATE DEFAULT NULL
)
RETURNS NUMERIC AS $$
DECLARE
    v_debit NUMERIC;
    v_credit NUMERIC;
BEGIN
    SELECT COALESCE(SUM(at_amount), 0)
    INTO v_debit
    FROM acc_turn
    WHERE at_dbt_acc_id = p_account_id
      AND (p_date_from IS NULL OR at_date >= p_date_from)
      AND (p_date_to IS NULL OR at_date <= p_date_to);
    
    SELECT COALESCE(SUM(at_amount), 0)
    INTO v_credit
    FROM acc_turn
    WHERE at_crd_acc_id = p_account_id
      AND (p_date_from IS NULL OR at_date >= p_date_from)
      AND (p_date_to IS NULL OR at_date <= p_date_to);
    
    RETURN v_debit - v_credit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- HR / SALARY PROCEDURES
-- ============================================================================

-- Calculate employee salary
CREATE OR REPLACE FUNCTION calc_salary(
    p_employee_id BIGINT,
    p_period DATE,
    p_base NUMERIC,
    p_bonus NUMERIC DEFAULT 0,
    p_penalty NUMERIC DEFAULT 0
)
RETURNS TABLE (
    gross NUMERIC,
    tax NUMERIC,
    net NUMERIC
) AS $$
DECLARE
    v_gross NUMERIC;
    v_tax NUMERIC;
    v_net NUMERIC;
BEGIN
    v_gross := p_base + p_bonus - p_penalty;
    v_tax := ROUND(v_gross * 0.13, 2);
    v_net := v_gross - v_tax;
    
    RETURN QUERY SELECT v_gross, v_tax, v_net;
END;
$$ LANGUAGE plpgsql;

-- Get employee schedule
CREATE OR REPLACE FUNCTION get_employee_schedule(
    p_employee_id BIGINT,
    p_date_from DATE,
    p_date_to DATE
)
RETURNS TABLE (
    work_date DATE,
    hours_worked NUMERIC,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ws.work_date,
        ws.hours_worked,
        CASE 
            WHEN ws.status = 0 THEN 'Worked'
            WHEN ws.status = 1 THEN 'Vacation'
            WHEN ws.status = 2 THEN 'Sick'
            ELSE 'Other'
        END AS status
    FROM work_schedule ws
    WHERE ws.employee_id = p_employee_id
      AND ws.work_date BETWEEN p_date_from AND p_date_to
    ORDER BY ws.work_date;
END;
$$ LANGUAGE plpgsql;
