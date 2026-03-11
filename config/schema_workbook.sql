-- ============================================================
-- Workbook Tables - Электронные таблицы
-- ============================================================

CREATE TABLE IF NOT EXISTS workbook (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sheet (
    id BIGSERIAL PRIMARY KEY,
    workbook_id BIGINT NOT NULL REFERENCES workbook(id),
    name VARCHAR(128) NOT NULL,
    row_order INT DEFAULT 0,
    flags INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS cell (
    id BIGSERIAL PRIMARY KEY,
    sheet_id BIGINT NOT NULL REFERENCES sheet(id),
    row_num INT NOT NULL,
    col_num INT NOT NULL,
    cell_type SMALLINT NOT NULL,  -- 0=EMPTY, 1=NUMBER, 2=STRING, 3=BOOLEAN
    value TEXT,
    formula VARCHAR(512),
    format VARCHAR(128)
);

CREATE INDEX IF NOT EXISTS idx_sheet_workbook ON sheet(workbook_id);
CREATE INDEX IF NOT EXISTS idx_cell_sheet ON cell(sheet_id, row_num, col_num);
