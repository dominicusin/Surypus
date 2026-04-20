-- Seed data for development/testing
-- 1) 50 Goods
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM goods) THEN RAISE NOTICE 'goods already seeded'; ELSE
  FOR i IN 1..75 LOOP
    INSERT INTO goods (name, price, company_id, goods_type, created_at) VALUES ('Product ' || i, ((i * 12) + 5)::numeric, 1, 'standard', NOW());
  END LOOP;
  END IF;
END$$;

-- 2) 20 Bills
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM bills) THEN RAISE NOTICE 'bills already seeded'; ELSE
  FOR i IN 21..25 LOOP
    INSERT INTO bills (company_id, bill_number, bill_date, total, status, created_at) VALUES (1, 'BILL-' || LPAD(i::text, 4, '0'), CURRENT_DATE - (i * 7), (100 * i)::numeric, 'pending', NOW());
  END LOOP;
  END IF;
END$$;

-- 3) 5 Roles (RBAC)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM roles WHERE name = 'Role_6') THEN
    INSERT INTO roles (name, description, created_at) VALUES ('Role_6', 'Seeded role 6', NOW());
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM roles WHERE name IN ('Role_1','Role_2','Role_3','Role_4','Role_5')) THEN
    INSERT INTO roles (name, description, created_at) VALUES
      ('Role_1','Seeded role 1', NOW()),
      ('Role_2','Seeded role 2', NOW()),
      ('Role_3','Seeded role 3', NOW()),
      ('Role_4','Seeded role 4', NOW()),
      ('Role_5','Seeded role 5', NOW());
  END IF;
END$$;
