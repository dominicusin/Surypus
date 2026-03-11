-- ============================================================
-- Template Tables - Шаблоны документов
-- ============================================================

CREATE TABLE IF NOT EXISTS template (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(128) NOT NULL,
    ttype SMALLINT NOT NULL,  -- 0=REPORT, 1=DOCUMENT, 2=EMAIL, 3=NOTIFICATION
    content TEXT NOT NULL,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

CREATE INDEX IF NOT EXISTS idx_template_code ON template(code);
