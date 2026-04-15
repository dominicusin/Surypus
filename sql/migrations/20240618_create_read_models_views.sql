-- Phase 3: Read models (accounts balances) and automatic projection via triggers
CREATE TABLE IF NOT EXISTS account_balances (
  account_id BIGINT PRIMARY KEY REFERENCES accounts(id),
  balance NUMERIC(18,2) NOT NULL DEFAULT 0,
  last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure balance derived from journal_entries (INSERT ONLY for MVP)
CREATE OR REPLACE FUNCTION recalc_account_balance_insert()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.account_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM account_balances WHERE account_id = NEW.account_id) THEN
      UPDATE account_balances
      SET balance = balance + COALESCE(NEW.debit, 0) - COALESCE(NEW.credit, 0),
          last_updated = NOW()
      WHERE account_id = NEW.account_id;
    ELSE
      INSERT INTO account_balances (account_id, balance, last_updated)
      VALUES (NEW.account_id, COALESCE(NEW.debit, 0) - COALESCE(NEW.credit, 0), NOW());
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_journal_entries_after_insert
AFTER INSERT ON journal_entries
FOR EACH ROW
EXECUTE PROCEDURE recalc_account_balance_insert();
