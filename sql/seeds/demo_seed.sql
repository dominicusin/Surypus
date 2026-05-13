-- Demo/Seed data for Surypus ERP
-- Realistic test data for development environment
-- Compatible with core schema (V001 + basic migrations)

-- ============================================================
-- 1. USERS & ROLES
-- ============================================================

-- Test users with different roles
INSERT INTO users (username, password_hash, email, is_active, created_at, updated_at)
VALUES 
  ('admin', crypt('admin123', gen_salt('bf')), 'admin@surypus.local', true, NOW(), NOW()),
  ('accountant', crypt('accountant123', gen_salt('bf')), 'accountant@surypus.local', true, NOW(), NOW()),
  ('viewer', crypt('viewer123', gen_salt('bf')), 'viewer@surypus.local', true, NOW(), NOW()),
  ('manager', crypt('manager123', gen_salt('bf')), 'manager@surypus.local', true, NOW(), NOW())
ON CONFLICT (username) DO NOTHING;

-- Assign roles
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u, roles r WHERE u.username = 'admin' AND r.name = 'admin'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u, roles r WHERE u.username = 'accountant' AND r.name = 'accountant'
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id FROM users u, roles r WHERE u.username = 'viewer' AND r.name = 'viewer'
ON CONFLICT DO NOTHING;

-- ============================================================
-- 2. ROLES (if not exist from basic_seed.sql)
-- ============================================================

INSERT INTO roles (name) VALUES ('admin'), ('accountant'), ('viewer')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- 3. ACCOUNTS (План счетов)
-- ============================================================

INSERT INTO accounts (code, name, type, currency, description, is_active)
VALUES
  ('4001', 'Касса', 'Asset', 'RUB', 'Наличные денежные средства', true),
  ('4002', 'Расчетный счет', 'Asset', 'RUB', 'Банковский счет', true),
  ('4003', 'Товары', 'Asset', 'RUB', 'Товарный запас', true),
  ('6001', 'Выручка', 'Income', 'RUB', 'Основная выручка', true),
  ('6002', 'Себестоимость', 'Income', 'RUB', 'Себестоимость продаж', true),
  ('7001', 'Зарплата', 'Expense', 'RUB', 'Оплата труда', true),
  ('7002', 'Аренда', 'Expense', 'RUB', 'Арендная плата', true)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- 4. GOODS (Товары) - 75 entities
-- ============================================================

DO $$
DECLARE
  i INT;
BEGIN
  FOR i IN 1..75 LOOP
    INSERT INTO goods (id, name, price, company_id, goods_type, created_at)
    VALUES (
      1000 + i,
      'Товар ' || i || CASE 
        WHEN i <= 25 THEN ' (электроника)'
        WHEN i <= 50 THEN ' (одежда)'
        ELSE ' (обувь)'
      END,
      (100 + i * 5)::NUMERIC,
      1,
      'standard',
      NOW()
    ) ON CONFLICT (id) DO NOTHING;
  END LOOP;
END$$;

-- ============================================================
-- 5. BILLS (Документы) - 30 entities
-- ============================================================

DO $$
DECLARE
  i INT;
  btype INT;
  status TEXT;
BEGIN
  FOR i IN 1..30 LOOP
    btype := CASE (i % 3)
      WHEN 0 THEN 1  -- Purchase
      WHEN 1 THEN 2  -- Sales
      ELSE 3         -- Transfer
    END;
    
    status := CASE (i % 4)
      WHEN 0 THEN 'posted'
      WHEN 1 THEN 'paid'
      ELSE 'draft'
    END;
    
    INSERT INTO bills (
      id, company_id, bill_number, bill_date, 
      total_amount, status, created_at
    ) VALUES (
      2000 + i,
      1,
      'BILL-' || LPAD(i::text, 5, '0'),
      CURRENT_DATE - (i * 3),
      (1000 + (i * 50))::NUMERIC,
      status,
      NOW()
    ) ON CONFLICT (id) DO NOTHING;
  END LOOP;
END$$;

-- ============================================================
-- 6. STOCK BALANCES
-- ============================================================

DO $$
DECLARE
  i INT;
BEGIN
  FOR i IN 1..30 LOOP
    INSERT INTO stock (goods_id, location_id, quantity, reserved_quantity)
    VALUES (
      1000 + i,
      (i % 3) + 1,
      ((i * 10) + 5)::NUMERIC,
      (i % 5)::NUMERIC
    ) ON CONFLICT (goods_id, location_id) DO NOTHING;
  END LOOP;
END$$;

-- ============================================================
-- 7. JOBS TABLE (if exists in schema, populate)
-- ============================================================

INSERT INTO scheduled_jobs (job_name, function_name, schedule_interval, is_active)
VALUES
  ('Report Generation Demo', 'health_record', INTERVAL '1 hour', true),
  ('Data Export Demo', 'outbox_cleanup', INTERVAL '30 minutes', true)
ON CONFLICT (job_name) DO NOTHING;

-- ============================================================
-- COMPLETION NOTICE
-- ============================================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Demo seed complete!';
  RAISE NOTICE '- Users: admin/admin123, accountant/accountant123, viewer/viewer123';
  RAISE NOTICE '- Goods: 75 products (id 1001-1075)';
  RAISE NOTICE '- Bills: 30 documents (id 2001-2030)';
  RAISE NOTICE '========================================';
END$$;