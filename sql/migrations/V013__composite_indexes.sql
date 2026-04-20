-- V013: Composite indexes for common query patterns
-- Improves pagination and filtered queries performance

-- Bills composite indexes for common access patterns
CREATE INDEX IF NOT EXISTS idx_bills_company_date ON bills(company_id, bill_date DESC);
CREATE INDEX IF NOT EXISTS idx_bills_person_status ON bills(person_id, status);
CREATE INDEX IF NOT EXISTS idx_bills_location_type_date ON bills(location_id, bill_type, bill_date DESC);
CREATE INDEX IF NOT EXISTS idx_bills_status_date ON bills(status, bill_date DESC);

-- Goods composite indexes
CREATE INDEX IF NOT EXISTS idx_goods_company_type ON goods(company_id, goods_type);
CREATE INDEX IF NOT EXISTS idx_goods_name_search ON goods(company_id, name);
CREATE INDEX IF NOT EXISTS idx_goods_barcode ON goods(company_id, barcode);

-- Stock composite indexes
CREATE INDEX IF NOT EXISTS idx_stock_location_goods ON stock(location_id, goods_id);
CREATE INDEX IF NOT EXISTS idx_stock_goods_location ON stock(goods_id, location_id);
CREATE INDEX IF NOT EXISTS idx_stock_lot_goods_date ON stock_lot(goods_id, lot_date);

-- Persons composite indexes
CREATE INDEX IF NOT EXISTS idx_persons_company_type ON persons(company_id, person_type);
CREATE INDEX IF NOT EXISTS idx_persons_name_search ON persons(company_id, name);

-- Orders composite indexes
CREATE INDEX IF NOT EXISTS idx_orders_company_status_date ON orders(company_id, status, order_date DESC);
CREATE INDEX IF NOT EXISTS idx_orders_person ON orders(person_id, order_date DESC);

-- Accounting turns composite indexes
CREATE INDEX IF NOT EXISTS idx_acc_turns_date ON accounting_turns(turn_date);
CREATE INDEX IF NOT EXISTS idx_acc_turns_account_date ON accounting_turns(credit_acc_id, turn_date);
CREATE INDEX IF NOT EXISTS idx_acc_turns_debit_date ON accounting_turns(debit_acc_id, turn_date);

-- Job queue composite index for pending job selection
CREATE INDEX IF NOT EXISTS idx_job_queue_status_priority_date ON job_queue(status, priority DESC, created_at ASC);

-- Audit log composite indexes
CREATE INDEX IF NOT EXISTS idx_audit_log_company_time ON audit_log(company_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_user_time ON audit_log(user_id, created_at DESC);

-- Refresh token index for cleanup
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires ON refresh_tokens(expires_at) WHERE expires_at > CURRENT_TIMESTAMP;

-- RBAC grants composite index
CREATE INDEX IF NOT EXISTS idx_rbac_grants_role_subject ON rbac_grants(role_id, subject_id) WHERE deleted_at IS NULL;

-- Analysis tables for dashboard queries
CREATE INDEX IF NOT EXISTS idx_daily_sales_company_date ON daily_sales(company_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_monthly_sales_company_date ON monthly_sales(company_id, year, month);

-- Location composite index
CREATE INDEX IF NOT EXISTS idx_locations_company_type ON locations(company_id, location_type);

-- Payments composite index
CREATE INDEX IF NOT EXISTS idx_payments_bill_status ON payments(bill_id, status);
CREATE INDEX IF NOT EXISTS idx_payments_company_date ON payments(company_id, payment_date DESC);

-- Analysis: explain analyze target queries
-- SELECT * FROM bills WHERE company_id = $1 AND bill_date > $2 ORDER BY bill_date DESC LIMIT 100;
-- SELECT * FROM stock WHERE location_id = $1 AND goods_id = $2;
-- SELECT * FROM job_queue WHERE status = 'pending' ORDER BY priority DESC, created_at ASC LIMIT 1;