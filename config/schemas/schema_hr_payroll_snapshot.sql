-- ============================================================================
-- HR Payroll Snapshot - Журнал снимков зарплатных сводок
-- ============================================================================

CREATE TABLE IF NOT EXISTS hr_payroll_snapshot (
    id BIGSERIAL PRIMARY KEY,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    summary JSONB NOT NULL DEFAULT '[]'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_hr_payroll_snapshot_period ON hr_payroll_snapshot(period_start, period_end);

-- Записываем данные сводки по сотрудникам
CREATE OR REPLACE FUNCTION log_hr_payroll_snapshot(
    p_period_start DATE,
    p_period_end DATE
) RETURNS BIGINT AS $$
DECLARE
    v_summary JSONB;
BEGIN
    SELECT jsonb_agg(row_to_json(t))
    INTO v_summary
    FROM (
        SELECT employee_id, employee_name, position_name, total_salary
        FROM hr_payroll_summary(p_period_start, p_period_end)
    ) AS t;

    INSERT INTO hr_payroll_snapshot (period_start, period_end, summary)
    VALUES (p_period_start, p_period_end, COALESCE(v_summary, '[]'::jsonb))
    RETURNING id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW v_hr_payroll_snapshot AS
SELECT id, period_start, period_end, created_at, summary
FROM hr_payroll_snapshot
ORDER BY created_at DESC;
