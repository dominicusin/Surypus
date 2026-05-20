-- V187: Bank statement import tables (OFX/ISO 20022)
CREATE TABLE IF NOT EXISTS bank_statement_import (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL,
    filename    TEXT NOT NULL,
    format      TEXT NOT NULL CHECK (format IN ('OFX', 'ISO20022', 'CSV')),
    bank_name   TEXT,
    account_no  TEXT,
    date_from   DATE,
    date_to     DATE,
    total_rows  INT DEFAULT 0,
    imported_at TIMESTAMPTZ DEFAULT NOW(),
    status      TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'done', 'error')),
    error_msg   TEXT
);

CREATE TABLE IF NOT EXISTS bank_statement_line (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    import_id       UUID NOT NULL REFERENCES bank_statement_import(id) ON DELETE CASCADE,
    txn_date        DATE NOT NULL,
    value_date      DATE,
    amount          NUMERIC NOT NULL,
    currency        TEXT DEFAULT 'RUB',
    description     TEXT,
    ref_number      TEXT,
    counterparty    TEXT,
    is_matched      BOOLEAN DEFAULT FALSE,
    matched_bill_id BIGINT,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bsl_import ON bank_statement_line(import_id);
CREATE INDEX IF NOT EXISTS idx_bsl_date   ON bank_statement_line(txn_date);
CREATE INDEX IF NOT EXISTS idx_bsl_match  ON bank_statement_line(is_matched);
