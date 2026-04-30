- -- Add index to speed up ledger lookups by ref_type/ref_id
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ledger_entry_ref ON ledger_entry (ref_type, ref_id);
