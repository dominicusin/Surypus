-- ============================================================================
-- V1002__performance_indexes.sql
-- Performance indexes for tables that actually exist in the schema.
-- All guarded by table-existence AND column-existence checks.
-- ============================================================================

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bills')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bills' AND column_name = 'doc_date') THEN
    CREATE INDEX IF NOT EXISTS idx_bill_doc_date_person_id ON bills(doc_date, person_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bills')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bills' AND column_name = 'status_id') THEN
    CREATE INDEX IF NOT EXISTS idx_bill_status_active ON bills(status_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bills')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bills' AND column_name = 'loc_id') THEN
    CREATE INDEX IF NOT EXISTS idx_bill_loc_id ON bills(loc_id);
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bills')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bills' AND column_name = 'op_id') THEN
    CREATE INDEX IF NOT EXISTS idx_bill_op_id ON bills(op_id);
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bill_lines') THEN
    CREATE INDEX IF NOT EXISTS idx_bill_lines_bill_id ON bill_lines(bill_id);
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'payments') THEN
    CREATE INDEX IF NOT EXISTS idx_payments_bill_id ON payments(bill_id);
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'accounts')
     AND EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'accounts' AND column_name = 'tenant_id') THEN
    CREATE INDEX IF NOT EXISTS idx_accounts_tenant ON accounts(tenant_id);
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'accounting_events') THEN
    CREATE INDEX IF NOT EXISTS idx_accounting_events_aggregate ON accounting_events(aggregate_id);
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_head') THEN
    CREATE INDEX IF NOT EXISTS idx_order_head_doc_date_person_status ON order_head(doc_date, person_id, doc_status);
    CREATE INDEX IF NOT EXISTS idx_order_head_status_active ON order_head(status);
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tech_card') THEN
    CREATE INDEX IF NOT EXISTS idx_tech_card_goods_id ON tech_card(goods_id);
    CREATE INDEX IF NOT EXISTS idx_tech_card_status ON tech_card(status);
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'work_order') THEN
    CREATE INDEX IF NOT EXISTS idx_work_order_goods_id ON work_order(goods_id);
    CREATE INDEX IF NOT EXISTS idx_work_order_status ON work_order(status);
  END IF;
END $$;