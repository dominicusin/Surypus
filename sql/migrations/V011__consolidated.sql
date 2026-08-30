-- Migration V011: Consolidated accounting events and schema fixes
-- Original files: V011__accounting_events.sql, V011__fix_schema_columns.sql

-- uuid-ossp provides uuid_generate_v4(), used by the accounting_events defaults.
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Ensure accounting_events has the full consolidated schema (idempotent: the
-- table may already exist from an earlier migration, so we ADD COLUMN IF NOT
-- EXISTS rather than relying on CREATE TABLE IF NOT EXISTS, which is a no-op
-- when the table is present and would leave columns/indexes missing).
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

-- Backfill any columns missing from a pre-existing accounting_events table.
ALTER TABLE accounting_events ADD COLUMN IF NOT EXISTS event_id UUID DEFAULT uuid_generate_v4() UNIQUE;
ALTER TABLE accounting_events ADD COLUMN IF NOT EXISTS aggregate_type VARCHAR(50) DEFAULT 'account';
ALTER TABLE accounting_events ADD COLUMN IF NOT EXISTS event_version INTEGER DEFAULT 1;
ALTER TABLE accounting_events ADD COLUMN IF NOT EXISTS metadata JSONB;
ALTER TABLE accounting_events ADD COLUMN IF NOT EXISTS occurred_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE accounting_events ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

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

-- The tables below (bill_lines, lot, stock_movement, acc_turn) may be created by
-- later migrations; guard each ALTER so this consolidated migration is ordering-
-- tolerant and idempotent.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bill_lines') THEN
    ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS line_num SMALLINT;
    ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS discount DECIMAL(15, 2) DEFAULT 0;
    ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS vat_rate DECIMAL(5, 2) DEFAULT 0;
    ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS vat_amount DECIMAL(15, 2) DEFAULT 0;
    ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS line_total DECIMAL(15, 2) DEFAULT 0;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'lot') THEN
    ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_goods_id INT;
    ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_location_id INT;
    ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_qty DECIMAL(15, 4) DEFAULT 0;
    ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_cost DECIMAL(15, 2);
    ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_price DECIMAL(15, 2);
    ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_date TIMESTAMP;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stock_movement') THEN
    ALTER TABLE stock_movement ADD COLUMN IF NOT EXISTS sm_goods_id INT;
    ALTER TABLE stock_movement ADD COLUMN IF NOT EXISTS sm_location_id INT;
    ALTER TABLE stock_movement ADD COLUMN IF NOT EXISTS sm_qty DECIMAL(15, 4);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'acc_turn') THEN
    ALTER TABLE acc_turn ADD COLUMN IF NOT EXISTS dbt_acc_id INT;
    ALTER TABLE acc_turn ADD COLUMN IF NOT EXISTS crd_acc_id INT;
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'acc_turn') THEN
    ALTER TABLE acc_turn ADD COLUMN IF NOT EXISTS bill_id BIGINT;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_salary') THEN
    ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS employee_id INT;
    ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS charge_id INT;
    ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS period_start DATE;
    ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS period_end DATE;
    ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS amount DECIMAL(15, 2);
    ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS ext_obj_id INT;
    ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS link_bill_id BIGINT;
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_salary') THEN
    ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS gen_bill_id BIGINT;
  END IF;
END $$;