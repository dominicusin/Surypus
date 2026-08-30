-- V013: Composite indexes for common query patterns
-- Improves pagination and filtered queries performance

-- Bills composite indexes for common access patterns
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bills') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bills' AND column_name='company_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bills' AND column_name='bill_date') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_bills_company_date ON bills(company_id, bill_date DESC)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bills') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bills' AND column_name='person_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bills' AND column_name='status') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_bills_person_status ON bills(person_id, status)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bills') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bills' AND column_name='location_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bills' AND column_name='bill_type') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bills' AND column_name='bill_date') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_bills_location_type_date ON bills(location_id, bill_type, bill_date DESC)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bills') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bills' AND column_name='status') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='bills' AND column_name='bill_date') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_bills_status_date ON bills(status, bill_date DESC)';
  END IF;
END $$;

-- Goods composite indexes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'goods') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='goods' AND column_name='company_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='goods' AND column_name='goods_type') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_goods_company_type ON goods(company_id, goods_type)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'goods') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='goods' AND column_name='company_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='goods' AND column_name='name') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_goods_name_search ON goods(company_id, name)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'goods') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='goods' AND column_name='company_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='goods' AND column_name='barcode') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_goods_barcode ON goods(company_id, barcode)';
  END IF;
END $$;

-- Stock composite indexes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stock') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='stock' AND column_name='location_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='stock' AND column_name='goods_id') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_stock_location_goods ON stock(location_id, goods_id)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stock') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='stock' AND column_name='goods_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='stock' AND column_name='location_id') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_stock_goods_location ON stock(goods_id, location_id)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stock_lot') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='stock_lot' AND column_name='goods_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='stock_lot' AND column_name='lot_date') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_stock_lot_goods_date ON stock_lot(goods_id, lot_date)';
  END IF;
END $$;

-- Persons composite indexes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'persons') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='company_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='person_type') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_persons_company_type ON persons(company_id, person_type)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'persons') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='company_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='persons' AND column_name='name') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_persons_name_search ON persons(company_id, name)';
  END IF;
END $$;

-- Orders composite indexes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'orders') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='company_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='status') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='order_date') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_company_status_date ON orders(company_id, status, order_date DESC)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'orders') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='person_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='orders' AND column_name='order_date') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_orders_person ON orders(person_id, order_date DESC)';
  END IF;
END $$;

-- Accounting turns composite indexes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'accounting_turns') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='accounting_turns' AND column_name='turn_date') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_acc_turns_date ON accounting_turns(turn_date)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'accounting_turns') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='accounting_turns' AND column_name='credit_acc_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='accounting_turns' AND column_name='turn_date') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_acc_turns_account_date ON accounting_turns(credit_acc_id, turn_date)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'accounting_turns') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='accounting_turns' AND column_name='debit_acc_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='accounting_turns' AND column_name='turn_date') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_acc_turns_debit_date ON accounting_turns(debit_acc_id, turn_date)';
  END IF;
END $$;

-- Job queue composite index for pending job selection
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'job_queue') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='job_queue' AND column_name='status') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='job_queue' AND column_name='priority') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='job_queue' AND column_name='created_at') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_job_queue_status_priority_date ON job_queue(status, priority DESC, created_at ASC)';
  END IF;
END $$;

-- Audit log composite indexes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'audit_log') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='audit_log' AND column_name='company_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='audit_log' AND column_name='created_at') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_audit_log_company_time ON audit_log(company_id, created_at DESC)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'audit_log') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='audit_log' AND column_name='user_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='audit_log' AND column_name='created_at') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_audit_log_user_time ON audit_log(user_id, created_at DESC)';
  END IF;
END $$;

-- Refresh token index for cleanup
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'refresh_tokens') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='refresh_tokens' AND column_name='expires_at') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires ON refresh_tokens(expires_at)';
  END IF;
END $$;

-- RBAC grants composite index
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'rbac_grants') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='rbac_grants' AND column_name='role_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='rbac_grants' AND column_name='subject_id') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_rbac_grants_role_subject ON rbac_grants(role_id, subject_id) WHERE deleted_at IS NULL';
  END IF;
END $$;

-- Analysis tables for dashboard queries
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'daily_sales') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='daily_sales' AND column_name='company_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='daily_sales' AND column_name='date') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_daily_sales_company_date ON daily_sales(company_id, date DESC)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'monthly_sales') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='monthly_sales' AND column_name='company_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='monthly_sales' AND column_name='year') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='monthly_sales' AND column_name='month') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_monthly_sales_company_date ON monthly_sales(company_id, year, month)';
  END IF;
END $$;

-- Location composite index
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'locations') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='locations' AND column_name='company_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='locations' AND column_name='location_type') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_locations_company_type ON locations(company_id, location_type)';
  END IF;
END $$;

-- Payments composite index
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payments') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='payments' AND column_name='bill_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='payments' AND column_name='status') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_payments_bill_status ON payments(bill_id, status)';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payments') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='payments' AND column_name='company_id') AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='payments' AND column_name='payment_date') THEN
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_payments_company_date ON payments(company_id, payment_date DESC)';
  END IF;
END $$;

-- Analysis: explain analyze target queries
-- SELECT * FROM bills WHERE company_id = $1 AND bill_date > $2 ORDER BY bill_date DESC LIMIT 100;
-- SELECT * FROM stock WHERE location_id = $1 AND goods_id = $2;
-- SELECT * FROM job_queue WHERE status = 'pending' ORDER BY priority DESC, created_at ASC LIMIT 1;