-- =============================================================================
-- ДОЛЖНОСТИ
-- Соответствуют Core.HR.Position
-- Аналог: PPOBJ_STAFFRANK
-- =============================================================================

CREATE TABLE IF NOT EXISTS position (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    category INT DEFAULT 0,  -- 0:General, 1:Management, 2:Specialist, 3:Worker
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_position_category ON position(category);

-- DEFAULT DATA
INSERT INTO position (id, name, code, category) VALUES
(1, 'Генеральный директор', 'CEO', 1),
(2, 'Заместитель директора', 'DEPUTY', 1),
(3, 'Главный бухгалтер', 'CFO', 1),
(4, 'Начальник отдела', 'HEAD', 1),
(5, 'Бухгалтер', 'ACCOUNTANT', 2),
(6, 'Экономист', 'ECONOMIST', 2),
(7, 'Менеджер', 'MANAGER', 2),
(8, 'Кассир', 'CASHIER', 2),
(9, 'Кладовщик', 'WAREHOUSEMAN', 3),
(10, 'Продавец', 'SELLER', 3),
(11, 'Водитель', 'DRIVER', 3),
(12, 'Охранник', 'SECURITY', 3),
(13, 'Уборщик', 'CLEANER', 3)
ON CONFLICT (id) DO NOTHING;
