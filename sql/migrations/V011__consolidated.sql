-- Migration V011: Consolidated accounting events and schema fixes
-- Original files: V011__accounting_events.sql, V011__fix_schema_columns.sql

-- Create accounting_events table (from accounting_events.sql)
CREATE TABLE IF NOT EXISTS accounting_events (
    id BIGSERIAL PRIMARY KEY,
    event_id UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    aggregate_id BIGINT NOT NULL REFERENCES account(id),
    aggregate_type VARCHAR(50) DEFAULT 'account',
    event_type VARCHAR(100) NOT NULL,
    event_version INTEGER DEFAULT 1,
    event_data JSONB NOT NULL,
    metadata JSONB,
    sequence_number BIGINT NOT NULL,
    occurred_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(aggregate_id, sequence_number)
);

CREATE INDEX IF NOT EXISTS idx_accounting_events_aggregate ON accounting_events(aggregate_id);
CREATE INDEX IF NOT EXISTS idx_accounting_events_type ON accounting_events(event_type);
CREATE INDEX IF NOT EXISTS idx_accounting_events_occurred_at ON accounting_events(occurred_at);
CREATE INDEX IF NOT EXISTS idx_accounting_events_event_id ON accounting_events(event_id);

-- Add missing columns from fix_schema_columns.sql
ALTER TABLE bills ADD COLUMN IF NOT EXISTS vat_sum DECIMAL(15, 2) DEFAULT 0;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS edi_status SMALLINT DEFAULT 0;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS edi_conf_status SMALLINT DEFAULT 0;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS obj_type VARCHAR(50);
ALTER TABLE bills ADD COLUMN IF NOT EXISTS bill_type SMALLINT NOT NULL DEFAULT 1;

ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS line_num SMALLINT;
ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS discount DECIMAL(15, 2) DEFAULT 0;
ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS vat_rate DECIMAL(5, 2) DEFAULT 0;
ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS vat_amount DECIMAL(15, 2) DEFAULT 0;
ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS line_total DECIMAL(15, 2) DEFAULT 0;

ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_goods_id INT;
ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_location_id INT;
ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_qty DECIMAL(15, 4) DEFAULT 0;
ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_cost DECIMAL(15, 2);
ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_price DECIMAL(15, 2);
ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_date TIMESTAMP;

ALTER TABLE stock_movement ADD COLUMN IF NOT EXISTS sm_goods_id INT;
ALTER TABLE stock_movement ADD COLUMN IF NOT EXISTS sm_location_id INT;
ALTER TABLE stock_movement ADD COLUMN IF NOT EXISTS sm_qty DECIMAL(15, 4);

ALTER TABLE acc_turn ADD COLUMN IF NOT EXISTS dbt_acc_id INT;
ALTER TABLE acc_turn ADD COLUMN IF NOT EXISTS crd_acc_id INT;
ALTER TABLE acc_turn ADD COLUMN IF NOT EXISTS bill_id BIGINT;

ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS employee_id INT;
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS charge_id INT;
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS period_start DATE;
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS period_end DATE;
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS amount DECIMAL(15, 2);
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS ext_obj_id INT;
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS link_bill_id BIGINT;
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS gen_bill_id BIGINT;
