-- V1005: Payroll results table for persisted payroll calculations
-- Implements PYR-01, PYR-02, PYR-03: Decimal precision, audit fields, tenant isolation

CREATE TABLE IF NOT EXISTS payroll_results (
    id              BIGSERIAL PRIMARY KEY,
    tenant_id       BIGINT NOT NULL REFERENCES tenants(id),
    period          DATE NOT NULL,
    employee_id     BIGINT NOT NULL,
    gross           NUMERIC(14,2) NOT NULL DEFAULT 0,
    deductions      NUMERIC(14,2) NOT NULL DEFAULT 0,
    net             NUMERIC(14,2) NOT NULL DEFAULT 0,
    income_tax      NUMERIC(14,2) NOT NULL DEFAULT 0,
    social_tax      NUMERIC(14,2) NOT NULL DEFAULT 0,
    advance         NUMERIC(14,2) NOT NULL DEFAULT 0,
    bonus           NUMERIC(14,2) NOT NULL DEFAULT 0,
    vacation_pay    NUMERIC(14,2) NOT NULL DEFAULT 0,
    sick_pay        NUMERIC(14,2) NOT NULL DEFAULT 0,
    total_to_pay    NUMERIC(14,2) NOT NULL DEFAULT 0,
    currency        TEXT NOT NULL DEFAULT 'RUB',
    version         INT NOT NULL DEFAULT 1,
    created_by      BIGINT REFERENCES users(id),
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payroll_results_tenant_period
    ON payroll_results(tenant_id, period);
CREATE INDEX IF NOT EXISTS idx_payroll_results_tenant_employee
    ON payroll_results(tenant_id, employee_id);
CREATE INDEX IF NOT EXISTS idx_payroll_results_period
    ON payroll_results(period);

GRANT SELECT, INSERT, UPDATE ON payroll_results TO surypus_app;
GRANT USAGE, SELECT ON SEQUENCE payroll_results_id_seq TO surypus_app;
