-- Migration V1001: Add currency_id and exchange_rate to bill table
ALTER TABLE bill ADD COLUMN currency_id TEXT NOT NULL DEFAULT 'RUB';
ALTER TABLE bill ADD COLUMN exchange_rate DOUBLE PRECISION NOT NULL DEFAULT 1.0;

