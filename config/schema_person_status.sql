-- =============================================================================
-- СТАТУСЫ ПЕРСОНАЛИЙ
-- Соответствуют Core.People.PersonStatus
-- Аналог: PPOBJ_PRSNSTATUS
-- =============================================================================

CREATE TABLE IF NOT EXISTS person_status (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO person_status (id, name, code) VALUES
(1, 'Действующий', 'ACTIVE'),
(2, 'Банкрот', 'BANKRUPT'),
(3, 'Ликвидирован', 'LIQUIDATED'),
(4, 'Приостановлен', 'SUSPENDED'),
(5, 'Недействующий', 'INACTIVE')
ON CONFLICT (id) DO NOTHING;