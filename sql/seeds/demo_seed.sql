-- Demo/Seed data for Surypus ERP
-- Realistic test data for development environment
-- Schema: V256 (UUID-based)

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

-- ============================================================
-- 2. PERSONS (Контрагенты) - 20+ entities
-- ============================================================

-- Customers
INSERT INTO persons (id, tenant_id, person_type, first_name, last_name, full_name, email, is_active, created_at)
VALUES
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a01', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'CUSTOMER', 'ООО', '"Ромашка"', 'ООО "Ромашка"', 'info@romashka.ru', true, NOW()),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'CUSTOMER', 'ЗАО', '"Технопark"', 'ЗАО "Технопark"', 'info@technopark.ru', true, NOW()),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a03', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'CUSTOMER', 'ИП', 'Иванов', 'ИП Иванов И.И.', 'ivanov@example.com', true, NOW()),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a04', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'CUSTOMER', 'ООО', '"СветоТорг"', 'ООО "СветоТорг"', 'info@svetotrg.ru', true, NOW()),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a05', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'CUSTOMER', 'АО', '"ГлобалСнаб"', 'АО "ГлобалСнаб"', 'info@global-snab.ru', true, NOW())
ON CONFLICT (id) DO NOTHING;

-- Suppliers
INSERT INTO persons (id, tenant_id, person_type, first_name, last_name, full_name, email, is_active, created_at)
VALUES
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'SUPPLIER', 'ООО', '"ПоставщикПлюс"', 'ООО "ПоставщикПлюс"', 'info@postavshikplus.ru', true, NOW()),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a12', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'SUPPLIER', 'ЗАО', '"ГудЗакуп"', 'ЗАО "ГудЗакуп"', 'info@goodzakup.ru', true, NOW()),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a13', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'SUPPLIER', 'ИП', 'Петров', 'ИП Петров П.П.', 'petrov@example.com', true, NOW()),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a14', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'SUPPLIER', 'ООО', '"СкладТранс"', 'ООО "СкладТранс"', 'info@skladtrans.ru', true, NOW()),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a15', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'SUPPLIER', 'АО', '"ЛогистикСервис"', 'АО "ЛогистикСервис"', 'info@logservice.ru', true, NOW())
ON CONFLICT (id) DO NOTHING;

-- Employees
INSERT INTO persons (id, tenant_id, person_type, first_name, last_name, full_name, email, is_active, created_at)
VALUES
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a21', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'EMPLOYEE', 'Сидоров', 'Алексей', 'Сидоров Алексей', 'sidorov@surypus.local', true, NOW()),
  ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'EMPLOYEE', 'Козлова', 'Мария', 'Козлова Мария', 'kozlova@surypus.local', true, NOW())
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 3. GOODS (Товары) - 75 entities
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM goods LIMIT 1) THEN
    FOR i IN 1..75 LOOP
      INSERT INTO goods (id, tenant_id, goods_code, goods_name, unit_of_measure, is_active, created_at)
      VALUES (
        ('c' || LPAD(i::text, 5, '0') || '-4d9e-11eb-8dcd-0242ac130003')::uuid,
        'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid,
        'GOOD-' || LPAD(i::text, 4, '0'),
        CASE 
          WHEN i <= 25 THEN 'Товар ' || i || ' (электроника)'
          WHEN i <= 50 THEN 'Товар ' || i || ' (одежда)'
          ELSE 'Товар ' || i || ' (обувь)'
        END,
        'шт',
        true,
        NOW()
      );
    END LOOP;
  END IF;
END$$;

-- ============================================================
-- 4. LOCATIONS (Склады)
-- ============================================================

INSERT INTO warehouses (id, tenant_id, warehouse_name, location_code, is_active, created_at)
VALUES 
  ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a01', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Главный склад', 'WH-01', true, NOW()),
  ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a02', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Склад МСК', 'WH-02', true, NOW()),
  ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a03', 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'Склад СПБ', 'WH-03', true, NOW())
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 5. BILLS (Документы) - 30 entities
-- ============================================================

DO $$
DECLARE
  btype TEXT;
  status TEXT;
  i INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM bills LIMIT 1) THEN
    FOR i IN 1..30 LOOP
      btype := CASE (i % 3)
        WHEN 0 THEN 'PURCHASE'
        WHEN 1 THEN 'SALES'
        ELSE 'TRANSFER'
      END;
      
      status := CASE (i % 4)
        WHEN 0 THEN 'POSTED'
        WHEN 1 THEN 'PAID'
        ELSE 'DRAFT'
      END;
      
      INSERT INTO bills (
        id, tenant_id, bill_number, bill_type, bill_date, 
        counterparty_id, total_amount, status, created_at
      ) VALUES (
        ('e' || LPAD(i::text, 5, '0') || '-4d9e-11eb-8dcd-0242ac130003')::uuid,
        'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid,
        'BILL-' || LPAD(i::text, 5, '0'),
        btype,
        CURRENT_DATE - (i * 3),
        ('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a' || LPAD((i % 15 + 1)::text, 2, '0'))::uuid,
        (1000 + (i * 50))::NUMERIC,
        status,
        NOW()
      );
    END LOOP;
  END IF;
END$$;

-- ============================================================
-- 6. ACCOUNTS (План счетов)
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
-- 7. STOCK (Остатки)
-- ============================================================

INSERT INTO stock_balances (tenant_id, goods_id, warehouse_id, quantity)
SELECT 
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'::uuid,
  g.id,
  ('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a0' || ((g.id::text::int % 3) + 1)::text)::uuid,
  ((g.id::text::int * 10) + 5)::NUMERIC
FROM goods g
WHERE g.id::text::int % 30 = 0 OR g.id::text::int <= 30
ON CONFLICT (tenant_id, goods_id, warehouse_id) DO NOTHING;

-- ============================================================
-- 8. JOBS (Задачи) - using scheduled_jobs
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
  RAISE NOTICE '- Persons: 12 suppliers/customers + 2 employees';
  RAISE NOTICE '- Goods: 75 products';
  RAISE NOTICE '- Bills: 30 documents';
  RAISE NOTICE '========================================';
END$$;