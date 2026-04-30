-- ============================================================
-- Category Tables - Категории
-- ============================================================

CREATE TABLE IF NOT EXISTS category (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(128) NOT NULL,
    parent_id BIGINT REFERENCES category(id),
    flags INTEGER DEFAULT 0,
    UNIQUE(code)
);

CREATE INDEX IF NOT EXISTS idx_category_parent ON category(parent_id);
