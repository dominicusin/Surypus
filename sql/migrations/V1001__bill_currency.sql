-- Migration V1001: Add currency_id and exchange_rate to bill table
ALTER TABLE bills ADD COLUMN IF NOT EXISTS currency_id TEXT NOT NULL DEFAULT 'RUB';
ALTER TABLE bills ADD COLUMN IF NOT EXISTS exchange_rate DOUBLE PRECISION NOT NULL DEFAULT 1.0;

