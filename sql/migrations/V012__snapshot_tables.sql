-- Migration for snapshot tables needed by procedures
-- Add to V011 or create new migration

-- Person summary snapshot table
CREATE TABLE IF NOT EXISTS person_summary_snapshot (
    id SERIAL PRIMARY KEY,
    person_id BIGINT NOT NULL REFERENCES person(id),
    snapshot_date DATE NOT NULL,
    total_sales NUMERIC(15, 2) DEFAULT 0,
    total_purchases NUMERIC(15, 2) DEFAULT 0,
    outstanding_debt NUMERIC(15, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_person_summary_snapshot_person ON person_summary_snapshot(person_id);
CREATE INDEX IF NOT EXISTS idx_person_summary_snapshot_date ON person_summary_snapshot(snapshot_date);

-- Payroll snapshot table
CREATE TABLE IF NOT EXISTS payroll_snapshot (
    id SERIAL PRIMARY KEY,
    employee_id BIGINT NOT NULL, -- FK to employees omitted: employees table is provisioned by a later domain migration
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    amount NUMERIC(15, 2) DEFAULT 0,
    snapshot_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payroll_snapshot_employee ON payroll_snapshot(employee_id);
CREATE INDEX IF NOT EXISTS idx_payroll_snapshot_period ON payroll_snapshot(period_start, period_end);