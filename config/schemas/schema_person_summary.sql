-- =============================================================================
-- Person Summary View / Stored Procedure
-- =============================================================================

CREATE OR REPLACE VIEW view_person_summary AS
SELECT
    status,
    category,
    COUNT(*) AS total_persons,
    SUM(COALESCE(credit_limit, 0)) AS total_credit_limit,
    AVG(COALESCE(discount, 0)) AS avg_discount
FROM person
GROUP BY status, category;

CREATE OR REPLACE FUNCTION get_person_summary()
RETURNS TABLE (
    status SMALLINT,
    category SMALLINT,
    total_persons BIGINT,
    total_credit_limit NUMERIC,
    avg_discount NUMERIC
)
LANGUAGE sql STABLE
AS $$
SELECT status, category, COUNT(*), SUM(COALESCE(credit_limit, 0)), AVG(COALESCE(discount, 0))
FROM person
GROUP BY status, category;
$$;
