-- Migration to add missing columns to match procedures.sql schema
-- B1-1: Align tables with procedures

-- Add missing columns to bills table
ALTER TABLE bills ADD COLUMN IF NOT EXISTS vat_sum DECIMAL(15, 2) DEFAULT 0;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS edi_status SMALLINT DEFAULT 0;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS edi_conf_status SMALLINT DEFAULT 0;
ALTER TABLE bills ADD COLUMN IF NOT EXISTS obj_type VARCHAR(50);
ALTER TABLE bills ADD COLUMN IF NOT EXISTS bill_type SMALLINT NOT NULL DEFAULT 1;

-- Rename columns if needed to match procedures
-- The procedures use: bill_id, line_num, discount, vat_rate, vat_amount, line_total

-- Add missing columns to bill_lines table
ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS line_num SMALLINT;
ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS discount DECIMAL(15, 2) DEFAULT 0;
ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS vat_rate DECIMAL(5, 2) DEFAULT 0;
ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS vat_amount DECIMAL(15, 2) DEFAULT 0;
ALTER TABLE bill_lines ADD COLUMN IF NOT EXISTS line_total DECIMAL(15, 2) DEFAULT 0;

-- Add missing columns to lot table
ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_goods_id INT;
ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_location_id INT;
ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_qty DECIMAL(15, 4) DEFAULT 0;
ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_cost DECIMAL(15, 2);
ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_price DECIMAL(15, 2);
ALTER TABLE lot ADD COLUMN IF NOT EXISTS lot_date TIMESTAMP;

-- Add missing columns to stock_movement table
ALTER TABLE stock_movement ADD COLUMN IF NOT EXISTS sm_goods_id INT;
ALTER TABLE stock_movement ADD COLUMN IF NOT EXISTS sm_location_id INT;
ALTER TABLE stock_movement ADD COLUMN IF NOT EXISTS sm_qty DECIMAL(15, 4);

-- Add missing columns to acc_turn table
ALTER TABLE acc_turn ADD COLUMN IF NOT EXISTS dbt_acc_id INT;
ALTER TABLE acc_turn ADD COLUMN IF NOT EXISTS crd_acc_id INT;
ALTER TABLE acc_turn ADD COLUMN IF NOT EXISTS bill_id BIGINT;

-- Add missing columns to hr_salary table
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS employee_id INT;
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS charge_id INT;
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS period_start DATE;
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS period_end DATE;
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS amount DECIMAL(15, 2);
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS ext_obj_id INT;
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS link_bill_id BIGINT;
ALTER TABLE hr_salary ADD COLUMN IF NOT EXISTS gen_bill_id BIGINT;
