-- ============================================================
-- AccMask Tables - Маски проводок
-- ============================================================

CREATE TABLE IF NOT EXISTS acc_mask (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(128) NOT NULL,
    op_kind_id BIGINT NOT NULL,
    debit_acc_id BIGINT NOT NULL,
    credit_acc_id BIGINT NOT NULL,
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

CREATE INDEX IF NOT EXISTS idx_acc_mask_op_kind ON acc_mask(op_kind_id);
