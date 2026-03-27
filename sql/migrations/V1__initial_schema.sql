-- V1__initial_schema.sql
-- Initial database schema for Surypus ERP

-- Core tables
CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    role_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(100) NOT NULL,
    role_description TEXT,
    permissions JSONB
);

-- Persons / Counterparties
CREATE TABLE IF NOT EXISTS persons (
    person_id SERIAL PRIMARY KEY,
    person_code VARCHAR(50) NOT NULL UNIQUE,
    person_name VARCHAR(500) NOT NULL,
    person_full_name TEXT,
    person_inn VARCHAR(20),
    person_kpp VARCHAR(20),
    person_type SMALLINT NOT NULL DEFAULT 1,
    person_status SMALLINT NOT NULL DEFAULT 1,
    person_category SMALLINT DEFAULT 1,
    person_phone VARCHAR(50),
    person_email VARCHAR(255),
    person_address TEXT,
    person_contact VARCHAR(255),
    credit_limit DECIMAL(15, 2) DEFAULT 0,
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Goods and products
CREATE TABLE IF NOT EXISTS goods (
    goods_id SERIAL PRIMARY KEY,
    goods_code VARCHAR(50) NOT NULL UNIQUE,
    goods_name VARCHAR(500) NOT NULL,
    goods_full_name TEXT,
    goods_type SMALLINT NOT NULL DEFAULT 1,
    unit_id INT,
    goods_group_id INT,
    barcode VARCHAR(100),
    vat_rate_id INT,
    purchase_price DECIMAL(15, 2) DEFAULT 0,
    sell_price DECIMAL(15, 2) DEFAULT 0,
    min_stock DECIMAL(15, 3) DEFAULT 0,
    max_stock DECIMAL(15, 3) DEFAULT 0,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Units of measure
CREATE TABLE IF NOT EXISTS units (
    unit_id SERIAL PRIMARY KEY,
    unit_code VARCHAR(20) NOT NULL UNIQUE,
    unit_name VARCHAR(100) NOT NULL,
    unit_short_name VARCHAR(20)
);

-- Warehouses / Locations
CREATE TABLE IF NOT EXISTS locations (
    location_id SERIAL PRIMARY KEY,
    location_code VARCHAR(50) NOT NULL UNIQUE,
    location_name VARCHAR(500) NOT NULL,
    location_type SMALLINT NOT NULL DEFAULT 1,
    location_address TEXT,
    location_capacity DECIMAL(15, 2) DEFAULT 0,
    responsible_person_id INT,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stock by location
CREATE TABLE IF NOT EXISTS stock (
    stock_id SERIAL PRIMARY KEY,
    goods_id INT NOT NULL,
    location_id INT NOT NULL,
    stock_qty DECIMAL(15, 3) DEFAULT 0,
    reserved_qty DECIMAL(15, 3) DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(goods_id, location_id)
);

-- Bills / Documents
CREATE TABLE IF NOT EXISTS bills (
    bill_id SERIAL PRIMARY KEY,
    bill_number VARCHAR(50) NOT NULL,
    bill_date DATE NOT NULL,
    bill_type SMALLINT NOT NULL,
    bill_person_id INT,
    bill_location_id INT,
    bill_total DECIMAL(15, 2) DEFAULT 0,
    bill_discount DECIMAL(15, 2) DEFAULT 0,
    bill_tax DECIMAL(15, 2) DEFAULT 0,
    bill_status SMALLINT NOT NULL DEFAULT 1,
    bill_memo TEXT,
    bill_author_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Bill lines
CREATE TABLE IF NOT EXISTS bill_lines (
    bill_line_id SERIAL PRIMARY KEY,
    bill_id INT NOT NULL,
    goods_id INT NOT NULL,
    line_number SMALLINT NOT NULL,
    quantity DECIMAL(15, 3) NOT NULL,
    price DECIMAL(15, 2) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    tax_rate DECIMAL(5, 2) DEFAULT 0,
    tax_amount DECIMAL(15, 2) DEFAULT 0,
    discount_percent DECIMAL(5, 2) DEFAULT 0
);

-- Payments
CREATE TABLE IF NOT EXISTS payments (
    payment_id SERIAL PRIMARY KEY,
    payment_date DATE NOT NULL,
    payment_type SMALLINT NOT NULL,
    bill_id INT,
    person_id INT,
    amount DECIMAL(15, 2) NOT NULL,
    currency_id INT,
    exchange_rate DECIMAL(15, 4) DEFAULT 1,
    payment_method SMALLINT DEFAULT 1,
    reference_number VARCHAR(100),
    memo TEXT,
    author_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Currencies
CREATE TABLE IF NOT EXISTS currencies (
    currency_id SERIAL PRIMARY KEY,
    currency_code VARCHAR(3) NOT NULL UNIQUE,
    currency_name VARCHAR(100) NOT NULL,
    currency_symbol VARCHAR(10),
    exchange_rate DECIMAL(15, 6) DEFAULT 1,
    is_base BOOLEAN DEFAULT FALSE,
    active BOOLEAN DEFAULT TRUE
);

-- Taxes
CREATE TABLE IF NOT EXISTS taxes (
    tax_id SERIAL PRIMARY KEY,
    tax_name VARCHAR(100) NOT NULL,
    tax_rate DECIMAL(5, 2) NOT NULL,
    tax_type SMALLINT NOT NULL DEFAULT 1,
    tax_flags INT DEFAULT 0,
    active BOOLEAN DEFAULT TRUE
);

-- Accounting
CREATE TABLE IF NOT EXISTS acc_plans (
    acc_plan_id SERIAL PRIMARY KEY,
    acc_code VARCHAR(20) NOT NULL UNIQUE,
    acc_name VARCHAR(500) NOT NULL,
    acc_type SMALLINT NOT NULL,
    acc_parent_id INT,
    acc_level SMALLINT DEFAULT 1,
    acc_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS acc_turns (
    acc_turn_id SERIAL PRIMARY KEY,
    acc_date DATE NOT NULL,
    acc_plan_debit_id INT NOT NULL,
    acc_plan_credit_id INT NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    document_type VARCHAR(50),
    document_id INT,
    memo TEXT,
    author_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Document registers
CREATE TABLE IF NOT EXISTS doc_registers (
    register_id SERIAL PRIMARY KEY,
    register_type_id INT NOT NULL,
    register_person_id INT,
    register_number VARCHAR(50) NOT NULL,
    register_date DATE NOT NULL,
    register_issue_date DATE,
    register_expiry_date DATE,
    register_status SMALLINT DEFAULT 1,
    register_memo TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS doc_register_types (
    register_type_id SERIAL PRIMARY KEY,
    register_type_name VARCHAR(200) NOT NULL,
    register_type_code VARCHAR(20) NOT NULL UNIQUE,
    counter_id INT
);

CREATE TABLE IF NOT EXISTS doc_counters (
    counter_id SERIAL PRIMARY KEY,
    counter_name VARCHAR(100) NOT NULL,
    counter_prefix VARCHAR(20),
    counter_suffix VARCHAR(20),
    counter_current_value INT DEFAULT 0,
    counter_op_kind_id INT,
    active BOOLEAN DEFAULT TRUE
);

-- HR / Payroll
CREATE TABLE IF NOT EXISTS employees (
    employee_id SERIAL PRIMARY KEY,
    employee_code VARCHAR(50) NOT NULL UNIQUE,
    person_id INT NOT NULL,
    position VARCHAR(200),
    department VARCHAR(200),
    salary DECIMAL(15, 2) DEFAULT 0,
    hire_date DATE,
    status SMALLINT DEFAULT 1
);

CREATE TABLE IF NOT EXISTS hr_charges (
    charge_id SERIAL PRIMARY KEY,
    charge_name VARCHAR(200) NOT NULL,
    charge_code VARCHAR(50),
    charge_type SMALLINT NOT NULL DEFAULT 1,
    charge_flags INT DEFAULT 0,
    active BOOLEAN DEFAULT TRUE
);

-- Jobs / Tasks
CREATE TABLE IF NOT EXISTS jobs (
    job_id SERIAL PRIMARY KEY,
    job_code VARCHAR(50) NOT NULL,
    job_name VARCHAR(500) NOT NULL,
    job_type SMALLINT NOT NULL,
    job_status SMALLINT DEFAULT 1,
    job_priority SMALLINT DEFAULT 5,
    job_scheduled_at TIMESTAMP,
    job_started_at TIMESTAMP,
    job_completed_at TIMESTAMP,
    job_error_message TEXT,
    job_payload JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS job_dependencies (
    dependency_id SERIAL PRIMARY KEY,
    job_id INT NOT NULL,
    depends_on_job_id INT NOT NULL,
    dependency_type VARCHAR(50) DEFAULT 'BLOCKS'
);

-- Report schedules
CREATE TABLE IF NOT EXISTS report_schedules (
    schedule_id SERIAL PRIMARY KEY,
    schedule_name VARCHAR(200) NOT NULL,
    report_name VARCHAR(100) NOT NULL,
    schedule_cron VARCHAR(100),
    schedule_params JSONB,
    schedule_enabled BOOLEAN DEFAULT TRUE,
    schedule_next_run TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS report_snapshots (
    snapshot_id SERIAL PRIMARY KEY,
    schedule_id INT NOT NULL,
    run_id UUID NOT NULL,
    run_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status SMALLINT DEFAULT 1,
    message TEXT,
    result_data JSONB
);

-- Inventory documents
CREATE TABLE IF NOT EXISTS inventory_documents (
    inv_doc_id SERIAL PRIMARY KEY,
    inv_doc_code VARCHAR(50) NOT NULL,
    inv_doc_date DATE NOT NULL,
    inv_doc_type SMALLINT NOT NULL,
    inv_doc_location_id INT NOT NULL,
    inv_doc_status SMALLINT DEFAULT 1,
    inv_doc_memo TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS inventory_lines (
    inv_line_id SERIAL PRIMARY KEY,
    inv_doc_id INT NOT NULL,
    goods_id INT NOT NULL,
    expected_qty DECIMAL(15, 3),
    actual_qty DECIMAL(15, 3),
    diff_qty DECIMAL(15, 3),
    price DECIMAL(15, 2),
    memo TEXT
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_persons_code ON persons(person_code);
CREATE INDEX IF NOT EXISTS idx_persons_inn ON persons(person_inn);
CREATE INDEX IF NOT EXISTS idx_goods_code ON goods(goods_code);
CREATE INDEX IF NOT EXISTS idx_goods_barcode ON goods(barcode);
CREATE INDEX IF NOT EXISTS idx_bills_date ON bills(bill_date);
CREATE INDEX IF NOT EXISTS idx_bills_person ON bills(bill_person_id);
CREATE INDEX IF NOT EXISTS idx_bills_status ON bills(bill_status);
CREATE INDEX IF NOT EXISTS idx_stock_goods ON stock(goods_id);
CREATE INDEX IF NOT EXISTS idx_stock_location ON stock(location_id);
CREATE INDEX IF NOT EXISTS idx_acc_turns_date ON acc_turns(acc_date);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(job_status);
CREATE INDEX IF NOT EXISTS idx_jobs_scheduled ON jobs(job_scheduled_at);
