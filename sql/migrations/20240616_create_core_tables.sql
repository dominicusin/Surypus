-- Phase 2 Core tables (Users, RBAC, Accounts, Journals, Bills, Payments, Taxes)
CREATE TABLE IF NOT EXISTS users (
  id BIGINT PRIMARY KEY DEFAULT NEXTVAL('users_id_seq'),
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  email TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS roles (
  id BIGINT PRIMARY KEY DEFAULT NEXTVAL('roles_id_seq'),
  name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS permissions (
  id BIGINT PRIMARY KEY DEFAULT NEXTVAL('permissions_id_seq'),
  name TEXT UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS user_roles (
  user_id BIGINT REFERENCES users(id),
  role_id BIGINT REFERENCES roles(id),
  PRIMARY KEY (user_id, role_id)
);

CREATE TABLE IF NOT EXISTS role_permissions (
  role_id BIGINT REFERENCES roles(id),
  permission_id BIGINT REFERENCES permissions(id),
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS accounts (
  id BIGINT PRIMARY KEY DEFAULT NEXTVAL('accounts_id_seq'),
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  type TEXT,
  currency CHAR(3),
  description TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS journal_entries (
  id BIGINT PRIMARY KEY DEFAULT NEXTVAL('journal_entries_id_seq'),
  account_id BIGINT REFERENCES accounts(id),
  debit NUMERIC(18,2) DEFAULT 0,
  credit NUMERIC(18,2) DEFAULT 0,
  amount NUMERIC(18,2),
  currency CHAR(3),
  date TIMESTAMPTZ,
  description TEXT,
  posted BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS bills (
  id BIGINT PRIMARY KEY DEFAULT NEXTVAL('bills_id_seq'),
  number TEXT UNIQUE,
  date TIMESTAMPTZ,
  currency CHAR(3),
  total_amount NUMERIC(18,2),
  status TEXT
);

CREATE TABLE IF NOT EXISTS payments (
  id BIGINT PRIMARY KEY DEFAULT NEXTVAL('payments_id_seq'),
  payment_ref UUID UNIQUE,
  bill_id BIGINT REFERENCES bills(id),
  amount NUMERIC(18,2),
  status TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  confirmed_at TIMESTAMPTZ,
  settled_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS tax_rates (
  code TEXT PRIMARY KEY,
  rate NUMERIC(5,4),
  effective_from TIMESTAMPTZ,
  active BOOLEAN
);
