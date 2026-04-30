-- ============================================================================
-- SURYPUS DATABASE SCHEMA - Complete Schema with Constraints and Indexes
-- ============================================================================
-- PostgreSQL 14+ schema for Surypus ERP/CRM
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- ENUMS
-- ============================================================================

-- Object types
CREATE TYPE obj_type AS ENUM ('person', 'goods', 'location', 'bill', 'job', 'account', 'employee', 'report');

-- Object status
CREATE TYPE obj_status AS ENUM ('active', 'draft', 'pending', 'completed', 'cancelled', 'deleted');

-- Document status
CREATE TYPE doc_status AS ENUM ('draft', 'pending', 'approved', 'completed', 'cancelled');

-- Account types
CREATE TYPE acc_type AS ENUM ('asset', 'liability', 'equity', 'revenue', 'expense');

-- Job status
CREATE TYPE job_status AS ENUM ('pending', 'running', 'completed', 'failed', 'cancelled');

-- ============================================================================
-- COMPANIES (Организации)
-- ============================================================================

CREATE TABLE companies (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(500) NOT NULL,
    full_name VARCHAR(1000),
    inn VARCHAR(12) CHECK (inn ~ '^[0-9]{10,12}$'),
    kpp VARCHAR(9) CHECK (kpp ~ '^[0-9]{9}$'),
    ogrn VARCHAR(13),
    okpo VARCHAR(10),
    address VARCHAR(1000),
    phone VARCHAR(100),
    email VARCHAR(255),
    website VARCHAR(255),
    bank_name VARCHAR(500),
    bank_bik VARCHAR(9),
    bank_account VARCHAR(20),
    bank_cor_account VARCHAR(20),
    status obj_status DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_companies_code ON companies(code);
CREATE INDEX idx_companies_inn ON companies(inn);
CREATE INDEX idx_companies_status ON companies(status);
CREATE INDEX idx_companies_name_gin ON companies USING gin(name gin_trgm_ops);

-- ============================================================================
-- PERSONS (Контрагенты - CRM)
-- ============================================================================

CREATE TABLE persons (
    id BIGSERIAL PRIMARY KEY,
    company_id BIGINT REFERENCES companies(id) ON DELETE SET NULL,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(500) NOT NULL,
    full_name VARCHAR(1000),
    inn VARCHAR(12),
    kpp VARCHAR(9),
    ogrn VARCHAR(13),
    person_type VARCHAR(50) NOT NULL DEFAULT 'company', -- 'company' or 'person'
    status obj_status DEFAULT 'active',
    credit_limit DECIMAL(15,2) DEFAULT 0,
    discount_percent DECIMAL(5,2) DEFAULT 0,
    phone VARCHAR(100),
    email VARCHAR(255),
    address VARCHAR(1000),
    contact_person VARCHAR(500),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_persons_code ON persons(code);
CREATE INDEX idx_persons_company ON persons(company_id);
CREATE INDEX idx_persons_inn ON persons(inn);
CREATE INDEX idx_persons_type ON persons(person_type);
CREATE INDEX idx_persons_status ON persons(status);
CREATE INDEX idx_persons_name_gin ON persons USING gin(name gin_trgm_ops);

-- ============================================================================
-- GOODS (Товары и услуги)
-- ============================================================================

CREATE TABLE goods (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(500) NOT NULL,
    full_name VARCHAR(1000),
    barcode VARCHAR(50),
    goods_type VARCHAR(50) NOT NULL DEFAULT 'goods', -- 'goods', 'service', 'product'
    unit VARCHAR(20) DEFAULT 'pcs',
    vat_rate DECIMAL(5,2) DEFAULT 20.00,
    price DECIMAL(15,2) DEFAULT 0,
    cost_price DECIMAL(15,2) DEFAULT 0,
    parent_id BIGINT REFERENCES goods(id) ON DELETE SET NULL,
    group_id BIGINT,
    status obj_status DEFAULT 'active',
    weight DECIMAL(10,3),
    volume DECIMAL(10,3),
    expiry_days INTEGER,
    min_stock INTEGER DEFAULT 0,
    max_stock INTEGER,
    image_url VARCHAR(500),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_code ON goods(code);
CREATE INDEX idx_goods_barcode ON goods(barcode);
CREATE INDEX idx_goods_parent ON goods(parent_id);
CREATE INDEX idx_goods_group ON goods(group_id);
CREATE INDEX idx_goods_type ON goods(goods_type);
CREATE INDEX idx_goods_status ON goods(status);
CREATE INDEX idx_goods_name_gin ON goods USING gin(name gin_trgm_ops);

-- ============================================================================
-- GOODS GROUPS (Группы товаров)
-- ============================================================================

CREATE TABLE goods_groups (
    id BIGSERIAL PRIMARY KEY,
    parent_id BIGINT REFERENCES goods_groups(id) ON DELETE CASCADE,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(500) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_goods_groups_parent ON goods_groups(parent_id);
CREATE INDEX idx_goods_groups_code ON goods_groups(code);

-- ============================================================================
-- LOCATIONS (Склады и магазины)
-- ============================================================================

CREATE TABLE locations (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(500) NOT NULL,
    location_type VARCHAR(50) NOT NULL DEFAULT 'warehouse', -- 'warehouse', 'shop', 'office'
    address VARCHAR(1000),
    phone VARCHAR(100),
    email VARCHAR(255),
    is_main BOOLEAN DEFAULT FALSE,
    capacity INTEGER,
    status obj_status DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_locations_code ON locations(code);
CREATE INDEX idx_locations_type ON locations(location_type);
CREATE INDEX idx_locations_status ON locations(status);

-- ============================================================================
-- STOCK (Остатки товаров)
-- ============================================================================

CREATE TABLE stock (
    id BIGSERIAL PRIMARY KEY,
    goods_id BIGINT NOT NULL REFERENCES goods(id) ON DELETE CASCADE,
    location_id BIGINT NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 0,
    reserved INTEGER NOT NULL DEFAULT 0,
    ordered INTEGER NOT NULL DEFAULT 0,
    available INTEGER GENERATED ALWAYS AS (quantity - reserved - ordered) STORED,
    min_quantity INTEGER DEFAULT 0,
    max_quantity INTEGER,
    last_movement TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(goods_id, location_id)
);

CREATE INDEX idx_stock_goods ON stock(goods_id);
CREATE INDEX idx_stock_location ON stock(location_id);
CREATE INDEX idx_stock_available ON stock(available) WHERE available < 0;

-- ============================================================================
-- BILLS (Документы - Счета, накладные)
-- ============================================================================

CREATE TABLE bills (
    id BIGSERIAL PRIMARY KEY,
    bill_number VARCHAR(50) NOT NULL UNIQUE,
    bill_type VARCHAR(50) NOT NULL DEFAULT 'invoice', -- 'invoice', 'order', 'act'
    bill_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,
    customer_id BIGINT REFERENCES persons(id) ON DELETE SET NULL,
    supplier_id BIGINT REFERENCES persons(id) ON DELETE SET NULL,
    location_id BIGINT REFERENCES locations(id) ON DELETE SET NULL,
    status doc_status DEFAULT 'draft',
    total DECIMAL(15,2) DEFAULT 0,
    vat_sum DECIMAL(15,2) DEFAULT 0,
    total_with_vat DECIMAL(15,2) DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'RUB',
    payment_terms TEXT,
    delivery_terms TEXT,
    notes TEXT,
    created_by BIGINT,
    approved_by BIGINT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_bills_number ON bills(bill_number);
CREATE INDEX idx_bills_date ON bills(bill_date);
CREATE INDEX idx_bills_customer ON bills(customer_id);
CREATE INDEX idx_bills_supplier ON bills(supplier_id);
CREATE INDEX idx_bills_status ON bills(status);
CREATE INDEX idx_bills_type ON bills(bill_type);

-- ============================================================================
-- BILL ITEMS (Строки документов)
-- ============================================================================

CREATE TABLE bill_items (
    id BIGSERIAL PRIMARY KEY,
    bill_id BIGINT NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
    line_number INTEGER NOT NULL,
    goods_id BIGINT REFERENCES goods(id) ON DELETE SET NULL,
    goods_name VARCHAR(500),
    quantity DECIMAL(15,3) NOT NULL DEFAULT 0,
    unit VARCHAR(20),
    price DECIMAL(15,2) NOT NULL DEFAULT 0,
    vat_rate DECIMAL(5,2) DEFAULT 20.00,
    vat_sum DECIMAL(15,2) DEFAULT 0,
    discount_percent DECIMAL(5,2) DEFAULT 0,
    discount_sum DECIMAL(15,2) DEFAULT 0,
    total DECIMAL(15,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_bill_items_bill ON bill_items(bill_id);
CREATE INDEX idx_bill_items_goods ON bill_items(goods_id);

-- ============================================================================
-- ACCOUNTS (План счетов)
-- ============================================================================

CREATE TABLE accounts (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(500) NOT NULL,
    acc_type acc_type NOT NULL,
    parent_id BIGINT REFERENCES accounts(id) ON DELETE SET NULL,
    is_analytic BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    opening_balance DECIMAL(15,2) DEFAULT 0,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_accounts_code ON accounts(code);
CREATE INDEX idx_accounts_type ON accounts(acc_type);
CREATE INDEX idx_accounts_parent ON accounts(parent_id);
CREATE INDEX idx_accounts_active ON accounts(is_active) WHERE is_active = true;

-- ============================================================================
-- ACCOUNTING ENTRIES (Проводки)
-- ============================================================================

CREATE TABLE accounting_entries (
    id BIGSERIAL PRIMARY KEY,
    entry_date DATE NOT NULL DEFAULT CURRENT_DATE,
    entry_number VARCHAR(50),
    bill_id BIGINT REFERENCES bills(id) ON DELETE SET NULL,
    debit_acc_id BIGINT NOT NULL REFERENCES accounts(id),
    credit_acc_id BIGINT NOT NULL REFERENCES accounts(id),
    amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'RUB',
    currency_rate DECIMAL(10,4) DEFAULT 1,
    amount_cur DECIMAL(15,2),
    memo VARCHAR(1000),
    created_by BIGINT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_entries_date ON accounting_entries(entry_date);
CREATE INDEX idx_entries_number ON accounting_entries(entry_number);
CREATE INDEX idx_entries_bill ON accounting_entries(bill_id);
CREATE INDEX idx_entries_debit ON accounting_entries(debit_acc_id);
CREATE INDEX idx_entries_credit ON accounting_entries(credit_acc_id);

-- ============================================================================
-- EMPLOYEES (Сотрудники)
-- ============================================================================

CREATE TABLE employees (
    id BIGSERIAL PRIMARY KEY,
    person_id BIGINT REFERENCES persons(id) ON DELETE SET NULL,
    employee_number VARCHAR(20) NOT NULL UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    birth_date DATE,
    hire_date DATE NOT NULL,
    fire_date DATE,
    position VARCHAR(500),
    department VARCHAR(500),
    salary DECIMAL(15,2),
    status obj_status DEFAULT 'active',
    inn VARCHAR(12),
    snils VARCHAR(14),
    phone VARCHAR(100),
    email VARCHAR(255),
    address VARCHAR(1000),
    bank_account VARCHAR(20),
    bank_name VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_employees_number ON employees(employee_number);
CREATE INDEX idx_employees_person ON employees(person_id);
CREATE INDEX idx_employees_department ON employees(department);
CREATE INDEX idx_employees_status ON employees(status);
CREATE INDEX idx_employees_name ON employees(last_name, first_name);

-- ============================================================================
-- PAYROLL (Зарплата)
-- ============================================================================

CREATE TABLE payroll (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL REFERENCES employees(id),
    period VARCHAR(7) NOT NULL, -- YYYY-MM
    worked_days INTEGER NOT NULL DEFAULT 0,
    worked_hours DECIMAL(6,2) DEFAULT 0,
    accrued DECIMAL(15,2) NOT NULL DEFAULT 0,
    deductions DECIMAL(15,2) DEFAULT 0,
    tax_ndfl DECIMAL(15,2) DEFAULT 0,
    tax_ndfl_advance DECIMAL(15,2) DEFAULT 0,
    social_contribution DECIMAL(15,2) DEFAULT 0,
    advance_paid DECIMAL(15,2) DEFAULT 0,
    net_pay DECIMAL(15,2) NOT NULL DEFAULT 0,
    payment_date DATE,
    status doc_status DEFAULT 'draft',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(employee_id, period)
);

CREATE INDEX idx_payroll_employee ON payroll(employee_id);
CREATE INDEX idx_payroll_period ON payroll(period);
CREATE INDEX idx_payroll_status ON payroll(status);

-- ============================================================================
-- JOBS (Задачи)
-- ============================================================================

CREATE TABLE jobs (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(500) NOT NULL,
    job_type VARCHAR(50) NOT NULL DEFAULT 'generic',
    status job_status DEFAULT 'pending',
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    scheduled_at TIMESTAMP WITH TIME ZONE,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    result TEXT,
    error_message TEXT,
    created_by BIGINT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_jobs_code ON jobs(code);
CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_jobs_priority ON jobs(priority);
CREATE INDEX idx_jobs_scheduled ON jobs(scheduled_at);

-- ============================================================================
-- REPORTS (Отчёты)
-- ============================================================================

CREATE TABLE reports (
    id BIGSERIAL PRIMARY KEY,
    report_type VARCHAR(50) NOT NULL,
    name VARCHAR(500) NOT NULL,
    template_name VARCHAR(100),
    parameters JSONB,
    status obj_status DEFAULT 'draft',
    file_path VARCHAR(1000),
    file_size BIGINT,
    format VARCHAR(20) DEFAULT 'pdf',
    created_by BIGINT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_reports_type ON reports(report_type);
CREATE INDEX idx_reports_status ON reports(reports);
CREATE INDEX idx_reports_created ON reports(created_at);

-- ============================================================================
-- USER SESSIONS (Сессии пользователей)
-- ============================================================================

CREATE TABLE user_sessions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    token VARCHAR(500) NOT NULL UNIQUE,
    ip_address VARCHAR(50),
    user_agent VARCHAR(500),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sessions_token ON user_sessions(token);
CREATE INDEX idx_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_sessions_expires ON user_sessions(expires_at) WHERE expires_at > CURRENT_TIMESTAMP;

-- ============================================================================
-- AUDIT LOG (Аудит изменений)
-- ============================================================================

CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id BIGINT NOT NULL,
    operation VARCHAR(10) NOT NULL, -- INSERT, UPDATE, DELETE
    old_values JSONB,
    new_values JSONB,
    user_id BIGINT,
    ip_address VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_table ON audit_log(table_name);
CREATE INDEX idx_audit_record ON audit_log(record_id);
CREATE INDEX idx_audit_operation ON audit_log(operation);
CREATE INDEX idx_audit_created ON audit_log(created_at);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_companies_updated_at BEFORE UPDATE ON companies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_persons_updated_at BEFORE UPDATE ON persons
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_goods_updated_at BEFORE UPDATE ON goods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_locations_updated_at BEFORE UPDATE ON locations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_stock_updated_at BEFORE UPDATE ON stock
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bills_updated_at BEFORE UPDATE ON bills
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_accounts_updated_at BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payroll_updated_at BEFORE UPDATE ON payroll
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_jobs_updated_at BEFORE UPDATE ON jobs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate bill totals
CREATE OR REPLACE FUNCTION calculate_bill_total()
RETURNS TRIGGER AS $$
BEGIN
    SELECT 
        COALESCE(SUM(total), 0),
        COALESCE(SUM(vat_sum), 0),
        COALESCE(SUM(total), 0) + COALESCE(SUM(vat_sum), 0)
    INTO NEW.total, NEW.vat_sum, NEW.total_with_vat
    FROM bill_items
    WHERE bill_id = NEW.id;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER calculate_bill_total_trigger
    AFTER INSERT OR UPDATE ON bill_items
    FOR EACH ROW
    EXECUTE FUNCTION calculate_bill_total();

-- ============================================================================
-- VIEWS
-- ============================================================================

-- View: Stock with goods details
CREATE OR REPLACE VIEW v_stock AS
SELECT 
    s.id,
    s.goods_id,
    g.code AS goods_code,
    g.name AS goods_name,
    g.barcode,
    s.location_id,
    l.code AS location_code,
    l.name AS location_name,
    s.quantity,
    s.reserved,
    s.available,
    s.min_quantity,
    s.last_movement
FROM stock s
JOIN goods g ON s.goods_id = g.id
JOIN locations l ON s.location_id = l.id;

-- View: Account balances
CREATE OR REPLACE VIEW v_account_balances AS
SELECT 
    a.id,
    a.code,
    a.name,
    a.acc_type,
    a.opening_balance,
    COALESCE(SUM(CASE WHEN ae.credit_acc_id = a.id THEN ae.amount ELSE 0 END), 0) AS credit_sum,
    COALESCE(SUM(CASE WHEN ae.debit_acc_id = a.id THEN ae.amount ELSE 0 END), 0) AS debit_sum,
    a.opening_balance + COALESCE(SUM(CASE WHEN ae.debit_acc_id = a.id THEN ae.amount ELSE 0 END), 0) 
        - COALESCE(SUM(CASE WHEN ae.credit_acc_id = a.id THEN ae.amount ELSE 0 END), 0) AS balance
FROM accounts a
LEFT JOIN accounting_entries ae ON a.id IN (ae.debit_acc_id, ae.credit_acc_id)
WHERE a.is_active = true
GROUP BY a.id, a.code, a.name, a.acc_type, a.opening_balance;

-- View: Employee salary summary
CREATE OR REPLACE VIEW v_employee_salary AS
SELECT 
    e.id,
    e.employee_number,
    e.first_name,
    e.last_name,
    e.position,
    e.department,
    e.salary,
    COALESCE(SUM(p.accrued), 0) AS total_accrued,
    COALESCE(SUM(p.net_pay), 0) AS total_paid
FROM employees e
LEFT JOIN payroll p ON e.id = p.employee_id AND p.status = 'completed'
WHERE e.status = 'active'
GROUP BY e.id, e.employee_number, e.first_name, e.last_name, e.position, e.department, e.salary;

-- ============================================================================
-- SEQUENCES
-- ============================================================================

CREATE SEQUENCE IF NOT EXISTS companies_code_seq;
CREATE SEQUENCE IF NOT EXISTS persons_code_seq;
CREATE SEQUENCE IF NOT EXISTS goods_code_seq;
CREATE SEQUENCE IF NOT EXISTS locations_code_seq;
CREATE SEQUENCE IF NOT EXISTS bills_number_seq;
CREATE SEQUENCE IF NOT EXISTS accounts_code_seq;
CREATE SEQUENCE IF NOT EXISTS employees_number_seq;
CREATE SEQUENCE IF NOT EXISTS jobs_code_seq;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE companies IS 'Организации (компании)';
COMMENT ON TABLE persons IS 'Контрагенты (CRM)';
COMMENT ON TABLE goods IS 'Товары и услуги';
COMMENT ON TABLE locations IS 'Склады и магазины';
COMMENT ON TABLE stock IS 'Остатки товаров';
COMMENT ON TABLE bills IS 'Документы (счета, накладные)';
COMMENT ON TABLE bill_items IS 'Строки документов';
COMMENT ON TABLE accounts IS 'План счетов';
COMMENT ON TABLE accounting_entries IS 'Бухгалтерские проводки';
COMMENT ON TABLE employees IS 'Сотрудники';
COMMENT ON TABLE payroll IS 'Зарплата';
COMMENT ON TABLE jobs IS 'Задачи';
COMMENT ON TABLE reports IS 'Отчёты';
COMMENT ON TABLE user_sessions IS 'Сессии пользователей';
COMMENT ON TABLE audit_log IS 'Журнал аудита';
